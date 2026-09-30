-- ============================================================
-- Módulo 1: Usuarios y accesos
-- Sincroniza el rol del perfil cuando cambia app_metadata.rol.
--
-- GoTrue (Auth) puede escribir app_metadata en un UPDATE posterior
-- al INSERT del usuario, por lo que el trigger de alta no siempre
-- alcanza a ver el rol. Este trigger mantiene profiles.rol como
-- espejo de auth.users.raw_app_meta_data (fuente de verdad).
-- ============================================================

create or replace function public.sync_rol_from_app_metadata()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rol public.rol_usuario;
begin
  if new.raw_app_meta_data ->> 'rol' = 'admin' then
    v_rol := 'admin';
  else
    v_rol := 'chofer';
  end if;

  update public.profiles
     set rol = v_rol
   where id = new.id
     and rol is distinct from v_rol;

  return new;
exception
  when others then
    -- No bloquear la operación de Auth por un fallo del perfil.
    return new;
end$$;

drop trigger if exists on_auth_user_updated_rol on auth.users;
create trigger on_auth_user_updated_rol
  after update of raw_app_meta_data on auth.users
  for each row execute function public.sync_rol_from_app_metadata();
