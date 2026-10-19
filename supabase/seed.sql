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