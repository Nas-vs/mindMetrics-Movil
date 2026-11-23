-- =====================================================================
-- Avatar conversacional · Fase 1: contrato de datos con el motor
-- Back: Julián Gómez · Juliana Pérez
--
-- El motor de MindMetrics (repo Mindmetrics-dev/mindMetrics, carpeta
-- backend/agente) es un sistema experto por reglas:
--   mapper.py → 19 variables en {0.2, 0.6, 1.0}
--   scorer + rules (21 sinergias) + protectors → nivel de riesgo 1–5.
-- Esta migración guarda lo que el motor necesita y lo que devuelve.
--
-- Qué crea:
--   1. evaluaciones_iniciales → la encuesta inicial (una por usuario).
--                               Se llena con el formulario o con el avatar
--                               (canal = 'formulario' | 'voz').
--   2. encuestas_diarias      → hábitos y estrés del día. Se guarda con la
--                               RPC guardar_encuesta_diaria(). El ánimo del
--                               día NO se repite aquí: se toma de
--                               registros_animo (RF-08, requiere esa migración).
--   3. niveles_riesgo         → historial de resultados del motor. La app
--                               solo lo lee.
--   4. nivel_riesgo_actual    → vista con el último nivel de cada usuario.
--   5. Esquema motor (fuera de la API REST) con un rol propio:
--        motor.estado_consolidado()  → JSON listo para mapear_evaluacion()
--        motor.pendientes()          → qué falta por calcular
--        motor.registrar_resultado() → guarda la salida de evaluar()
--      Más un aviso pg_notify('motor_pendiente') en cada encuesta nueva.
--
-- Vocabulario: los valores de texto son los mismos que reconoce
-- agente/mapper.py y los choices de formulario/forms.py de la web.
-- Cambiar uno aquí sin cambiarlo allá hace que el motor use su valor
-- por defecto sin avisar.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Evaluación inicial (una por usuario)
-- ---------------------------------------------------------------------
create table public.evaluaciones_iniciales (
  id                    uuid primary key default gen_random_uuid(),
  usuario_id            uuid not null unique default auth.uid()
                          references auth.users (id) on delete cascade,
  canal                 text not null default 'formulario'
                          check (canal in ('formulario', 'voz')),
  version_contrato      text not null default '1.0',

  -- Sociodemográficos. La edad NO se pregunta: el trigger la calcula con
  -- perfiles.fecha_nacimiento (RF-03).
  edad                  smallint not null check (edad between 18 and 120),
  genero                text not null
                          check (genero in ('femenino', 'masculino', 'no_binario', 'otro')),
  estado_relacion       text not null
                          check (estado_relacion in ('soltero', 'noviazgo', 'union libre',
                                 'casado', 'poliamor', 'divorciado', 'viudo')),
  situacion_trabajo     text not null
                          check (situacion_trabajo in ('estudiante', 'empleado tiempo completo',
                                 'empleado medio tiempo', 'independiente', 'contrato temporal',
                                 'desempleado', 'pensionado')),

  -- Hábitos. OJO con las unidades: el mapper compara trabajo y actividad
  -- física contra umbrales SEMANALES (40/48 h y 150 min).
  hr_sueno              numeric(3,1) not null check (hr_sueno between 0 and 24),
  hr_trabajo            numeric(4,1) not null check (hr_trabajo between 0 and 168),
  hr_pantalla           numeric(3,1) not null check (hr_pantalla between 0 and 24),
  hr_act_fis            numeric(4,1) not null check (hr_act_fis between 0 and 168),

  -- Escalas 1–10
  estres_laboral        smallint not null check (estres_laboral between 1 and 10),
  estres_academico      smallint not null check (estres_academico between 1 and 10),
  estres_financ         smallint not null check (estres_financ between 1 and 10),
  satisfaccion_laboral  smallint not null check (satisfaccion_laboral between 1 and 10),
  cambio_emocional      smallint not null check (cambio_emocional between 1 and 10),

  -- Antecedentes
  uso_sustancias        boolean not null,
  diagnostico_previo    boolean not null,
  historial_panico      boolean not null,
  historial_familiar    boolean not null,
  dificultad_concentra  text not null
                          check (dificultad_concentra in ('ninguno', 'ocasional', 'frecuente')),
  tratamiento_previo    text not null
                          check (tratamiento_previo in ('ninguno', 'adherente', 'abandono')),
  apoyo_percibido       text not null
                          check (apoyo_percibido in ('excelente', 'alto', 'moderado',
                                 'intermitente', 'poco', 'nulo')),

  creado_en             timestamptz not null default now()
);

comment on table public.evaluaciones_iniciales is
  'Encuesta inicial del motor de riesgo (formulario o avatar por voz). Una por usuario.';
comment on column public.evaluaciones_iniciales.hr_sueno    is 'Horas de sueño por DÍA.';
comment on column public.evaluaciones_iniciales.hr_trabajo  is 'Horas de trabajo/estudio por SEMANA.';
comment on column public.evaluaciones_iniciales.hr_pantalla is 'Horas de pantalla por DÍA.';
comment on column public.evaluaciones_iniciales.hr_act_fis  is 'Horas de actividad física por SEMANA.';


-- Edad calculada desde el perfil (no se confía en la que mande el cliente)
create function public.evaluacion_calcular_edad()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_nacimiento date;
begin
  select p.fecha_nacimiento into v_nacimiento
  from public.perfiles p
  where p.id = new.usuario_id;

  if v_nacimiento is null then
    raise exception 'perfil_inexistente';
  end if;

  new.edad := extract(year from age(current_date, v_nacimiento))::smallint;
  return new;
end;
$$;

create trigger evaluacion_antes_de_insertar
  before insert on public.evaluaciones_iniciales
  for each row
  execute function public.evaluacion_calcular_edad();

revoke execute on function public.evaluacion_calcular_edad() from public, anon, authenticated;


-- ---------------------------------------------------------------------
-- 2. Encuesta diaria (una por usuario y por día)
-- ---------------------------------------------------------------------
create table public.encuestas_diarias (
  -- El id lo genera la app (UUID), igual que RF-08, para guardar sin conexión
  id                  uuid primary key,
  usuario_id          uuid not null default auth.uid()
                        references auth.users (id) on delete cascade,
  -- Día LOCAL del usuario (lo envía la app)
  fecha               date not null check (fecha <= current_date + 1),
  canal               text not null default 'formulario'
                        check (canal in ('formulario', 'voz')),

  hr_sueno            numeric(3,1) not null check (hr_sueno between 0 and 24),
  hr_trabajo          numeric(3,1) not null check (hr_trabajo between 0 and 24),
  hr_pantalla         numeric(3,1) not null check (hr_pantalla between 0 and 24),
  hr_act_fis          numeric(3,1) not null check (hr_act_fis between 0 and 24),
  estres_laboral      smallint not null check (estres_laboral between 1 and 10),
  estres_academico    smallint not null check (estres_academico between 1 and 10),
  estres_financ       smallint not null check (estres_financ between 1 and 10),
  interaccion_social  boolean not null,
  autocuidado         boolean not null,

  creado_en           timestamptz not null default now(),
  actualizado_en      timestamptz not null default now(),

  -- La pantalla se cruza con el trabajo, pero sueño + trabajo + ejercicio no
  -- pueden pasar de un día.
  constraint encuestas_diarias_horas_del_dia
    check (hr_sueno + hr_trabajo + hr_act_fis <= 24),
  unique (usuario_id, fecha)
);

comment on table public.encuestas_diarias is
  'Hábitos y estrés del día para el motor. El ánimo del día viene de registros_animo (RF-08).';

create index encuestas_diarias_usuario_fecha_idx
  on public.encuestas_diarias (usuario_id, fecha desc);

create function public.encuesta_marcar_actualizacion()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.actualizado_en := now();
  return new;
end;
$$;

create trigger encuesta_antes_de_actualizar
  before update on public.encuestas_diarias
  for each row
  execute function public.encuesta_marcar_actualizacion();


-- ---------------------------------------------------------------------
-- 3. Resultados del motor
-- ---------------------------------------------------------------------
create table public.niveles_riesgo (
  id              bigint generated always as identity primary key,
  usuario_id      uuid not null references auth.users (id) on delete cascade,
  origen          text not null check (origen in ('evaluacion_inicial', 'encuesta_diaria')),
  evaluacion_id   uuid unique references public.evaluaciones_iniciales (id) on delete cascade,
  encuesta_id     uuid unique references public.encuestas_diarias (id) on delete cascade,
  nivel           smallint not null check (nivel between 1 and 5),
  -- Mismas claves que usa la web (formulario/services.py)
  etiqueta        text generated always as (
                    case nivel
                      when 1 then 'muy_bajo' when 2 then 'bajo' when 3 then 'moderado'
                      when 4 then 'alto' else 'critico'
                    end) stored,
  score_final     numeric(5,4) not null check (score_final between 0 and 1),
  -- Salida completa de evaluar(): sinergias, protectores, techo aplicado…
  detalle         jsonb not null default '{}'::jsonb,
  -- Estado consolidado con el que se calculó (auditoría y prueba de concordancia)
  estado_entrada  jsonb not null,
  version_motor   text not null,
  calculado_en    timestamptz not null default now(),

  constraint niveles_riesgo_origen_coherente check (
    (origen = 'evaluacion_inicial' and evaluacion_id is not null and encuesta_id is null)
    or (origen = 'encuesta_diaria' and encuesta_id is not null and evaluacion_id is null)
  )
);

comment on table public.niveles_riesgo is
  'Historial de niveles de riesgo (1–5) calculados por el motor. Solo lo escribe el motor.';

create index niveles_riesgo_usuario_fecha_idx
  on public.niveles_riesgo (usuario_id, calculado_en desc);

-- Último nivel de cada usuario. security_invoker: respeta la RLS de la tabla.
create view public.nivel_riesgo_actual
with (security_invoker = true) as
select distinct on (usuario_id)
  usuario_id, nivel, etiqueta, origen, calculado_en
from public.niveles_riesgo
order by usuario_id, calculado_en desc, id desc;


-- ---------------------------------------------------------------------
-- 4. Permisos y RLS
--
-- RLS filtra FILAS; los privilegios por columna limitan QUÉ se escribe.
-- Supabase da ALL a anon y authenticated por defecto: se quita y se
-- concede solo lo necesario.
-- ---------------------------------------------------------------------
alter table public.evaluaciones_iniciales enable row level security;
alter table public.encuestas_diarias      enable row level security;
alter table public.niveles_riesgo         enable row level security;

revoke all on public.evaluaciones_iniciales, public.encuestas_diarias,
              public.niveles_riesgo, public.nivel_riesgo_actual
  from anon, authenticated;

-- Evaluación inicial: se crea una vez y no se edita (igual que en la web).
-- usuario_id, edad, id y version_contrato los pone el servidor.
grant select on public.evaluaciones_iniciales to authenticated;
grant insert (canal, genero, estado_relacion, situacion_trabajo,
              hr_sueno, hr_trabajo, hr_pantalla, hr_act_fis,
              estres_laboral, estres_academico, estres_financ,
              satisfaccion_laboral, cambio_emocional,
              uso_sustancias, diagnostico_previo, historial_panico, historial_familiar,
              dificultad_concentra, tratamiento_previo, apoyo_percibido)
  on public.evaluaciones_iniciales to authenticated;

create policy "cada usuario ve su evaluacion inicial"
  on public.evaluaciones_iniciales for select to authenticated
  using ((select auth.uid()) = usuario_id);

create policy "cada usuario crea su evaluacion inicial"
  on public.evaluaciones_iniciales for insert to authenticated
  with check ((select auth.uid()) = usuario_id);

-- Encuesta diaria: solo lectura directa. Se escribe con la RPC
-- guardar_encuesta_diaria() (abajo), igual que RF-08: así el upsert del
-- mismo día conserva el id del servidor aunque la app mande otro.
grant select on public.encuestas_diarias to authenticated;

create policy "cada usuario ve sus encuestas diarias"
  on public.encuestas_diarias for select to authenticated
  using ((select auth.uid()) = usuario_id);

create function public.guardar_encuesta_diaria(
  p_id                  uuid,
  p_fecha               date,
  p_hr_sueno            numeric,
  p_hr_trabajo          numeric,
  p_hr_pantalla         numeric,
  p_hr_act_fis          numeric,
  p_estres_laboral      int,
  p_estres_academico    int,
  p_estres_financ       int,
  p_interaccion_social  boolean,
  p_autocuidado         boolean,
  p_canal               text default 'formulario'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usuario uuid := auth.uid();
  v_fila    public.encuestas_diarias%rowtype;
begin
  if v_usuario is null then
    raise exception 'sesion_requerida';
  end if;
  if p_id is null or p_fecha is null then
    raise exception 'datos_incompletos';
  end if;

  -- Los CHECK de la tabla validan rangos, canal y fecha futura.
  insert into public.encuestas_diarias as d
    (id, usuario_id, fecha, canal, hr_sueno, hr_trabajo, hr_pantalla, hr_act_fis,
     estres_laboral, estres_academico, estres_financ, interaccion_social, autocuidado)
  values
    (p_id, v_usuario, p_fecha, coalesce(p_canal, 'formulario'), p_hr_sueno, p_hr_trabajo,
     p_hr_pantalla, p_hr_act_fis, p_estres_laboral, p_estres_academico, p_estres_financ,
     p_interaccion_social, p_autocuidado)
  on conflict (usuario_id, fecha) do update
    set canal              = excluded.canal,
        hr_sueno           = excluded.hr_sueno,
        hr_trabajo         = excluded.hr_trabajo,
        hr_pantalla        = excluded.hr_pantalla,
        hr_act_fis         = excluded.hr_act_fis,
        estres_laboral     = excluded.estres_laboral,
        estres_academico   = excluded.estres_academico,
        estres_financ      = excluded.estres_financ,
        interaccion_social = excluded.interaccion_social,
        autocuidado        = excluded.autocuidado
  returning d.* into v_fila;

  return to_jsonb(v_fila) - 'usuario_id';
end;
$$;

revoke execute on function public.guardar_encuesta_diaria(uuid, date, numeric, numeric, numeric,
  numeric, int, int, int, boolean, boolean, text) from public, anon;
grant  execute on function public.guardar_encuesta_diaria(uuid, date, numeric, numeric, numeric,
  numeric, int, int, int, boolean, boolean, text) to authenticated;

-- Niveles: la app solo lee. Escribe el motor con motor.registrar_resultado().
grant select on public.niveles_riesgo, public.nivel_riesgo_actual to authenticated;

create policy "cada usuario ve sus niveles de riesgo"
  on public.niveles_riesgo for select to authenticated
  using ((select auth.uid()) = usuario_id);


-- ---------------------------------------------------------------------
-- 5. Esquema motor: lo que usa el servicio Django
--
-- No se agrega a "Exposed schemas" de la API, así que no tiene endpoint
-- REST. El servicio se conecta por PostgreSQL con un usuario miembro de
-- motor_mindmetrics (ver LEEME: el usuario con contraseña se crea a mano,
-- nunca en una migración).
-- ---------------------------------------------------------------------
-- Los roles son del clúster, no de la base: `supabase db reset` no los
-- borra. Por eso se crea solo si no existe.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'motor_mindmetrics') then
    create role motor_mindmetrics nologin;
  end if;
end $$;
create schema motor;
revoke all on schema motor from public;
grant usage on schema motor to motor_mindmetrics;


-- Redondeo "mitad al par", igual que round() de Python: así el promedio
-- 6.5 da 6 en los dos lados y no cruza el umbral 7 del mapper.
create function motor.redondear_como_python(x numeric)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case
    when x is null then null
    when abs(x - trunc(x)) = 0.5 then (2 * round(x / 2))::integer
    else round(x)::integer
  end
$$;


-- Mismo algoritmo que agente/state_builder.py, con dos diferencias
-- documentadas en el LEEME:
--   a) Trabajo y actividad física diarios se pasan a SEMANA (×7) antes
--      de entregarlos al mapper, que usa umbrales semanales.
--   b) El ánimo sale de registros_animo (RF-08, escala 1–5) y se lleva a
--      la escala 1–10 de la web (×2) antes de calcular la varianza.
create function motor.estado_consolidado(p_usuario uuid, p_fecha date default current_date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c_ventana constant int := 7;
  e        public.evaluaciones_iniciales%rowtype;
  v_n      int;
  v_sueno  numeric; v_trab numeric; v_pant numeric; v_fis numeric;
  v_lab    numeric; v_acad numeric;
  v_animos int;
  v_var    numeric;
  v_cambio int;
begin
  select * into e from public.evaluaciones_iniciales where usuario_id = p_usuario;
  if not found then
    raise exception 'evaluacion_inicial_faltante';
  end if;

  select count(*), avg(hr_sueno), avg(hr_trabajo), avg(hr_pantalla), avg(hr_act_fis),
         avg(estres_laboral), avg(estres_academico)
    into v_n, v_sueno, v_trab, v_pant, v_fis, v_lab, v_acad
  from (
    select * from public.encuestas_diarias
    where usuario_id = p_usuario and fecha <= p_fecha
    order by fecha desc
    limit c_ventana
  ) d;

  if v_n = 0 then
    v_sueno := e.hr_sueno;  v_trab := e.hr_trabajo;
    v_pant  := e.hr_pantalla; v_fis := e.hr_act_fis;
    v_lab   := e.estres_laboral; v_acad := e.estres_academico;
  else
    v_trab := v_trab * 7;   -- diario → semanal
    v_fis  := v_fis * 7;    -- diario → semanal
  end if;

  select count(*), var_pop(nivel * 2)
    into v_animos, v_var
  from (
    select nivel from public.registros_animo
    where usuario_id = p_usuario and fecha <= p_fecha
    order by fecha desc
    limit c_ventana
  ) a;

  if v_animos < 2 then
    v_cambio := e.cambio_emocional;
  elsif v_var < 1.0 then
    v_cambio := 1;
  elsif v_var > 4.0 then
    v_cambio := least(10, 7 + trunc(v_var - 4.0)::int);
  else
    v_cambio := motor.redondear_como_python(2 + (v_var - 1.0) / 3.0 * 4);
  end if;

  return jsonb_build_object(
    'edad',                 e.edad,
    'genero',               e.genero,
    'estado_relacion',      e.estado_relacion,
    'situacion_trabajo',    e.situacion_trabajo,
    'diagnostico_previo',   e.diagnostico_previo,
    'historial_panico',     e.historial_panico,
    'historial_familiar',   e.historial_familiar,
    'tratamiento_previo',   e.tratamiento_previo,
    'apoyo_percibido',      e.apoyo_percibido,
    'uso_sustancias',       e.uso_sustancias,
    'dificultad_concentra', e.dificultad_concentra,
    'satisfaccion_laboral', e.satisfaccion_laboral,
    'hr_sueno',             round(v_sueno, 2),
    'hr_trabajo',           round(v_trab, 2),
    'hr_pantalla',          round(v_pant, 2),
    'hr_act_fis',           round(v_fis, 2),
    'estres_laboral',       motor.redondear_como_python(v_lab),
    'estres_academico',     motor.redondear_como_python(v_acad),
    'cambio_emocional',     v_cambio,
    -- Metadatos (el mapper los ignora)
    '_registros_diarios',   v_n,
    '_registros_animo',     v_animos,
    '_fecha',               p_fecha
  );
end;
$$;


-- Lo que falta por calcular: evaluaciones sin nivel y encuestas sin nivel
-- o editadas después del último cálculo.
create function motor.pendientes()
returns table (origen text, id uuid, usuario_id uuid, fecha date)
language sql
stable
security definer
set search_path = ''
as $$
  select 'evaluacion_inicial', e.id, e.usuario_id, e.creado_en::date
  from public.evaluaciones_iniciales e
  where not exists (select 1 from public.niveles_riesgo n where n.evaluacion_id = e.id)
  union all
  select 'encuesta_diaria', d.id, d.usuario_id, d.fecha
  from public.encuestas_diarias d
  left join public.niveles_riesgo n on n.encuesta_id = d.id
  where n.id is null or n.calculado_en < d.actualizado_en
  order by 4, 1
$$;


-- Guarda la salida de agente.classifier.evaluar(). Si ya había un nivel
-- para esa encuesta (porque se editó), lo reemplaza.
create function motor.registrar_resultado(
  p_origen        text,
  p_id            uuid,
  p_nivel         int,
  p_score_final   numeric,
  p_estado        jsonb,
  p_version_motor text,
  p_detalle       jsonb default '{}'::jsonb
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usuario uuid;
  v_id      bigint;
begin
  if p_nivel not between 1 and 5 then
    raise exception 'nivel_invalido';
  end if;

  if p_origen = 'evaluacion_inicial' then
    select usuario_id into v_usuario from public.evaluaciones_iniciales where id = p_id;
  elsif p_origen = 'encuesta_diaria' then
    select usuario_id into v_usuario from public.encuestas_diarias where id = p_id;
  else
    raise exception 'origen_invalido';
  end if;

  if v_usuario is null then
    raise exception 'origen_inexistente';
  end if;

  if p_origen = 'evaluacion_inicial' then
    insert into public.niveles_riesgo
      (usuario_id, origen, evaluacion_id, nivel, score_final, detalle, estado_entrada, version_motor)
    values
      (v_usuario, p_origen, p_id, p_nivel, p_score_final, coalesce(p_detalle, '{}'), p_estado, p_version_motor)
    on conflict (evaluacion_id) do update
      set nivel = excluded.nivel, score_final = excluded.score_final,
          detalle = excluded.detalle, estado_entrada = excluded.estado_entrada,
          version_motor = excluded.version_motor, calculado_en = now()
    returning id into v_id;
  else
    insert into public.niveles_riesgo
      (usuario_id, origen, encuesta_id, nivel, score_final, detalle, estado_entrada, version_motor)
    values
      (v_usuario, p_origen, p_id, p_nivel, p_score_final, coalesce(p_detalle, '{}'), p_estado, p_version_motor)
    on conflict (encuesta_id) do update
      set nivel = excluded.nivel, score_final = excluded.score_final,
          detalle = excluded.detalle, estado_entrada = excluded.estado_entrada,
          version_motor = excluded.version_motor, calculado_en = now()
    returning id into v_id;
  end if;

  return v_id;
end;
$$;

revoke execute on all functions in schema motor from public, anon, authenticated;
grant execute on function motor.estado_consolidado(uuid, date),
                         motor.pendientes(),
                         motor.registrar_resultado(text, uuid, int, numeric, jsonb, text, jsonb)
  to motor_mindmetrics;


-- ---------------------------------------------------------------------
-- 6. Aviso al motor: pg_notify en cada evaluación o encuesta nueva/editada
-- El servicio hace LISTEN motor_pendiente (conexión directa, no pooler en
-- modo transacción) y, si se cae, recupera lo perdido con motor.pendientes().
-- ---------------------------------------------------------------------
create function motor.avisar_pendiente()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform pg_notify('motor_pendiente', jsonb_build_object(
    'origen', tg_argv[0],
    'id', new.id,
    'usuario_id', new.usuario_id
  )::text);
  return null;
end;
$$;

create trigger evaluacion_avisar_motor
  after insert on public.evaluaciones_iniciales
  for each row execute function motor.avisar_pendiente('evaluacion_inicial');

create trigger encuesta_avisar_motor
  after insert or update on public.encuestas_diarias
  for each row execute function motor.avisar_pendiente('encuesta_diaria');

revoke execute on function motor.avisar_pendiente() from public, anon, authenticated;
