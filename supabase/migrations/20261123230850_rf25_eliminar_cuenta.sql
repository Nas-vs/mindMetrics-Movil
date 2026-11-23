-- =====================================================================
-- RF-25: Desactivación inmediata y eliminación diferida a 30 días
-- =====================================================================

-- 1. Tabla de registro de solicitudes de eliminación
create table if not exists public.solicitudes_eliminacion_cuenta (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references auth.users(id) on delete cascade,
  solicitado_en timestamptz not null default now(),
  fecha_ejecucion timestamptz not null default (now() + interval '30 days'),
  procesado boolean not null default false
);

comment on table public.solicitudes_eliminacion_cuenta is
  'RF-25: almacena solicitudes de eliminación con periodo de gracia de 30 días.';

-- RLS
alter table public.solicitudes_eliminacion_cuenta enable row level security;

create policy "cada usuario ve sus solicitudes de eliminacion"
  on public.solicitudes_eliminacion_cuenta
  for select
  to authenticated
  using ((select auth.uid()) = usuario_id);

-- ---------------------------------------------------------------------
-- 2. RPC: solicitar_eliminacion_cuenta(p_contrasena text)
-- ---------------------------------------------------------------------
create or replace function public.solicitar_eliminacion_cuenta(p_contrasena text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_hash text;
  v_fecha_ejecucion timestamptz;
begin
  -- Validación de sesión autenticada
  if v_uid is null then
    raise exception 'sesion_requerida' using errcode = '42501';
  end if;

  -- Validación de contraseña presente
  if p_contrasena is null or trim(p_contrasena) = '' then
    raise exception 'contrasena_requerida' using errcode = '22023';
  end if;

  -- 1. Obtener hash actual de la contraseña del usuario
  select encrypted_password into v_hash
    from auth.users
   where id = v_uid;

  if v_hash is null then
    raise exception 'usuario_no_encontrado' using errcode = 'P0002';
  end if;

  -- 2. Validar que la contraseña coincida
  if extensions.crypt(p_contrasena, v_hash) <> v_hash then
    raise exception 'contrasena_incorrecta' using errcode = '28P01';
  end if;

  -- 3. Desactivar el perfil inmediatamente
  update public.perfiles
     set activo = false,
         actualizado_en = now()
   where id = v_uid;

  -- 4. Revocar dispositivos confiables (RF-04 / RF-05 / RF-06)
  delete from public.dispositivos_confiables
   where usuario_id = v_uid;

  -- 5. Banear en auth.users para evitar nuevos inicios de sesión
  update auth.users
     set banned_until = now() + interval '100 years'
   where id = v_uid;

  -- 6. Cancelar citas pendientes o confirmadas si existe la tabla
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'citas') then
    execute 'update public.citas set estado = ''cancelada'' where usuario_id = $1 and estado in (''pendiente'', ''confirmada'')'
    using v_uid;
  end if;

  -- 7. Registrar solicitud para purga a 30 días
  v_fecha_ejecucion := now() + interval '30 days';

  insert into public.solicitudes_eliminacion_cuenta (usuario_id, solicitado_en, fecha_ejecucion, procesado)
  values (v_uid, now(), v_fecha_ejecucion, false);

  -- 8. Revocar todas las sesiones activas en auth.sessions
  delete from auth.sessions
   where user_id = v_uid;

  return jsonb_build_object(
    'ok', true,
    'mensaje', 'Cuenta desactivada exitosamente. Se eliminará definitivamente en 30 días.',
    'fecha_ejecucion', v_fecha_ejecucion
  );
end;
$$;

revoke execute on function public.solicitar_eliminacion_cuenta(text) from public, anon;
grant  execute on function public.solicitar_eliminacion_cuenta(text) to authenticated;

-- ---------------------------------------------------------------------
-- 3. RPC: purgar_cuentas_eliminadas()
-- Ejecutada periódicamente por el sistema (Cron / service_role)
-- ---------------------------------------------------------------------
create or replace function public.purgar_cuentas_eliminadas()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_purgados integer := 0;
begin
  with usuarios_a_borrar as (
    select usuario_id
      from public.solicitudes_eliminacion_cuenta
     where procesado = false
       and fecha_ejecucion <= now()
  ),
  eliminados as (
    delete from auth.users
     where id in (select usuario_id from usuarios_a_borrar)
    returning id
  )
  select count(*)::int into v_purgados from eliminados;

  return v_purgados;
end;
$$;

revoke execute on function public.purgar_cuentas_eliminadas() from public, anon, authenticated;
grant  execute on function public.purgar_cuentas_eliminadas() to service_role;