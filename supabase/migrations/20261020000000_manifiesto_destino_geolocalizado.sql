-- ============================================================
-- Manifiesto: destino geolocalizado, aprobación y factura por entrega
--
--   * El tabulador de localidades guarda coordenadas para calcular la
--     localidad más cercana a cada cliente y el destino del viaje.
--   * El destino calculado queda pendiente hasta que el administrador lo
--     apruebe o lo corrija. Solo un destino aprobado/corregido es facturable.
--   * Cada entrega queda vinculada a su factura (tipo + número).
--   * El flujo nuevo es solo factura (sin PRO); se conserva el enum por
--     compatibilidad con registros históricos.
-- ============================================================

-- ------------------------------------------------------------
-- Coordenadas del tabulador de localidades.
-- ------------------------------------------------------------
alter table public.fletes_tabulador
  add column if not exists lat numeric,
  add column if not exists lng numeric;

comment on column public.fletes_tabulador.lat is
  'Latitud del centro de la localidad (para geolocalización).';
comment on column public.fletes_tabulador.lng is
  'Longitud del centro de la localidad (para geolocalización).';

-- ------------------------------------------------------------
-- Estado del destino del manifiesto.
-- ------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where t.typname = 'destino_estado' and n.nspname = 'public'
  ) then
    create type public.destino_estado as enum (
      'sin_calcular',
      'pendiente',
      'aprobado',
      'corregido'
    );
  end if;
end$$;

alter table public.manifiestos
  add column if not exists destino_calculado text,
  add column if not exists destino_calculado_km numeric,
  add column if not exists destino_aprobado text,
  add column if not exists destino_estado public.destino_estado
    not null default 'sin_calcular',
  add column if not exists destino_aprobado_por uuid
    references public.profiles (id) on delete set null,
  add column if not exists destino_aprobado_en timestamptz;

comment on column public.manifiestos.destino_calculado is
  'Localidad de destino calculada por geolocalización.';
comment on column public.manifiestos.destino_aprobado is
  'Localidad de destino aprobada o corregida por el administrador.';
comment on column public.manifiestos.destino_estado is
  'sin_calcular | pendiente | aprobado | corregido.';

create index if not exists manifiestos_destino_estado_idx
  on public.manifiestos (destino_estado);

-- ------------------------------------------------------------
-- Factura de cada entrega.
-- ------------------------------------------------------------
alter table public.entregas
  add column if not exists documento_tipo public.documento_tipo
    not null default 'factura',
  add column if not exists documento_numero text,
  add column if not exists localidad_calculada text;

comment on column public.entregas.documento_numero is
  'Número de factura que corresponde a esta entrega.';
comment on column public.entregas.localidad_calculada is
  'Localidad asignada automáticamente por geolocalización.';

create index if not exists entregas_documento_numero_idx
  on public.entregas (lower(documento_numero));

-- ------------------------------------------------------------
-- Flujo nuevo: solo factura.
-- ------------------------------------------------------------
alter table public.manifiesto_lineas
  alter column tipo set default 'factura';

-- ------------------------------------------------------------
-- Relleno de datos históricos.
-- ------------------------------------------------------------
update public.entregas e
set documento_tipo = coalesce(l.tipo, 'factura'),
    documento_numero = coalesce(e.documento_numero, l.numero)
from public.manifiesto_lineas l
where e.linea_id = l.id
  and (e.documento_numero is null or e.documento_tipo is null);

-- Los manifiestos con una localidad manual ya definida se consideran
-- aprobados para no bloquear la facturación histórica.
update public.manifiestos
set destino_calculado = coalesce(destino_calculado, localidad_mas_lejana),
    destino_aprobado = coalesce(destino_aprobado, localidad_mas_lejana),
    destino_estado = 'aprobado',
    destino_aprobado_en = coalesce(destino_aprobado_en, now())
where localidad_mas_lejana is not null
  and btrim(localidad_mas_lejana) <> ''
  and destino_estado = 'sin_calcular';
