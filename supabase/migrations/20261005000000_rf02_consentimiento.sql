-- =====================================================================
-- RF-02 · Aceptación de términos y tratamiento de datos sensibles
-- Back: Nasly Valencia
--
-- Qué crea esta migración:
--   1. politicas_privacidad  → el texto del consentimiento y su versión.
--                              La app lo LEE para mostrarlo (CA-1, CA-2).
--   2. consentimientos       → prueba de que cada usuario aceptó, con qué
--                              versión y cuándo (Ley 1581 de 2012).
--   3. Trigger en auth.users → guarda el consentimiento EN EL MISMO MOMENTO
--                              del registro (CA-3) y rechaza el registro si
--                              no aceptó ("no puede crear cuenta sin aceptar").
--   4. RPC aceptar_politica  → para que un usuario ya registrado acepte una
--                              versión nueva cuando la política cambie.
--   5. Versión 1.0 del texto.
--
-- RF-01 no tiene parte de backend: la bandera onboarding_completado vive
-- en el celular (shared_preferences), según su CA-4.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Políticas de privacidad (una fila por versión)
-- ---------------------------------------------------------------------
create table public.politicas_privacidad (
  version       text primary key check (version ~ '^\d+\.\d+$'),   -- ej. '1.0'
  titulo        text not null,
  contenido     text not null,                                   -- Markdown
  vigente       boolean not null default false,
  publicada_en  timestamptz not null default now()
);

comment on table public.politicas_privacidad is
  'RF-02: versiones del consentimiento informado. Solo una puede estar vigente.';

-- Solo puede haber UNA versión vigente a la vez
create unique index politicas_privacidad_una_vigente
  on public.politicas_privacidad (vigente)
  where vigente;

-- RLS: cualquiera (incluso sin sesión) puede LEER las políticas, porque la
-- pantalla de RF-02 se muestra ANTES de crear la cuenta.
-- Nadie puede escribir desde la app: se cambian solo con migraciones.
alter table public.politicas_privacidad enable row level security;

create policy "cualquiera puede leer las politicas"
  on public.politicas_privacidad
  for select
  to anon, authenticated
  using (true);


-- ---------------------------------------------------------------------
-- 2. Consentimientos (una fila por aceptación)
-- ---------------------------------------------------------------------
create table public.consentimientos (
  id                      bigint generated always as identity primary key,
  usuario_id              uuid not null references auth.users (id) on delete cascade,
  version_politica        text not null references public.politicas_privacidad (version),
  acepta_datos_sensibles  boolean not null check (acepta_datos_sensibles),  -- solo se guarda un "sí"
  fecha_aceptacion        timestamptz not null default now(),               -- la pone el backend (UTC)
  unique (usuario_id, version_politica)
);

comment on table public.consentimientos is
  'RF-02: prueba de la autorización explícita de cada usuario (Ley 1581 de 2012).';

create index consentimientos_usuario_idx on public.consentimientos (usuario_id);

-- RLS: cada usuario solo ve SUS consentimientos.
-- No hay política de insert/update/delete: la app no puede escribir aquí
-- directamente. Solo el trigger y la RPC (security definer) insertan, y
-- así nadie puede inventar una fecha_aceptacion.
alter table public.consentimientos enable row level security;

create policy "cada usuario ve sus consentimientos"
  on public.consentimientos
  for select
  to authenticated
  using ((select auth.uid()) = usuario_id);


-- ---------------------------------------------------------------------
-- 3. Trigger: guardar el consentimiento al registrarse (CA-3)
--
-- La app envía en supabase.auth.signUp(data: {...}):
--   'acepta_datos_sensibles': true
--   'version_politica': '1.0'      (la versión que le mostró al usuario)
--
-- Si falta la aceptación o la versión no es la vigente, se lanza un error
-- y Supabase CANCELA el registro completo (no queda usuario a medias).
-- ---------------------------------------------------------------------
create function public.registrar_consentimiento_inicial()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_acepta  boolean;
  v_version text;
begin
  v_acepta  := coalesce((new.raw_user_meta_data ->> 'acepta_datos_sensibles')::boolean, false);
  v_version := new.raw_user_meta_data ->> 'version_politica';

  if not v_acepta then
    raise exception 'consentimiento_requerido'
      using hint = 'El usuario debe aceptar el tratamiento de datos sensibles (RF-02).';
  end if;

  if not exists (
    select 1 from public.politicas_privacidad
    where version = v_version and vigente
  ) then
    raise exception 'version_politica_invalida'
      using hint = 'La version_politica enviada no es la vigente. La app debe recargar el texto.';
  end if;

  insert into public.consentimientos (usuario_id, version_politica, acepta_datos_sensibles)
  values (new.id, v_version, true);

  return new;
end;
$$;

create trigger al_crear_usuario_registrar_consentimiento
  after insert on auth.users
  for each row
  execute function public.registrar_consentimiento_inicial();


-- ---------------------------------------------------------------------
-- 4. RPC: aceptar una versión nueva (usuario ya registrado)
--
-- Uso desde la app:
--   await supabase.rpc('aceptar_politica', params: {'p_version': '1.1'});
-- Si ya la había aceptado, no hace nada (no falla).
-- ---------------------------------------------------------------------
create function public.aceptar_politica(p_version text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'sesion_requerida';
  end if;

  if not exists (
    select 1 from public.politicas_privacidad
    where version = p_version and vigente
  ) then
    raise exception 'version_politica_invalida';
  end if;

  insert into public.consentimientos (usuario_id, version_politica, acepta_datos_sensibles)
  values (auth.uid(), p_version, true)
  on conflict (usuario_id, version_politica) do nothing;
end;
$$;

revoke execute on function public.aceptar_politica(text) from public, anon;
grant  execute on function public.aceptar_politica(text) to authenticated;

-- Las funciones del trigger no deben poder llamarse desde la API
revoke execute on function public.registrar_consentimiento_inicial() from public, anon, authenticated;


-- ---------------------------------------------------------------------
-- 5. Texto de la versión 1.0 (CA-2)
-- Va en la migración (no en seed.sql) para que también exista en la nube
-- cuando hagan `supabase db push`.
-- ⚠ Revisar el texto con el equipo y el profesor antes de la entrega.
-- ---------------------------------------------------------------------
insert into public.politicas_privacidad (version, titulo, contenido, vigente)
values (
  '1.0',
  'Consentimiento informado y tratamiento de datos sensibles',
  $texto$
## Antes de empezar

MindMetrics te ayuda a registrar cómo te sientes y a descubrir patrones en tu bienestar. Para hacerlo necesitamos guardar información sobre tu salud mental, que la ley colombiana considera **dato sensible** (Ley 1581 de 2012). Por eso te pedimos tu autorización explícita.

## Qué datos recogemos

- **Datos de tu cuenta:** nombre, nickname, correo y fecha de nacimiento.
- **Datos de bienestar:** tus registros de ánimo, emociones, notas, hábitos, actividades, resultados de juegos y respuestas a cuestionarios.
- **Datos de citas:** las citas que agendes con un profesional.

## Para qué los usamos

- Mostrarte tu historial, tu calendario emocional y recomendaciones personalizadas.
- Recordarte registrar tu día, si lo autorizas.
- No vendemos tus datos ni los usamos para publicidad.

## Quién puede verlos

- **Solo tú.** Cada registro está protegido para que ninguna otra cuenta pueda leerlo.
- El profesional con quien agendes una cita solo verá los datos de esa cita.
- Este es un proyecto académico: el equipo de desarrollo no consulta registros individuales.

## Tus derechos

- **Conocer y exportar** tus datos cuando lo pidas.
- **Corregir** tu información desde tu perfil.
- **Eliminar** tu cuenta y todos tus datos desde Perfil → Eliminar cuenta.
- **Retirar** esta autorización en cualquier momento, eliminando tu cuenta.

## Importante

MindMetrics **no es un servicio de diagnóstico ni reemplaza la atención profesional.** Si estás en crisis o piensas en hacerte daño, usa el botón de ayuda o comunícate con la línea de atención de tu ciudad.

Al pulsar **"Aceptar y continuar"** autorizas de forma libre, previa, expresa e informada el tratamiento de tus datos sensibles para las finalidades descritas.
$texto$,
  true
);
