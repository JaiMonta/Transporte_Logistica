-- ============================================================
-- Módulo 4: Manifiestos
-- Registro documental de manifiestos (foto del BOL + OCR).
--   * El chofer captura y ve solo los suyos.
--   * El administrador ve y gestiona todos.
--   * PRO único por cliente y fecha.
-- ============================================================

-- Estado del cotejo documental (revisión humana del OCR).
do $$
begin
  if not exists (
    select 1 from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where t.typname = 'cotejo_estado' and n.nspname = 'public'
  ) then
    create type public.cotejo_estado as enum ('pendiente', 'ok', 'revision');
  end if;
end$$;

create table if not exists public.manifiestos (
  id            uuid primary key default gen_random_uuid(),
  numero_pro    text not null,
  cliente_id    uuid references public.clientes (id) on delete set null,
  fecha         date not null,
  capturado_por uuid not null references public.profiles (id) on delete cascade,
  bucket        text,
  path          text,
  hash_sha256   text,
  ocr_pro       text,
  ocr_confianza numeric,
  cotejo        public.cotejo_estado not null default 'pendiente',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.manifiestos is
  'Manifiestos capturados en campo (foto del BOL y datos extraídos).';

-- Número PRO único por cliente y fecha (comparación sin distinguir
-- mayúsculas). NULLS NOT DISTINCT hace que dos registros con cliente
-- nulo también cuenten como repetidos (Postgres 15+).
create unique index if not exists manifiestos_pro_cliente_fecha_idx
  on public.manifiestos (lower(numero_pro), cliente_id, fecha) nulls not distinct
  where numero_pro is not null;

-- Índices de consulta.
create index if not exists manifiestos_fecha_idx on public.manifiestos (fecha);
create index if not exists manifiestos_cliente_idx on public.manifiestos (cliente_id);
create index if not exists manifiestos_capturado_por_idx
  on public.manifiestos (capturado_por);

-- ------------------------------------------------------------
-- Mantener updated_at al día (reutiliza la función del Módulo 1).
-- ------------------------------------------------------------
drop trigger if exists manifiestos_set_updated_at on public.manifiestos;
create trigger manifiestos_set_updated_at
  before update on public.manifiestos
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- Seguridad a nivel de fila (RLS).
-- ------------------------------------------------------------
alter table public.manifiestos enable row level security;

-- El chofer ve solo los suyos; el administrador ve todos.
drop policy if exists manifiestos_select_own_or_admin on public.manifiestos;
create policy manifiestos_select_own_or_admin
  on public.manifiestos
  for select
  to authenticated
  using (capturado_por = auth.uid() or public.is_admin());

-- El chofer crea manifiestos a su nombre.
drop policy if exists manifiestos_insert_own on public.manifiestos;
create policy manifiestos_insert_own
  on public.manifiestos
  for insert
  to authenticated
  with check (capturado_por = auth.uid());

-- Solo el administrador edita o elimina.
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

-- ------------------------------------------------------------
-- Permisos explícitos.
-- ------------------------------------------------------------
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.manifiestos to authenticated;
grant all on public.manifiestos to service_role;
