begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(27);

-- Usuarios de prueba (con los datos que piden los triggers de RF-02 y RF-03)
insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'ana@prueba.co',
   '{"nombre_completo":"Ana Prueba","nickname":"ana","fecha_nacimiento":"1995-05-05",
     "acepta_datos_sensibles":true,"version_politica":"1.0"}'),
  ('22222222-2222-2222-2222-222222222222', 'beto@prueba.co',
   '{"nombre_completo":"Beto Prueba","nickname":"beto","fecha_nacimiento":"1995-05-05",
     "acepta_datos_sensibles":true,"version_politica":"1.0"}');

-- ---------------------------------------------------------------------
-- Estructura
-- ---------------------------------------------------------------------
select has_column('public', 'actividades', 'recordatorio_minutos_antes',
  'existe la columna recordatorio_minutos_antes');

select col_default_is('public', 'actividades', 'usuario_id', 'auth.uid()',
  'usuario_id toma por defecto el usuario de la sesión');

-- ---------------------------------------------------------------------
-- Registro
-- ---------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok(
  $$ insert into public.actividades
       (id, titulo, categoria, fecha, hora, tiene_recordatorio,
        recordatorio_minutos_antes, actualizado_en, actualizado_en_cliente)
     values
       ('a1000000-0000-4000-8000-000000000001', 'Caminar', 'ejercicio',
        '2026-12-01', '18:00', true, 30,
        '2020-01-01', now() - interval '10 minutes') $$,
  'la app crea una actividad sin enviar usuario_id'
);

select is(
  (select usuario_id from public.actividades where id = 'a1000000-0000-4000-8000-000000000001'),
  '11111111-1111-1111-1111-111111111111'::uuid,
  'la actividad quedó a nombre del usuario de la sesión'
);

select is(
  (select recordatorio_minutos_antes from public.actividades
    where id = 'a1000000-0000-4000-8000-000000000001'),
  30,
  'se guardan los minutos del recordatorio'
);

-- ---------------------------------------------------------------------
-- Edición: actualizado_en lo pone el servidor
-- ---------------------------------------------------------------------
update public.actividades
   set titulo = 'Caminar 30 min',
       actualizado_en = '2000-01-01',            -- intento de falsearlo
       actualizado_en_cliente = now() - interval '5 minutes'
 where id = 'a1000000-0000-4000-8000-000000000001';

select is(
  (select titulo from public.actividades where id = 'a1000000-0000-4000-8000-000000000001'),
  'Caminar 30 min',
  'una edición más nueva se aplica'
);

select is(
  (select actualizado_en from public.actividades where id = 'a1000000-0000-4000-8000-000000000001'),
  now(),
  'el trigger pone actualizado_en = now() en cada update (ignora lo que mande la app)'
);

-- Mismo actualizado_en_cliente: se aplica (reintento idempotente)
update public.actividades
   set completada = false,
       actualizado_en_cliente = now() - interval '5 minutes'
 where id = 'a1000000-0000-4000-8000-000000000001';

select is(
  (select titulo from public.actividades where id = 'a1000000-0000-4000-8000-000000000001'),
  'Caminar 30 min',
  'repetir el mismo cambio no rompe nada'
);

-- ---------------------------------------------------------------------
-- Conflicto offline: una edición vieja no pisa una nueva
-- ---------------------------------------------------------------------
update public.actividades
   set titulo = 'Versión vieja',
       actualizado_en_cliente = now() - interval '1 hour'
 where id = 'a1000000-0000-4000-8000-000000000001';

select is(
  (select titulo from public.actividades where id = 'a1000000-0000-4000-8000-000000000001'),
  'Caminar 30 min',
  'un update viejo que llega tarde se ignora'
);

-- Lo mismo vía upsert (como sincroniza la app)
select lives_ok(
  $$ insert into public.actividades
       (id, titulo, categoria, fecha, actualizado_en_cliente)
     values
       ('a1000000-0000-4000-8000-000000000001', 'Upsert viejo', 'ocio',
        '2026-12-01', now() - interval '2 hours')
     on conflict (id) do update
       set titulo = excluded.titulo,
           categoria = excluded.categoria,
           actualizado_en_cliente = excluded.actualizado_en_cliente $$,
  'un upsert viejo no lanza error'
);

select is(
  (select titulo || '/' || categoria from public.actividades
    where id = 'a1000000-0000-4000-8000-000000000001'),
  'Caminar 30 min/ejercicio',
  'un upsert viejo tampoco pisa la versión nueva'
);

select lives_ok(
  $$ insert into public.actividades
       (id, titulo, categoria, fecha, actualizado_en_cliente)
     values
       ('a1000000-0000-4000-8000-000000000001', 'Caminar al parque', 'ejercicio',
        '2026-12-01', now() - interval '1 minute')
     on conflict (id) do update
       set titulo = excluded.titulo,
           actualizado_en_cliente = excluded.actualizado_en_cliente $$,
  'un upsert más nuevo se sincroniza'
);

select is(
  (select titulo from public.actividades where id = 'a1000000-0000-4000-8000-000000000001'),
  'Caminar al parque',
  'el upsert más nuevo sí se aplicó'
);

-- ---------------------------------------------------------------------
-- Validaciones
-- ---------------------------------------------------------------------
select throws_ok(
  $$ insert into public.actividades
       (id, titulo, categoria, fecha, tiene_recordatorio, recordatorio_minutos_antes)
     values ('a1000000-0000-4000-8000-000000000099', 'X', 'otro', '2026-12-01', true, 1441) $$,
  '23514', 'new row for relation "actividades" violates check constraint "actividades_recordatorio_minutos_antes_check"',
  'el recordatorio no puede ser de más de 1440 minutos'
);

select throws_ok(
  $$ insert into public.actividades
       (id, titulo, categoria, fecha, tiene_recordatorio, recordatorio_minutos_antes)
     values ('a1000000-0000-4000-8000-000000000099', 'X', 'otro', '2026-12-01', true, -1) $$,
  '23514', 'new row for relation "actividades" violates check constraint "actividades_recordatorio_minutos_antes_check"',
  'el recordatorio no puede ser negativo'
);

select throws_ok(
  $$ insert into public.actividades
       (id, titulo, categoria, fecha, tiene_recordatorio, recordatorio_minutos_antes)
     values ('a1000000-0000-4000-8000-000000000099', 'X', 'otro', '2026-12-01', false, 30) $$,
  '23514', 'new row for relation "actividades" violates check constraint "actividades_minutos_requieren_recordatorio_check"',
  'no se pueden poner minutos si la actividad no tiene recordatorio'
);

select lives_ok(
  $$ insert into public.actividades
       (id, titulo, categoria, fecha, tiene_recordatorio, recordatorio_minutos_antes)
     values ('a1000000-0000-4000-8000-000000000098', 'Bordes', 'otro', '2026-12-01', true, 0) $$,
  '0 minutos (a la hora exacta) es válido'
);

-- ---------------------------------------------------------------------
-- proximas_actividades
-- ---------------------------------------------------------------------
-- Datos de Ana (además de las dos de arriba, ambas el 2026-12-01)
insert into public.actividades (id, titulo, categoria, fecha, hora, completada) values
  ('a1000000-0000-4000-8000-000000000002', 'Ayer',          'otro',    '2026-11-30', '09:00', false),
  ('a1000000-0000-4000-8000-000000000003', 'Ya hecha',      'otro',    '2026-12-02', '09:00', true),
  ('a1000000-0000-4000-8000-000000000004', 'Temprano',      'estudio', '2026-12-01', '07:00', false),
  ('a1000000-0000-4000-8000-000000000005', 'Pasado mañana', 'social',  '2026-12-03', '10:00', false),
  ('a1000000-0000-4000-8000-000000000006', 'Mañana',        'trabajo', '2026-12-02', '08:00', false);

select results_eq(
  $$ select titulo from public.proximas_actividades(10, '2026-12-01') $$,
  $$ values ('Temprano'), ('Caminar al parque'), ('Bordes'), ('Mañana'), ('Pasado mañana') $$,
  'trae las no completadas desde hoy, por fecha y hora (sin hora al final del día)'
);

select is(
  (select count(*)::int from public.proximas_actividades(p_hoy => '2026-12-01')),
  5,
  'por defecto el límite es 5'
);

select results_eq(
  $$ select titulo from public.proximas_actividades(2, '2026-12-01') $$,
  $$ values ('Temprano'), ('Caminar al parque') $$,
  'respeta el límite'
);

select lives_ok(
  $$ select * from public.proximas_actividades() $$,
  'sin p_hoy usa el día de Colombia'
);

select throws_ok(
  $$ select * from public.proximas_actividades(0) $$,
  'P0001', 'limite_invalido',
  'el límite debe ser al menos 1'
);

-- ---------------------------------------------------------------------
-- RLS entre dos usuarios
-- ---------------------------------------------------------------------
set local request.jwt.claims to '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select is(
  (select count(*)::int from public.actividades),
  0,
  'Beto no ve las actividades de Ana'
);

select is(
  (select count(*)::int from public.proximas_actividades(10, '2026-01-01')),
  0,
  'proximas_actividades de Beto no trae las de Ana'
);

update public.actividades set titulo = 'Hackeado'
 where id = 'a1000000-0000-4000-8000-000000000001';

reset role;
select is(
  (select titulo from public.actividades where id = 'a1000000-0000-4000-8000-000000000001'),
  'Caminar al parque',
  'Beto no puede editar las actividades de Ana'
);

set local role authenticated;
set local request.jwt.claims to '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select throws_ok(
  $$ insert into public.actividades (id, usuario_id, titulo, categoria, fecha)
     values ('b2000000-0000-4000-8000-000000000001',
             '11111111-1111-1111-1111-111111111111', 'Intruso', 'otro', '2026-12-01') $$,
  '42501', null,
  'Beto no puede crear actividades a nombre de Ana'
);

set local role anon;
set local request.jwt.claims to '{"role":"anon"}';

select throws_ok(
  $$ select * from public.proximas_actividades() $$,
  '42501', null,
  'sin sesión no se puede llamar proximas_actividades'
);

reset role;

select * from finish();
rollback;
