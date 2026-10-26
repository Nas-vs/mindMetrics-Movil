-- =====================================================================
-- Pruebas de RF-23 (pgTAP). Se corren con:   supabase test db
-- Todo ocurre dentro de una transacción que se deshace al final.
-- Cada usuario de prueba incluye los datos de RF-02 y RF-03, porque sus
-- triggers también se ejecutan al registrarse.
-- =====================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(21);

-- Usuarios de prueba:
--   Ana  = 11111111-1111-1111-1111-111111111111
--   Beto = 22222222-2222-2222-2222-222222222222
insert into auth.users (id, email, raw_app_meta_data, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'ana@prueba.co',
   '{"provider":"email","providers":["email"]}',
   '{"nombre_completo":"Ana Prueba","nickname":"ana","fecha_nacimiento":"1995-05-05",
     "acepta_datos_sensibles":true,"version_politica":"1.0"}'),
  ('22222222-2222-2222-2222-222222222222', 'beto@prueba.co',
   '{"provider":"email","providers":["email"]}',
   '{"nombre_completo":"Beto Prueba","nickname":"beto","fecha_nacimiento":"1995-05-05",
     "acepta_datos_sensibles":true,"version_politica":"1.0"}');

-- Fecha de actualización en el pasado, para ver si el trigger la cambia
-- (dentro de una transacción now() es constante).
update public.perfiles set actualizado_en = '2026-01-01 00:00:00+00';


-- ---------------------------------------------------------------------
-- Estructura
-- ---------------------------------------------------------------------
select policies_are(
  'public', 'perfiles',
  array['cada usuario ve su perfil', 'cada usuario edita su perfil'],
  'perfiles tiene solo las políticas de lectura y edición propia'
);

select ok(
  has_column_privilege('authenticated', 'public.perfiles', 'nombre_completo', 'update')
  and has_column_privilege('authenticated', 'public.perfiles', 'nickname', 'update'),
  'un usuario con sesión puede actualizar nombre_completo y nickname'
);

select ok(
  not has_column_privilege('authenticated', 'public.perfiles', 'fecha_nacimiento', 'update')
  and not has_column_privilege('authenticated', 'public.perfiles', 'activo', 'update')
  and not has_column_privilege('authenticated', 'public.perfiles', 'creado_en', 'update')
  and not has_column_privilege('authenticated', 'public.perfiles', 'actualizado_en', 'update')
  and not has_column_privilege('authenticated', 'public.perfiles', 'id', 'update'),
  'ningún otro campo de perfiles es editable por el usuario'
);


-- =====================================================================
-- Como Ana (sesión iniciada)
-- =====================================================================
set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

-- ---------------------------------------------------------------------
-- CA-1: los datos del perfil se pueden leer
-- ---------------------------------------------------------------------
select results_eq(
  $$ select nombre_completo, nickname, creado_en is not null
       from public.perfiles $$,
  $$ values ('Ana Prueba'::text, 'ana'::text, true) $$,
  'CA-1: Ana lee su nombre, nickname y fecha de registro, y solo su perfil'
);

-- ---------------------------------------------------------------------
-- nickname_disponible con sesión
-- ---------------------------------------------------------------------
select is(public.nickname_disponible('Beto'), false,
  'con sesión, nickname_disponible sigue detectando el nickname de otro usuario');

-- ---------------------------------------------------------------------
-- CA-2: editar nombre y nickname
-- ---------------------------------------------------------------------
select lives_ok(
  $$ update public.perfiles
        set nombre_completo = 'Ana María Ríos', nickname = 'AnaMaria'
      where id = '11111111-1111-1111-1111-111111111111' $$,
  'CA-2: Ana cambia su nombre y su nickname'
);

select results_eq(
  $$ select nombre_completo, nickname, actualizado_en = now() from public.perfiles $$,
  $$ values ('Ana María Ríos'::text, 'AnaMaria'::text, true) $$,
  'los cambios quedan guardados y actualizado_en se renueva'
);

select lives_ok(
  $$ update public.perfiles set nickname = 'anamaria'
      where id = '11111111-1111-1111-1111-111111111111' $$,
  'cambiar solo las mayúsculas del nickname propio está permitido'
);

select lives_ok(
  $$ update public.perfiles
        set nombre_completo = '  Ana   María  Ríos ', nickname = ' AnaMaria '
      where id = '11111111-1111-1111-1111-111111111111' $$,
  'se aceptan espacios sobrantes al inicio, al final o repetidos'
);

select results_eq(
  $$ select nombre_completo, nickname from public.perfiles $$,
  $$ values ('Ana María Ríos'::text, 'AnaMaria'::text) $$,
  'los espacios sobrantes se limpian antes de guardar'
);

-- ---------------------------------------------------------------------
-- Validaciones (las reglas de RF-03 también aplican al editar)
-- ---------------------------------------------------------------------
select throws_ok(
  $$ update public.perfiles set nickname = 'BETO'
      where id = '11111111-1111-1111-1111-111111111111' $$,
  '23505', null,
  'un nickname ocupado (sin importar mayúsculas) se rechaza'
);

select throws_ok(
  $$ update public.perfiles set nickname = 'ana m'
      where id = '11111111-1111-1111-1111-111111111111' $$,
  '23514', null,
  'un nickname con espacios internos se rechaza'
);

select throws_ok(
  $$ update public.perfiles set nickname = 'an'
      where id = '11111111-1111-1111-1111-111111111111' $$,
  '23514', null,
  'un nickname de menos de 3 caracteres se rechaza'
);

select throws_ok(
  $$ update public.perfiles set nombre_completo = 'Ana María 2'
      where id = '11111111-1111-1111-1111-111111111111' $$,
  '23514', null,
  'un nombre con números se rechaza'
);

select throws_ok(
  $$ update public.perfiles set nombre_completo = '   '
      where id = '11111111-1111-1111-1111-111111111111' $$,
  '23514', null,
  'un nombre vacío (solo espacios) se rechaza'
);

-- ---------------------------------------------------------------------
-- Seguridad
-- ---------------------------------------------------------------------
select throws_ok(
  $$ update public.perfiles set fecha_nacimiento = '2015-01-01'
      where id = '11111111-1111-1111-1111-111111111111' $$,
  '42501', null,
  'Ana no puede cambiar su fecha de nacimiento (saltarse la regla de 18 años)'
);

select throws_ok(
  $$ update public.perfiles set activo = false, creado_en = now()
      where id = '11111111-1111-1111-1111-111111111111' $$,
  '42501', null,
  'Ana no puede cambiar activo ni creado_en'
);

select results_eq(
  $$ with editados as (
       update public.perfiles set nickname = 'robado'
        where id = '22222222-2222-2222-2222-222222222222'
       returning 1)
     select count(*)::int from editados $$,
  $$ values (0) $$,
  'Ana no puede editar el perfil de Beto (RLS no le muestra la fila)'
);

reset role;

-- ---------------------------------------------------------------------
-- Comprobaciones con permisos de administrador
-- ---------------------------------------------------------------------
select is(
  (select raw_app_meta_data ->> 'nickname' from auth.users
    where id = '11111111-1111-1111-1111-111111111111'),
  'AnaMaria',
  'el nickname editado llega a la sesión (trigger de RF-07)'
);

-- Guardar sin cambios no debe mover actualizado_en.
update public.perfiles set actualizado_en = '2026-01-01 00:00:00+00'
 where id = '11111111-1111-1111-1111-111111111111';

set local role authenticated;
update public.perfiles
   set nombre_completo = 'Ana María Ríos', nickname = 'AnaMaria'
 where id = '11111111-1111-1111-1111-111111111111';
reset role;

select is(
  (select actualizado_en from public.perfiles
    where id = '11111111-1111-1111-1111-111111111111'),
  '2026-01-01 00:00:00+00'::timestamptz,
  'guardar sin cambios no modifica actualizado_en'
);

-- ---------------------------------------------------------------------
-- Sin sesión
-- ---------------------------------------------------------------------
set local role anon;
set local request.jwt.claims to '{"role":"anon"}';

select throws_ok(
  $$ update public.perfiles set nickname = 'hacker'
      where id = '11111111-1111-1111-1111-111111111111' $$,
  '42501', null,
  'un visitante sin sesión no puede editar perfiles'
);

reset role;

select * from finish();
rollback;
