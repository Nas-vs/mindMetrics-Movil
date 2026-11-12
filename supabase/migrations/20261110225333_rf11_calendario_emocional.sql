-- =====================================================================
-- RF-11: Calendario emocional (y soporte para RF-12 Actividades)
-- =====================================================================

-- 1. Tabla de actividades personalizadas en el calendario
create table public.actividades (
  -- El id lo genera la APP (UUID) para soporte offline-first (RF-12 CA-5)
  id                      uuid primary key,
  usuario_id              uuid not null references auth.users (id) on delete cascade,
  titulo                  text not null check (char_length(trim(titulo)) between 1 and 100),
  categoria               text not null check (categoria in (
                            'salud', 'ejercicio', 'estudio', 'trabajo', 
                            'ocio', 'social', 'bienestar', 'otro'
                          )),
  fecha                   date not null,
  hora                    time,
  tiene_recordatorio      boolean not null default false,
  completada              boolean not null default false,
  creado_en               timestamptz not null default now(),
  actualizado_en          timestamptz not null default now(),
  actualizado_en_cliente  timestamptz not null default now()
);

comment on table public.actividades is
  'RF-11 CA-3 y RF-12: actividades programadas que marcan puntos en el calendario mensual.';

-- Índices para búsquedas eficientes por mes y fecha
create index actividades_usuario_fecha_idx
  on public.actividades (usuario_id, fecha asc);

-- 2. Seguridad RLS
alter table public.actividades enable row level security;

create policy "cada usuario gestiona sus actividades" on public.actividades
  for all to authenticated
  using (usuario_id = auth.uid())
  with check (usuario_id = auth.uid());

-- 3. RPC: Resumen mensual para alimentar el calendario en una sola petición (RF-11 CA-1, CA-2, CA-3)
create or replace function public.obtener_resumen_calendario_mes(
  p_anio integer,
  p_mes  integer
)
returns table (
  fecha              date,
  nivel_animo        smallint,
  total_actividades  bigint,
  tiene_actividades  boolean
)
language sql
security definer
set search_path = public
stable
as $$
  with dias_mes as (
    -- Genera todos los días del mes solicitado
    select generate_series(
      make_date(p_anio, p_mes, 1),
      (make_date(p_anio, p_mes, 1) + interval '1 month - 1 day')::date,
      interval '1 day'
    )::date as dia
  ),
  animos as (
    select
      r.fecha,
      r.nivel
    from public.registros_animo r
    where r.usuario_id = auth.uid()
      and extract(year from r.fecha) = p_anio
      and extract(month from r.fecha) = p_mes
  ),
  conteos_actividades as (
    select
      a.fecha,
      count(*) as total
    from public.actividades a
    where a.usuario_id = auth.uid()
      and extract(year from a.fecha) = p_anio
      and extract(month from a.fecha) = p_mes
    group by a.fecha
  )
  select
    d.dia as fecha,
    an.nivel as nivel_animo,
    coalesce(ca.total, 0) as total_actividades,
    (coalesce(ca.total, 0) > 0) as tiene_actividades
  from dias_mes d
  left join animos an on an.fecha = d.dia
  left join conteos_actividades ca on ca.fecha = d.dia
  order by d.dia asc;
$$;

comment on function public.obtener_resumen_calendario_mes is
  'RF-11 CA-1..CA-3: Entrega todos los días del mes con su nivel de ánimo (1-5) y si tiene actividades programadas.';

grant execute on function public.obtener_resumen_calendario_mes to authenticated;