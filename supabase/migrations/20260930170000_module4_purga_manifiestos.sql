-- ============================================================
-- Módulo 4: Manifiestos — retención y purga
--
-- Los manifiestos crecen con el uso (p. ej. 7 camiones x 7 destinos
-- diarios ≈ 1.470 líneas/mes). Para acotar el crecimiento se ofrece una
-- función de mantenimiento que elimina manifiestos ANTIGUOS YA VALIDADOS
-- (cotejo = 'ok'), borrando en cascada sus líneas.
--
-- No es automática: se invoca a mano o por pg_cron si se desea.
-- La retención es configurable (por defecto 90 días ≈ 3 meses).
--
-- NO borra manifiestos pendientes ni "requiere revisión", sin importar su
-- antigüedad, para no perder historial sin validar.
-- ============================================================

-- ------------------------------------------------------------
-- Parámetro de retención (en días). Editable sin migración.
-- ------------------------------------------------------------
create table if not exists public.configuracion (
  clave  text primary key,
  valor  text not null,
  descripcion text,
  updated_at timestamptz not null default now()
);

comment on table public.configuracion is
  'Parámetros del sistema editables (p. ej. retención de manifiestos).';

insert into public.configuracion (clave, valor, descripcion)
values (
  'manifiestos_retencion_dias',
  '90',
  'Días que se conservan los manifiestos validados antes de poder purgarlos.'
)
on conflict (clave) do nothing;

-- Solo el administrador lee y escribe la configuración.
alter table public.configuracion enable row level security;

drop policy if exists configuracion_select_admin on public.configuracion;
create policy configuracion_select_admin
  on public.configuracion
  for select
  to authenticated
  using (public.is_admin());

drop policy if exists configuracion_upsert_admin on public.configuracion;
create policy configuracion_upsert_admin
  on public.configuracion
  for insert
  to authenticated
  with check (public.is_admin());

drop policy if exists configuracion_update_admin on public.configuracion;
create policy configuracion_update_admin
  on public.configuracion
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

grant usage on schema public to authenticated;
grant select, insert, update on public.configuracion to authenticated;
grant all on public.configuracion to service_role;

-- ------------------------------------------------------------
-- Función de purga. Devuelve cuántos manifiestos borró.
--   * p_dias: antigüedad mínima (NULL -> usa la config, o 90).
--   * p_dry_run: si es true, solo cuenta (no borra).
-- Solo admin (o service_role) puede ejecutarla.
-- ------------------------------------------------------------
create or replace function public.purgar_manifiestos_antiguos(
  p_dias integer default null,
  p_dry_run boolean default false
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_dias integer;
  v_corte date;
  v_borrados integer;
begin
  -- Autorización: administrador activo (o service_role sin JWT).
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'Solo un administrador puede purgar manifiestos.'
      using errcode = '42501';
  end if;

  v_dias := coalesce(
    p_dias,
    (select nullif(valor, '')::int
       from public.configuracion
      where clave = 'manifiestos_retencion_dias'),
    90
  );
  if v_dias < 1 then
    raise exception 'La retención debe ser al menos 1 día.';
  end if;

  v_corte := (current_date - make_interval(days => v_dias))::date;

  if p_dry_run then
    select count(*) into v_borrados
      from public.manifiestos
     where cotejo = 'ok'
       and fecha < v_corte;
    return v_borrados;
  end if;

  -- Borra cabeceras validadas y antiguas; las líneas caen en cascada.
  delete from public.manifiestos
   where cotejo = 'ok'
     and fecha < v_corte;
  get diagnostics v_borrados = row_count;
  return v_borrados;
end$$;

comment on function public.purgar_manifiestos_antiguos(integer, boolean) is
  'Elimina manifiestos validados (cotejo=ok) más antiguos que la retención.';

grant execute on function public.purgar_manifiestos_antiguos(integer, boolean)
  to authenticated;
grant execute on function public.purgar_manifiestos_antiguos(integer, boolean)
  to service_role;
