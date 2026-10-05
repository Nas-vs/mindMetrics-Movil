-- =====================================================================
-- Pruebas de RF-03 (pgTAP). Se corren con:   supabase test db
-- Todo ocurre dentro de una transacción que se deshace al final.
-- Cada usuario de prueba incluye el consentimiento de RF-02, porque
-- su trigger también exige esos datos para registrarse.
-- =====================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(14);

-- Usuarios de prueba:
--   Ana  = 11111111-1111-1111-1111-111111111111
--   Beto = 22222222-2222-2222-2222-222222222222

-- ---------------------------------------------------------------------
-- Registro válido
-- ---------------------------------------------------------------------
select lives_ok(
  $$ insert into auth.users (id, email, raw_user_meta_data) values
     ('11111111-1111-1111-1111-111111111111', 'ana@prueba.co',
      '{"nombre_completo":"Ana María Peña","nickname":"Ana","fecha_nacimiento":"1995-05-05",
        "acepta_datos_sensibles":true,"version_politica":"1.0"}'),
     ('22222222-2222-2222-2222-222222222222', 'beto@prueba.co',
      '{"nombre_completo":"Beto Prueba","nickname":"beto","fecha_nacimiento":"1995-05-05",
        "acepta_datos_sensibles":true,"version_politica":"1.0"}') $$,
  'registro con datos válidos funciona (acepta tildes y ñ)'
);

select is(
  (select nickname from public.perfiles where id = '11111111-1111-1111-1111-111111111111'),
  'Ana',
  'el trigger creó el perfil con los datos enviados'
);

-- ---------------------------------------------------------------------
-- Edad mínima: 18 años exactos sí, un día menos no
-- ---------------------------------------------------------------------
select lives_ok(
  format(
    $$ insert into auth.users (id, email, raw_user_meta_data) values
       ('33333333-3333-3333-3333-333333333333', 'justo18@prueba.co', %L::jsonb) $$,
    jsonb_build_object(
      'nombre_completo', 'Justo Dieciocho', 'nickname', 'justo18',
      'fecha_nacimiento', (current_date - interval '18 years')::date,
      'acepta_datos_sensibles', true, 'version_politica', '1.0')
  ),
  'quien cumple 18 años hoy sí puede registrarse'
);

select throws_ok(
  format(
    $$ insert into auth.users (id, email, raw_user_meta_data) values
       ('99999999-9999-9999-9999-999999999999', 'menor@prueba.co', %L::jsonb) $$,
    jsonb_build_object(
      'nombre_completo', 'Menor Prueba', 'nickname', 'menor',
      'fecha_nacimiento', (current_date - interval '18 years' + interval '1 day')::date,
      'acepta_datos_sensibles', true, 'version_politica', '1.0')
  ),
  'P0001',
  'menor_de_edad',
  'un menor de 18 años no puede registrarse'
);

-- ---------------------------------------------------------------------
-- Nickname
-- ---------------------------------------------------------------------
select throws_ok(
  $$ insert into auth.users (id, email, raw_user_meta_data) values
     ('99999999-9999-9999-9999-999999999999', 'otra.ana@prueba.co',
      '{"nombre_completo":"Otra Ana","nickname":"ANA","fecha_nacimiento":"1995-05-05",
        "acepta_datos_sensibles":true,"version_politica":"1.0"}') $$,
  '23505',
  null,
  'nickname duplicado se rechaza sin importar mayúsculas'
);

select throws_ok(
  $$ insert into auth.users (id, email, raw_user_meta_data) values
     ('99999999-9999-9999-9999-999999999999', 'espacio@prueba.co',
      '{"nombre_completo":"Con Espacio","nickname":"con espacio","fecha_nacimiento":"1995-05-05",
        "acepta_datos_sensibles":true,"version_politica":"1.0"}') $$,
  '23514',
  null,
  'nickname con espacios se rechaza'
);

select throws_ok(
  $$ insert into auth.users (id, email, raw_user_meta_data) values
     ('99999999-9999-9999-9999-999999999999', 'corto@prueba.co',
      '{"nombre_completo":"Muy Corto","nickname":"ab","fecha_nacimiento":"1995-05-05",
        "acepta_datos_sensibles":true,"version_politica":"1.0"}') $$,
  '23514',
  null,
  'nickname de menos de 3 caracteres se rechaza'
);

-- ---------------------------------------------------------------------
-- Nombre completo y campos obligatorios
-- ---------------------------------------------------------------------
select throws_ok(
  $$ insert into auth.users (id, email, raw_user_meta_data) values
     ('99999999-9999-9999-9999-999999999999', 'numeros@prueba.co',
      '{"nombre_completo":"Ana 123","nickname":"numeros","fecha_nacimiento":"1995-05-05",
        "acepta_datos_sensibles":true,"version_politica":"1.0"}') $$,
  '23514',
  null,
  'nombre con números se rechaza'
);

select throws_ok(
  $$ insert into auth.users (id, email, raw_user_meta_data) values
     ('99999999-9999-9999-9999-999999999999', 'sinnick@prueba.co',
      '{"nombre_completo":"Sin Nickname","fecha_nacimiento":"1995-05-05",
        "acepta_datos_sensibles":true,"version_politica":"1.0"}') $$,
  '23502',
  null,
  'registro sin nickname se rechaza'
);

-- ---------------------------------------------------------------------
-- RLS: cada usuario solo ve su perfil
-- ---------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select is(
  (select count(*)::int from public.perfiles),
  1,
  'Ana solo ve su propio perfil'
);

select is(
  (select count(*)::int from public.perfiles where id = '22222222-2222-2222-2222-222222222222'),
  0,
  'Ana no puede ver el perfil de Beto'
);

reset role;

set local role anon;

select is(
  (select count(*)::int from public.perfiles),
  0,
  'sin sesión no se ve ningún perfil'
);

-- ---------------------------------------------------------------------
-- RPC nickname_disponible (se usa sin sesión, antes de signUp)
-- ---------------------------------------------------------------------
select is(
  public.nickname_disponible('aNa'),
  false,
  'nickname_disponible detecta un nickname ocupado sin importar mayúsculas'
);

select is(
  public.nickname_disponible('nuevo_nick'),
  true,
  'nickname_disponible devuelve true si está libre'
);

reset role;

select * from finish();
rollback;
