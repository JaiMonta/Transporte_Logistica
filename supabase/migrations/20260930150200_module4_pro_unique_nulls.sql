-- ============================================================
-- Módulo 4: Manifiestos
-- El número PRO debe ser único por cliente y fecha. Se refuerza el
-- índice con NULLS NOT DISTINCT para que un cliente nulo también
-- cuente como valor repetido (Postgres 15+).
-- ============================================================

-- Limpiar duplicados de prueba si existieran antes de crear el índice.
delete from public.manifiestos a
 using public.manifiestos b
 where a.id <> b.id
   and lower(a.numero_pro) = lower(b.numero_pro)
   and a.cliente_id is not distinct from b.cliente_id
   and a.fecha = b.fecha;

drop index if exists public.manifiestos_pro_cliente_fecha_idx;
create unique index manifiestos_pro_cliente_fecha_idx
  on public.manifiestos (lower(numero_pro), cliente_id, fecha) nulls not distinct
  where numero_pro is not null;
