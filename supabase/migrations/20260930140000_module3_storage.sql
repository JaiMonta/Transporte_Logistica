-- ============================================================
-- Módulo 3: Almacenamiento y modo offline
-- Infraestructura reutilizable: evidencias en Storage, registro
-- de archivos y bitácora de sincronización (sync_events).
--
--   * Los buckets son privados y se crean por separado (Storage).
--   * El chofer solo ve y registra sus propios archivos/eventos.
--   * El administrador gestiona todos.
--   * Las URLs firmadas las emite una Edge Function privilegiada.
-- ============================================================

-- ------------------------------------------------------------
-- Tipos enumerados del módulo.
-- ------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where t.typname = 'evidencia_tipo' and n.nspname = 'public'
  ) then
    create type public.evidencia_tipo as enum ('bol', 'firma', 'recibo', 'extra', 'otro');
  end if;
end$$;

do $$
begin
  if not exists (
    select 1 from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where t.typname = 'sync_estado' and n.nspname = 'public'
  ) then
    create type public.sync_estado as enum ('pendiente', 'subiendo', 'fallido', 'completado');
  end if;
end$$;

do $$
begin
  if not exists (
    select 1 from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where t.typname = 'sync_accion' and n.nspname = 'public'
  ) then
    create type public.sync_accion as enum ('crear', 'actualizar', 'eliminar');
  end if;
end$$;

-- ------------------------------------------------------------
-- Registro de archivos subidos a Storage.
-- ------------------------------------------------------------
create table if not exists public.evidencias (
  id           uuid primary key default gen_random_uuid(),
  usuario_id   uuid not null references public.profiles (id) on delete cascade,
  tipo         public.evidencia_tipo not null default 'otro',
  bucket       text not null,
  path         text not null,
  hash_sha256  text,
  tamano_bytes bigint,
  subido_en    timestamptz not null default now(),
  created_at   timestamptz not null default now()
);

create unique index if not exists evidencias_bucket_path_idx
  on public.evidencias (bucket, path);

create index if not exists evidencias_usuario_idx
  on public.evidencias (usuario_id);

comment on table public.evidencias is
  'Archivos (BOL, firmas, recibos, extras) guardados en buckets privados.';

-- ------------------------------------------------------------
-- Bitácora de sincronización (espejo de la cola local).
-- La clave única garantiza idempotencia por evento.
-- ------------------------------------------------------------
create table if not exists public.sync_events (
  id           uuid primary key default gen_random_uuid(),
  usuario_id   uuid not null references public.profiles (id) on delete cascade,
  entidad      text not null,
  entidad_id   text not null,
  accion       public.sync_accion not null,
  payload      jsonb,
  estado       public.sync_estado not null default 'pendiente',
  intentos     integer not null default 0,
  ultimo_error text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create unique index if not exists sync_events_unico_idx
  on public.sync_events (usuario_id, entidad, entidad_id, accion);

create index if not exists sync_events_usuario_estado_idx
  on public.sync_events (usuario_id, estado);

comment on table public.sync_events is
  'Bitácora idempotente de operaciones creadas sin conexión.';

drop trigger if exists sync_events_set_updated_at on public.sync_events;
create trigger sync_events_set_updated_at
  before update on public.sync_events
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- Seguridad a nivel de fila (RLS).
-- ------------------------------------------------------------
alter table public.evidencias enable row level security;
alter table public.sync_events enable row level security;

-- Evidencias: el chofer solo las suyas; el admin todas. Sin DELETE propio.
drop policy if exists evidencias_select_own_or_admin on public.evidencias;
create policy evidencias_select_own_or_admin
  on public.evidencias
  for select
  to authenticated
  using (usuario_id = auth.uid() or public.is_admin());

drop policy if exists evidencias_insert_own_or_admin on public.evidencias;
create policy evidencias_insert_own_or_admin
  on public.evidencias
  for insert
  to authenticated
  with check (usuario_id = auth.uid() or public.is_admin());

drop policy if exists evidencias_update_admin on public.evidencias;
create policy evidencias_update_admin
  on public.evidencias
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists evidencias_delete_admin on public.evidencias;
create policy evidencias_delete_admin
  on public.evidencias
  for delete
  to authenticated
  using (public.is_admin());

-- Eventos de sincronización: el chofer solo los suyos; el admin todos.
drop policy if exists sync_events_select_own_or_admin on public.sync_events;
create policy sync_events_select_own_or_admin
  on public.sync_events
  for select
  to authenticated
  using (usuario_id = auth.uid() or public.is_admin());

drop policy if exists sync_events_insert_own_or_admin on public.sync_events;
create policy sync_events_insert_own_or_admin
  on public.sync_events
  for insert
  to authenticated
  with check (usuario_id = auth.uid() or public.is_admin());

drop policy if exists sync_events_update_own_or_admin on public.sync_events;
create policy sync_events_update_own_or_admin
  on public.sync_events
  for update
  to authenticated
  using (usuario_id = auth.uid() or public.is_admin())
  with check (usuario_id = auth.uid() or public.is_admin());

drop policy if exists sync_events_delete_admin on public.sync_events;
create policy sync_events_delete_admin
  on public.sync_events
  for delete
  to authenticated
  using (public.is_admin());

-- ------------------------------------------------------------
-- Permisos explícitos.
-- ------------------------------------------------------------
grant usage on schema public to authenticated;
grant select, insert, update on public.evidencias to authenticated;
grant select, insert, update on public.sync_events to authenticated;

grant all on public.evidencias to service_role;
grant all on public.sync_events to service_role;
