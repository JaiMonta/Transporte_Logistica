-- ============================================================
-- Módulo 2: Clientes — código de cliente
-- Agrega el campo de texto `cod_cli` (código interno del cliente).
-- ============================================================

alter table public.clientes
  add column if not exists cod_cli text;

comment on column public.clientes.cod_cli is
  'Código interno del cliente (texto libre, opcional).';

-- Búsqueda por código de cliente.
create index if not exists clientes_cod_cli_idx
  on public.clientes (lower(cod_cli));
