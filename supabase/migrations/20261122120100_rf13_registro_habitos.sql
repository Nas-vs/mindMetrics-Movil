-- =====================================================================
-- RF-13: Registro diario de hábitos y detalle de un día
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Catálogo de hábitos
-- ---------------------------------------------------------------------
create table public.habitos (
  id      smallint primary key,
  nombre  text not null unique,
  icono   text not null,               -- nombre del ícono de Material en la app
  orden   smallint not null,
  activo  boolean not null default true
);

comment on table public.habitos is 'RF-13: catálogo de hábitos que el usuario marca cada día.';

alter table public.habitos enable row level security;

create policy "usuarios leen habitos" on public.habitos
  for select to authenticated using (true);

insert into public.habitos (id, nombre, icono, orden) values
  (1, 'Tomar agua',                   'water_drop',       1),
  (2, 'Dormir bien',                  'bedtime',          2),
  (3, 'Ejercicio',                    'fitness_center',   3),
  (4, 'Meditar',                      'self_improvement', 4),
  (5, 'Leer',                         'menu_book',        5),
  (6, 'Comer saludable',              'restaurant',       6),
  (7, 'Desconectarse de pantallas',   'phonelink_off',    7),
  (8, 'Salir al aire libre',          'park',             8);


-- ---------------------------------------------------------------------
-- 2. Registro de hábitos (uno por usuario, día y hábito)
-- ---------------------------------------------------------------------
create table public.registro_habitos (
  usuario_id              uuid not null references auth.users (id) on delete cascade,
  -- Día LOCAL del usuario (lo envía la app), como en RF-08.
  fecha                   date not null,
  habito_id               smallint not null references public.habitos (id),
  completado              boolean not null,
  creado_en               timestamptz not null default now(),
  actualizado_en          timestamptz not null default now(),
  -- Hora del cambio en el teléfono: una edición vieja no pisa una nueva.
  actualizado_en_cliente  timestamptz not null,
  primary key (usuario_id, fecha, habito_id)
);

comment on table public.registro_habitos is
  'RF-13: si el usuario cumplió (o no) cada hábito en un día. Solo se escribe por marcar_habito.';

alter table public.registro_habitos enable row level security;

create policy "cada usuario ve sus habitos"
  on public.registro_habitos for select to authenticated
  using ((select auth.uid()) = usuario_id);

-- Escribir solo por la RPC (security definer).
revoke insert, update, delete on public.registro_habitos from anon, authenticated;


-- ---------------------------------------------------------------------
-- 3. RPC: marcar un hábito (upsert idempotente)
-- ---------------------------------------------------------------------
create function public.marcar_habito(
  p_fecha           date,
  p_habito_id       int,
  p_completado      boolean,
  p_actualizado_en  timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usuario   uuid := auth.uid();
  v_aplicado  boolean;
begin
  -- ---------- Validaciones ----------
  if v_usuario is null then
    raise exception 'sesion_requerida';
  end if;

  if p_fecha is null or p_habito_id is null or p_completado is null
     or p_actualizado_en is null then
    raise exception 'datos_incompletos';
  end if;

  -- +1 día de margen por zonas horarias, igual que RF-08
  if p_fecha > current_date + 1 then
    raise exception 'fecha_futura';
  end if;

  if not exists (
    select 1 from public.habitos h where h.id = p_habito_id and h.activo
  ) then
    raise exception 'habito_invalido';
  end if;

  -- ---------- Upsert: solo pisa si el cambio es igual o más nuevo ----------
  insert into public.registro_habitos as r
    (usuario_id, fecha, habito_id, completado, actualizado_en_cliente)
  values
    (v_usuario, p_fecha, p_habito_id, p_completado, p_actualizado_en)
  on conflict (usuario_id, fecha, habito_id) do update
    set completado             = excluded.completado,
        actualizado_en         = now(),
        actualizado_en_cliente = excluded.actualizado_en_cliente
    where r.actualizado_en_cliente <= excluded.actualizado_en_cliente;

  v_aplicado := found;

  -- ---------- Respuesta: el registro tal como quedó ----------
  return jsonb_build_object(
    'aplicado', v_aplicado,
    'registro', (
      select jsonb_build_object(
        'fecha',                  r.fecha,
        'habito_id',              r.habito_id,
        'completado',             r.completado,
        'actualizado_en_cliente', r.actualizado_en_cliente
      )
      from public.registro_habitos r
      where r.usuario_id = v_usuario
        and r.fecha      = p_fecha
        and r.habito_id  = p_habito_id
    )
  );
end;
$$;

comment on function public.marcar_habito(date, int, boolean, timestamptz) is
  'RF-13: marca o desmarca un hábito en un día. Idempotente; un cambio viejo no pisa uno nuevo.';

revoke execute on function public.marcar_habito(date, int, boolean, timestamptz) from public, anon;
grant  execute on function public.marcar_habito(date, int, boolean, timestamptz) to authenticated;


-- ---------------------------------------------------------------------
-- 4. RPC: detalle de un día (ánimo + hábitos + actividades)
-- ---------------------------------------------------------------------
create function public.detalle_dia(p_fecha date)
returns jsonb
language plpgsql
security definer
set search_path = ''
stable
as $$
declare
  v_usuario uuid := auth.uid();
begin
  if v_usuario is null then
    raise exception 'sesion_requerida';
  end if;

  if p_fecha is null then
    raise exception 'datos_incompletos';
  end if;

  return jsonb_build_object(
    'fecha', p_fecha,

    -- Registro de ánimo del día (null si no hay)
    'animo', (
      select jsonb_build_object(
        'id',        ra.id,
        'nivel',     ra.nivel,
        'nota',      ra.nota,
        'emociones', coalesce((
          select jsonb_agg(jsonb_build_object('id', e.id, 'nombre', e.nombre)
                           order by e.orden)
          from public.registro_emociones re
          join public.emociones e on e.id = re.emocion_id
          where re.registro_id = ra.id
        ), '[]'::jsonb),
        'factores',  coalesce((
          select jsonb_agg(jsonb_build_object('id', f.id, 'nombre', f.nombre)
                           order by f.orden)
          from public.registro_factores rf
          join public.factores f on f.id = rf.factor_id
          where rf.registro_id = ra.id
        ), '[]'::jsonb)
      )
      from public.registros_animo ra
      where ra.usuario_id = v_usuario
        and ra.fecha      = p_fecha
    ),

    -- TODOS los hábitos activos; completado = false si no hay registro
    'habitos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id',         h.id,
               'nombre',     h.nombre,
               'icono',      h.icono,
               'completado', coalesce(rh.completado, false)
             ) order by h.orden)
      from public.habitos h
      left join public.registro_habitos rh
        on rh.habito_id  = h.id
       and rh.usuario_id = v_usuario
       and rh.fecha      = p_fecha
      where h.activo
    ), '[]'::jsonb),

    -- Actividades del día
    'actividades', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id',                         a.id,
               'titulo',                     a.titulo,
               'categoria',                  a.categoria,
               'hora',                       a.hora,
               'completada',                 a.completada,
               'tiene_recordatorio',         a.tiene_recordatorio,
               'recordatorio_minutos_antes', a.recordatorio_minutos_antes
             ) order by a.hora asc nulls last, a.creado_en asc)
      from public.actividades a
      where a.usuario_id = v_usuario
        and a.fecha      = p_fecha
    ), '[]'::jsonb)
  );
end;
$$;

comment on function public.detalle_dia(date) is
  'RF-13: detalle de un día para el calendario: ánimo, todos los hábitos activos y las actividades.';

revoke execute on function public.detalle_dia(date) from public, anon;
grant  execute on function public.detalle_dia(date) to authenticated;
