-- ---------------------------------------------------------------------
-- 1. Intentos fallidos de inicio de sesión (RF-04 CA-7)
-- ---------------------------------------------------------------------
create table public.intentos_login (
  correo             text primary key check (correo = lower(correo)),
  intentos_fallidos  int not null default 0 check (intentos_fallidos >= 0),
  ultimo_fallo       timestamptz,
  bloqueado_hasta    timestamptz
);

comment on table public.intentos_login is
  'RF-04 CA-7: 5 intentos fallidos seguidos bloquean el correo 15 minutos.';

-- RLS activo y SIN políticas: ni anon ni authenticated pueden leer ni
-- escribir. Solo el servidor (service_role) desde la Edge Function.
alter table public.intentos_login enable row level security;


-- ¿Está bloqueado este correo? Devuelve hasta cuándo, o null si no.
create function public.estado_bloqueo(p_correo text)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select bloqueado_hasta
  from public.intentos_login
  where correo = lower(trim(p_correo))
    and bloqueado_hasta > now();
$$;


-- Suma un intento fallido. Al llegar a 5, bloquea 15 minutos.
-- Devuelve: { "intentos_restantes": n, "bloqueado_hasta": fecha | null }
create function public.registrar_intento_fallido(p_correo text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_max_intentos constant int      := 5;
  c_bloqueo      constant interval := interval '15 minutes';
  v_correo  text := lower(trim(p_correo));
  v_intentos int;
  v_hasta    timestamptz;
begin
  insert into public.intentos_login as il (correo, intentos_fallidos, ultimo_fallo)
  values (v_correo, 1, now())
  on conflict (correo) do update
    set intentos_fallidos = il.intentos_fallidos + 1,
        ultimo_fallo      = now(),
        -- si había un bloqueo ya vencido, se limpia
        bloqueado_hasta   = case when il.bloqueado_hasta > now()
                                 then il.bloqueado_hasta end
  returning intentos_fallidos into v_intentos;

  if v_intentos >= c_max_intentos then
    update public.intentos_login
       set intentos_fallidos = 0,                -- al vencer, empieza de cero
           bloqueado_hasta   = now() + c_bloqueo
     where correo = v_correo
    returning bloqueado_hasta into v_hasta;
  end if;

  return jsonb_build_object(
    'intentos_restantes', case when v_hasta is null then c_max_intentos - v_intentos else 0 end,
    'bloqueado_hasta',    v_hasta
  );
end;
$$;


-- Inicio de sesión correcto: se olvidan los fallos ("seguidos").
create function public.limpiar_intentos(p_correo text)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.intentos_login where correo = lower(trim(p_correo));
$$;


-- ---------------------------------------------------------------------
-- 2. Dispositivos confiables (RF-04 CA-4 / CA-5)
--
-- La app genera UNA vez un identificador aleatorio (UUID) y lo guarda en
-- almacenamiento seguro. Ese es el `dispositivo_id`.
-- ---------------------------------------------------------------------
create table public.dispositivos_confiables (
  usuario_id      uuid not null references auth.users (id) on delete cascade,
  dispositivo_id  text not null check (char_length(dispositivo_id) between 8 and 100),
  registrado_en   timestamptz not null default now(),
  ultimo_uso      timestamptz not null default now(),
  primary key (usuario_id, dispositivo_id)
);

comment on table public.dispositivos_confiables is
  'RF-04/RF-05: celulares donde el usuario ya verificó el código de 6 dígitos.';

alter table public.dispositivos_confiables enable row level security;

-- Cada usuario ve y puede borrar SUS dispositivos (útil para RF-06 y RF-24,
-- que cierran sesiones en otros dispositivos). Insertar: solo por la RPC.
create policy "cada usuario ve sus dispositivos"
  on public.dispositivos_confiables
  for select to authenticated
  using ((select auth.uid()) = usuario_id);

create policy "cada usuario borra sus dispositivos"
  on public.dispositivos_confiables
  for delete to authenticated
  using ((select auth.uid()) = usuario_id);


-- Uso interno (Edge Function): ¿este celular ya es conocido para el usuario?
-- Si lo es, actualiza ultimo_uso.
create function public.dispositivo_es_confiable(p_usuario_id uuid, p_dispositivo_id text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.dispositivos_confiables
     set ultimo_uso = now()
   where usuario_id = p_usuario_id
     and dispositivo_id = p_dispositivo_id;
  return found;
end;
$$;


-- Uso desde la app, DESPUÉS de verificar el código de RF-05:
--   await supabase.rpc('registrar_dispositivo',
--                      params: {'p_dispositivo_id': dispositivoId});
create function public.registrar_dispositivo(p_dispositivo_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'sesion_requerida';
  end if;

  insert into public.dispositivos_confiables (usuario_id, dispositivo_id)
  values (auth.uid(), p_dispositivo_id)
  on conflict (usuario_id, dispositivo_id) do update set ultimo_uso = now();
end;
$$;


-- ---------------------------------------------------------------------
-- 3. Permisos de las funciones
-- Supabase da permiso de ejecutar a anon y authenticated por defecto.
-- Las funciones del servidor se lo quitamos: si la app pudiera llamar
-- limpiar_intentos, cualquiera se quitaría el bloqueo.
-- ---------------------------------------------------------------------
revoke execute on function public.estado_bloqueo(text)                   from public, anon, authenticated;
revoke execute on function public.registrar_intento_fallido(text)        from public, anon, authenticated;
revoke execute on function public.limpiar_intentos(text)                 from public, anon, authenticated;
revoke execute on function public.dispositivo_es_confiable(uuid, text)   from public, anon, authenticated;

grant execute on function public.estado_bloqueo(text)                    to service_role;
grant execute on function public.registrar_intento_fallido(text)         to service_role;
grant execute on function public.limpiar_intentos(text)                  to service_role;
grant execute on function public.dispositivo_es_confiable(uuid, text)    to service_role;

revoke execute on function public.registrar_dispositivo(text) from public, anon;
grant  execute on function public.registrar_dispositivo(text) to authenticated;
