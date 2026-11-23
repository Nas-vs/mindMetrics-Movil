-- =====================================================================
-- Pruebas de RF-25: Eliminar cuenta (pgTAP)
-- Ejecutar con: supabase test db
-- =====================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(8);

-- 1. Preparar usuario de prueba con contraseña encriptada válida
insert into auth.users (
  id,
  email,
  encrypted_password,
  raw_app_meta_data,
  raw_user_meta_data
) values (
  '99999999-9999-9999-9999-999999999999',
  'eliminar@prueba.co',
  extensions.crypt('ClaveSegura123!', extensions.gen_salt('bf')),
  '{"provider":"email","providers":["email"]}',
  '{"nombre_completo":"Usuario A Eliminar","nickname":"eliminar_test","fecha_nacimiento":"1995-05-05","acepta_datos_sensibles":true,"version_politica":"1.0"}'
);

-- Simular sesión activa en auth.sessions y dispositivo confiable
insert into auth.sessions (id, user_id, created_at, updated_at)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '99999999-9999-9999-9999-999999999999', now(), now());

insert into public.dispositivos_confiables (usuario_id, dispositivo_id)
values ('99999999-9999-9999-9999-999999999999', 'dispositivo_pixel_test_123');

-- ---------------------------------------------------------------------
-- Test 1: Rechazo si no hay sesión autenticada
-- ---------------------------------------------------------------------
select throws_ok(
  $$ select public.solicitar_eliminacion_cuenta('ClaveSegura123!') $$,
  '42501',
  'sesion_requerida',
  '1. Debe fallar si se llama sin sesión'
);

-- Autenticamos la transacción como el usuario
set local role authenticated;
set local request.jwt.claims = '{"sub": "99999999-9999-9999-9999-999999999999"}';

-- ---------------------------------------------------------------------
-- Test 2: Rechazo si la contraseña viene vacía o nula
-- ---------------------------------------------------------------------
select throws_ok(
  $$ select public.solicitar_eliminacion_cuenta('') $$,
  '22023',
  'contrasena_requerida',
  '2. Debe fallar si la contraseña está vacía'
);

-- ---------------------------------------------------------------------
-- Test 3: Rechazo si la contraseña es incorrecta
-- ---------------------------------------------------------------------
select throws_ok(
  $$ select public.solicitar_eliminacion_cuenta('ClaveEquivocada') $$,
  '28P01',
  'contrasena_incorrecta',
  '3. Debe fallar si la contraseña es incorrecta'
);

-- ---------------------------------------------------------------------
-- Test 4: Éxito al solicitar eliminación con contraseña correcta
-- ---------------------------------------------------------------------
select lives_ok(
  $$ select public.solicitar_eliminacion_cuenta('ClaveSegura123!') $$,
  '4. La solicitud de eliminación debe ejecutarse exitosamente con la contraseña correcta'
);

-- Restauramos el rol postgres para verificar tablas del sistema y correr la purga
reset role;

-- ---------------------------------------------------------------------
-- Test 5: Perfil queda inactivo inmediatamente
-- ---------------------------------------------------------------------
select is(
  (select activo from public.perfiles where id = '99999999-9999-9999-9999-999999999999'),
  false,
  '5. El perfil debe quedar inmediatamente en activo = false'
);

-- ---------------------------------------------------------------------
-- Test 6: Sesiones y dispositivos confiables revocados inmediatamente
-- ---------------------------------------------------------------------
select is(
  (select count(*)::int from auth.sessions where user_id = '99999999-9999-9999-9999-999999999999') +
  (select count(*)::int from public.dispositivos_confiables where usuario_id = '99999999-9999-9999-9999-999999999999'),
  0,
  '6. Las sesiones activas y dispositivos confiables deben eliminarse de inmediato'
);

-- ---------------------------------------------------------------------
-- Test 7: Solicitud registrada a 30 días en el futuro
-- ---------------------------------------------------------------------
select ok(
  exists (
    select 1
      from public.solicitudes_eliminacion_cuenta
     where usuario_id = '99999999-9999-9999-9999-999999999999'
       and fecha_ejecucion > now() + interval '29 days'
       and procesado = false
  ),
  '7. La solicitud debe programarse con fecha_ejecucion a 30 días'
);

-- ---------------------------------------------------------------------
-- Test 8: Purga de cuentas que cumplieron los 30 días
-- ---------------------------------------------------------------------
update public.solicitudes_eliminacion_cuenta
   set fecha_ejecucion = now() - interval '1 day'
 where usuario_id = '99999999-9999-9999-9999-999999999999';

select is(
  public.purgar_cuentas_eliminadas(),
  1,
  '8. purgar_cuentas_eliminadas() debe purgar al usuario cuya fecha de gracia venció'
);

rollback;