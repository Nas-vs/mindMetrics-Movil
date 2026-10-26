-- =====================================================================
-- RF-06 · Recuperar contraseña (Back)
-- Back: Samuel Orozco
--
-- Qué resuelve esta migración:
--   1. Trigger al cambiar la contraseña en auth.users:
--      - Limpia el bloqueo y los intentos fallidos en public.intentos_login
--        para que el usuario pueda entrar de inmediato con su nueva clave.
--   2. RPC cerrar_sesiones_recuperacion():
--      - Cumple CA-6 desde la base de datos: elimina todas las sesiones
--        activas del usuario en otros dispositivos (auth.sessions) y
--        limpia sus dispositivos confiables para exigir verificación limpia,
--        o permite que el Front cierre todo tras restablecer la contraseña.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Trigger: al actualizar la contraseña, limpiar bloqueo de login
-- ---------------------------------------------------------------------
create function public.al_cambiar_contrasena()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Solo actúa si el hash de la contraseña realmente cambió
  if new.encrypted_password is distinct from old.encrypted_password then
    -- Si el usuario recuperó su contraseña porque estaba bloqueado tras
    -- 5 intentos fallidos (RF-04 CA-7), se le quita el bloqueo.
    delete from public.intentos_login
     where correo = lower(trim(new.email));
  end if;

  return new;
end;
$$;

comment on function public.al_cambiar_contrasena() is
  'RF-06: cuando el usuario cambia su contraseña, limpia bloqueos de login previos.';

create trigger al_actualizar_contrasena_usuario
  after update of encrypted_password on auth.users
  for each row
  execute function public.al_cambiar_contrasena();

revoke execute on function public.al_cambiar_contrasena() from public, anon, authenticated;


-- ---------------------------------------------------------------------
-- 2. RPC: cerrar sesiones abiertas al recuperar contraseña (CA-6)
--
-- Uso desde la app después de actualizar la contraseña en RF-06:
--   await supabase.rpc('cerrar_sesiones_recuperacion');
--
-- Borra todas las sesiones activas del usuario en auth.sessions y limpia
-- la lista de dispositivos confiables (RF-04/RF-05) para que ningún otro
-- celular conserve acceso sin volver a autenticarse.
-- ---------------------------------------------------------------------
create function public.cerrar_sesiones_recuperacion()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'sesion_requerida'
      using errcode = '42501';
  end if;

  -- 1. Revocar los dispositivos confiables registrados previamente
  delete from public.dispositivos_confiables
   where usuario_id = v_uid;

  -- 2. Eliminar todas las sesiones abiertas del usuario en Supabase Auth
  delete from auth.sessions
   where user_id = v_uid;
end;
$$;

comment on function public.cerrar_sesiones_recuperacion() is
  'RF-06 CA-6: cierra todas las sesiones abiertas del usuario y revoca dispositivos confiables.';

revoke execute on function public.cerrar_sesiones_recuperacion() from public, anon;
grant  execute on function public.cerrar_sesiones_recuperacion() to authenticated;