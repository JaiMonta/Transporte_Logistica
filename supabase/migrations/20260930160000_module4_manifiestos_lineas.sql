-- ============================================================
-- Módulo 4: Manifiestos — v2 (cabecera + líneas)
--
-- Un manifiesto (o Guía de Carga) tiene una cabecera (foto del BOL,
-- capturista, fecha única) y N líneas de documentos (PRO o FACTURA),
-- cada una con su número y cliente (de catálogo o texto libre).
--
--   * El chofer captura y ve solo los suyos.
--   * El administrador ve y gestiona todos.
--   * La unicidad de documento (tipo + número + fecha) se valida en la app.
-- ============================================================

-- Tipo de documento de cada línea.
do $$
begin
  if not exists (
    select 1 from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where t.typname = 'documento_tipo' and n.nspname = 'public'
  ) then
    create type public.documento_tipo as enum ('pro', 'factura');
  end if;
end$$;

-- ------------------------------------------------------------
-- Recrear la cabecera. La tabla está vacía (esquema limpio).
-- ------------------------------------------------------------
drop table if exists public.manifiesto_lineas cascade;
drop table if exists public.manifiestos cascade;

create table public.manifiestos (
  id            uuid primary key default gen_random_uuid(),
  fecha         date not null,
  capturado_por uuid not null references public.profiles (id) on delete cascade,
  bucket        text,
  path          text,
  hash_sha256   text,
  ocr_confianza numeric,
  cotejo        public.cotejo_estado not null default 'pendiente',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.manifiestos is
  'Cabecera del manifiesto/guía de carga (foto del BOL y datos generales).';

-- ------------------------------------------------------------
-- Líneas de documento (sin límite de cantidad).
-- ------------------------------------------------------------
create table public.manifiesto_lineas (
  id            uuid primary key default gen_random_uuid(),
  manifiesto_id uuid not null references public.manifiestos (id) on delete cascade,
  tipo          public.documento_tipo not null default 'pro',
  numero        text not null,
  cliente_id    uuid references public.clientes (id) on delete set null,
  cliente_texto text,
  orden         integer not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.manifiesto_lineas is
  'Documentos (PRO o factura) que componen un manifiesto.';

create index if not exists manifiesto_lineas_manifiesto_idx
  on public.manifiesto_lineas (manifiesto_id);
create index if not exists manifiesto_lineas_numero_idx
  on public.manifiesto_lineas (lower(numero));
create index if not exists manifiesto_lineas_cliente_idx
  on public.manifiesto_lineas (cliente_id);

create index if not exists manifiestos_fecha_idx on public.manifiestos (fecha);
create index if not exists manifiestos_capturado_por_idx
  on public.manifiestos (capturado_por);

-- ------------------------------------------------------------
-- updated_at (reutiliza la función del Módulo 1).
-- ------------------------------------------------------------
drop trigger if exists manifiestos_set_updated_at on public.manifiestos;
create trigger manifiestos_set_updated_at
  before update on public.manifiestos
  for each row execute function public.set_updated_at();

drop trigger if exists manifiesto_lineas_set_updated_at on public.manifiesto_lineas;
create trigger manifiesto_lineas_set_updated_at
  before update on public.manifiesto_lineas
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- RLS.
-- ------------------------------------------------------------
alter table public.manifiestos enable row level security;
alter table public.manifiesto_lineas enable row level security;

-- Cabecera: el chofer ve/crea las suyas; el admin todo.
drop policy if exists manifiestos_select_own_or_admin on public.manifiestos;
create policy manifiestos_select_own_or_admin
  on public.manifiestos
  for select
  to authenticated
  using (capturado_por = auth.uid() or public.is_admin());

drop policy if exists manifiestos_insert_own on public.manifiestos;
create policy manifiestos_insert_own
  on public.manifiestos
  for insert
  to authenticated
  with check (capturado_por = auth.uid());

drop policy if exists manifiestos_update_admin on public.manifiestos;
create policy manifiestos_update_admin
  on public.manifiestos
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists manifiestos_delete_admin on public.manifiestos;
create policy manifiestos_delete_admin
  on public.manifiestos
  for delete
  to authenticated
  using (public.is_admin());

-- Líneas: visibles/creables si el manifiesto es del chofer o admin.
drop policy if exists manifiesto_lineas_select on public.manifiesto_lineas;
create policy manifiesto_lineas_select
  on public.manifiesto_lineas
  for select
  to authenticated
  using (
    public.is_admin()
    or exists (
      select 1 from public.manifiestos m
      where m.id = manifiesto_id and m.capturado_por = auth.uid()
    )
  );

drop policy if exists manifiesto_lineas_insert on public.manifiesto_lineas;
create policy manifiesto_lineas_insert
  on public.manifiesto_lineas
  for insert
  to authenticated
  with check (
    public.is_admin()
    or exists (
      select 1 from public.manifiestos m
      where m.id = manifiesto_id and m.capturado_por = auth.uid()
    )
  );

drop policy if exists manifiesto_lineas_update_admin on public.manifiesto_lineas;
create policy manifiesto_lineas_update_admin
  on public.manifiesto_lineas
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists manifiesto_lineas_delete_admin on public.manifiesto_lineas;
create policy manifiesto_lineas_delete_admin
  on public.manifiesto_lineas
  for delete
  to authenticated
  using (public.is_admin());

-- ------------------------------------------------------------
-- Permisos.
-- ------------------------------------------------------------
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.manifiestos to authenticated;
grant select, insert, update, delete on public.manifiesto_lineas to authenticated;
grant all on public.manifiestos to service_role;
grant all on public.manifiesto_lineas to service_role;
