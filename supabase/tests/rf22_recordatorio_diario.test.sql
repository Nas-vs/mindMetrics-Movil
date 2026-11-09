-- =====================================================================
-- Pruebas de RF-22 (pgTAP). Se corren con:   supabase test db
-- Todo ocurre dentro de una transacción que se deshace al final (rollback).
-- =====================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(10);

-- ---------------------------------------------------------------------
-- 1. Preparación: dos usuarios de prueba (Ana y Beto)
-- ---------------------------------------------------------------------
insert into auth.users (id, email, raw_app_meta_data, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'ana@prueba.co',
   '{"provider":"email","providers":["email"]}',
   '{"nombre_completo":"Ana Prueba","nickname":"ana","fecha_nacimiento":"1995-05-05",
     "acepta_datos_sensibles":true,"version_politica":"1.0"}'),
  ('22222222-2222-2222-2222-222222222222', 'beto@prueba.co',
   '{"provider":"email","providers":["email"]}',
   '{"nombre_completo":"Beto Prueba","nickname":"beto","fecha_nacimiento":"1995-05-05",
     "acepta_datos_sensibles":true,"version_politica":"1.0"}');


-- ---------------------------------------------------------------------
-- 2. Seguridad: visitante sin sesión (anon) no puede interactuar
-- ---------------------------------------------------------------------
set local role anon;

select throws_ok(
  $$ select * from public.preferencias_recordatorio $$,
  '42501', null,
  'anon no tiene permisos para consultar preferencias_recordatorio'
);

select throws_ok(
  $$ select public.guardar_preferencias_recordatorio(true, 20, 0, true) $$,
  '42501', null,
  'anon no puede ejecutar guardar_preferencias_recordatorio'
);

reset role;


-- ---------------------------------------------------------------------
-- 3. Como Ana: guardar y actualizar preferencias de recordatorio
-- ---------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

-- Validaciones de hora y minuto
select throws_ok(
  $$ select public.guardar_preferencias_recordatorio(true, 25, 0, false) $$,
  '22003', null,
  'hora 25 es inválida y se rechaza'
);

select throws_ok(
  $$ select public.guardar_preferencias_recordatorio(true, 20, 60, false) $$,
  '22003', null,
  'minuto 60 es inválido y se rechaza'
);

-- Guardar correctamente
select lives_ok(
  $$ select public.guardar_preferencias_recordatorio(true, 21, 30, true) $$,
  'Ana guarda su recordatorio para las 21:30'
);

select results_eq(
  $$ select activo, hora, minuto, beneficio_explicado
       from public.preferencias_recordatorio $$,
  $$ values (true, 21::smallint, 30::smallint, true) $$,
  'los datos guardados de Ana son exactamente los enviados'
);

-- Actualizar (cambiar hora a 22:15)
select lives_ok(
  $$ select public.guardar_preferencias_recordatorio(true, 22, 15, true) $$,
  'Ana actualiza la hora de su recordatorio a 22:15'
);

select results_eq(
  $$ select hora, minuto
       from public.preferencias_recordatorio $$,
  $$ values (22::smallint, 15::smallint) $$,
  'la actualización se guardó correctamente sin crear duplicados'
);


-- ---------------------------------------------------------------------
-- 4. Aislamiento RLS: Beto no ve ni altera las preferencias de Ana
-- ---------------------------------------------------------------------
set local request.jwt.claims to '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select is_empty(
  $$ select * from public.preferencias_recordatorio $$,
  'Beto no puede ver las preferencias de recordatorio de Ana'
);

select lives_ok(
  $$ select public.guardar_preferencias_recordatorio(false, 8, 0, false) $$,
  'Beto puede guardar sus propias preferencias'
);

reset role;

select * from finish();
rollback;