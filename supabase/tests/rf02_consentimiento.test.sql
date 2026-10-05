-- =====================================================================
-- Pruebas de RF-02 (pgTAP). Se corren con:   supabase test db
-- Todo ocurre dentro de una transacción que se deshace al final,
-- así que no deja basura en la base local.
-- =====================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(12);

-- Usuarios de prueba:
--   Ana  = 11111111-1111-1111-1111-111111111111
--   Beto = 22222222-2222-2222-2222-222222222222

-- ---------------------------------------------------------------------
-- La política se puede leer SIN sesión (pantalla previa al registro)
-- ---------------------------------------------------------------------
set local role anon;

select is(
  (select count(*)::int from public.politicas_privacidad where vigente),
  1,
  'anon ve exactamente una política vigente'
);

select is(
  (select version from public.politicas_privacidad where vigente),
  '1.0',
  'la versión vigente es la 1.0'
);

-- Con RLS, un update sin política no da error: simplemente no cambia nada
update public.politicas_privacidad set contenido = 'hackeado';
select is(
  (select count(*)::int from public.politicas_privacidad where contenido = 'hackeado'),
  0,
  'anon no puede modificar la política'
);

reset role;

-- ---------------------------------------------------------------------
-- Registro (simulamos lo que hace supabase.auth.signUp)
-- Se envían también los datos de RF-03 para que estas pruebas sigan
-- funcionando cuando exista el trigger de perfiles.
-- ---------------------------------------------------------------------
select throws_ok(
  $$ insert into auth.users (id, email, raw_user_meta_data) values (
       '99999999-9999-9999-9999-999999999999', 'sin@prueba.co',
       '{"nombre_completo":"Sin Consentimiento","nickname":"sin_ok","fecha_nacimiento":"1990-01-01",
         "version_politica":"1.0"}') $$,
  'P0001',
  'consentimiento_requerido',
  'no se puede crear cuenta sin aceptar'
);

select throws_ok(
  $$ insert into auth.users (id, email, raw_user_meta_data) values (
       '99999999-9999-9999-9999-999999999999', 'vieja@prueba.co',
       '{"nombre_completo":"Version Vieja","nickname":"vieja","fecha_nacimiento":"1990-01-01",
         "acepta_datos_sensibles":true,"version_politica":"0.9"}') $$,
  'P0001',
  'version_politica_invalida',
  'no se puede aceptar una versión que no es la vigente'
);

select lives_ok(
  $$ insert into auth.users (id, email, raw_user_meta_data) values
     ('11111111-1111-1111-1111-111111111111', 'ana@prueba.co',  '{"nombre_completo":"Ana Prueba","nickname":"ana","fecha_nacimiento":"1995-05-05",
                              "acepta_datos_sensibles":true,"version_politica":"1.0"}'),
     ('22222222-2222-2222-2222-222222222222', 'beto@prueba.co', '{"nombre_completo":"Beto Prueba","nickname":"beto","fecha_nacimiento":"1995-05-05",
                              "acepta_datos_sensibles":true,"version_politica":"1.0"}') $$,
  'registro con consentimiento válido funciona'
);

select ok(
  (select fecha_aceptacion is not null
     from public.consentimientos
    where usuario_id = '11111111-1111-1111-1111-111111111111' and version_politica = '1.0'),
  'el backend guardó el consentimiento con su fecha'
);

-- ---------------------------------------------------------------------
-- RLS: cada usuario solo ve lo suyo y no puede escribir directamente
-- ---------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select is(
  (select count(*)::int from public.consentimientos),
  1,
  'Ana solo ve su propio consentimiento'
);

select is(
  (select count(*)::int from public.consentimientos where usuario_id = '22222222-2222-2222-2222-222222222222'),
  0,
  'Ana no puede ver el consentimiento de Beto'
);

select throws_ok(
  $$ insert into public.consentimientos (usuario_id, version_politica, acepta_datos_sensibles)
     values ('22222222-2222-2222-2222-222222222222', '1.0', true) $$,
  '42501',
  null,
  'la app no puede insertar consentimientos directamente'
);

select lives_ok(
  $$ select public.aceptar_politica('1.0') $$,
  'aceptar_politica es seguro de llamar dos veces (no duplica)'
);

reset role;

-- ---------------------------------------------------------------------
-- La RPC no está disponible sin sesión
-- ---------------------------------------------------------------------
set local role anon;
select throws_ok(
  $$ select public.aceptar_politica('1.0') $$,
  '42501',
  null,
  'anon no puede llamar aceptar_politica'
);
reset role;

select * from finish();
rollback;
