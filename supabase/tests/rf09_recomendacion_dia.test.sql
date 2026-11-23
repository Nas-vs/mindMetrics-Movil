-- =====================================================================
-- Pruebas de RF-09 (recomendación del día). Se corren con: supabase test db
-- Todo ocurre dentro de una transacción que se deshace al final.
-- =====================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(14);

-- Usuarios de prueba (con los datos que piden los triggers de RF-02 y RF-03)
insert into auth.users (id, email, raw_user_meta_data)
select u.id, u.nombre || '@prueba.co',
       jsonb_build_object('nombre_completo', initcap(u.nombre) || ' Prueba', 'nickname', u.nombre,
                          'fecha_nacimiento', '1995-05-05',
                          'acepta_datos_sensibles', true, 'version_politica', '1.0')
from (values
  ('11111111-1111-1111-1111-111111111111'::uuid, 'ana'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'beto'),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'carla')
) as u(id, nombre);

-- ---------------------------------------------------------------------
-- Catálogo (CA-2)
-- ---------------------------------------------------------------------
select ok(
  (select bool_and(
     (select count(*) from public.recomendaciones r
      where r.activo and not r.sin_registro
        and n between r.nivel_min and r.nivel_max) >= 2)
   from generate_series(1, 5) as n),
  'cada nivel de ánimo (1 a 5) tiene al menos 2 recomendaciones (CA-3 nunca deja la tarjeta vacía)'
);

select ok(
  (select count(*) from public.recomendaciones where activo and sin_registro) >= 2,
  'hay al menos 2 recomendaciones para cuando aún no se registra el ánimo'
);

set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select ok(
  (select count(*) from public.recomendaciones) >= 10,
  'la app puede leer el catálogo para guardar una copia local'
);

select throws_ok(
  $$ insert into public.recomendaciones (id, titulo, descripcion) values (99, 'x', 'y') $$,
  '42501',
  null,
  'la app no puede modificar el catálogo'
);

-- ---------------------------------------------------------------------
-- Sin registro de hoy
-- ---------------------------------------------------------------------
select ok(
  (select sin_registro from public.recomendaciones
   where id = (public.recomendacion_del_dia(current_date) ->> 'id')::int),
  'sin registro de hoy, se elige una recomendación general'
);

-- ---------------------------------------------------------------------
-- Con registro: se elige por nivel, emociones y factores (CA-2)
-- Ana: nivel 1 con Ansiedad (7) → "Calma la mente" (id 7)
-- ---------------------------------------------------------------------
select public.guardar_registro_animo(
  'aaaa0000-0000-4000-8000-000000000001', current_date, 1,
  p_emociones => array[7], p_actualizado_en => now());

select is(
  (public.recomendacion_del_dia(current_date) ->> 'id')::int,
  7,
  'la emoción del día da prioridad a su recomendación'
);

select is(
  public.recomendacion_del_dia(current_date) ->> 'accion',
  'respiracion',
  'la recomendación trae la acción del botón (CA-1)'
);

select is(
  (select count(*)::int from public.recomendaciones_mostradas),
  1,
  'llamarla varias veces el mismo día deja un solo registro en el historial'
);

-- CA-4: si cambia el ánimo de hoy, al refrescar cambia la recomendación
select public.guardar_registro_animo(
  'aaaa0000-0000-4000-8000-000000000001', current_date, 5,
  p_emociones => array[1], p_actualizado_en => now() + interval '1 minute');

select ok(
  (select 5 between nivel_min and nivel_max and not sin_registro
   from public.recomendaciones
   where id = (public.recomendacion_del_dia(current_date) ->> 'id')::int),
  'al editar el ánimo, la recomendación se recalcula con el nuevo nivel'
);

-- ---------------------------------------------------------------------
-- CA-3: no se repite la de ayer
-- Beto: ayer vio la 7; hoy tiene el mismo ánimo que la haría ganar.
-- ---------------------------------------------------------------------
reset role;
insert into public.recomendaciones_mostradas (usuario_id, fecha, recomendacion_id)
values ('22222222-2222-2222-2222-222222222222', current_date - 1, 7);

set local role authenticated;
set local request.jwt.claims to '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select public.guardar_registro_animo(
  'bbbb0000-0000-4000-8000-000000000001', current_date, 1,
  p_emociones => array[7], p_actualizado_en => now());

select isnt(
  (public.recomendacion_del_dia(current_date) ->> 'id')::int,
  7,
  'no se repite la recomendación de ayer'
);

select is(
  (select count(*)::int from public.recomendaciones_mostradas),
  2,
  'Beto solo ve su propio historial (RLS)'
);

-- ---------------------------------------------------------------------
-- Validaciones
-- ---------------------------------------------------------------------
select throws_ok(
  $$ select public.recomendacion_del_dia(current_date + 5) $$,
  'P0001',
  'fecha_invalida',
  'no acepta fechas fuera de hoy (± 1 día por zona horaria)'
);

reset role;
set local role anon;
select throws_ok(
  $$ select public.recomendacion_del_dia(current_date) $$,
  '42501',
  null,
  'sin sesión no se puede pedir la recomendación'
);

reset role;

-- Las recomendaciones con botón tienen texto y acción juntos
select ok(
  not exists (
    select 1 from public.recomendaciones
    where (accion is null) <> (texto_accion is null)),
  'toda recomendación con acción tiene texto de botón, y al revés'
);

select * from finish();
rollback;
