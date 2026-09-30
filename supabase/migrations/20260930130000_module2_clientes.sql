-- ============================================================
-- Módulo 2: Clientes
-- Catálogo de clientes con baja lógica y geolocalización.
--   * El administrador crea, edita y desactiva.
--   * El chofer solo lee los clientes activos.
-- ============================================================

create table if not exists public.clientes (
  id              uuid primary key default gen_random_uuid(),
  nombre          text not null,
  nombre_contacto text,
  telefono        text,
  email           text,
  direccion       text,
  lat             double precision,
  lng             double precision,
  activo          boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.clientes is 'Catálogo de clientes (baja lógica con activo).';

-- El correo debe ser único (comparación sin distinguir mayúsculas).
create unique index if not exists clientes_email_unique_idx
  on public.clientes (lower(email))
  where email is not null;

-- Búsqueda por nombre.
create index if not exists clientes_nombre_idx
  on public.clientes (nombre);

-- ------------------------------------------------------------
-- Mantener updated_at al día (reutiliza la función del Módulo 1).
-- ------------------------------------------------------------
drop trigger if exists clientes_set_updated_at on public.clientes;
create trigger clientes_set_updated_at
  before update on public.clientes
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- Seguridad a nivel de fila (RLS).
-- ------------------------------------------------------------
alter table public.clientes enable row level security;

-- El chofer ve solo clientes activos; el administrador ve todos.
drop policy if exists clientes_select_active_or_admin on public.clientes;
create policy clientes_select_active_or_admin
  on public.clientes
  for select
  to authenticated
  using (activo = true or public.is_admin());

-- Solo el administrador escribe (crear, editar, desactivar).
drop policy if exists clientes_insert_admin on public.clientes;
create policy clientes_insert_admin
  on public.clientes
  for insert
  to authenticated
  with check (public.is_admin());

drop policy if exists clientes_update_admin on public.clientes;
create policy clientes_update_admin
  on public.clientes
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists clientes_delete_admin on public.clientes;
create policy clientes_delete_admin
  on public.clientes
  for delete
  to authenticated
  using (public.is_admin());

-- ------------------------------------------------------------
-- Permisos explícitos.
-- ------------------------------------------------------------
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.clientes to authenticated;
grant all on public.clientes to service_role;
