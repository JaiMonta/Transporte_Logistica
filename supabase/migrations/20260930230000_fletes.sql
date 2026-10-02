-- ============================================================
-- Módulo: Fletes
-- Fase 1: tabulador de fletes (precio por localidad y capacidad) y
-- reglas de extras (referencia). El motor de extras será la Fase 2.
--
--   * El precio del flete de un manifiesto depende de la localidad más
--     lejana (destino) y de la capacidad (tier) del camión.
--   * Los precios están en USD.
--
--   RLS: el catálogo lo lee cualquier autenticado; solo el admin escribe.
-- ============================================================

-- ------------------------------------------------------------
-- Tabulador de fletes (una fila por localidad).
-- ------------------------------------------------------------
create table if not exists public.fletes_tabulador (
  id           uuid primary key default gen_random_uuid(),
  region       text,
  localidad    text not null,
  km           numeric,
  precio_1_2   numeric,
  precio_2_5   numeric,
  precio_3_5   numeric,
  precio_5     numeric,
  precio_6     numeric,
  precio_7_5   numeric,
  precio_10    numeric,
  precio_12    numeric,
  precio_15    numeric,
  precio_30    numeric,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.fletes_tabulador is
  'Tabulador de fletes USD por localidad y capacidad (tier) del camión.';

create unique index if not exists fletes_tabulador_localidad_unique_idx
  on public.fletes_tabulador (localidad);
create index if not exists fletes_tabulador_region_idx
  on public.fletes_tabulador (region);

drop trigger if exists fletes_tabulador_set_updated_at on public.fletes_tabulador;
create trigger fletes_tabulador_set_updated_at
  before update on public.fletes_tabulador
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- Reglas de extras (referencia; el cálculo es la Fase 2).
-- ------------------------------------------------------------
create table if not exists public.fletes_extras (
  id           uuid primary key default gen_random_uuid(),
  capacidad_t  numeric not null,
  caleta       numeric,
  mora         text,
  reparto      text,
  desvio       text,
  fin_semana   text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.fletes_extras is
  'Parámetros de extras por capacidad (caleta, mora, reparto, desvío, fin de semana).';

create unique index if not exists fletes_extras_capacidad_unique_idx
  on public.fletes_extras (capacidad_t);

drop trigger if exists fletes_extras_set_updated_at on public.fletes_extras;
create trigger fletes_extras_set_updated_at
  before update on public.fletes_extras
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- Enlace del manifiesto con la localidad del tabulador.
-- ------------------------------------------------------------
alter table public.manifiestos
  add column if not exists fletes_tabulador_id uuid
    references public.fletes_tabulador (id) on delete set null;

comment on column public.manifiestos.fletes_tabulador_id is
  'Localidad del tabulador usada para calcular el costo de flete.';

-- ------------------------------------------------------------
-- RLS.
-- ------------------------------------------------------------
alter table public.fletes_tabulador enable row level security;
alter table public.fletes_extras enable row level security;

drop policy if exists fletes_tabulador_select on public.fletes_tabulador;
create policy fletes_tabulador_select
  on public.fletes_tabulador
  for select
  to authenticated
  using (true);

drop policy if exists fletes_tabulador_write_admin on public.fletes_tabulador;
create policy fletes_tabulador_write_admin
  on public.fletes_tabulador
  for insert
  to authenticated
  with check (public.is_admin());

drop policy if exists fletes_tabulador_update_admin on public.fletes_tabulador;
create policy fletes_tabulador_update_admin
  on public.fletes_tabulador
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists fletes_tabulador_delete_admin on public.fletes_tabulador;
create policy fletes_tabulador_delete_admin
  on public.fletes_tabulador
  for delete
  to authenticated
  using (public.is_admin());

drop policy if exists fletes_extras_select on public.fletes_extras;
create policy fletes_extras_select
  on public.fletes_extras
  for select
  to authenticated
  using (true);

drop policy if exists fletes_extras_write_admin on public.fletes_extras;
create policy fletes_extras_write_admin
  on public.fletes_extras
  for insert
  to authenticated
  with check (public.is_admin());

drop policy if exists fletes_extras_update_admin on public.fletes_extras;
create policy fletes_extras_update_admin
  on public.fletes_extras
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists fletes_extras_delete_admin on public.fletes_extras;
create policy fletes_extras_delete_admin
  on public.fletes_extras
  for delete
  to authenticated
  using (public.is_admin());

-- ------------------------------------------------------------
-- Permisos.
-- ------------------------------------------------------------
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.fletes_tabulador to authenticated;
grant select, insert, update, delete on public.fletes_extras to authenticated;
grant all on public.fletes_tabulador to service_role;
grant all on public.fletes_extras to service_role;
