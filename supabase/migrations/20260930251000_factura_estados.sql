-- ============================================================
-- Facturación semanal — corrección de estados.
--
-- Por lenguaje de negocio:
--   * "pagada"  = la factura quedó cancelada (saldada).
--   * "anulada" = no válida (no se elimina por trazabilidad).
--
-- El estado previo 'cancelada' se renombra a 'anulada' y se agrega 'pagada'.
-- ============================================================

-- Renombrar el valor existente (conserva las filas con ese valor).
do $$
begin
  if exists (
    select 1 from pg_enum e
    join pg_type t on t.oid = e.enumtypid
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'factura_estado'
      and e.enumlabel = 'cancelada'
  ) then
    alter type public.factura_estado rename value 'cancelada' to 'anulada';
  end if;
end$$;

-- Agregar 'pagada' si no existe (después de 'pendiente').
do $$
begin
  if not exists (
    select 1 from pg_enum e
    join pg_type t on t.oid = e.enumtypid
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'factura_estado'
      and e.enumlabel = 'pagada'
  ) then
    alter type public.factura_estado add value 'pagada' after 'pendiente';
  end if;
end$$;
