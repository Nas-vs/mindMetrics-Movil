-- =====================================================================
-- RF-07 · Saludo personalizado
-- Back: Julián Gómez
--
-- CA-2: "El nickname se lee del estado global de la app (cargado al
--        iniciar sesión); no se hace una petición adicional."
--
-- Qué crea esta migración:
--   1. Trigger en perfiles   → copia el nickname a auth.users.raw_app_meta_data.
--                              Supabase Auth lo devuelve en la sesión al
--                              iniciar sesión (currentUser.appMetadata) y en
--                              el JWT (claim app_metadata.nickname), así la
--                              app lo tiene sin consultar public.perfiles.
--   2. Backfill              → usuarios registrados antes de esta migración.
--
-- ¿Por qué app_metadata y no user_metadata?
--   user_metadata lo puede cambiar el propio usuario con
--   supabase.auth.updateUser(data: {...}); podría mostrar un nickname que
--   no existe en perfiles o que ya es de otra persona. app_metadata solo lo
--   escribe el backend, así que public.perfiles sigue siendo la fuente de
--   verdad y la sesión es una copia de solo lectura.
--
-- Cuando RF-23 permita editar el nickname, este mismo trigger mantiene la
-- sesión sincronizada. La app debe llamar a supabase.auth.refreshSession()
-- después de guardar para recibir el valor nuevo.
--
-- Uso desde la app (Front RF-07):
--   final nickname = Supabase.instance.client.auth.currentUser
--       ?.appMetadata['nickname'] as String?;
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Trigger: perfiles.nickname → auth.users.raw_app_meta_data.nickname
--
-- Se dispara al crear el perfil (dentro del registro, RF-03) y cuando se
-- actualiza la columna nickname (RF-23). El operador || conserva las demás
-- claves que pone Supabase Auth (provider, providers).
-- ---------------------------------------------------------------------
create function public.sincronizar_nickname_sesion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update auth.users
     set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
                             || jsonb_build_object('nickname', new.nickname)
   where id = new.id;

  return null;  -- trigger AFTER: el valor de retorno se ignora
end;
$$;

comment on function public.sincronizar_nickname_sesion() is
  'RF-07: copia perfiles.nickname a auth.users.raw_app_meta_data para que la sesión lo traiga sin petición adicional.';

create trigger al_cambiar_nickname_sincronizar_sesion
  after insert or update of nickname on public.perfiles
  for each row
  execute function public.sincronizar_nickname_sesion();

-- La función del trigger no debe poder llamarse desde la API
revoke execute on function public.sincronizar_nickname_sesion() from public, anon, authenticated;


-- ---------------------------------------------------------------------
-- 2. Backfill: usuarios que ya existían antes de esta migración
-- ---------------------------------------------------------------------
update auth.users u
   set raw_app_meta_data = coalesce(u.raw_app_meta_data, '{}'::jsonb)
                           || jsonb_build_object('nickname', p.nickname)
  from public.perfiles p
 where p.id = u.id;
