-- ============================================================
-- Módulo: Fletes — Fase 2 (motor de extras)
--
-- Los extras se suman aparte del flete base y se desglosan por ítem:
--   caleta (2 por manifiesto), reparto (1 por cliente; grupo <=10 km = 1),
--   desvío (otra localidad: tramos 6/12 USD o 20% del flete), retorno
--   (devolución 15% o 60%), mora, fin de semana (5%) y picking fijo.
--
--   El chofer AVISA (devolución/mora) y el administrador registra/aprueba.
-- ============================================================

do $$
begin
  if not exists (
    select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
    where t.typname = 'extra_tipo' and n.nspname = 'public'
  ) then
    create type public.extra_tipo as enum
      ('caleta', 'reparto', 'desvio', 'retorno', 'mora', 'fin_semana', 'picking');
  end if;
  if not exists (
    select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
    where t.typname = 'extra_estado' and n.nspname = 'public'
  ) then
    create type public.extra_estado as enum ('sugerido', 'aprobado', 'rechazado');
  end if;
end$$;

create table if not exists public.manifiesto_extras (
  id            uuid primary key default gen_random_uuid(),
  manifiesto_id uuid not null references public.manifiestos (id) on delete cascade,
  tipo          public.extra_tipo not null,
  descripcion   text,
  base          numeric,
  monto         numeric not null default 0,
  porcentaje    numeric,
  estado        public.extra_estado not null default 'sugerido',
  origen        text,
  aprobado_por  uuid references public.profiles (id) on delete set null,
  aprobado_en   timestamptz,
  notas         text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.manifiesto_extras is
  'Extras de un manifiesto (caleta, reparto, desvío, retorno, mora, fin de semana, picking).';

create index if not exists manifiesto_extras_manifiesto_idx
  on public.manifiesto_extras (manifiesto_id);

drop trigger if exists manifiesto_extras_set_updated_at on public.manifiesto_extras;
create trigger manifiesto_extras_set_updated_at
  before update on public.manifiesto_extras
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- Campos auxiliares.
-- ------------------------------------------------------------
alter table public.manifiestos
  add column if not exists es_fin_semana boolean not null default false;

alter table public.entregas
  add column if not exists es_otra_localidad boolean not null default false;

-- ------------------------------------------------------------
-- Parámetros configurables.
-- ------------------------------------------------------------
insert into public.configuracion (clave, valor, descripcion) values
  ('extra_radio_reparto_km', '10', 'Radio (km) para agrupar clientes en un mismo reparto.'),
  ('desvio_usd_hasta_3t', '6', 'Desvío en USD para camiones de hasta 3 t.'),
  ('desvio_usd_hasta_6t', '12', 'Desvío en USD para camiones de más de 3 t y hasta 6 t.'),
  ('desvio_pct_mayor_6t', '20', 'Desvío en % del flete base para camiones de más de 6 t.'),
  ('retorno_pct_parcial', '15', 'Retorno parcial (<=20% de capacidad) como % del flete.'),
  ('retorno_pct_completa', '60', 'Retorno por devolución completa como % del flete.'),
  ('fin_semana_pct', '5', 'Recargo por servicio en fin de semana (% del flete).'),
  ('picking_usd', '119', 'Flete del picking entre plantas (USD).')
on conflict (clave) do nothing;

-- ------------------------------------------------------------
-- RLS.
-- ------------------------------------------------------------
alter table public.manifiesto_extras enable row level security;

drop policy if exists manifiesto_extras_select on public.manifiesto_extras;
create policy manifiesto_extras_select
  on public.manifiesto_extras
  for select
  to authenticated
  using (
    public.is_admin()
    or exists (
      select 1 from public.manifiestos m
      where m.id = manifiesto_id and m.capturado_por = auth.uid()
    )
  );

drop policy if exists manifiesto_extras_insert on public.manifiesto_extras;
create policy manifiesto_extras_insert
  on public.manifiesto_extras
  for insert
  to authenticated
  with check (
    public.is_admin()
    or exists (
      select 1 from public.manifiestos m
      where m.id = manifiesto_id and m.capturado_por = auth.uid()
    )
  );

drop policy if exists manifiesto_extras_update on public.manifiesto_extras;
create policy manifiesto_extras_update
  on public.manifiesto_extras
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists manifiesto_extras_delete_admin on public.manifiesto_extras;
create policy manifiesto_extras_delete_admin
  on public.manifiesto_extras
  for delete
  to authenticated
  using (public.is_admin());

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.manifiesto_extras to authenticated;
grant all on public.manifiesto_extras to service_role;
