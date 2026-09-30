-- ============================================================
-- Módulo 1: Usuarios y accesos
-- Corrige la protección de campos del perfil para que las
-- operaciones privilegiadas (service_role / procesos internos)
-- puedan ajustar rol, estado y correo, mientras los choferes
-- siguen con esos campos congelados.
-- ============================================================

create or replace function public.protect_profile_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Los procesos privilegiados (service_role, migraciones, el
  -- propio dueño de la tabla) y los administradores gestionan
  -- todos los campos.
  if public.is_admin()
     or current_user in ('service_role', 'postgres', 'supabase_admin')
     or auth.uid() is null then
    return new;
  end if;

  -- Un chofer solo puede modificar su nombre y su teléfono.
  new.rol    := old.rol;
  new.activo := old.activo;
  new.email  := old.email;
  new.id     := old.id;
  return new;
end$$;
