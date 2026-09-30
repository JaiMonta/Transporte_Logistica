-- ============================================================
-- Reconciliación del esquema
-- Elimina las tablas del diseño original que no forman parte del
-- plan de módulos y que estaban vacías/sin uso.
--   usuarios, rutas, manifiestos, entregas, camiones,
--   extras_servicio, pagos_choferes, ubicaciones_gps (+ particiones)
--
-- La tabla usuarios NO estaba enlazada a auth.users: la fuente de
-- verdad de usuarios es public.profiles (Módulo 1).
-- ============================================================

drop table if exists public.ubicaciones_gps_2027 cascade;
drop table if exists public.ubicaciones_gps_2026 cascade;
drop table if exists public.ubicaciones_gps cascade;
drop table if exists public.extras_servicio cascade;
drop table if exists public.pagos_choferes cascade;
drop table if exists public.entregas cascade;
drop table if exists public.manifiestos cascade;
drop table if exists public.camiones cascade;
drop table if exists public.rutas cascade;
drop table if exists public.usuarios cascade;
