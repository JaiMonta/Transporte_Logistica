-- ============================================================
-- Módulo: Camiones
-- Registro de camiones con baja lógica y chofer asignado.
--   * El administrador crea, edita y desactiva.
--   * El chofer solo lee los camiones activos.
-- La placa es única (no se repite, ni entre inactivos).
-- ============================================================

create table if not exists public.camiones (
  id            uuid primary key default gen_random_uuid(),
  marca         text not null,
  placa         text not null,
  modelo        text,
  anio          integer,
  capacidad_kg  numeric,
  volumen_m3    numeric,
  chofer_id     uuid not null references public.profiles (id) on delete restrict,
  activo        boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.camiones is
  'Catálogo de camiones (baja lógica con activo) y su chofer asignado.';

-- La placa debe ser única (comparación sin distinguir mayúsculas).
create unique index if not exists camiones_placa_unique_idx
  on public.camiones (lower(placa));

create index if not exists camiones_marca_idx on public.camiones (marca);
create index if not exists camiones_chofer_idx on public.camiones (chofer_id);
create index if not exists camiones_activo_idx on public.camiones (activo);

-- ------------------------------------------------------------
-- Mantener updated_at al día (reutiliza la función del Módulo 1).
-- ------------------------------------------------------------
drop trigger if exists camiones_set_updated_at on public.camiones;
create trigger camiones_set_updated_at
  before update on public.camiones
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- Seguridad a nivel de fila (RLS).
-- ------------------------------------------------------------
alter table public.camiones enable row level security;

-- El chofer ve solo camiones activos; el administrador ve todos.
drop policy if exists camiones_select_active_or_admin on public.camiones;
create policy camiones_select_active_or_admin
  on public.camiones
  for select
  to authenticated
  using (activo = true or public.is_admin());

-- Solo el administrador escribe (crear, editar, desactivar).
drop policy if exists camiones_insert_admin on public.camiones;
create policy camiones_insert_admin
  on public.camiones
  for insert
  to authenticated
  with check (public.is_admin());

drop policy if exists camiones_update_admin on public.camiones;
create policy camiones_update_admin
  on public.camiones
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists camiones_delete_admin on public.camiones;
create policy camiones_delete_admin
  on public.camiones
  for delete
  to authenticated
  using (public.is_admin());

-- ------------------------------------------------------------
-- Permisos explícitos.
-- ------------------------------------------------------------
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.camiones to authenticated;
grant all on public.camiones to service_role;
