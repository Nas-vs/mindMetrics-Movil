-- =====================================================================
-- RF-03 · Registro de cuenta
-- Back: Juliana Perez
--
-- Qué crea esta migración:
--   1. perfiles              → datos del usuario que no guarda Auth
--                              (correo y contraseña viven en auth.users).
--   2. RLS                   → cada usuario solo lee su propio perfil.
--   3. Trigger en auth.users → crea el perfil EN EL MISMO MOMENTO del
--                              registro y lo rechaza si los datos no
--                              cumplen RF-03.
--   4. RPC nickname_disponible → para avisar "nickname no disponible"
--                              antes de llamar a signUp.
--
-- El consentimiento (acepta_datos_sensibles, version_politica) es de RF-02
-- y lo guarda su propio trigger en public.consentimientos.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Perfiles (una fila por usuario)
-- ---------------------------------------------------------------------
create table public.perfiles (
    id                uuid primary key references auth.users (id) on delete cascade,

  -- máx. 60 caracteres; solo letras, espacios y tildes
  nombre_completo   text not null
    constraint perfiles_nombre_completo_formato check (
      char_length(nombre_completo) between 1 and 60
      and nombre_completo ~ '^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ ]+$'
    ),

  -- 3 a 20 caracteres, sin espacios (único: ver índice abajo)
  nickname          text not null
    constraint perfiles_nickname_formato check (
      char_length(nickname) between 3 and 20
      and nickname !~ '\s'
    ),

  -- mayor de 18 años: se valida en el trigger (sección 3)
  fecha_nacimiento  date not null,

  activo            boolean not null default true,
  creado_en         timestamptz not null default now(),
  actualizado_en    timestamptz not null default now()
);

comment on table public.perfiles is
  'RF-03: datos de la cuenta que no maneja Auth. El id es el mismo de auth.users.';

-- Nickname único sin distinguir mayúsculas: "Ana" y "ana" cuentan igual
create unique index perfiles_nickname_unico
  on public.perfiles (lower(nickname));


-- ---------------------------------------------------------------------
-- 2. RLS: cada usuario solo ve SU perfil
-- No hay política de insert/update/delete:
--   insert → solo el trigger (security definer)
--   update → le corresponde al RF de perfil (RF-23)
--   delete → ocurre en cascada al borrar la cuenta (RF-25)
-- ---------------------------------------------------------------------
alter table public.perfiles enable row level security;

create policy "cada usuario ve su perfil"
  on public.perfiles
  for select
  to authenticated
  using ((select auth.uid()) = id);


-- ---------------------------------------------------------------------
-- 3. Trigger: crear el perfil al registrarse
--
-- La app envía en supabase.auth.signUp(data: {...}):
--   'nombre_completo':  'Ana Prueba'
--   'nickname':         'ana'
--   'fecha_nacimiento': '1995-05-05'   (AAAA-MM-DD)
--
-- Si un dato falta o no cumple las reglas, se lanza un error y Supabase
-- CANCELA el registro completo.
-- ---------------------------------------------------------------------
create function public.crear_perfil_inicial()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_fecha_nacimiento date;
begin
  v_fecha_nacimiento := (new.raw_user_meta_data ->> 'fecha_nacimiento')::date;

  if v_fecha_nacimiento > (current_date - interval '18 years') then
    raise exception 'menor_de_edad'
      using hint = 'El usuario debe tener 18 años o más.';
  end if;

  insert into public.perfiles (id, nombre_completo, nickname, fecha_nacimiento)
  values (
    new.id,
    trim(new.raw_user_meta_data ->> 'nombre_completo'),
    trim(new.raw_user_meta_data ->> 'nickname'),
    v_fecha_nacimiento
  );

  return new;
end;
$$;

create trigger al_crear_usuario_crear_perfil
  after insert on auth.users
  for each row
  execute function public.crear_perfil_inicial();

-- Las funciones del trigger no deben poder llamarse desde la API
revoke execute on function public.crear_perfil_inicial() from public, anon, authenticated;


-- ---------------------------------------------------------------------
-- 4. RPC: ¿el nickname está libre?
--
-- Uso desde la app (antes de signUp, sin sesión):
--   await supabase.rpc('nickname_disponible', params: {'p_nickname': 'ana'});
-- Devuelve true si está libre, false si ya existe (sin importar mayúsculas).
-- Es security definer porque un visitante no puede leer perfiles por RLS;
-- solo responde sí/no, no expone datos.
-- ---------------------------------------------------------------------
create function public.nickname_disponible(p_nickname text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1
    from public.perfiles
    where lower(nickname) = lower(trim(p_nickname))
  );
$$;

revoke execute on function public.nickname_disponible(text) from public;
grant  execute on function public.nickname_disponible(text) to anon, authenticated;