begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(8);

-- 1. Estructura de la tabla
select has_table('public', 'actividades', 'La tabla actividades debe existir');

-- 2. Seguridad: Visitante sin sesión no puede ver actividades
set local role anon;

select results_eq(
  $$ select count(*)::int from public.actividades $$,
  $$ values (0) $$,
  'anon no puede ver ninguna actividad por RLS'
);

reset role;

-- 3. Crear usuarios de prueba (Ana y Beto)
insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'ana@prueba.co',
   '{"nombre_completo":"Ana Prueba","nickname":"ana","fecha_nacimiento":"1995-05-05",
     "acepta_datos_sensibles":true,"version_politica":"1.0"}'),
  ('22222222-2222-2222-2222-222222222222', 'beto@prueba.co',
   '{"nombre_completo":"Beto Prueba","nickname":"beto","fecha_nacimiento":"1995-05-05",
     "acepta_datos_sensibles":true,"version_politica":"1.0"}');

-- 4. Como Ana: registrar actividad y registro de ánimo
set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

insert into public.actividades (
  id, usuario_id, titulo, categoria, fecha
) values (
  gen_random_uuid(),
  '11111111-1111-1111-1111-111111111111',
  'Caminata en el parque',
  'ejercicio',
  '2026-11-05'
);

select results_eq(
  $$ select count(*)::int from public.actividades $$,
  $$ values (1) $$,
  'Ana puede ver su actividad registrada'
);

-- Registrar ánimo de prueba para el día 5 de noviembre usando la función oficial de RF-08
select public.guardar_registro_animo(
  gen_random_uuid(),
  '2026-11-05'::date,
  4
);

-- 5. Como Beto: aislamiento RLS (no debe ver la actividad de Ana)
set local role authenticated;
set local request.jwt.claims to '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select results_eq(
  $$ select count(*)::int from public.actividades $$,
  $$ values (0) $$,
  'Beto no puede ver las actividades de Ana por RLS'
);

-- 6. Como Ana: probar la función RPC obtener_resumen_calendario_mes
set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

-- Retorna exactamente los 30 días de noviembre
select results_eq(
  $$ select count(*)::int from public.obtener_resumen_calendario_mes(2026, 11) $$,
  $$ values (30) $$,
  'El RPC retorna exactamente los 30 días de noviembre'
);

-- El día 5 debe tener ánimo = 4 y tiene_actividades = true (RF-11 CA-2 y CA-3)
select results_eq(
  $$ 
    select nivel_animo, tiene_actividades 
    from public.obtener_resumen_calendario_mes(2026, 11) 
    where fecha = '2026-11-05'::date 
  $$,
  $$ values (4::smallint, true) $$,
  'El día 5 muestra nivel 4 y actividades = true'
);

-- Un día sin datos (ej. 1 de noviembre) debe tener ánimo null y actividades = false
select results_eq(
  $$ 
    select nivel_animo is null, tiene_actividades 
    from public.obtener_resumen_calendario_mes(2026, 11) 
    where fecha = '2026-11-01'::date 
  $$,
  $$ values (true, false) $$,
  'Día sin registros retorna ánimo nulo y actividades false'
);

-- Aislamiento en el RPC: Beto no debe ver los datos de Ana en el resumen mensual
set local role authenticated;
set local request.jwt.claims to '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select results_eq(
  $$ 
    select nivel_animo is null, tiene_actividades 
    from public.obtener_resumen_calendario_mes(2026, 11) 
    where fecha = '2026-11-05'::date 
  $$,
  $$ values (true, false) $$,
  'Beto no ve el ánimo ni las actividades de Ana en el RPC mensual'
);

select * from finish();
rollback;