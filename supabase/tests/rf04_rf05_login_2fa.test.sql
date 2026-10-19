-- =====================================================================
-- =====================================================================
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(17);

-- ---------------------------------------------------------------------
-- ---------------------------------------------------------------------
do $$ begin
  perform public.registrar_intento_fallido('ana@prueba.co');
  perform public.registrar_intento_fallido('ana@prueba.co');
  perform public.registrar_intento_fallido('ana@prueba.co');
end $$;

select is(
  (public.registrar_intento_fallido('ANA@prueba.co ') ->> 'intentos_restantes')::int,
  1,
  'el correo se normaliza: 4 fallos (con mayúsculas y espacios) dejan 1 intento'
);

select is(
  public.estado_bloqueo('ana@prueba.co'),
  null,
  'con 4 fallos todavía no está bloqueado'
);

select ok(
  (public.registrar_intento_fallido('ana@prueba.co') ->> 'bloqueado_hasta') is not null,
  'el 5.º fallo bloquea el correo'
);

select ok(
  public.estado_bloqueo('ana@prueba.co')
    between now() + interval '14 minutes' and now() + interval '15 minutes',
  'el bloqueo dura 15 minutos'
);

select is(
  public.estado_bloqueo('beto@prueba.co'),
  null,
  'el bloqueo de un correo no afecta a otro'
);

-- Simulamos que pasaron los 15 minutos
update public.intentos_login
   set bloqueado_hasta = now() - interval '1 second'
 where correo = 'ana@prueba.co';

select is(
  public.estado_bloqueo('ana@prueba.co'),
  null,
  'al vencer los 15 minutos se puede intentar de nuevo'
);

select is(
  (public.registrar_intento_fallido('ana@prueba.co') ->> 'intentos_restantes')::int,
  4,
  'después del bloqueo el conteo empieza de cero'
);

do $$ begin perform public.limpiar_intentos('ana@prueba.co'); end $$;
select is(
  (select count(*)::int from public.intentos_login where correo = 'ana@prueba.co'),
  0,
  'un inicio de sesión correcto borra los fallos'
);

-- ---------------------------------------------------------------------
-- La app NO puede tocar el bloqueo
-- ---------------------------------------------------------------------
set local role anon;

select throws_ok(
  $$ select public.limpiar_intentos('ana@prueba.co') $$,
  '42501', null,
  'anon no puede quitarse el bloqueo'
);

select throws_ok(
  $$ select public.registrar_intento_fallido('ana@prueba.co') $$,
  '42501', null,
  'anon no puede registrar intentos'
);

select is(
  (select count(*)::int from public.intentos_login),
  0,
  'anon no puede leer la tabla de intentos'
);

reset role;

-- ---------------------------------------------------------------------
-- RF-04 CA-4 / RF-05: dispositivos confiables
-- Usuarios con los datos de RF-02 y RF-03 para que pasen sus triggers.
-- ---------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'ana@prueba.co',
   '{"nombre_completo":"Ana Prueba","nickname":"ana","fecha_nacimiento":"1995-05-05",
     "acepta_datos_sensibles":true,"version_politica":"1.0"}'),
  ('22222222-2222-2222-2222-222222222222', 'beto@prueba.co',
   '{"nombre_completo":"Beto Prueba","nickname":"beto","fecha_nacimiento":"1995-05-05",
     "acepta_datos_sensibles":true,"version_politica":"1.0"}');

select is(
  public.dispositivo_es_confiable('11111111-1111-1111-1111-111111111111', 'celular-de-ana-01'),
  false,
  'un celular nuevo no es confiable (se pide código)'
);

-- Ana verificó el código y la app registra su celular
set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok(
  $$ select public.registrar_dispositivo('celular-de-ana-01') $$,
  'tras verificar el código, la app registra el celular'
);

select throws_ok(
  $$ select public.dispositivo_es_confiable('11111111-1111-1111-1111-111111111111', 'celular-de-ana-01') $$,
  '42501', null,
  'la app no puede preguntar directamente si un celular es confiable'
);

reset role;

select is(
  public.dispositivo_es_confiable('11111111-1111-1111-1111-111111111111', 'celular-de-ana-01'),
  true,
  'la próxima vez ese celular es conocido (no se pide código)'
);

select is(
  public.dispositivo_es_confiable('22222222-2222-2222-2222-222222222222', 'celular-de-ana-01'),
  false,
  'el celular de Ana no es confiable para la cuenta de Beto'
);

-- Beto no ve los dispositivos de Ana
set local role authenticated;
set local request.jwt.claims to '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select is(
  (select count(*)::int from public.dispositivos_confiables),
  0,
  'cada usuario solo ve sus propios dispositivos'
);

reset role;

select * from finish();
rollback;
