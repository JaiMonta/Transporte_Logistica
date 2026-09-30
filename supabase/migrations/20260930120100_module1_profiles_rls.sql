-- ============================================================
-- Módulo 1: Usuarios y accesos
-- Seguridad a nivel de fila (RLS) sobre public.profiles.
--   * El chofer solo ve y edita su propio perfil.
--   * El administrador gestiona todos los perfiles.
--   * Ningún usuario autenticado puede insertar ni borrar perfiles
--     (la creación/eliminación se hace por funciones privilegiadas).
-- ============================================================

alter table public.profiles enable row level security;

-- ------------------------------------------------------------
-- ¿El usuario actual es administrador activo?
-- Se resuelve contra la base de datos para que un cambio de rol
-- surta efecto de inmediato (sin esperar el refresco del token).
-- ------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_claim text;
begin
  v_claim := coalesce(auth.jwt() -> 'app_metadata' ->> 'rol', '');
  if v_claim = 'admin' then
    return true;
  end if;

  return exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.rol = 'admin'
      and p.activo
  );
end$$;

-- ------------------------------------------------------------
-- Un chofer únicamente puede modificar nombre y teléfono de su
-- propio perfil; rol, estado y correo quedan congelados.
-- ------------------------------------------------------------
create or replace function public.protect_profile_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  new.rol    := old.rol;
  new.activo := old.activo;
  new.email  := old.email;
  new.id     := old.id;
  return new;
end$$;

drop trigger if exists profiles_protect_fields on public.profiles;
create trigger profiles_protect_fields
  before update on public.profiles
  for each row execute function public.protect_profile_fields();

-- ------------------------------------------------------------
-- Políticas
-- ------------------------------------------------------------
drop policy if exists profiles_select_own_or_admin on public.profiles;
create policy profiles_select_own_or_admin
  on public.profiles
  for select
  to authenticated
  using (id = auth.uid() or public.is_admin());

drop policy if exists profiles_update_own_or_admin on public.profiles;
create policy profiles_update_own_or_admin
  on public.profiles
  for update
  to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

-- Sin políticas de INSERT ni DELETE para usuarios autenticados:
-- la creación y el borrado se reservan a procesos privilegiados.

-- ------------------------------------------------------------
-- Permisos explícitos (el proyecto no auto-expone entidades nuevas).
-- ------------------------------------------------------------
grant usage on schema public to authenticated;
grant select, update on public.profiles to authenticated;
grant execute on function public.is_admin() to authenticated;

grant all on public.profiles to service_role;
grant execute on function public.is_admin() to service_role;
