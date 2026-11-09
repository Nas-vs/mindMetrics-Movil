-- =====================================================================
-- RF-08 CA-8 · Regla de alerta
-- Back: Juliana Pérez · Front: Julián Gómez
--
-- "Cada vez que se guarda un registro, la app evalúa la regla de alerta."
--
-- La regla (acordada en el equipo). Hay alerta si el ánimo del día es
-- bajo (1 o 2) y además se cumple alguna de estas:
--   riesgo_alto       el motor dio nivel de riesgo 4 o 5 (alto/crítico)
--                     en los últimos 7 días.
--   muy_bajo_seguido  ánimo 1 hoy y el día anterior.
--   racha_baja        los 3 últimos días registrados (dentro de los
--                     últimos 5) tienen ánimo 1 o 2.
-- Si hay varias, se guarda la primera en ese orden.
-- No se repite: máximo una alerta cada 3 días por usuario.
--
-- riesgo_alto queda listo pero solo se activa cuando el motor escriba en
-- niveles_riesgo; mientras no haya resultados, la regla usa las otras dos.
--
-- Qué crea:
--   1. alertas_bienestar              → historial de alertas (RLS estricto).
--   2. evaluar_regla_alerta()         → la regla (uso interno).
--   3. Trigger en registros_animo     → evalúa al guardar (CA-8), aunque
--                                       la app no lo haga.
--   4. RPC alerta_pendiente()         → ¿hay una alerta sin mostrar?
--   5. RPC marcar_alerta_vista(id)    → la app ya la mostró.
--
-- Sin conexión: la app debe replicar la regla en local con sus registros
-- (Drift) para mostrar el mensaje de inmediato; al sincronizar, el
-- servidor la vuelve a evaluar y la deja registrada.
--
-- Datos sensibles (Ley 1581): solo se guarda el motivo, no el detalle.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Historial de alertas
-- ---------------------------------------------------------------------
create table public.alertas_bienestar (
  id          uuid primary key default gen_random_uuid(),
  usuario_id  uuid not null references auth.users (id) on delete cascade,
  -- Día LOCAL del registro de ánimo que la disparó
  fecha       date not null,
  motivo      text not null
                check (motivo in ('riesgo_alto', 'muy_bajo_seguido', 'racha_baja')),
  creada_en   timestamptz not null default now(),
  -- La app la mostró (marcar_alerta_vista). null = pendiente.
  vista_en    timestamptz,
  unique (usuario_id, fecha)
);

comment on table public.alertas_bienestar is
  'RF-08 CA-8: alertas de bienestar generadas por la regla. Solo las escribe el servidor.';

create index alertas_bienestar_usuario_fecha_idx
  on public.alertas_bienestar (usuario_id, fecha desc);

alter table public.alertas_bienestar enable row level security;

-- La app solo lee las suyas; insertar y marcar como vista va por RPC.
revoke all on public.alertas_bienestar from anon, authenticated;
grant select on public.alertas_bienestar to authenticated;

create policy "cada usuario ve sus alertas"
  on public.alertas_bienestar for select to authenticated
  using ((select auth.uid()) = usuario_id);


-- ---------------------------------------------------------------------
-- 2. La regla
-- Devuelve el motivo de la alerta, o null si no hay alerta.
-- No mira si ya hubo una alerta reciente: eso lo decide quien la llame.
-- ---------------------------------------------------------------------
create function public.evaluar_regla_alerta(p_usuario uuid, p_fecha date)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_hoy        smallint;
  v_ayer       smallint;
  v_ultimos    smallint[];
begin
  select nivel into v_hoy
  from public.registros_animo
  where usuario_id = p_usuario and fecha = p_fecha;

  -- Solo un día bajo puede disparar la alerta.
  if v_hoy is null or v_hoy > 2 then
    return null;
  end if;

  -- riesgo_alto: el motor dio 4 o 5 en los últimos 7 días.
  if exists (
    select 1
    from public.niveles_riesgo n
    where n.usuario_id = p_usuario
      and n.calculado_en >= now() - interval '7 days'
      and n.nivel >= 4
      -- Debe ser el ÚLTIMO resultado: si después mejoró, no cuenta.
      and n.calculado_en = (
        select max(m.calculado_en) from public.niveles_riesgo m
        where m.usuario_id = p_usuario
      )
  ) then
    return 'riesgo_alto';
  end if;

  -- muy_bajo_seguido: 1 hoy y 1 el día anterior.
  select nivel into v_ayer
  from public.registros_animo
  where usuario_id = p_usuario and fecha = p_fecha - 1;

  if v_hoy = 1 and v_ayer = 1 then
    return 'muy_bajo_seguido';
  end if;

  -- racha_baja: los 3 últimos registros (de los últimos 5 días) en 1 o 2.
  select array_agg(nivel order by fecha desc) into v_ultimos
  from (
    select nivel, fecha
    from public.registros_animo
    where usuario_id = p_usuario
      and fecha between p_fecha - 4 and p_fecha
    order by fecha desc
    limit 3
  ) ultimos;

  if cardinality(v_ultimos) = 3 and 2 >= all (v_ultimos) then
    return 'racha_baja';
  end if;

  return null;
end;
$$;

-- Uso interno: no se publica en la API.
revoke execute on function public.evaluar_regla_alerta(uuid, date)
  from public, anon, authenticated;


-- ---------------------------------------------------------------------
-- 3. Trigger: evaluar al guardar un registro de ánimo (CA-8)
-- ---------------------------------------------------------------------
create function public.alerta_al_guardar_animo()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_motivo text;
begin
  -- Solo días recientes: editar un día viejo (RF-13) no genera alertas.
  -- (+1 / -1 día de margen por la zona horaria del usuario.)
  if new.fecha < current_date - 1 or new.fecha > current_date + 1 then
    return new;
  end if;

  -- Máximo una alerta cada 3 días.
  if exists (
    select 1 from public.alertas_bienestar a
    where a.usuario_id = new.usuario_id
      and a.fecha > new.fecha - 3
      and a.fecha <= new.fecha
  ) then
    return new;
  end if;

  v_motivo := public.evaluar_regla_alerta(new.usuario_id, new.fecha);

  if v_motivo is not null then
    insert into public.alertas_bienestar (usuario_id, fecha, motivo)
    values (new.usuario_id, new.fecha, v_motivo)
    on conflict (usuario_id, fecha) do nothing;
  end if;

  return new;
end;
$$;

create trigger alerta_despues_de_guardar_animo
  after insert or update of nivel on public.registros_animo
  for each row
  execute function public.alerta_al_guardar_animo();

revoke execute on function public.alerta_al_guardar_animo()
  from public, anon, authenticated;


-- ---------------------------------------------------------------------
-- 4. RPC: ¿hay una alerta por mostrar?
--
-- Uso desde la app, después de guardar el ánimo:
--   await supabase.rpc('alerta_pendiente');
-- Devuelve {id, fecha, motivo} o null.
-- Solo cuenta alertas de los últimos 3 días: una vieja ya no tiene sentido.
-- ---------------------------------------------------------------------
create function public.alerta_pendiente()
returns jsonb
language sql
stable
security invoker   -- respeta la RLS: cada quien solo ve las suyas
set search_path = ''
as $$
  select jsonb_build_object('id', a.id, 'fecha', a.fecha, 'motivo', a.motivo)
  from public.alertas_bienestar a
  where a.usuario_id = (select auth.uid())
    and a.vista_en is null
    and a.fecha >= current_date - 3
  order by a.fecha desc
  limit 1;
$$;

revoke execute on function public.alerta_pendiente() from public, anon;
grant  execute on function public.alerta_pendiente() to authenticated;


-- ---------------------------------------------------------------------
-- 5. RPC: la app ya mostró la alerta
--   await supabase.rpc('marcar_alerta_vista', params: {'p_id': id});
-- Devuelve true si se marcó (false si no existe o no es del usuario).
-- ---------------------------------------------------------------------
create function public.marcar_alerta_vista(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.alertas_bienestar
     set vista_en = coalesce(vista_en, now())
   where id = p_id
     and usuario_id = auth.uid();
  return found;
end;
$$;

revoke execute on function public.marcar_alerta_vista(uuid) from public, anon;
grant  execute on function public.marcar_alerta_vista(uuid) to authenticated;
