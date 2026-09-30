-- ============================================================
-- Módulo 3: Buckets privados y políticas de Storage.
--
--   * Buckets privados: manifiestos, firmas, extras.
--   * El chofer solo puede leer/escribir dentro de su carpeta
--     ({uid}/...). El administrador gestiona todo.
--   * Los archivos nunca se exponen con URL pública: las URLs
--     firmadas de corta vida las emite la Edge Function `firmar-url`.
-- ============================================================

-- ------------------------------------------------------------
-- Crear buckets privados (idempotente).
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values
  ('manifiestos', 'manifiestos', false),
  ('firmas', 'firmas', false),
  ('extras', 'extras', false)
on conflict (id) do update set public = excluded.public;

-- ------------------------------------------------------------
-- ¿El path pertenece al usuario actual? (carpeta raíz = auth.uid())
-- ------------------------------------------------------------
create or replace function public.es_mi_carpeta(nombre text)
returns boolean
language sql
stable
as $$
  select nombre is not null
     and split_part(nombre, '/', 1) = auth.uid()::text;
$$;

grant execute on function public.es_mi_carpeta(text) to authenticated;

-- ------------------------------------------------------------
-- Políticas sobre storage.objects (solo los 3 buckets del sistema).
-- ------------------------------------------------------------
drop policy if exists storage_evidencias_select on storage.objects;
create policy storage_evidencias_select
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id in ('manifiestos', 'firmas', 'extras')
    and (public.es_mi_carpeta(name) or public.is_admin())
  );

drop policy if exists storage_evidencias_insert on storage.objects;
create policy storage_evidencias_insert
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id in ('manifiestos', 'firmas', 'extras')
    and (public.es_mi_carpeta(name) or public.is_admin())
  );

drop policy if exists storage_evidencias_update on storage.objects;
create policy storage_evidencias_update
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id in ('manifiestos', 'firmas', 'extras')
    and (public.es_mi_carpeta(name) or public.is_admin())
  )
  with check (
    bucket_id in ('manifiestos', 'firmas', 'extras')
    and (public.es_mi_carpeta(name) or public.is_admin())
  );

drop policy if exists storage_evidencias_delete on storage.objects;
create policy storage_evidencias_delete
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id in ('manifiestos', 'firmas', 'extras')
    and public.is_admin()
  );
