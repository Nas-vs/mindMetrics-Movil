-- =====================================================================
-- RF-23 Ver y editar perfil (back)
--
--   CA-1: Perfil muestra avatar (iniciales), nombre, @nickname, correo
--         y fecha de registro.
--         → No necesita objetos nuevos: nombre, nickname y creado_en ya
--           se leen con la política "cada usuario ve su perfil" (RF-03).
--           El correo sale de la sesión (auth.currentUser.email) y las
--           iniciales se calculan en el celular.
--   CA-2: "Editar perfil" permite cambiar nombre y nickname.
--         → Esta migración.
--
-- Diseño:
--   * La escritura es un UPDATE directo por PostgREST sobre perfiles.
--   * RLS decide QUÉ FILA (solo la propia); el privilegio por columna
--     decide QUÉ CAMPOS (solo nombre_completo y nickname).
--   * Las reglas de formato y la unicidad del nickname ya existen desde
--     RF-03 (CHECK + índice único sobre lower(nickname)).
--   * nickname_disponible (RF-03) no se modifica: devuelve false también
--     para el nickname propio. El formulario no lo consulta cuando el
--     valor es igual al actual sin importar mayúsculas.
--   * El trigger de RF-07 ya copia el nickname nuevo a app_metadata.
--     El cliente debe llamar a auth.refreshSession() después de guardar
--     para que el JWT traiga el nickname actualizado.
--
-- Errores que verá el cliente (código SQLSTATE en PostgrestException):
--   23505  nickname ocupado (sin importar mayúsculas)
--   23514  formato inválido de nombre_completo o nickname
--   42501  se intentó cambiar un campo no editable
--   0 filas devueltas: sin sesión o fila ajena (lo filtra RLS)
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Qué campos se pueden editar
-- ---------------------------------------------------------------------
-- RLS filtra filas, no columnas. Supabase concede UPDATE sobre toda la
-- tabla a anon y authenticated, así que sin esto un cliente podría
-- cambiar fecha_nacimiento (saltándose la regla de 18 años), activo o
-- creado_en con un PATCH directo.
revoke update on table public.perfiles from anon, authenticated;
grant  update (nombre_completo, nickname) on table public.perfiles to authenticated;


-- ---------------------------------------------------------------------
-- 2. Qué fila se puede editar
-- ---------------------------------------------------------------------
create policy "cada usuario edita su perfil"
  on public.perfiles
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);


-- ---------------------------------------------------------------------
-- 3. Normalización y fecha de actualización
-- ---------------------------------------------------------------------
-- Antes de validar los CHECK:
--   * nombre_completo: sin espacios al inicio o al final, y los espacios
--     repetidos se reducen a uno ("  Ana   María " → "Ana María").
--   * nickname: sin espacios al inicio o al final. Un espacio interno
--     sigue siendo inválido (CHECK de RF-03).
--   * actualizado_en: solo cambia si cambió algún dato real, así que
--     guardar el formulario sin tocar nada no altera la fecha.
create function public.normalizar_perfil_al_editar()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.nombre_completo := regexp_replace(trim(new.nombre_completo), '\s+', ' ', 'g');
  new.nickname        := trim(new.nickname);

  if (to_jsonb(new) - 'actualizado_en') is distinct from (to_jsonb(old) - 'actualizado_en') then
    new.actualizado_en := now();
  end if;

  return new;
end;
$$;

comment on function public.normalizar_perfil_al_editar() is
  'RF-23: limpia espacios de nombre y nickname, y actualiza actualizado_en solo si hubo cambios.';

create trigger al_editar_perfil_normalizar
  before update on public.perfiles
  for each row
  execute function public.normalizar_perfil_al_editar();

revoke execute on function public.normalizar_perfil_al_editar() from public, anon, authenticated;

