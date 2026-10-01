-- ============================================================
-- Módulo: Consumo de combustible
--
--   * Al capturar el manifiesto el chofer registra los litros iniciales
--     del tanque (opcionalmente el odómetro). Eso inicia la jornada.
--   * Durante el recorrido puede registrar N recargas (litros + monto/foto).
--   * Al cerrar la jornada registra los litros finales.
--   * El administrador valida o corrige las cantidades inicial/final.
--
--   km y consumo se calculan en la app (Haversine + rendimiento).
--   Rendimiento por defecto: 0.32 lt/km (configurable).
--
--   RLS: el chofer solo ve/gestiona el combustible de sus manifiestos;
--   el administrador ve y gestiona todo.
-- ============================================================

-- Estado de la jornada de combustible.
do $$
begin
  if not exists (
    select 1 from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where t.typname = 'combustible_estado' and n.nspname = 'public'
  ) then
    create type public.combustible_estado as enum ('iniciada', 'en_recorrido', 'cerrada', 'validada');
  end if;
end$$;

-- Rendimiento configurable (lt/km).
insert into public.configuracion (clave, valor, descripcion)
values (
  'combustible_rendimiento_lt_km',
  '0.32',
  'Rendimiento teórico de combustible en litros por kilómetro.'
)
on conflict (clave) do nothing;

-- ------------------------------------------------------------
-- Jornadas de combustible (una por manifiesto).
-- ------------------------------------------------------------
create table if not exists public.combustible_jornadas (
  id                        uuid primary key default gen_random_uuid(),
  manifiesto_id             uuid not null unique references public.manifiestos (id) on delete cascade,
  usuario_id                uuid not null references public.profiles (id) on delete cascade,
  litros_iniciales          numeric,
  litros_iniciales_validados numeric,
  inicial_validado_por      uuid references public.profiles (id) on delete set null,
  inicial_validado_en       timestamptz,
  odometro_inicial          numeric,
  odometro_final            numeric,
  litros_finales            numeric,
  litros_finales_validados  numeric,
  final_validado_por        uuid references public.profiles (id) on delete set null,
  final_validado_en         timestamptz,
  km_recorridos             numeric,
  consumo_teorico_lt        numeric,
  consumo_real_lt           numeric,
  rendimiento_lt_km         numeric,
  estado                    public.combustible_estado not null default 'iniciada',
  iniciada_en               timestamptz not null default now(),
  cerrada_en                timestamptz,
  notas                     text,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now()
);

comment on table public.combustible_jornadas is
  'Jornada de combustible por manifiesto (litros, km y consumo).';

create index if not exists combustible_jornadas_usuario_idx
  on public.combustible_jornadas (usuario_id);

-- ------------------------------------------------------------
-- Recargas de combustible (N por jornada).
-- ------------------------------------------------------------
create table if not exists public.combustible_recargas (
  id            uuid primary key default gen_random_uuid(),
  jornada_id    uuid not null references public.combustible_jornadas (id) on delete cascade,
  usuario_id    uuid not null references public.profiles (id) on delete cascade,
  litros        numeric not null,
  monto         numeric,
  bucket        text,
  path          text,
  hash_sha256   text,
  registrada_en timestamptz not null default now(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.combustible_recargas is
  'Recargas de combustible registradas durante una jornada.';

create index if not exists combustible_recargas_jornada_idx
  on public.combustible_recargas (jornada_id);

-- ------------------------------------------------------------
-- updated_at.
-- ------------------------------------------------------------
drop trigger if exists combustible_jornadas_set_updated_at on public.combustible_jornadas;
create trigger combustible_jornadas_set_updated_at
  before update on public.combustible_jornadas
  for each row execute function public.set_updated_at();

drop trigger if exists combustible_recargas_set_updated_at on public.combustible_recargas;
create trigger combustible_recargas_set_updated_at
  before update on public.combustible_recargas
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- RLS.
-- ------------------------------------------------------------
alter table public.combustible_jornadas enable row level security;
alter table public.combustible_recargas enable row level security;

drop policy if exists combustible_jornadas_select on public.combustible_jornadas;
create policy combustible_jornadas_select
  on public.combustible_jornadas
  for select
  to authenticated
  using (
    public.is_admin()
    or exists (
      select 1 from public.manifiestos m
      where m.id = manifiesto_id and m.capturado_por = auth.uid()
    )
  );

drop policy if exists combustible_jornadas_insert on public.combustible_jornadas;
create policy combustible_jornadas_insert
  on public.combustible_jornadas
  for insert
  to authenticated
  with check (
    public.is_admin()
    or exists (
      select 1 from public.manifiestos m
      where m.id = manifiesto_id and m.capturado_por = auth.uid()
    )
  );

drop policy if exists combustible_jornadas_update on public.combustible_jornadas;
create policy combustible_jornadas_update
  on public.combustible_jornadas
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

drop policy if exists combustible_jornadas_delete_admin on public.combustible_jornadas;
create policy combustible_jornadas_delete_admin
  on public.combustible_jornadas
  for delete
  to authenticated
  using (public.is_admin());

-- Recargas: visibles/gestionables si la jornada es del chofer o admin.
drop policy if exists combustible_recargas_select on public.combustible_recargas;
create policy combustible_recargas_select
  on public.combustible_recargas
  for select
  to authenticated
  using (
    public.is_admin()
    or exists (
      select 1
        from public.combustible_jornadas j
        join public.manifiestos m on m.id = j.manifiesto_id
       where j.id = jornada_id and m.capturado_por = auth.uid()
    )
  );

drop policy if exists combustible_recargas_insert on public.combustible_recargas;
create policy combustible_recargas_insert
  on public.combustible_recargas
  for insert
  to authenticated
  with check (
    public.is_admin()
    or exists (
      select 1
        from public.combustible_jornadas j
        join public.manifiestos m on m.id = j.manifiesto_id
       where j.id = jornada_id and m.capturado_por = auth.uid()
    )
  );

drop policy if exists combustible_recargas_delete on public.combustible_recargas;
create policy combustible_recargas_delete
  on public.combustible_recargas
  for delete
  to authenticated
  using (
    public.is_admin()
    or exists (
      select 1
        from public.combustible_jornadas j
        join public.manifiestos m on m.id = j.manifiesto_id
       where j.id = jornada_id and m.capturado_por = auth.uid()
    )
  );

-- ------------------------------------------------------------
-- Permisos.
-- ------------------------------------------------------------
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.combustible_jornadas to authenticated;
grant select, insert, update, delete on public.combustible_recargas to authenticated;
grant all on public.combustible_jornadas to service_role;
grant all on public.combustible_recargas to service_role;
