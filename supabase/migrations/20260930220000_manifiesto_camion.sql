-- ============================================================
-- Módulo: Camiones — enlace con manifiestos y flete
--
--   * Cada manifiesto puede tener un camión asignado (el chofer elige el
--     suyo al capturar).
--   * La localidad más lejana la decide el administrador (más adelante se
--     podrá derivar del punto más lejano por geocodificación).
--   * `costo_flete` queda provisionado; se calculará con la tabla de fletes
--     (capacidad del camión x localidad) más adelante.
-- ============================================================

alter table public.manifiestos
  add column if not exists camion_id uuid references public.camiones (id) on delete set null,
  add column if not exists localidad_mas_lejana text,
  add column if not exists costo_flete numeric;

comment on column public.manifiestos.camion_id is
  'Camión asignado al manifiesto (elegido por el chofer).';
comment on column public.manifiestos.localidad_mas_lejana is
  'Localidad más lejana del recorrido (la fija el administrador).';
comment on column public.manifiestos.costo_flete is
  'Costo de flete calculado (tabla de fletes: capacidad x localidad).';

create index if not exists manifiestos_camion_idx
  on public.manifiestos (camion_id);
