-- ---------------------------------------------------------------------
-- 1. Catálogos
-- ---------------------------------------------------------------------
create table public.emociones (
  id          smallint primary key,
  nombre      text not null unique,
  definicion  text not null,            -- la usa RF-17 (Memoria de emociones)
  orden       smallint not null,
  activo      boolean not null default true
);

create table public.factores (
  id      smallint primary key,
  nombre  text not null unique,
  orden   smallint not null,
  activo  boolean not null default true
);

comment on table public.emociones is 'RF-08 CA-4: chips de emociones. También RF-17.';
comment on table public.factores  is 'RF-08 CA-4: chips de factores (qué influyó en el ánimo).';

-- Los usuarios con sesión pueden leerlos; nadie los modifica desde la app.
alter table public.emociones enable row level security;
alter table public.factores  enable row level security;

create policy "usuarios leen emociones" on public.emociones
  for select to authenticated using (true);
create policy "usuarios leen factores" on public.factores
  for select to authenticated using (true);

insert into public.emociones (id, nombre, definicion, orden) values
  (1,  'Alegría',     'Sensación de bienestar y gusto por lo que está pasando.',            1),
  (2,  'Calma',       'Estado de tranquilidad, sin tensión ni prisa.',                      2),
  (3,  'Gratitud',    'Aprecio por algo bueno que recibiste o que tienes.',                 3),
  (4,  'Motivación',  'Ganas y energía para empezar o seguir algo.',                        4),
  (5,  'Esperanza',   'Confianza en que algo puede mejorar.',                               5),
  (6,  'Tristeza',    'Sentimiento de pérdida o desánimo que pide calma y apoyo.',          6),
  (7,  'Ansiedad',    'Preocupación por lo que podría pasar, a veces con tensión física.',  7),
  (8,  'Enojo',       'Reacción ante algo que sientes injusto o que te frena.',             8),
  (9,  'Miedo',       'Alerta ante algo que percibes como peligroso o incierto.',           9),
  (10, 'Cansancio',   'Falta de energía física o mental.',                                  10),
  (11, 'Frustración', 'Malestar cuando algo no sale como esperabas.',                       11),
  (12, 'Soledad',     'Sensación de no tener con quién compartir o conectar.',              12);

insert into public.factores (id, nombre, orden) values
  (1,  'Sueño',        1),
  (2,  'Estudio',      2),
  (3,  'Trabajo',      3),
  (4,  'Familia',      4),
  (5,  'Pareja',       5),
  (6,  'Amigos',       6),
  (7,  'Salud',        7),
  (8,  'Ejercicio',    8),
  (9,  'Alimentación', 9),
  (10, 'Dinero',       10),
  (11, 'Clima',        11);


-- ---------------------------------------------------------------------
-- 2. Registros de ánimo (CA-1: uno por usuario y por día)
-- ---------------------------------------------------------------------
create table public.registros_animo (
  -- El id lo genera la APP (UUID) para poder guardar sin conexión (CA-6)
  id                      uuid primary key,
  usuario_id              uuid not null references auth.users (id) on delete cascade,
  -- Día LOCAL del usuario (lo envía la app). Así "hoy" es el hoy de Colombia,
  -- no el del servidor (UTC).
  fecha                   date not null,
  nivel                   smallint not null check (nivel between 1 and 5),  -- CA-2: 5 emojis
  nota                    text check (char_length(nota) <= 500),
  creado_en               timestamptz not null default now(),
  actualizado_en          timestamptz not null default now(),
  -- edición vieja que llega tarde (sin conexión) no pise una más nueva.
  actualizado_en_cliente  timestamptz not null,
  unique (usuario_id, fecha)
);

comment on table public.registros_animo is
  'RF-08: un registro de ánimo por usuario y por día (nivel 1 a 5).';

create index registros_animo_usuario_fecha_idx
  on public.registros_animo (usuario_id, fecha desc);

create table public.registro_emociones (
  registro_id  uuid not null references public.registros_animo (id) on delete cascade,
  emocion_id   smallint not null references public.emociones (id),
  primary key (registro_id, emocion_id)
);

create table public.registro_factores (
  registro_id  uuid not null references public.registros_animo (id) on delete cascade,
  factor_id    smallint not null references public.factores (id),
  primary key (registro_id, factor_id)
);

alter table public.registros_animo    enable row level security;
alter table public.registro_emociones enable row level security;
alter table public.registro_factores  enable row level security;

create policy "cada usuario ve sus registros de animo"
  on public.registros_animo for select to authenticated
  using ((select auth.uid()) = usuario_id);

create policy "cada usuario ve las emociones de sus registros"
  on public.registro_emociones for select to authenticated
  using (exists (
    select 1 from public.registros_animo r
    where r.id = registro_id and r.usuario_id = (select auth.uid())
  ));

create policy "cada usuario ve los factores de sus registros"
  on public.registro_factores for select to authenticated
  using (exists (
    select 1 from public.registros_animo r
    where r.id = registro_id and r.usuario_id = (select auth.uid())
  ));

create function public.guardar_registro_animo(
  p_id              uuid,
  p_fecha           date,
  p_nivel           int,
  p_emociones       int[] default null,
  p_factores        int[] default null,
  p_nota            text default null,
  p_actualizado_en  timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usuario   uuid := auth.uid();
  v_existente public.registros_animo%rowtype;
  v_id        uuid;
  v_aplicado  boolean := true;
begin
  -- ---------- Validaciones ----------
  if v_usuario is null then
    raise exception 'sesion_requerida';
  end if;

  if p_id is null or p_fecha is null or p_nivel is null then
    raise exception 'datos_incompletos';
  end if;

  if p_nivel not between 1 and 5 then
    raise exception 'nivel_invalido' using hint = 'El nivel va de 1 a 5.';
  end if;

  -- +1 día de margen por zonas horarias; los días pasados sí se permiten (RF-13)
  if p_fecha > current_date + 1 then
    raise exception 'fecha_futura';
  end if;

  if p_nota is not null and char_length(p_nota) > 500 then
    raise exception 'nota_muy_larga' using hint = 'Máximo 500 caracteres.';
  end if;

  if p_emociones is not null and exists (
    select 1 from unnest(p_emociones) as e(id)
    where not exists (select 1 from public.emociones x where x.id = e.id and x.activo)
  ) then
    raise exception 'emocion_invalida';
  end if;

  if p_factores is not null and exists (
    select 1 from unnest(p_factores) as f(id)
    where not exists (select 1 from public.factores x where x.id = f.id and x.activo)
  ) then
    raise exception 'factor_invalido';
  end if;

  -- ---------- ¿Ya hay registro ese día? ----------
  select * into v_existente
  from public.registros_animo
  where usuario_id = v_usuario and fecha = p_fecha
  for update;

  if not found then
    -- No hay: se crea con el id que mandó la app
    insert into public.registros_animo
      (id, usuario_id, fecha, nivel, nota, actualizado_en_cliente)
    values
      (p_id, v_usuario, p_fecha, p_nivel, nullif(p_nota, ''), p_actualizado_en);
    v_id := p_id;

  elsif v_existente.actualizado_en_cliente > p_actualizado_en then
    -- Hay uno MÁS RECIENTE en el servidor: no se pisa
    v_id := v_existente.id;
    v_aplicado := false;

  else
    -- Hay uno más viejo: se edita (CA-1). Se conserva el id del servidor.
    v_id := v_existente.id;
    update public.registros_animo
       set nivel                  = p_nivel,
           nota                   = case when p_nota is null then nota
                                         else nullif(p_nota, '') end,
           actualizado_en         = now(),
           actualizado_en_cliente = p_actualizado_en
     where id = v_id;
  end if;

  -- ---------- Chips (solo si se enviaron) ----------
  if v_aplicado and p_emociones is not null then
    delete from public.registro_emociones where registro_id = v_id;
    insert into public.registro_emociones (registro_id, emocion_id)
    select distinct v_id, e from unnest(p_emociones) as e;
  end if;

  if v_aplicado and p_factores is not null then
    delete from public.registro_factores where registro_id = v_id;
    insert into public.registro_factores (registro_id, factor_id)
    select distinct v_id, f from unnest(p_factores) as f;
  end if;

  -- ---------- Respuesta: el registro tal como quedó ----------
  return jsonb_build_object(
    'aplicado', v_aplicado,
    'registro', (
      select jsonb_build_object(
        'id',                     r.id,
        'fecha',                  r.fecha,
        'nivel',                  r.nivel,
        'nota',                   r.nota,
        'emociones',              coalesce((select jsonb_agg(emocion_id order by emocion_id)
                                            from public.registro_emociones
                                            where registro_id = r.id), '[]'::jsonb),
        'factores',               coalesce((select jsonb_agg(factor_id order by factor_id)
                                            from public.registro_factores
                                            where registro_id = r.id), '[]'::jsonb),
        'actualizado_en_cliente', r.actualizado_en_cliente
      )
      from public.registros_animo r
      where r.id = v_id
    )
  );
end;
$$;

revoke execute on function public.guardar_registro_animo(uuid, date, int, int[], int[], text, timestamptz)
  from public, anon;
grant  execute on function public.guardar_registro_animo(uuid, date, int, int[], int[], text, timestamptz)
  to authenticated;