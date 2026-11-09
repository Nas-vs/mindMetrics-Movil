-- =====================================================================
-- RF-09 · Recomendación del día
-- Back: Juliana Pérez · Front: Julián Gómez
--
-- Qué crea:
--   1. recomendaciones            → catálogo (CA-2). Lo administra el
--                                   backend; la app lo puede leer y guardar
--                                   una copia local para usarlo sin conexión.
--   2. recomendaciones_mostradas  → cuál se mostró cada día (CA-3).
--   3. RPC recomendacion_del_dia  → elige la de hoy con las reglas (CA-2).
--
-- Las reglas (las mismas que debe replicar la app sin conexión):
--   - Con registro de ánimo hoy: aplica si nivel_min <= nivel <= nivel_max.
--     Suma 2 puntos si su emoción está entre las de hoy y 1 si su factor
--     está entre los de hoy; gana la de más puntos.
--   - Sin registro hoy: solo las marcadas sin_registro.
--   - Nunca la misma que ayer (CA-3).
--   - Empates: un orden "al azar" que depende del usuario y del día, así
--     cambia de un día a otro pero no cada vez que se abre la app.
--   - Pull-to-refresh (CA-4) vuelve a llamar la RPC: si el ánimo de hoy
--     cambió, la recomendación cambia; si no, se mantiene.
--
-- El botón (CA-1) usa una "acción" y no una ruta: la app traduce la
-- acción a su ruta (Rutas.*). Así, si una ruta cambia de nombre, el
-- catálogo no se rompe. Las acciones de pantallas que aún no existen
-- se pueden ocultar en la app hasta que se construyan.
--   respiracion       → RF-18 Respiración sostenida
--   tension           → RF-19 Tensión y respiración
--   memoria_emociones → RF-17 Memoria de emociones
--   jardin            → RF-16 Jardín emocional
--   juegos            → RF-14 Catálogo de juegos
--   actividades       → RF-12 Registrar actividades
--   habitos           → RF-13 Registro diario de hábitos
--   calendario        → RF-11 Calendario emocional
--   encuesta          → RF-20 Responder encuesta
--   cita              → RF-21 Agendar cita
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Catálogo
-- ---------------------------------------------------------------------
create table public.recomendaciones (
  id            smallint primary key,
  titulo        text not null check (char_length(titulo) between 1 and 60),
  descripcion   text not null check (char_length(descripcion) between 1 and 200),
  accion        text check (accion in (
                  'respiracion', 'tension', 'memoria_emociones', 'jardin', 'juegos',
                  'actividades', 'habitos', 'calendario', 'encuesta', 'cita')),
  -- Texto del botón, ej. "Probar ahora". Va junto con accion.
  texto_accion  text check (char_length(texto_accion) <= 30),
  -- Rango de ánimo (1–5) en el que aplica
  nivel_min     smallint not null default 1 check (nivel_min between 1 and 5),
  nivel_max     smallint not null default 5 check (nivel_max between 1 and 5),
  -- Opcionales: dan prioridad si coinciden con los chips de hoy (RF-08 CA-4)
  emocion_id    smallint references public.emociones (id),
  factor_id     smallint references public.factores (id),
  -- true: se usa cuando el usuario aún no registra su ánimo hoy
  sin_registro  boolean not null default false,
  activo        boolean not null default true,

  constraint recomendaciones_rango_valido check (nivel_min <= nivel_max),
  constraint recomendaciones_accion_con_texto
    check ((accion is null) = (texto_accion is null))
);

comment on table public.recomendaciones is
  'RF-09: catálogo de recomendaciones. Lo administra el backend; la app guarda una copia local.';

alter table public.recomendaciones enable row level security;

revoke all on public.recomendaciones from anon, authenticated;
grant select on public.recomendaciones to authenticated;

create policy "usuarios leen las recomendaciones activas"
  on public.recomendaciones for select to authenticated
  using (activo);


-- ---------------------------------------------------------------------
-- 2. Historial: una recomendación por usuario y por día
-- ---------------------------------------------------------------------
create table public.recomendaciones_mostradas (
  usuario_id        uuid not null references auth.users (id) on delete cascade,
  -- Día LOCAL del usuario (lo envía la app)
  fecha             date not null,
  recomendacion_id  smallint not null references public.recomendaciones (id),
  mostrada_en       timestamptz not null default now(),
  primary key (usuario_id, fecha)
);

comment on table public.recomendaciones_mostradas is
  'RF-09 CA-3: qué recomendación se mostró cada día, para no repetirla al día siguiente.';

alter table public.recomendaciones_mostradas enable row level security;

revoke all on public.recomendaciones_mostradas from anon, authenticated;
grant select on public.recomendaciones_mostradas to authenticated;

create policy "cada usuario ve sus recomendaciones mostradas"
  on public.recomendaciones_mostradas for select to authenticated
  using ((select auth.uid()) = usuario_id);


-- ---------------------------------------------------------------------
-- 3. RPC: recomendación del día
--
-- Uso desde la app (al abrir el Inicio y en pull-to-refresh):
--   await supabase.rpc('recomendacion_del_dia',
--       params: {'p_fecha': '2026-11-09'});   // día local, AAAA-MM-DD
-- Devuelve {id, titulo, descripcion, accion, texto_accion}.
-- ---------------------------------------------------------------------
create function public.recomendacion_del_dia(p_fecha date)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usuario    uuid := auth.uid();
  v_registro   public.registros_animo%rowtype;
  v_emociones  smallint[] := '{}';
  v_factores   smallint[] := '{}';
  v_ayer       smallint;
  v_elegida    public.recomendaciones%rowtype;
begin
  if v_usuario is null then
    raise exception 'sesion_requerida';
  end if;

  if p_fecha is null or p_fecha > current_date + 1 or p_fecha < current_date - 1 then
    raise exception 'fecha_invalida'
      using hint = 'Se envía el día local de hoy (AAAA-MM-DD).';
  end if;

  -- Registro de ánimo de hoy, con sus chips (RF-08)
  select * into v_registro
  from public.registros_animo
  where usuario_id = v_usuario and fecha = p_fecha;

  if found then
    select coalesce(array_agg(emocion_id), '{}') into v_emociones
    from public.registro_emociones where registro_id = v_registro.id;

    select coalesce(array_agg(factor_id), '{}') into v_factores
    from public.registro_factores where registro_id = v_registro.id;
  end if;

  -- La de ayer no se repite (CA-3)
  select recomendacion_id into v_ayer
  from public.recomendaciones_mostradas
  where usuario_id = v_usuario and fecha = p_fecha - 1;

  -- Reglas (ver encabezado)
  select r.* into v_elegida
  from public.recomendaciones r
  where r.activo
    and r.id is distinct from v_ayer
    and case
          when v_registro.id is null then r.sin_registro
          else not r.sin_registro
               and v_registro.nivel between r.nivel_min and r.nivel_max
        end
  order by
    (case when r.emocion_id = any (v_emociones) then 2 else 0 end
     + case when r.factor_id = any (v_factores) then 1 else 0 end) desc,
    md5(v_usuario::text || p_fecha::text || r.id::text)
  limit 1;

  -- Respaldo: si las reglas no dejan ninguna, cualquiera activa que no
  -- sea la de ayer (así la tarjeta nunca queda vacía).
  if v_elegida.id is null then
    select r.* into v_elegida
    from public.recomendaciones r
    where r.activo and r.id is distinct from v_ayer
    order by md5(v_usuario::text || p_fecha::text || r.id::text)
    limit 1;
  end if;

  if v_elegida.id is null then
    return null;  -- catálogo vacío
  end if;

  insert into public.recomendaciones_mostradas (usuario_id, fecha, recomendacion_id)
  values (v_usuario, p_fecha, v_elegida.id)
  on conflict (usuario_id, fecha) do update
    set recomendacion_id = excluded.recomendacion_id,
        mostrada_en      = now();

  return jsonb_build_object(
    'id',           v_elegida.id,
    'titulo',       v_elegida.titulo,
    'descripcion',  v_elegida.descripcion,
    'accion',       v_elegida.accion,
    'texto_accion', v_elegida.texto_accion
  );
end;
$$;

revoke execute on function public.recomendacion_del_dia(date) from public, anon;
grant  execute on function public.recomendacion_del_dia(date) to authenticated;


-- ---------------------------------------------------------------------
-- 4. Catálogo inicial
-- Lenguaje cercano y sin diagnósticos: son sugerencias, no indicaciones
-- clínicas. Emociones y factores: ids del catálogo de RF-08.
-- ---------------------------------------------------------------------
insert into public.recomendaciones
  (id, titulo, descripcion, accion, texto_accion, nivel_min, nivel_max, emocion_id, factor_id, sin_registro)
values
  -- Sin registro de hoy
  (1,  '¿Cómo vas hoy?',
       'Tomarte un momento para notar cómo te sientes ya es un paso. Registra tu ánimo arriba.',
       null, null, 1, 5, null, null, true),
  (2,  'Una pausa para respirar',
       'Unos minutos de respiración lenta ayudan a empezar el día con más calma.',
       'respiracion', 'Probar ahora', 1, 5, null, null, true),

  -- Ánimo bajo (1–2)
  (3,  'Respira despacio',
       'Inhala en 4 tiempos, sostén y exhala en 6. Repetirlo unas veces puede bajar la tensión.',
       'respiracion', 'Probar ahora', 1, 2, null, null, false),
  (4,  'Suelta la tensión del cuerpo',
       'Tensar y soltar los músculos por zonas ayuda a liberar lo que el día acumula.',
       'tension', 'Probar ahora', 1, 3, 8, null, false),
  (5,  'Habla con alguien de confianza',
       'Contarle a alguien cercano cómo te sientes puede hacer el día más llevadero.',
       null, null, 1, 2, 12, null, false),
  (6,  'No tienes que hacerlo sola o solo',
       'Si estos días se sienten pesados, hablar con un profesional puede ayudarte.',
       'cita', 'Agendar cita', 1, 2, 6, null, false),
  (7,  'Calma la mente',
       'Cuando la preocupación crece, respirar con ritmo ayuda a volver al presente.',
       'respiracion', 'Probar ahora', 1, 4, 7, null, false),

  -- Ánimo medio (2–4)
  (8,  'Muévete un poco',
       'Una caminata corta o estirarte unos minutos le da un respiro a la mente.',
       null, null, 2, 4, 10, 8, false),
  (9,  'Descansa de la pantalla',
       'Aléjate del celular unos minutos: mira lejos, toma agua y estírate.',
       null, null, 2, 5, null, 2, false),
  (10, 'Ponle nombre a lo que sientes',
       'Reconocer tus emociones te ayuda a entenderlas mejor. Juega a la memoria de emociones.',
       'memoria_emociones', 'Jugar', 2, 4, 11, null, false),
  (11, 'Cuida tu descanso',
       'Dormir bien cambia cómo vives el día. Intenta acostarte un poco más temprano hoy.',
       null, null, 1, 4, 10, 1, false),
  (12, 'Divide la tarea',
       'Si el estudio o el trabajo pesan, parte lo pendiente en pasos pequeños y empieza por uno.',
       null, null, 2, 4, null, 3, false),

  -- Ánimo alto (4–5)
  (13, 'Anota lo bueno',
       'Escribe tres cosas por las que hoy te sientes agradecida o agradecido.',
       null, null, 4, 5, 3, null, false),
  (14, 'Cuida tu jardín',
       'Los días buenos también cuentan: riega tu jardín emocional.',
       'jardin', 'Ir al jardín', 3, 5, 1, null, false),
  (15, 'Aprovecha la energía',
       'Registra lo que hiciste hoy y mira qué actividades te hacen bien.',
       'actividades', 'Registrar', 4, 5, 4, null, false),
  (16, 'Comparte el momento',
       'Escríbele a alguien que quieras. Las buenas noticias se disfrutan más acompañadas.',
       null, null, 4, 5, null, 6, false);
