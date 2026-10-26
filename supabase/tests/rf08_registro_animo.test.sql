begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(20);

-- Usuarios de prueba (con los datos que piden los triggers de RF-02 y RF-03)
insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'ana@prueba.co',
   '{"nombre_completo":"Ana Prueba","nickname":"ana","fecha_nacimiento":"1995-05-05",
     "acepta_datos_sensibles":true,"version_politica":"1.0"}'),
  ('22222222-2222-2222-2222-222222222222', 'beto@prueba.co',
   '{"nombre_completo":"Beto Prueba","nickname":"beto","fecha_nacimiento":"1995-05-05",
     "acepta_datos_sensibles":true,"version_politica":"1.0"}');

-- ---------------------------------------------------------------------
-- Catálogos (CA-4)
-- ---------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select ok(
  (select count(*) from public.emociones) >= 10
  and (select count(*) from public.factores) >= 10,
  'el usuario puede leer los catálogos de emociones y factores'
);

select ok(
  not exists (select 1 from public.emociones where definicion is null or definicion = ''),
  'todas las emociones tienen definición (la usa RF-17)'
);

-- ---------------------------------------------------------------------
-- CA-3: tocar un emoji guarda de inmediato
-- ---------------------------------------------------------------------
select is(
  (public.guardar_registro_animo(
     'aaaa0000-0000-4000-8000-000000000001', current_date, 4,
     p_actualizado_en => now() - interval '10 minutes') ->> 'aplicado')::boolean,
  true,
  'tocar un emoji crea el registro del día'
);

select is(
  (select nivel::int from public.registros_animo where fecha = current_date),
  4,
  'quedó guardado el nivel 4'
);

-- ---------------------------------------------------------------------
-- CA-4: el panel agrega emociones, factores y nota
-- ---------------------------------------------------------------------
select is(
  public.guardar_registro_animo(
    'aaaa0000-0000-4000-8000-000000000001', current_date, 4,
    array[1, 3], array[2], 'Buen día',
    now() - interval '9 minutes') -> 'registro' -> 'emociones',
  '[1, 3]'::jsonb,
  'el panel guarda las emociones elegidas'
);

select is(
  (select count(*)::int from public.registro_factores),
  1,
  'el panel guarda los factores elegidos'
);

-- ---------------------------------------------------------------------
-- CA-1: un solo registro por día; volver a registrar EDITA
-- ---------------------------------------------------------------------
select is(
  public.guardar_registro_animo(
    'bbbb0000-0000-4000-8000-000000000002', 
    current_date, 2,
    p_actualizado_en => now() - interval '8 minutes') -> 'registro' ->> 'id',
  'aaaa0000-0000-4000-8000-000000000001',
  'registrar otra vez el mismo día edita el existente y devuelve su id'
);

select is(
  (select count(*)::int from public.registros_animo where fecha = current_date),
  1,
  'sigue habiendo un solo registro hoy'
);

select is(
  (select nivel::int from public.registros_animo where fecha = current_date),
  2,
  'el nivel quedó actualizado a 2'
);

select is(
  (select count(*)::int from public.registro_emociones),
  2,
  'cambiar solo el emoji NO borra las emociones (null = no tocar)'
);

select is(
  (select nota from public.registros_animo where fecha = current_date),
  'Buen día',
  'cambiar solo el emoji NO borra la nota'
);

select is(
  public.guardar_registro_animo(
    'aaaa0000-0000-4000-8000-000000000001', current_date, 2,
    array[]::int[], null, '',
    now() - interval '7 minutes') -> 'registro' -> 'emociones',
  '[]'::jsonb,
  'una lista vacía sí borra las emociones'
);

-- ---------------------------------------------------------------------
-- CA-6: sincronización sin conexión
-- ---------------------------------------------------------------------
select is(
  (public.guardar_registro_animo(
     'aaaa0000-0000-4000-8000-000000000001', current_date, 5,
     p_actualizado_en => now() - interval '1 hour') ->> 'aplicado')::boolean,
  false,
  'un cambio viejo que llega tarde NO pisa uno más reciente'
);

select is(
  (select nivel::int from public.registros_animo where fecha = current_date),
  2,
  'el nivel sigue siendo el más reciente (2)'
);

select lives_ok(
  $$ select public.guardar_registro_animo(
       'cccc0000-0000-4000-8000-000000000003', current_date - 3, 3) $$,
  'se puede sincronizar el registro de un día pasado'
);

-- ---------------------------------------------------------------------
-- Validaciones
-- ---------------------------------------------------------------------
select throws_ok(
  $$ select public.guardar_registro_animo(
       'dddd0000-0000-4000-8000-000000000004', current_date - 1, 6) $$,
  'P0001', 'nivel_invalido',
  'el nivel debe estar entre 1 y 5'
);

select throws_ok(
  $$ select public.guardar_registro_animo(
       'dddd0000-0000-4000-8000-000000000004', current_date + 5, 3) $$,
  'P0001', 'fecha_futura',
  'no se puede registrar un día futuro'
);

select throws_ok(
  $$ select public.guardar_registro_animo(
       'dddd0000-0000-4000-8000-000000000004', current_date - 1, 3, array[999]) $$,
  'P0001', 'emocion_invalida',
  'no se aceptan emociones que no existen'
);

-- ---------------------------------------------------------------------
-- Seguridad
-- ---------------------------------------------------------------------
select throws_ok(
  $$ insert into public.registros_animo (id, usuario_id, fecha, nivel, actualizado_en_cliente)
     values ('eeee0000-0000-4000-8000-000000000005',
             '11111111-1111-1111-1111-111111111111', current_date - 10, 3, now()) $$,
  '42501', null,
  'la app no puede insertar directamente (solo por la RPC)'
);

set local request.jwt.claims to '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select is(
  (select count(*)::int from public.registros_animo),
  0,
  'cada usuario solo ve sus propios registros'
);

reset role;

select * from finish();
rollback;
