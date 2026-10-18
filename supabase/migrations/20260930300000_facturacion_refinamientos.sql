-- ============================================================
-- Refinamientos de facturación por empresa
--
--   * `peaje` como tipo de extra (concepto del Excel).
--   * El chofer puede capturar los pesos de SUS manifiestos
--     (además del administrador).
-- ============================================================

-- ------------------------------------------------------------
-- Peaje como tipo de extra.
-- ------------------------------------------------------------
alter type public.extra_tipo add value if not exists 'peaje';

-- ------------------------------------------------------------
-- Pesos: el chofer dueño del manifiesto también puede escribir.
-- (Se reemplazan las políticas de solo-admin por admin o dueño.)
-- ------------------------------------------------------------
drop policy if exists manifiesto_pesos_insert_admin on public.manifiesto_pesos;
drop policy if exists manifiesto_pesos_update_admin on public.manifiesto_pesos;

drop policy if exists manifiesto_pesos_insert on public.manifiesto_pesos;
create policy manifiesto_pesos_insert
  on public.manifiesto_pesos
  for insert
  to authenticated
  with check (
    public.is_admin()
    or exists (
      select 1 from public.manifiestos m
      where m.id = manifiesto_id and m.capturado_por = auth.uid()
    )
  );

drop policy if exists manifiesto_pesos_update on public.manifiesto_pesos;
create policy manifiesto_pesos_update
  on public.manifiesto_pesos
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
