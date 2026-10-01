-- ============================================================
-- Módulo 5: Entregas + ubicaciones GPS
--
--   * Una entrega por cada línea del manifiesto (cliente/sucursal).
--   * El chofer marca "Entregado" (foto del recibo opcional + hora del
--     servidor) y avanza.
--   * El GPS reporta posiciones (en primer plano, cada 20 min).
--
--   RLS: el chofer solo ve/actualiza las entregas de sus manifiestos y sus
--   propias ubicaciones; el administrador ve y gestiona todo.
-- ============================================================

-- Estado de una entrega.
do $$
begin
  if not exists (
    select 1 from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where t.typname = 'entrega_estado' and n.nspname = 'public'
  ) then
    create type public.entrega_estado as enum ('pendiente', 'entregado', 'fallido');
  end if;
end$$;

-- ------------------------------------------------------------
-- Entregas.
-- ------------------------------------------------------------
create table if not exists public.entregas (
  id            uuid primary key default gen_random_uuid(),
  manifiesto_id uuid not null references public.manifiestos (id) on delete cascade,
  linea_id      uuid references public.manifiesto_lineas (id) on delete cascade,
  cliente_id    uuid references public.clientes (id) on delete set null,
  cliente_texto text,
  direccion     text,
  lat           double precision,
  lng           double precision,
  orden         integer not null default 0,
  estado        public.entrega_estado not null default 'pendiente',
  bucket        text,
  path          text,
  hash_sha256   text,
  entregado_en  timestamptz,
  entregado_por uuid references public.profiles (id) on delete set null,
  notas         text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.entregas is
  'Entregas por cliente/sucursal de un manifiesto (foto del recibo opcional).';

create index if not exists entregas_manifiesto_idx on public.entregas (manifiesto_id);
create index if not exists entregas_estado_idx on public.entregas (estado);
create index if not exists entregas_entregado_por_idx on public.entregas (entregado_por);

-- ------------------------------------------------------------
-- Ubicaciones GPS.
-- ------------------------------------------------------------
create table if not exists public.ubicaciones_gps (
  id            bigint generated always as identity primary key,
  usuario_id    uuid not null references public.profiles (id) on delete cascade,
  manifiesto_id uuid references public.manifiestos (id) on delete set null,
  lat           double precision not null,
  lng           double precision not null,
  precision     double precision,
  capturado_en  timestamptz not null default now(),
  created_at    timestamptz not null default now()
);

comment on table public.ubicaciones_gps is
  'Posiciones GPS reportadas por los choferes durante el recorrido.';

create index if not exists ubicaciones_gps_usuario_idx
  on public.ubicaciones_gps (usuario_id, capturado_en desc);

-- ------------------------------------------------------------
-- updated_at (reutiliza la función del Módulo 1).
-- ------------------------------------------------------------
drop trigger if exists entregas_set_updated_at on public.entregas;
create trigger entregas_set_updated_at
  before update on public.entregas
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- RLS.
-- ------------------------------------------------------------
alter table public.entregas enable row level security;
alter table public.ubicaciones_gps enable row level security;

-- Entregas: visibles si el manifiesto es del chofer o si es admin.
drop policy if exists entregas_select on public.entregas;
create policy entregas_select
  on public.entregas
  for select
  to authenticated
  using (
    public.is_admin()
    or exists (
      select 1 from public.manifiestos m
      where m.id = manifiesto_id and m.capturado_por = auth.uid()
    )
  );

drop policy if exists entregas_insert on public.entregas;
create policy entregas_insert
  on public.entregas
  for insert
  to authenticated
  with check (
    public.is_admin()
    or exists (
      select 1 from public.manifiestos m
      where m.id = manifiesto_id and m.capturado_por = auth.uid()
    )
  );

-- El chofer puede actualizar el estado de sus entregas; el admin todas.
drop policy if exists entregas_update on public.entregas;
create policy entregas_update
  on public.entregas
  for update
  to authenticated
  using (
    public.is_admin()
    or exists (
      select 1 from public.manifiestos m
      where m.id = manifiesto_id and m.capturado_por = auth.uid()
    )
  )
  with check (
    public.is_admin()
    or exists (
      select 1 from public.manifiestos m
      where m.id = manifiesto_id and m.capturado_por = auth.uid()
    )
  );

drop policy if exists entregas_delete_admin on public.entregas;
create policy entregas_delete_admin
  on public.entregas
  for delete
  to authenticated
  using (public.is_admin());

-- Ubicaciones GPS: el chofer inserta/lee las suyas; el admin todas.
drop policy if exists ubicaciones_gps_insert_own on public.ubicaciones_gps;
create policy ubicaciones_gps_insert_own
  on public.ubicaciones_gps
  for insert
  to authenticated
  with check (usuario_id = auth.uid());

drop policy if exists ubicaciones_gps_select_own_or_admin on public.ubicaciones_gps;
create policy ubicaciones_gps_select_own_or_admin
  on public.ubicaciones_gps
  for select
  to authenticated
  using (usuario_id = auth.uid() or public.is_admin());

drop policy if exists ubicaciones_gps_delete_admin on public.ubicaciones_gps;
create policy ubicaciones_gps_delete_admin
  on public.ubicaciones_gps
  for delete
  to authenticated
  using (public.is_admin());

-- ------------------------------------------------------------
-- Permisos.
-- ------------------------------------------------------------
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.entregas to authenticated;
grant select, insert, update, delete on public.ubicaciones_gps to authenticated;
grant all on public.entregas to service_role;
grant all on public.ubicaciones_gps to service_role;
