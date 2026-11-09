-- =====================================================================
-- Pruebas del contrato con el motor (pgTAP). Se corren con: supabase test db
-- Todo ocurre dentro de una transacción que se deshace al final.
-- =====================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(46);

-- Usuarios de prueba (con los datos que exigen los triggers de RF-02 y RF-03)
--   Ana  = 11111111-…  nació el 1995-05-05
--   Beto = 22222222-…
insert into auth.users (id, email, raw_app_meta_data, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'ana@prueba.co',
   '{"provider":"email","providers":["email"]}',
   '{"nombre_completo":"Ana Prueba","nickname":"ana","fecha_nacimiento":"1995-05-05",
     "acepta_datos_sensibles":true,"version_politica":"1.0"}'),
  ('22222222-2222-2222-2222-222222222222', 'beto@prueba.co',
   '{"provider":"email","providers":["email"]}',
   '{"nombre_completo":"Beto Prueba","nickname":"beto","fecha_nacimiento":"2000-01-01",
     "acepta_datos_sensibles":true,"version_politica":"1.0"}');

-- Respuestas válidas de la encuesta inicial (se reutilizan abajo)
create temporary table respuesta_base as
select 'femenino'::text as genero, 'soltero'::text as estado_relacion,
       'estudiante'::text as situacion_trabajo,
       7.5::numeric as hr_sueno, 30::numeric as hr_trabajo, 5::numeric as hr_pantalla,
       3::numeric as hr_act_fis,
       6::smallint as estres_laboral, 8::smallint as estres_academico,
       5::smallint as estres_financ, 6::smallint as satisfaccion_laboral,
       4::smallint as cambio_emocional,
       false as uso_sustancias, false as diagnostico_previo,
       false as historial_panico, true as historial_familiar,
       'ocasional'::text as dificultad_concentra, 'ninguno'::text as tratamiento_previo,
       'moderado'::text as apoyo_percibido;
grant select on respuesta_base to authenticated;


-- ---------------------------------------------------------------------
-- Estructura
-- ---------------------------------------------------------------------
select has_table('public', 'evaluaciones_iniciales', 'existe evaluaciones_iniciales');
select has_table('public', 'encuestas_diarias', 'existe encuestas_diarias');
select has_table('public', 'niveles_riesgo', 'existe niveles_riesgo');
select ok(
  (select bool_and(relrowsecurity) from pg_class
   where oid in ('public.evaluaciones_iniciales'::regclass, 'public.encuestas_diarias'::regclass,
                 'public.niveles_riesgo'::regclass)),
  'las tres tablas tienen RLS activa');
select policies_are('public', 'niveles_riesgo',
  array['cada usuario ve sus niveles de riesgo'],
  'niveles_riesgo solo tiene política de lectura');
select ok(not has_schema_privilege('authenticated', 'motor', 'usage'),
  'authenticated no puede usar el esquema motor');
select ok(not has_function_privilege('authenticated',
  'motor.registrar_resultado(text, uuid, int, numeric, jsonb, text, jsonb)', 'execute'),
  'authenticated no puede registrar resultados');
select ok(has_function_privilege('motor_mindmetrics', 'motor.estado_consolidado(uuid, date)', 'execute'),
  'el rol del motor puede leer el estado consolidado');


-- ---------------------------------------------------------------------
-- Evaluación inicial (como Ana)
-- ---------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok($$
  insert into evaluaciones_iniciales
    (genero, estado_relacion, situacion_trabajo, hr_sueno, hr_trabajo, hr_pantalla, hr_act_fis,
     estres_laboral, estres_academico, estres_financ, satisfaccion_laboral, cambio_emocional,
     uso_sustancias, diagnostico_previo, historial_panico, historial_familiar,
     dificultad_concentra, tratamiento_previo, apoyo_percibido)
  select * from respuesta_base
$$, 'Ana guarda su evaluación inicial');

select is(
  (select edad from evaluaciones_iniciales),
  extract(year from age(current_date, date '1995-05-05'))::smallint,
  'la edad se calcula con la fecha de nacimiento del perfil');
select is((select usuario_id from evaluaciones_iniciales),
  '11111111-1111-1111-1111-111111111111'::uuid, 'usuario_id se toma de la sesión');
select is((select canal from evaluaciones_iniciales), 'formulario', 'canal por defecto: formulario');

select throws_ok($$
  insert into evaluaciones_iniciales
    (genero, estado_relacion, situacion_trabajo, hr_sueno, hr_trabajo, hr_pantalla, hr_act_fis,
     estres_laboral, estres_academico, estres_financ, satisfaccion_laboral, cambio_emocional,
     uso_sustancias, diagnostico_previo, historial_panico, historial_familiar,
     dificultad_concentra, tratamiento_previo, apoyo_percibido)
  select * from respuesta_base
$$, '23505', null, 'no se puede crear una segunda evaluación inicial');

select throws_ok($$
  insert into evaluaciones_iniciales (edad, genero) values (20, 'femenino')
$$, '42501', null, 'el cliente no puede enviar la edad');

select throws_ok($$
  update evaluaciones_iniciales set estres_laboral = 1
$$, '42501', null, 'la evaluación inicial no se edita');

select throws_ok($$
  insert into niveles_riesgo (usuario_id, origen, nivel, score_final, estado_entrada, version_motor)
  values ('11111111-1111-1111-1111-111111111111', 'evaluacion_inicial', 1, 0.1, '{}', 'x')
$$, '42501', null, 'la app no puede escribir niveles de riesgo');

-- Beto intenta valores fuera del vocabulario del mapper
set local request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select throws_ok($$
  insert into evaluaciones_iniciales
    (genero, estado_relacion, situacion_trabajo, hr_sueno, hr_trabajo, hr_pantalla, hr_act_fis,
     estres_laboral, estres_academico, estres_financ, satisfaccion_laboral, cambio_emocional,
     uso_sustancias, diagnostico_previo, historial_panico, historial_familiar,
     dificultad_concentra, tratamiento_previo, apoyo_percibido)
  select 'mujer', estado_relacion, situacion_trabajo, hr_sueno, hr_trabajo, hr_pantalla, hr_act_fis,
     estres_laboral, estres_academico, estres_financ, satisfaccion_laboral, cambio_emocional,
     uso_sustancias, diagnostico_previo, historial_panico, historial_familiar,
     dificultad_concentra, tratamiento_previo, apoyo_percibido from respuesta_base
$$, '23514', null, 'género fuera del vocabulario del motor');

select throws_ok($$
  insert into evaluaciones_iniciales
    (genero, estado_relacion, situacion_trabajo, hr_sueno, hr_trabajo, hr_pantalla, hr_act_fis,
     estres_laboral, estres_academico, estres_financ, satisfaccion_laboral, cambio_emocional,
     uso_sustancias, diagnostico_previo, historial_panico, historial_familiar,
     dificultad_concentra, tratamiento_previo, apoyo_percibido)
  select genero, estado_relacion, situacion_trabajo, hr_sueno, hr_trabajo, hr_pantalla, hr_act_fis,
     11, estres_academico, estres_financ, satisfaccion_laboral, cambio_emocional,
     uso_sustancias, diagnostico_previo, historial_panico, historial_familiar,
     dificultad_concentra, tratamiento_previo, apoyo_percibido from respuesta_base
$$, '23514', null, 'estrés fuera de la escala 1–10');

select is((select count(*)::int from evaluaciones_iniciales), 0,
  'Beto no ve la evaluación de Ana');

select throws_ok($$
  insert into evaluaciones_iniciales (usuario_id) values ('11111111-1111-1111-1111-111111111111')
$$, '42501', null, 'Beto no puede escribir a nombre de Ana');


-- ---------------------------------------------------------------------
-- Encuesta diaria (como Ana)
-- ---------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok($$
  select guardar_encuesta_diaria('aaaaaaaa-0000-0000-0000-000000000001', current_date - 1,
    6, 8, 6, 1, 7, 6, 5, true, false)
$$, 'Ana guarda la encuesta de ayer');

select lives_ok($$
  select guardar_encuesta_diaria('aaaaaaaa-0000-0000-0000-000000000002', current_date,
    8, 6, 4, 0.5, 8, 6, 5, true, true, 'voz')
$$, 'Ana guarda la de hoy por voz');

select is(
  (guardar_encuesta_diaria('aaaaaaaa-0000-0000-0000-000000000099', current_date,
    7, 6, 4, 0.5, 8, 6, 5, true, true) ->> 'id')::uuid,
  'aaaaaaaa-0000-0000-0000-000000000002'::uuid,
  'corregir el mismo día conserva el id del servidor');

select is((select count(*)::int from encuestas_diarias), 2, 'sigue habiendo una encuesta por día');

select throws_ok($$
  select guardar_encuesta_diaria(gen_random_uuid(), current_date - 2, 10, 12, 4, 3, 5, 5, 5, true, true)
$$, '23514', null, 'sueño + trabajo + ejercicio no pasan de 24 h');

select throws_ok($$
  select guardar_encuesta_diaria(gen_random_uuid(), current_date + 5, 8, 6, 4, 1, 5, 5, 5, true, true)
$$, '23514', null, 'no se aceptan fechas futuras');

select throws_ok($$
  insert into encuestas_diarias (id, fecha, hr_sueno, hr_trabajo, hr_pantalla, hr_act_fis,
    estres_laboral, estres_academico, estres_financ, interaccion_social, autocuidado)
  values (gen_random_uuid(), current_date - 3, 8, 6, 4, 1, 5, 5, 5, true, true)
$$, '42501', null, 'la encuesta solo se escribe con la RPC');

reset role;
select throws_ok($$
  set local role anon;
  select guardar_encuesta_diaria(gen_random_uuid(), current_date, 8, 6, 4, 1, 5, 5, 5, true, true)
$$, '42501', null, 'sin sesión no se guarda la encuesta');
reset role;


-- ---------------------------------------------------------------------
-- Estado consolidado (como el motor)
-- ---------------------------------------------------------------------
-- Ánimo de RF-08 de Ana: 2, 4 → en escala web 4, 8 → varianza 4 → cambio = 6
insert into registros_animo (id, usuario_id, fecha, nivel, actualizado_en_cliente) values
  (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', current_date - 1, 2, now()),
  (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', current_date,     4, now());

-- Las llamadas se hacen con el rol del motor y se guardan en tablas
-- temporales; las aserciones se evalúan después con el rol de pruebas
-- (el rol del motor no tiene acceso a las funciones de pgTAP).
create temporary table r (clave text primary key, valor jsonb);
grant all on r to motor_mindmetrics;

set local role motor_mindmetrics;
insert into r values
  ('hoy',     motor.estado_consolidado('11111111-1111-1111-1111-111111111111')),
  ('antes',   motor.estado_consolidado('11111111-1111-1111-1111-111111111111', current_date - 2)),
  ('pend_1',  to_jsonb((select count(*) from motor.pendientes())));
reset role;

select is((select (valor ->> 'hr_sueno')::numeric from r where clave = 'hoy'), 6.50::numeric,
  'sueño: promedio de las encuestas diarias (6 y 7)');
select is((select (valor ->> 'hr_trabajo')::numeric from r where clave = 'hoy'), 49.00::numeric,
  'trabajo: promedio diario × 7 = horas por semana');
select is((select (valor ->> 'hr_act_fis')::numeric from r where clave = 'hoy'), 5.25::numeric,
  'actividad física: promedio diario × 7');
select is((select (valor ->> 'estres_laboral')::int from r where clave = 'hoy'), 8,
  'estrés laboral: promedio 7.5 redondeado al par (como Python)');
select is((select (valor ->> 'cambio_emocional')::int from r where clave = 'hoy'), 6,
  'cambio emocional: varianza del ánimo de RF-08 en escala 1–10');
select is((select valor ->> 'genero' from r where clave = 'hoy'), 'femenino',
  'los datos fijos salen de la evaluación inicial');
select is((select (valor ->> 'hr_trabajo')::numeric from r where clave = 'antes'), 30.00::numeric,
  'sin encuestas en la ventana usa la evaluación inicial (ya semanal)');
select is((select (valor ->> 'cambio_emocional')::int from r where clave = 'antes'), 4,
  'con menos de 2 registros de ánimo usa el cambio emocional inicial');

select throws_ok($$
  set local role motor_mindmetrics;
  select motor.estado_consolidado('22222222-2222-2222-2222-222222222222')
$$, 'P0001', 'evaluacion_inicial_faltante', 'sin evaluación inicial no hay estado');
reset role;


-- ---------------------------------------------------------------------
-- Pendientes y resultados
-- ---------------------------------------------------------------------
select is((select valor::int from r where clave = 'pend_1'), 3,
  'pendientes: la evaluación y las dos encuestas');

set local role motor_mindmetrics;
insert into r values
  ('reg_eval', to_jsonb(motor.registrar_resultado('evaluacion_inicial',
      -- el motor no lee las tablas: obtiene los ids con motor.pendientes()
      (select id from motor.pendientes() where origen = 'evaluacion_inicial'), 3, 0.512,
      (select valor from r where clave = 'hoy'), 'agente-2026.11'))),
  ('reg_hoy',  to_jsonb(motor.registrar_resultado('encuesta_diaria',
      'aaaaaaaa-0000-0000-0000-000000000002', 4, 0.71,
      (select valor from r where clave = 'hoy'), 'agente-2026.11')));
-- En otra sentencia: la anterior no ve sus propias inserciones
insert into r values ('pend_2', to_jsonb((select count(*) from motor.pendientes())));
reset role;

select ok((select valor::bigint from r where clave = 'reg_eval') > 0,
  'el motor registra el nivel de la evaluación inicial');
select ok((select valor::bigint from r where clave = 'reg_hoy') > 0,
  'el motor registra el nivel de la encuesta de hoy');
select is((select valor::int from r where clave = 'pend_2'), 1,
  'solo queda pendiente la encuesta de ayer');

select throws_ok($$
  set local role motor_mindmetrics;
  select motor.registrar_resultado('encuesta_diaria', 'aaaaaaaa-0000-0000-0000-000000000002',
    6, 0.9, '{}', 'x')
$$, 'P0001', 'nivel_invalido', 'nivel fuera de 1–5');
reset role;

-- Ana corrige la encuesta de hoy → vuelve a quedar pendiente.
-- now() no cambia dentro de la transacción: se fuerzan las horas.
update public.niveles_riesgo set calculado_en = now() - interval '1 minute';
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
select guardar_encuesta_diaria('aaaaaaaa-0000-0000-0000-000000000002', current_date,
  8, 6, 4, 0.5, 9, 6, 5, true, true);
reset role;

set local role motor_mindmetrics;
insert into r values ('pend_3', to_jsonb((select count(*) from motor.pendientes())));
reset role;
select is((select valor::int from r where clave = 'pend_3'), 2,
  'editar una encuesta ya calculada la vuelve pendiente');


-- ---------------------------------------------------------------------
-- Lo que ve cada usuario
-- ---------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select is((select count(*)::int from niveles_riesgo), 2, 'Ana ve sus dos niveles');
select is((select etiqueta from nivel_riesgo_actual), 'alto',
  'nivel actual: el último cálculo, con la etiqueta de la web');

set local request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';
select is((select count(*)::int from niveles_riesgo), 0, 'Beto no ve los niveles de Ana');

select * from finish();
rollback;
