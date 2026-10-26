do $$
declare
  v_id uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new,
    email_change_token_current, email_change
  ) values (
    '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
    'demo@mindmetrics.co', extensions.crypt('Prueba123', extensions.gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}',
    -- Datos de RF-03 y consentimiento de RF-02 (los piden los triggers)
    '{"nombre_completo":"Usuario Demo","nickname":"demo_app","fecha_nacimiento":"1995-05-05",
      "acepta_datos_sensibles":true,"version_politica":"1.0"}',
    now(), now(),
    '', '', '', '', ''   -- Supabase Auth necesita estos campos vacíos, no nulos
  );

  insert into auth.identities (
    id, user_id, provider_id, identity_data, provider,
    last_sign_in_at, created_at, updated_at
  ) values (
    gen_random_uuid(), v_id, v_id::text,
    jsonb_build_object('sub', v_id::text, 'email', 'demo@mindmetrics.co', 'email_verified', true),
    'email', now(), now(), now()
  );
end $$;

insert into public.registros_animo
  (id, usuario_id, fecha, nivel, nota, actualizado_en_cliente)
select
  gen_random_uuid(),
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  current_date - d,
  (array[3, 4, 2, 5, 4, 3, 1, 2, 3, 4, 5, 4, 3, 2])[d],   -- nivel fijo por día
  case when d in (2, 7) then 'Día difícil en la universidad' end,
  now() - make_interval(days => d)
from generate_series(1, 14) as d;

-- Algunas emociones y factores en esos registros
insert into public.registro_emociones (registro_id, emocion_id)
select r.id, case when r.nivel >= 4 then 1 when r.nivel = 3 then 2 else 7 end
from public.registros_animo r
where r.usuario_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

insert into public.registro_factores (registro_id, factor_id)
select r.id, case when r.nivel <= 2 then 2 else 1 end
from public.registros_animo r
where r.usuario_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
