-- ============================================================
-- Módulo: Facturación semanal
--
-- Agrupa las entregas finalizadas (estado 'entregado') de una semana
-- (lunes a domingo) de TODOS los choferes y manifiestos. Se calcula el
-- flete base por manifiesto (localidad más lejana × capacidad) más los
-- extras aprobados, y se guarda una FACTURA por semana con el detalle
-- por ítem (y desglose por chofer vía usuario_id).
--
--   RLS: solo el administrador ve y gestiona la facturación.
-- ============================================================

do $$
begin
  if not exists (
    select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
    where t.typname = 'factura_estado' and n.nspname = 'public'
  ) then
    create type public.factura_estado as enum ('emitida', 'pendiente', 'cancelada');
  end if;
end$$;

create table if not exists public.facturas (
  id              uuid primary key default gen_random_uuid(),
  periodo_inicio  date not null,
  periodo_fin     date not null,
  subtotal_flete  numeric not null default 0,
  subtotal_extras numeric not null default 0,
  total           numeric not null default 0,
  estado          public.factura_estado not null default 'emitida',
  notas           text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.facturas is
  'Factura semanal (cabecera) que agrupa los manifiestos con entregas finalizadas.';

create unique index if not exists facturas_periodo_unique_idx
  on public.facturas (periodo_inicio, periodo_fin);

drop trigger if exists facturas_set_updated_at on public.facturas;
create trigger facturas_set_updated_at
  before update on public.facturas
  for each row execute function public.set_updated_at();

create table if not exists public.factura_items (
  id            uuid primary key default gen_random_uuid(),
  factura_id    uuid not null references public.facturas (id) on delete cascade,
  manifiesto_id uuid references public.manifiestos (id) on delete set null,
  usuario_id    uuid references public.profiles (id) on delete set null,
  concepto      text not null,
  tipo          public.extra_tipo,
  descripcion   text,
  base          numeric,
  porcentaje    numeric,
  monto         numeric not null default 0,
  orden         integer not null default 0,
  created_at    timestamptz not null default now()
);

comment on table public.factura_items is
  'Detalle por ítem de una factura semanal (flete y extras).';

create index if not exists factura_items_factura_idx
  on public.factura_items (factura_id);
create index if not exists factura_items_usuario_idx
  on public.factura_items (usuario_id);
create index if not exists factura_items_manifiesto_idx
  on public.factura_items (manifiesto_id);

-- ------------------------------------------------------------
-- RLS: solo administrador.
-- ------------------------------------------------------------
alter table public.facturas enable row level security;
alter table public.factura_items enable row level security;

drop policy if exists facturas_admin on public.facturas;
create policy facturas_admin
  on public.facturas
  for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists factura_items_admin on public.factura_items;
create policy factura_items_admin
  on public.factura_items
  for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.facturas to authenticated;
grant select, insert, update, delete on public.factura_items to authenticated;
grant all on public.facturas to service_role;
grant all on public.factura_items to service_role;
