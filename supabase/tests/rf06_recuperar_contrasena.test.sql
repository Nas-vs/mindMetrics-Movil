-- =====================================================================
-- Pruebas de RF-06 (pgTAP). Se corren con:   supabase test db
-- Todo ocurre dentro de una transacción que se deshace al final (rollback).
-- =====================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(9);

-- ---------------------------------------------------------------------
-- Preparación: creamos dos usuarios de prueba (Ana y Beto)
-- con los metadatos que exigen los triggers de RF-02 y RF-03.
-- ---------------------------------------------------------------------
insert into auth.users (id, email, encrypted_password, raw_app_meta_data, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'ana@prueba.co', 'hash_viejo_ana',
   '{"provider":"email","providers":["email"]}',
   '{"nombre_completo":"Ana Prueba","nickname":"ana","fecha_nacimiento":"1995-05-05",
     "acepta_datos_sensibles":true,"version_politica":"1.0"}'),
  ('22222222-2222-2222-2222-222222222222', 'beto@prueba.co', 'hash_viejo_beto',
   '{"provider":"email","providers":["email"]}',
   '{"nombre_completo":"Beto Prueba","nickname":"beto","fecha_nacimiento":"1995-05-05",
     "acepta_datos_sensibles":true,"version_politica":"1.0"}');


-- =====================================================================
-- 1. Trigger al cambiar contraseña: desbloquea la cuenta en intentos_login
-- =====================================================================
-- Simulamos que Ana falló 5 veces su contraseña y quedó bloqueada (RF-04 CA-7)
do $$ begin
  perform public.registrar_intento_fallido('ana@prueba.co');
  perform public.registrar_intento_fallido('ana@prueba.co');
  perform public.registrar_intento_fallido('ana@prueba.co');
  perform public.registrar_intento_fallido('ana@prueba.co');
  perform public.registrar_intento_fallido('ana@prueba.co');
  -- Y Beto tiene 2 intentos fallidos
  perform public.registrar_intento_fallido('beto@prueba.co');
  perform public.registrar_intento_fallido('beto@prueba.co');
end $$;

select ok(
  public.estado_bloqueo('ana@prueba.co') is not null,
  'antes de recuperar la contraseña, Ana está bloqueada por 5 intentos fallidos'
);

-- Ana restablece su contraseña (cambia encrypted_password en auth.users)
update auth.users
   set encrypted_password = 'hash_nuevo_ana'
 where id = '11111111-1111-1111-1111-111111111111';

select is(
  public.estado_bloqueo('ana@prueba.co'),
  null,
  'al actualizar la contraseña, el trigger quita el bloqueo de Ana automáticamente'
);

select is(
  (select count(*)::int from public.intentos_login where correo = 'ana@prueba.co'),
  0,
  'el registro de intentos fallidos de Ana se elimina por completo'
);

select is(
  (select intentos_fallidos from public.intentos_login where correo = 'beto@prueba.co'),
  2,
  'cambiar la contraseña de Ana no borra los intentos de otros usuarios (Beto)'
);


-- =====================================================================
-- 2. Seguridad: la función del trigger no se puede invocar desde la API
-- =====================================================================
set local role anon;

select throws_ok(
  $$ select public.al_cambiar_contrasena() $$,
  '42501', null,
  'anon no puede llamar la función del trigger al_cambiar_contrasena'
);

-- =====================================================================
-- 3. Seguridad: un visitante sin sesión no puede cerrar sesiones
-- =====================================================================
select throws_ok(
  $$ select public.cerrar_sesiones_recuperacion() $$,
  '42501', null,
  'un visitante sin sesión (anon) no puede ejecutar cerrar_sesiones_recuperacion'
);

reset role;


-- =====================================================================
-- 4. CA-6: cerrar_sesiones_recuperacion() borra sesiones y dispositivos
--    de quien recupera su contraseña, sin afectar a otros usuarios
-- =====================================================================
-- Registramos dos celulares confiables para Ana y uno para Beto
insert into public.dispositivos_confiables (usuario_id, dispositivo_id) values
  ('11111111-1111-1111-1111-111111111111', 'celular-ana-01'),
  ('11111111-1111-1111-1111-111111111111', 'tablet-ana-02'),
  ('22222222-2222-2222-2222-222222222222', 'celular-beto-01');

-- Simulamos sesiones activas en auth.sessions para Ana y Beto
insert into auth.sessions (id, user_id, created_at, updated_at) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', '11111111-1111-1111-1111-111111111111', now(), now()),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2', '11111111-1111-1111-1111-111111111111', now(), now()),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', '22222222-2222-2222-2222-222222222222', now(), now());

-- Ana (con sesión temporal del enlace de recuperación) ejecuta la RPC
set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok(
  $$ select public.cerrar_sesiones_recuperacion() $$,
  'CA-6: Ana ejecuta cerrar_sesiones_recuperacion tras cambiar su contraseña'
);

reset role;

select is(
  (select count(*)::int from auth.sessions where user_id = '11111111-1111-1111-1111-111111111111')
  + (select count(*)::int from public.dispositivos_confiables where usuario_id = '11111111-1111-1111-1111-111111111111'),
  0,
  'CA-6: todas las sesiones y dispositivos confiables de Ana quedan cerrados/revocados'
);

select is(
  (select count(*)::int from auth.sessions where user_id = '22222222-2222-2222-2222-222222222222')
  + (select count(*)::int from public.dispositivos_confiables where usuario_id = '22222222-2222-2222-2222-222222222222'),
  2,
  'las sesiones y dispositivos de Beto siguen intactos'
);

select * from finish();
rollback;