-- ============================================================
-- Facturación: el administrador puede designar manualmente cuál
-- entrega es la "más lejana" para el cálculo del flete, por encima
-- del cálculo automático (mayor km del tabulador).
-- ============================================================

alter table public.entregas
  add column if not exists es_mas_lejana boolean not null default false;

comment on column public.entregas.es_mas_lejana is
  'Entrega designada por el admin como la más lejana (define el flete).';
