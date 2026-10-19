-- =====================================================================
-- Pruebas de RF-07 (pgTAP). Se corren con:   supabase test db
-- Todo ocurre dentro de una transacción que se deshace al final.
-- Cada usuario de prueba incluye los datos de RF-02 y RF-03, porque sus
-- triggers también se ejecutan al registrarse.
-- =====================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(8);

-- Usuarios de prueba:
--   Ana  = 11111111-1111-1111-1111-111111111111
--   Beto = 22222222-2222-2222-2222-222222222222
-- raw_app_meta_data imita lo que Supabase Auth pone al registrar por correo.
insert into auth.users (id, email, raw_app_meta_data, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'ana@prueba.co',
   '{"provider":"email","providers":["email"]}',
   '{"nombre_completo":"Ana Prueba","nickname":"Ana","fecha_nacimiento":"1995-05-05",
     "acepta_datos_sensibles":true,"version_politica":"1.0"}'),
  ('22222222-2222-2222-2222-222222222222', 'beto@prueba.co',
   '{"provider":"email","providers":["email"]}',
   '{"nombre_completo":"Beto Prueba","nickname":"beto","fecha_nacimiento":"1995-05-05",
     "acepta_datos_sensibles":true,"version_politica":"1.0"}');


-- ---------------------------------------------------------------------
-- CA-2: el nickname queda en la sesión desde el registro
-- ---------------------------------------------------------------------
select is(
  (select raw_app_meta_data ->> 'nickname' from auth.users
    where id = '11111111-1111-1111-1111-111111111111'),
  'Ana',
  'al registrarse, el nickname queda en app_metadata (respeta mayúsculas)'
);

select is(
  (select raw_app_meta_data ->> 'nickname' from auth.users
    where id = '11111111-1111-1111-1111-111111111111'),
  (select nickname from public.perfiles
    where id = '11111111-1111-1111-1111-111111111111'),
  'el nickname de la sesión es el mismo de perfiles (fuente de verdad)'
);

select is(
  (select raw_app_meta_data ->> 'provider' from auth.users
    where id = '11111111-1111-1111-1111-111111111111'),
  'email',
  'no se pierden las claves que pone Supabase Auth (provider)'
);


-- ---------------------------------------------------------------------
-- Sincronización al editar el nickname (lo usará RF-23)
-- ---------------------------------------------------------------------
update public.perfiles
   set nickname = 'AnaMaria'
 where id = '11111111-1111-1111-1111-111111111111';

select is(
  (select raw_app_meta_data ->> 'nickname' from auth.users
    where id = '11111111-1111-1111-1111-111111111111'),
  'AnaMaria',
  'al cambiar el nickname en perfiles, la sesión se actualiza'
);

select throws_ok(
  $$ update public.perfiles set nickname = 'BETO'
      where id = '11111111-1111-1111-1111-111111111111' $$,
  '23505',
  null,
  'un nickname ocupado (sin importar mayúsculas) se rechaza'
);

select is(
  (select raw_app_meta_data ->> 'nickname' from auth.users
    where id = '11111111-1111-1111-1111-111111111111'),
  'AnaMaria',
  'si el cambio de nickname falla, la sesión conserva el valor anterior'
);


-- ---------------------------------------------------------------------
-- Seguridad: la función del trigger no se expone por la API
-- ---------------------------------------------------------------------
select is(
  has_function_privilege('authenticated', 'public.sincronizar_nickname_sesion()', 'execute'),
  false,
  'un usuario con sesión no puede ejecutar la función del trigger'
);

select is(
  has_function_privilege('anon', 'public.sincronizar_nickname_sesion()', 'execute'),
  false,
  'un visitante sin sesión no puede ejecutar la función del trigger'
);

select * from finish();
rollback;
