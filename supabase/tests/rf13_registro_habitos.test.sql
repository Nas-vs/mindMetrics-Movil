begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(32);

-- Usuarios de prueba (con los datos que piden los triggers de RF-02 y RF-03)
insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'ana@prueba.co',
   '{"nombre_completo":"Ana Prueba","nickname":"ana","fecha_nacimiento":"1995-05-05",
     "acepta_datos_sensibles":true,"version_politica":"1.0"}'),
  ('22222222-2222-2222-2222-222222222222', 'beto@prueba.co',
   '{"nombre_completo":"Beto Prueba","nickname":"beto","fecha_nacimiento":"1995-05-05",
     "acepta_datos_sensibles":true,"version_politica":"1.0"}');

-- ---------------------------------------------------------------------
-- Catálogo
-- ---------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select is(
  (select count(*)::int from public.habitos where activo),
  8,
  'el usuario puede leer los 8 hábitos del catálogo'
);

select ok(
  not exists (select 1 from public.habitos where icono is null or icono = ''),
  'todos los hábitos tienen ícono'
);

select throws_ok(
  $$ insert into public.habitos (id, nombre, icono, orden) values (99, 'Hackeo', 'x', 99) $$,
  '42501', null,
  'la app no puede modificar el catálogo'
);

-- ---------------------------------------------------------------------
-- Registro
-- ---------------------------------------------------------------------
select is(
  (public.marcar_habito(current_date, 1, true, now() - interval '10 minutes') ->> 'aplicado')::boolean,
  true,
  'marcar un hábito crea el registro'
);

select is(
  (select completado from public.registro_habitos where fecha = current_date and habito_id = 1),
  true,
  'quedó marcado como completado'
);

-- Idempotente: el mismo cambio dos veces
select is(
  public.marcar_habito(current_date, 1, true, now() - interval '10 minutes') -> 'registro' -> 'completado',
  'true'::jsonb,
  'repetir el mismo cambio devuelve el mismo registro'
);

select is(
  (select count(*)::int from public.registro_habitos),
  1,
  'repetir no duplica el registro'
);

-- ---------------------------------------------------------------------
-- Edición
-- ---------------------------------------------------------------------
select is(
  (public.marcar_habito(current_date, 1, false, now() - interval '5 minutes') ->> 'aplicado')::boolean,
  true,
  'desmarcar con un cambio más nuevo se aplica'
);

select is(
  (select completado from public.registro_habitos where fecha = current_date and habito_id = 1),
  false,
  'el hábito quedó desmarcado'
);

-- ---------------------------------------------------------------------
-- Conflicto offline
-- ---------------------------------------------------------------------
select is(
  (public.marcar_habito(current_date, 1, true, now() - interval '1 hour') ->> 'aplicado')::boolean,
  false,
  'un cambio viejo que llega tarde NO pisa uno más reciente'
);

select is(
  public.marcar_habito(current_date, 1, true, now() - interval '1 hour') -> 'registro' -> 'completado',
  'false'::jsonb,
  'la respuesta trae lo que quedó guardado (el valor más reciente)'
);

select lives_ok(
  $$ select public.marcar_habito(current_date - 7, 3, true) $$,
  'se puede sincronizar un hábito de un día pasado'
);

-- ---------------------------------------------------------------------
-- Validaciones
-- ---------------------------------------------------------------------
select throws_ok(
  $$ select public.marcar_habito(current_date + 5, 1, true) $$,
  'P0001', 'fecha_futura',
  'no se puede marcar un día futuro'
);

select throws_ok(
  $$ select public.marcar_habito(current_date, 999, true) $$,
  'P0001', 'habito_invalido',
  'no se aceptan hábitos que no existen'
);

select throws_ok(
  $$ select public.marcar_habito(current_date, 1, null) $$,
  'P0001', 'datos_incompletos',
  'completado es obligatorio'
);

-- Un hábito desactivado no se puede marcar
reset role;
update public.habitos set activo = false where id = 8;
set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select throws_ok(
  $$ select public.marcar_habito(current_date, 8, true) $$,
  'P0001', 'habito_invalido',
  'no se puede marcar un hábito desactivado'
);

-- ---------------------------------------------------------------------
-- Seguridad: escribir solo por la RPC
-- ---------------------------------------------------------------------
select throws_ok(
  $$ insert into public.registro_habitos
       (usuario_id, fecha, habito_id, completado, actualizado_en_cliente)
     values ('11111111-1111-1111-1111-111111111111', current_date - 1, 2, true, now()) $$,
  '42501', null,
  'la app no puede insertar directamente (solo por la RPC)'
);

select throws_ok(
  $$ update public.registro_habitos set completado = true $$,
  '42501', null,
  'la app no puede editar directamente (solo por la RPC)'
);

-- ---------------------------------------------------------------------
-- detalle_dia
-- ---------------------------------------------------------------------
-- Datos de Ana para el día: ánimo con emociones, hábitos y actividades
select public.guardar_registro_animo(
  'aaaa0000-0000-4000-8000-000000000001', current_date, 4, array[2, 1], array[8, 1], 'Buen día');
select public.marcar_habito(current_date, 2, true);

insert into public.actividades (id, titulo, categoria, fecha, hora) values
  ('a1000000-0000-4000-8000-000000000001', 'Tarde',     'ocio',    current_date,     '19:00'),
  ('a1000000-0000-4000-8000-000000000002', 'Mañana',    'estudio', current_date,     '08:00'),
  ('a1000000-0000-4000-8000-000000000003', 'Otro día',  'otro',    current_date - 1, '08:00');

select is(
  public.detalle_dia(current_date) -> 'animo' -> 'nivel',
  '4'::jsonb,
  'detalle_dia trae el nivel de ánimo'
);

select is(
  public.detalle_dia(current_date) -> 'animo' ->> 'nota',
  'Buen día',
  'detalle_dia trae la nota'
);

select is(
  public.detalle_dia(current_date) -> 'animo' -> 'emociones',
  '[{"id": 1, "nombre": "Alegría"}, {"id": 2, "nombre": "Calma"}]'::jsonb,
  'detalle_dia trae las emociones con su nombre'
);

select is(
  public.detalle_dia(current_date) -> 'animo' -> 'factores',
  '[{"id": 1, "nombre": "Sueño"}, {"id": 8, "nombre": "Ejercicio"}]'::jsonb,
  'detalle_dia trae los factores con su nombre'
);

select is(
  jsonb_array_length(public.detalle_dia(current_date) -> 'habitos'),
  7,
  'detalle_dia trae todos los hábitos activos (el desactivado no)'
);

select is(
  (select jsonb_agg(h -> 'id') filter (where (h ->> 'completado')::boolean)
     from jsonb_array_elements(public.detalle_dia(current_date) -> 'habitos') h),
  '[2]'::jsonb,
  'solo el hábito 2 sale completado (el 1 fue desmarcado, los demás sin registro)'
);

select is(
  (select jsonb_agg(a ->> 'titulo')
     from jsonb_array_elements(public.detalle_dia(current_date) -> 'actividades') a),
  '["Mañana", "Tarde"]'::jsonb,
  'detalle_dia trae solo las actividades de ese día, por hora'
);

select is(
  public.detalle_dia(current_date - 30) -> 'animo',
  'null'::jsonb,
  'un día sin registro de ánimo devuelve animo = null'
);

select is(
  (select count(*)::int
     from jsonb_array_elements(public.detalle_dia(current_date - 30) -> 'habitos') h
    where not (h ->> 'completado')::boolean),
  7,
  'un día sin registros trae todos los hábitos en false'
);

-- ---------------------------------------------------------------------
-- RLS entre dos usuarios
-- ---------------------------------------------------------------------
set local request.jwt.claims to '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select is(
  (select count(*)::int from public.registro_habitos),
  0,
  'Beto no ve los hábitos de Ana'
);

select is(
  public.detalle_dia(current_date) - 'fecha' - 'habitos',
  '{"animo": null, "actividades": []}'::jsonb,
  'detalle_dia de Beto no trae el ánimo ni las actividades de Ana'
);

select is(
  (public.marcar_habito(current_date, 1, true, now() - interval '2 hours') ->> 'aplicado')::boolean,
  true,
  'Beto marca el mismo hábito el mismo día sin chocar con Ana (aunque su cambio sea más viejo)'
);

reset role;
select is(
  (select completado from public.registro_habitos
    where usuario_id = '11111111-1111-1111-1111-111111111111'
      and fecha = current_date and habito_id = 1),
  false,
  'el registro de Ana no cambió'
);

set local role anon;
set local request.jwt.claims to '{"role":"anon"}';

select throws_ok(
  $$ select public.detalle_dia(current_date) $$,
  '42501', null,
  'sin sesión no se puede pedir el detalle del día'
);

reset role;

select * from finish();
rollback;
