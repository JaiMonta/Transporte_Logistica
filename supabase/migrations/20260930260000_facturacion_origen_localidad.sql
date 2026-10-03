-- ============================================================
-- Corrección del cálculo de factura/extras
--
--   * Origen de carga configurable (por ahora Maracay), usado para
--     medir distancias y elegir la localidad más lejana del manifiesto.
--   * Cada entrega guarda su localidad (tabulador) y la distancia al
--     origen, para el reparto (radio de 10 km) y el desvío.
-- ============================================================

-- Configuración del origen de carga.
insert into public.configuracion (clave, valor, descripcion) values
  ('origen_carga_nombre', 'MARACAY', 'Localidad del sitio de carga/origen.'),
  ('origen_carga_lat', '10.2469', 'Latitud del sitio de carga.'),
  ('origen_carga_lng', '-67.5958', 'Longitud del sitio de carga.')
on conflict (clave) do nothing;

-- Localidad de cada entrega (se asigna por proximidad GPS o manual).
alter table public.entregas
  add column if not exists localidad text,
  add column if not exists localidad_distancia_km numeric;

comment on column public.entregas.localidad is
  'Localidad del tabulador asignada a la entrega (por GPS o manual).';
comment on column public.entregas.localidad_distancia_km is
  'Distancia (km) de la entrega al origen de carga.';
