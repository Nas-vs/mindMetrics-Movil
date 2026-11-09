-- =====================================================================
-- Pruebas de RF-08 CA-8 (regla de alerta). Se corren con: supabase test db
-- Todo ocurre dentro de una transacción que se deshace al final.
-- =====================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(15);

-- Usuarios de prueba (con los datos que piden los triggers de RF-02 y RF-03)
--   Ana   = 1111…  racha baja
--   Beto  = 2222…  muy bajo dos días seguidos
--   Carla = 3333…  nivel de riesgo del motor
--   Dani  = 4444…  días buenos
insert into auth.users (id, email, raw_user_meta_data)
select u.id, u.nombre || '@prueba.co',
       jsonb_build_object('nombre_completo', initcap(u.nombre) || ' Prueba', 'nickname', u.nombre,
                          'fecha_nacimiento', '1995-05-05',
                          'acepta_datos_sensibles', true, 'version_politica', '1.0')
from (values
  ('11111111-1111-1111-1111-111111111111'::uuid, 'ana'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'beto'),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'carla'),
  ('44444444-4444-4444-4444-444444444444'::uuid, 'dani')
) as u(id, nombre);

-- Guarda un registro de ánimo como lo haría la app (RPC de RF-08).
create function pg_temp.animo(p_usuario uuid, p_dias_atras int, p_nivel int)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', p_usuario, 'role', 'authenticated')::text, true);
  perform public.guardar_registro_animo(
    gen_random_uuid(), current_date - p_dias_atras, p_nivel,
    -- clock_timestamp avanza en cada llamada: la edición más nueva gana.
    p_actualizado_en => clock_timestamp());
end $$;

-- Id de la alerta de un usuario (security definer: la lee saltando la RLS,
-- para poder probar que otro usuario NO puede tocarla).
create function pg_temp.alerta_de(p_usuario uuid)
returns uuid language sql security definer as $$
  select id from public.alertas_bienestar where usuario_id = p_usuario limit 1
$$;

-- ---------------------------------------------------------------------
-- Sin alerta
-- ---------------------------------------------------------------------
set local role authenticated;

select pg_temp.animo('44444444-4444-4444-4444-444444444444', 2, 4);
select pg_temp.animo('44444444-4444-4444-4444-444444444444', 1, 5);
select pg_temp.animo('44444444-4444-4444-4444-444444444444', 0, 3);
select is(
  (select count(*)::int from public.alertas_bienestar
   where usuario_id = '44444444-4444-4444-4444-444444444444'),
  0,
  'días buenos no generan alerta'
);

select pg_temp.animo('33333333-3333-3333-3333-333333333333', 0, 2);
select is(
  (select count(*)::int from public.alertas_bienestar
   where usuario_id = '33333333-3333-3333-3333-333333333333'),
  0,
  'un solo día bajo, sin resultado del motor, no genera alerta'
);

-- ---------------------------------------------------------------------
-- racha_baja: 3 últimos registros en 1 o 2
-- ---------------------------------------------------------------------
select pg_temp.animo('11111111-1111-1111-1111-111111111111', 3, 2);
select pg_temp.animo('11111111-1111-1111-1111-111111111111', 1, 2);
select is(
  (select count(*)::int from public.alertas_bienestar
   where usuario_id = '11111111-1111-1111-1111-111111111111'),
  0,
  'dos días bajos todavía no generan alerta'
);

select pg_temp.animo('11111111-1111-1111-1111-111111111111', 0, 2);
select is(
  (select motivo from public.alertas_bienestar
   where usuario_id = '11111111-1111-1111-1111-111111111111' and fecha = current_date),
  'racha_baja',
  'tres registros bajos seguidos generan alerta racha_baja (aunque falte un día en medio)'
);

-- Editar el registro de hoy no crea otra alerta (máximo una cada 3 días)
select pg_temp.animo('11111111-1111-1111-1111-111111111111', 0, 1);
select is(
  (select count(*)::int from public.alertas_bienestar
   where usuario_id = '11111111-1111-1111-1111-111111111111'),
  1,
  'no se repite la alerta dentro de 3 días'
);

-- Editar un día viejo (RF-13) no evalúa la regla
select pg_temp.animo('44444444-4444-4444-4444-444444444444', 6, 1);
select pg_temp.animo('44444444-4444-4444-4444-444444444444', 5, 1);
select is(
  (select count(*)::int from public.alertas_bienestar
   where usuario_id = '44444444-4444-4444-4444-444444444444'),
  0,
  'registrar días viejos no genera alertas'
);

-- ---------------------------------------------------------------------
-- muy_bajo_seguido: 1 hoy y ayer
-- ---------------------------------------------------------------------
select pg_temp.animo('22222222-2222-2222-2222-222222222222', 1, 1);
select pg_temp.animo('22222222-2222-2222-2222-222222222222', 0, 1);
select is(
  (select motivo from public.alertas_bienestar
   where usuario_id = '22222222-2222-2222-2222-222222222222'),
  'muy_bajo_seguido',
  'ánimo 1 dos días seguidos genera alerta muy_bajo_seguido'
);

-- ---------------------------------------------------------------------
-- riesgo_alto: el motor dio 4 o 5 y hoy el ánimo es bajo
-- (el motor escribe con su propio rol; aquí se simula como postgres)
-- ---------------------------------------------------------------------
reset role;

insert into public.evaluaciones_iniciales (
  id, usuario_id, edad, genero, estado_relacion, situacion_trabajo,
  hr_sueno, hr_trabajo, hr_pantalla, hr_act_fis,
  estres_laboral, estres_academico, estres_financ, satisfaccion_laboral, cambio_emocional,
  uso_sustancias, diagnostico_previo, historial_panico, historial_familiar,
  dificultad_concentra, tratamiento_previo, apoyo_percibido)
values (
  'cccc0000-0000-4000-8000-000000000001', '33333333-3333-3333-3333-333333333333',
  31, 'femenino', 'soltero', 'estudiante',
  6, 40, 8, 1, 8, 8, 8, 3, 8,
  false, false, false, false, 'frecuente', 'ninguno', 'poco');

insert into public.niveles_riesgo
  (usuario_id, origen, evaluacion_id, nivel, score_final, estado_entrada, version_motor)
values
  ('33333333-3333-3333-3333-333333333333', 'evaluacion_inicial',
   'cccc0000-0000-4000-8000-000000000001', 4, 0.75, '{}', 'prueba');

set local role authenticated;

-- Carla ya tenía un 2 hoy (sin alerta); al guardarlo otra vez, el motor cuenta.
select pg_temp.animo('33333333-3333-3333-3333-333333333333', 0, 2);
select is(
  (select motivo from public.alertas_bienestar
   where usuario_id = '33333333-3333-3333-3333-333333333333'),
  'riesgo_alto',
  'con nivel de riesgo 4 del motor, un día bajo genera alerta riesgo_alto'
);

-- ---------------------------------------------------------------------
-- RPC alerta_pendiente / marcar_alerta_vista
-- ---------------------------------------------------------------------
set local request.jwt.claims to '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select is(
  public.alerta_pendiente() ->> 'motivo',
  'racha_baja',
  'alerta_pendiente devuelve la alerta sin mostrar'
);

select is(
  (select count(*)::int from public.alertas_bienestar),
  1,
  'Ana solo ve sus propias alertas (RLS)'
);

select throws_ok(
  $$ insert into public.alertas_bienestar (usuario_id, fecha, motivo)
     values ('11111111-1111-1111-1111-111111111111', current_date - 10, 'racha_baja') $$,
  '42501',
  null,
  'la app no puede crear alertas directamente'
);

-- Beto no puede marcar la alerta de Ana
set local request.jwt.claims to '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';
select is(
  public.marcar_alerta_vista(pg_temp.alerta_de('11111111-1111-1111-1111-111111111111')),
  false,
  'nadie puede marcar como vista la alerta de otro usuario'
);

select is(
  public.marcar_alerta_vista(null),
  false,
  'marcar una alerta inexistente devuelve false'
);

set local request.jwt.claims to '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
select ok(
  public.marcar_alerta_vista(pg_temp.alerta_de('11111111-1111-1111-1111-111111111111')),
  'Ana marca su alerta como vista'
);

select is(
  public.alerta_pendiente(),
  null,
  'una alerta vista ya no está pendiente'
);

reset role;

select * from finish();
rollback;
