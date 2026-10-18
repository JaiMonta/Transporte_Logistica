-- ============================================================
-- Facturación por empresa (prorrateo por producto)
--
-- Evoluciona la facturación semanal hacia facturas POR EMPRESA
-- (empresa facturada), prorrateando el flete base y los extras por
-- el peso de cada producto del manifiesto.
--
--   * `empresas`: catálogo de empresas facturadas.
--   * `productos`: catálogo de productos (varios por empresa).
--   * `manifiesto_pesos`: kg por producto y manifiesto.
--   * `facturas` gana `empresa_id`; `factura_items` gana `producto_id`.
--   * `configuracion.tasa_usd_bs`: tasa opcional USD -> Bs.
--
--   RLS: los catálogos los gestiona el administrador (lectura autenticada);
--   los pesos los escribe el administrador; las facturas son solo admin.
-- ============================================================

-- ------------------------------------------------------------
-- Empresas facturadas.
-- ------------------------------------------------------------
create table if not exists public.empresas (
  id         uuid primary key default gen_random_uuid(),
  nombre     text not null,
  rif        text,
  activo     boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.empresas is
  'Catálogo de empresas facturadas (baja lógica con activo).';

create unique index if not exists empresas_nombre_unique_idx
  on public.empresas (lower(nombre));

drop trigger if exists empresas_set_updated_at on public.empresas;
create trigger empresas_set_updated_at
  before update on public.empresas
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- Productos (varios por empresa).
-- ------------------------------------------------------------
create table if not exists public.productos (
  id         uuid primary key default gen_random_uuid(),
  nombre     text not null,
  empresa_id uuid references public.empresas (id) on delete set null,
  orden      integer not null default 0,
  activo     boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.productos is
  'Catálogo de productos; cada producto pertenece a una empresa facturada.';

create unique index if not exists productos_nombre_unique_idx
  on public.productos (lower(nombre));
create index if not exists productos_empresa_idx on public.productos (empresa_id);

drop trigger if exists productos_set_updated_at on public.productos;
create trigger productos_set_updated_at
  before update on public.productos
  for each row execute function public.set_updated_at();

-- Semilla genérica de productos (sin empresa; la asigna el administrador).
insert into public.productos (nombre, orden)
select v.nombre, v.orden
from (values ('Pasta', 0), ('Confite', 1), ('Harina', 2)) as v(nombre, orden)
where not exists (
  select 1 from public.productos p where lower(p.nombre) = lower(v.nombre)
);

-- ------------------------------------------------------------
-- Pesos por manifiesto y producto.
-- ------------------------------------------------------------
create table if not exists public.manifiesto_pesos (
  id            uuid primary key default gen_random_uuid(),
  manifiesto_id uuid not null references public.manifiestos (id) on delete cascade,
  producto_id   uuid not null references public.productos (id) on delete cascade,
  kg            numeric not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.manifiesto_pesos is
  'Peso (kg) por producto de un manifiesto, para el prorrateo del flete.';

create unique index if not exists manifiesto_pesos_unique_idx
  on public.manifiesto_pesos (manifiesto_id, producto_id);

drop trigger if exists manifiesto_pesos_set_updated_at on public.manifiesto_pesos;
create trigger manifiesto_pesos_set_updated_at
  before update on public.manifiesto_pesos
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- Evolución de la facturación.
-- ------------------------------------------------------------
alter table public.facturas
  add column if not exists empresa_id uuid references public.empresas (id) on delete set null;

comment on column public.facturas.empresa_id is
  'Empresa facturada de esta factura (una factura por empresa y período).';

drop index if exists facturas_periodo_unique_idx;
create unique index if not exists facturas_periodo_empresa_unique_idx
  on public.facturas (periodo_inicio, periodo_fin, empresa_id);

alter table public.factura_items
  add column if not exists producto_id uuid references public.productos (id) on delete set null;

comment on column public.factura_items.producto_id is
  'Producto al que corresponde el ítem (tras el prorrateo por peso).';

create index if not exists factura_items_producto_idx
  on public.factura_items (producto_id);

-- ------------------------------------------------------------
-- Tasa de conversión USD -> Bs (opcional).
-- ------------------------------------------------------------
insert into public.configuracion (clave, valor, descripcion)
values ('tasa_usd_bs', '0', 'Tasa USD->Bs para mostrar equivalencias en la facturación')
on conflict (clave) do nothing;

-- ------------------------------------------------------------
-- RLS.
-- ------------------------------------------------------------
alter table public.empresas enable row level security;
alter table public.productos enable row level security;
alter table public.manifiesto_pesos enable row level security;

-- Empresas: lectura autenticada; escritura solo admin.
drop policy if exists empresas_select on public.empresas;
create policy empresas_select
  on public.empresas
  for select
  to authenticated
  using (activo = true or public.is_admin());

drop policy if exists empresas_insert_admin on public.empresas;
create policy empresas_insert_admin
  on public.empresas
  for insert
  to authenticated
  with check (public.is_admin());

drop policy if exists empresas_update_admin on public.empresas;
create policy empresas_update_admin
  on public.empresas
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists empresas_delete_admin on public.empresas;
create policy empresas_delete_admin
  on public.empresas
  for delete
  to authenticated
  using (public.is_admin());

-- Productos: misma política.
drop policy if exists productos_select on public.productos;
create policy productos_select
  on public.productos
  for select
  to authenticated
  using (activo = true or public.is_admin());

drop policy if exists productos_insert_admin on public.productos;
create policy productos_insert_admin
  on public.productos
  for insert
  to authenticated
  with check (public.is_admin());

drop policy if exists productos_update_admin on public.productos;
create policy productos_update_admin
  on public.productos
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists productos_delete_admin on public.productos;
create policy productos_delete_admin
  on public.productos
  for delete
  to authenticated
  using (public.is_admin());

-- Pesos: el chofer lee los de sus manifiestos; el admin todo.
drop policy if exists manifiesto_pesos_select on public.manifiesto_pesos;
create policy manifiesto_pesos_select
  on public.manifiesto_pesos
  for select
  to authenticated
  using (
    public.is_admin()
    or exists (
      select 1 from public.manifiestos m
      where m.id = manifiesto_id and m.capturado_por = auth.uid()
    )
  );

drop policy if exists manifiesto_pesos_insert_admin on public.manifiesto_pesos;
create policy manifiesto_pesos_insert_admin
  on public.manifiesto_pesos
  for insert
  to authenticated
  with check (public.is_admin());

drop policy if exists manifiesto_pesos_update_admin on public.manifiesto_pesos;
create policy manifiesto_pesos_update_admin
  on public.manifiesto_pesos
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists manifiesto_pesos_delete_admin on public.manifiesto_pesos;
create policy manifiesto_pesos_delete_admin
  on public.manifiesto_pesos
  for delete
  to authenticated
  using (public.is_admin());

-- ------------------------------------------------------------
-- Permisos.
-- ------------------------------------------------------------
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.empresas to authenticated;
grant select, insert, update, delete on public.productos to authenticated;
grant select, insert, update, delete on public.manifiesto_pesos to authenticated;
grant all on public.empresas to service_role;
grant all on public.productos to service_role;
grant all on public.manifiesto_pesos to service_role;
