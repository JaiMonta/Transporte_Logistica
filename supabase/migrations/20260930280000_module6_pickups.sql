-- ============================================================
-- Módulo 6: Pickups (asignación por admin y aviso "En camino").
--
--   * El administrador crea y asigna pickups (chofer, cliente, hora estimada).
--   * El chofer ve los suyos y marca "En camino" / "Completado"; la hora la
--     registra el servidor (trigger), no el teléfono.
--   * Notificación in-app por Realtime (la tabla se añade a la publicación).
--
--   RLS: el chofer solo ve/actualiza los suyos; el administrador gestiona todo.
-- ============================================================

-- Estado de un pickup.
do $$
begin
  if not exists (
    select 1 from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where t.typname = 'pickup_estado' and n.nspname = 'public'
  ) then
    create type public.pickup_estado as enum
      ('pendiente', 'en_camino', 'completado', 'cancelado');
  end if;
end$$;

-- ------------------------------------------------------------
-- Pickups.
-- ------------------------------------------------------------
create table if not exists public.pickups (
  id             uuid primary key default gen_random_uuid(),
  chofer_id      uuid not null references public.profiles (id) on delete restrict,
  cliente_id     uuid references public.clientes (id) on delete set null,
  cliente_texto  text,
  direccion      text,
  lat            double precision,
  lng            double precision,
  camion_id      uuid references public.camiones (id) on delete set null,
  fecha_estimada date,
  hora_estimada  time,
  notas          text,
  estado         public.pickup_estado not null default 'pendiente',
  asignado_por   uuid default auth.uid(),
  asignado_en    timestamptz not null default now(),
  en_camino_en   timestamptz,
  completado_en  timestamptz,
  cancelado_en   timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

comment on table public.pickups is
  'Pickups asignados por el administrador a un chofer, con hora estimada y aviso "En camino".';

create index if not exists pickups_chofer_idx on public.pickups (chofer_id);
create index if not exists pickups_estado_idx on public.pickups (estado);
create index if not exists pickups_fecha_idx on public.pickups (fecha_estimada);

-- ------------------------------------------------------------
-- updated_at (reutiliza la función del Módulo 1).
-- ------------------------------------------------------------
drop trigger if exists pickups_set_updated_at on public.pickups;
create trigger pickups_set_updated_at
  before update on public.pickups
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- Horas del servidor según el estado (no las pone el teléfono).
-- ------------------------------------------------------------
create or replace function public.pickups_marcar_tiempos()
returns trigger
language plpgsql
as $$
begin
  if new.estado is distinct from old.estado then
    if new.estado = 'en_camino' then
      new.en_camino_en := now();
    elsif new.estado = 'completado' then
      new.completado_en := now();
    elsif new.estado = 'cancelado' then
      new.cancelado_en := now();
    end if;
  end if;
  return new;
end$$;

drop trigger if exists pickups_tiempos_servidor on public.pickups;
create trigger pickups_tiempos_servidor
  before update on public.pickups
  for each row execute function public.pickups_marcar_tiempos();

-- ------------------------------------------------------------
-- Protección de campos: el chofer solo cambia el estado.
-- ------------------------------------------------------------
create or replace function public.pickups_proteger_campos()
returns trigger
language plpgsql
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  -- El chofer no puede reasignar ni editar los datos del pickup.
  new.chofer_id      := old.chofer_id;
  new.cliente_id     := old.cliente_id;
  new.cliente_texto  := old.cliente_texto;
  new.direccion      := old.direccion;
  new.lat            := old.lat;
  new.lng            := old.lng;
  new.camion_id      := old.camion_id;
  new.fecha_estimada := old.fecha_estimada;
  new.hora_estimada  := old.hora_estimada;
  new.notas          := old.notas;
  new.asignado_por   := old.asignado_por;
  new.asignado_en    := old.asignado_en;

  -- Solo transiciones permitidas: pendiente -> en_camino -> completado/cancelado.
  if new.estado is distinct from old.estado and not (
      (old.estado = 'pendiente' and new.estado in ('en_camino', 'completado', 'cancelado'))
   or (old.estado = 'en_camino' and new.estado in ('completado', 'cancelado'))
  ) then
    raise exception 'Transición de estado no permitida para el chofer.';
  end if;

  return new;
end$$;

drop trigger if exists pickups_proteger_campos_trg on public.pickups;
create trigger pickups_proteger_campos_trg
  before update on public.pickups
  for each row execute function public.pickups_proteger_campos();

-- ------------------------------------------------------------
-- Seguridad a nivel de fila (RLS).
-- ------------------------------------------------------------
alter table public.pickups enable row level security;

-- El chofer ve los suyos; el administrador todos.
drop policy if exists pickups_select on public.pickups;
create policy pickups_select
  on public.pickups
  for select
  to authenticated
  using (public.is_admin() or chofer_id = auth.uid());

-- Solo el administrador crea/asigna.
drop policy if exists pickups_insert_admin on public.pickups;
create policy pickups_insert_admin
  on public.pickups
  for insert
  to authenticated
  with check (public.is_admin());

-- El chofer actualiza los suyos (solo el estado, por el trigger); el admin todo.
drop policy if exists pickups_update on public.pickups;
create policy pickups_update
  on public.pickups
  for update
  to authenticated
  using (public.is_admin() or chofer_id = auth.uid())
  with check (public.is_admin() or chofer_id = auth.uid());

drop policy if exists pickups_delete_admin on public.pickups;
create policy pickups_delete_admin
  on public.pickups
  for delete
  to authenticated
  using (public.is_admin());

-- ------------------------------------------------------------
-- Permisos.
-- ------------------------------------------------------------
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.pickups to authenticated;
grant all on public.pickups to service_role;

-- ------------------------------------------------------------
-- Realtime (notificaciones in-app).
-- ------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'pickups'
  ) then
    alter publication supabase_realtime add table public.pickups;
  end if;
end$$;
