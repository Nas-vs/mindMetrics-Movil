-- =====================================================================
-- RF-12: Registrar actividades
-- Completa la tabla public.actividades creada en RF-11 (no la recrea).
-- La app escribe directo en la tabla (RLS ya limita a sus filas) y hace
-- upsert por id; los triggers garantizan la marca de tiempo y que una
-- edición vieja que llega tarde (sin conexión) no pise una más nueva.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Columnas
-- ---------------------------------------------------------------------
-- La app puede omitir usuario_id: se toma de la sesión.
alter table public.actividades
  alter column usuario_id set default auth.uid();

-- Minutos antes de la actividad para el recordatorio (máximo 24 horas).
alter table public.actividades
  add column recordatorio_minutos_antes int null
    constraint actividades_recordatorio_minutos_antes_check
    check (recordatorio_minutos_antes between 0 and 1440);

-- Los minutos solo tienen sentido si la actividad tiene recordatorio.
-- Null siempre es válido (con o sin recordatorio).
alter table public.actividades
  add constraint actividades_minutos_requieren_recordatorio_check
    check (recordatorio_minutos_antes is null or tiene_recordatorio);

comment on column public.actividades.recordatorio_minutos_antes is
  'RF-12: minutos antes de la actividad en que suena el recordatorio (0 a 1440). Solo con tiene_recordatorio = true; null = sin minutos.';

-- Para proximas_actividades: pendientes por usuario y fecha.
create index actividades_usuario_pendientes_idx
  on public.actividades (usuario_id, fecha, hora)
  where not completada;

-- ---------------------------------------------------------------------
-- 2. Trigger: ignorar ediciones viejas (CA-5, offline)
-- ---------------------------------------------------------------------
-- Si el cambio que llega fue hecho en el cliente ANTES que el guardado,
-- se descarta en silencio (return null): el upsert no falla, pero la fila
-- se queda como estaba.
create function public.actividades_rechazar_edicion_vieja()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.actualizado_en_cliente < old.actualizado_en_cliente then
    return null;
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- 3. Trigger: actualizado_en lo pone siempre el servidor
-- ---------------------------------------------------------------------
create function public.actividades_marcar_actualizado_en()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.actualizado_en := now();
  return new;
end;
$$;

-- Postgres dispara los triggers en orden alfabético: primero (a) decide si
-- el cambio se aplica y solo entonces (b) marca la hora.
create trigger a_rechazar_edicion_vieja
  before update on public.actividades
  for each row execute function public.actividades_rechazar_edicion_vieja();

create trigger b_marcar_actualizado_en
  before update on public.actividades
  for each row execute function public.actividades_marcar_actualizado_en();

revoke execute on function public.actividades_rechazar_edicion_vieja() from public, anon, authenticated;
revoke execute on function public.actividades_marcar_actualizado_en()  from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 4. RPC: próximas actividades (pendientes desde hoy)
-- ---------------------------------------------------------------------
-- p_hoy: día LOCAL del usuario (lo envía la app, igual que en RF-08). Si no
-- llega, se usa el día de Colombia y no el del servidor (UTC), para que
-- después de las 7 p. m. no desaparezcan las actividades de hoy.
create function public.proximas_actividades(
  p_limite  int  default 5,
  p_hoy     date default null
)
returns setof public.actividades
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

  if p_limite is null or p_limite not between 1 and 50 then
    raise exception 'limite_invalido' using hint = 'El límite va de 1 a 50.';
  end if;

  return query
    select a.*
    from public.actividades a
    where a.usuario_id = v_usuario
      and not a.completada
      and a.fecha >= coalesce(p_hoy, (now() at time zone 'America/Bogota')::date)
    order by a.fecha asc, a.hora asc nulls last, a.creado_en asc
    limit p_limite;
end;
$$;

comment on function public.proximas_actividades(int, date) is
  'RF-12: las próximas actividades no completadas del usuario desde hoy, ordenadas por fecha y hora.';

revoke execute on function public.proximas_actividades(int, date) from public, anon;
grant  execute on function public.proximas_actividades(int, date) to authenticated;
