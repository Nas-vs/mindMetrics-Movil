-- =====================================================================
-- RF-22 · Recordatorio diario de registro (Back)
-- Back: Samuel Orozco
--
-- Guarda las preferencias del usuario para que la configuración del
-- recordatorio (activo, hora, minuto, beneficio_explicado) sobreviva a
-- reinstalar la app o cambiar de dispositivo.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Tabla de preferencias de recordatorio (una fila por usuario)
-- ---------------------------------------------------------------------
create table public.preferencias_recordatorio (
  usuario_id           uuid primary key references auth.users (id) on delete cascade,
  activo               boolean not null default false,
  hora                 smallint not null default 20 check (hora between 0 and 23),
  minuto               smallint not null default 0 check (minuto between 0 and 59),
  beneficio_explicado  boolean not null default false,
  actualizado_en       timestamptz not null default now()
);

comment on table public.preferencias_recordatorio is
  'RF-22: configuración del recordatorio diario del usuario (hora, estado y beneficio).';

-- ---------------------------------------------------------------------
-- 2. Seguridad: Row Level Security (RLS)
-- Cada usuario solo puede ver, insertar y actualizar sus propios datos.
-- ---------------------------------------------------------------------
alter table public.preferencias_recordatorio enable row level security;

create policy "cada usuario ve sus preferencias de recordatorio"
  on public.preferencias_recordatorio
  for select
  to authenticated
  using ((select auth.uid()) = usuario_id);

create policy "cada usuario inserta sus preferencias de recordatorio"
  on public.preferencias_recordatorio
  for insert
  to authenticated
  with check ((select auth.uid()) = usuario_id);

create policy "cada usuario actualiza sus preferencias de recordatorio"
  on public.preferencias_recordatorio
  for update
  to authenticated
  using ((select auth.uid()) = usuario_id)
  with check ((select auth.uid()) = usuario_id);

-- Los visitantes sin sesión (anon) no pueden leer ni escribir.
revoke all on table public.preferencias_recordatorio from anon;
grant select, insert, update on table public.preferencias_recordatorio to authenticated;

-- ---------------------------------------------------------------------
-- 3. Función RPC: guardar o actualizar en un solo paso (Upsert)
--
-- Uso desde la app:
--   await supabase.rpc('guardar_preferencias_recordatorio', params: {
--     'p_activo': true,
--     'p_hora': 20,
--     'p_minuto': 0,
--     'p_beneficio_explicado': true
--   });
-- ---------------------------------------------------------------------
create function public.guardar_preferencias_recordatorio(
  p_activo              boolean,
  p_hora                int,
  p_minuto              int,
  p_beneficio_explicado boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'sesion_requerida' using errcode = '42501';
  end if;

  if p_hora not between 0 and 23 or p_minuto not between 0 and 59 then
    raise exception 'hora_invalida' using errcode = '22003';
  end if;

  insert into public.preferencias_recordatorio (
    usuario_id,
    activo,
    hora,
    minuto,
    beneficio_explicado,
    actualizado_en
  ) values (
    v_uid,
    p_activo,
    p_hora,
    p_minuto,
    p_beneficio_explicado,
    now()
  )
  on conflict (usuario_id) do update set
    activo               = excluded.activo,
    hora                 = excluded.hora,
    minuto               = excluded.minuto,
    beneficio_explicado  = excluded.beneficio_explicado,
    actualizado_en       = now();
end;
$$;

comment on function public.guardar_preferencias_recordatorio is
  'RF-22: crea o actualiza las preferencias del recordatorio del usuario actual.';

revoke execute on function public.guardar_preferencias_recordatorio from public, anon;
grant execute on function public.guardar_preferencias_recordatorio to authenticated;