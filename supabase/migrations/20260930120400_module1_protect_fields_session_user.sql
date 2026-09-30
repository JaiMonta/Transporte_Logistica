-- ============================================================
-- Módulo 1: Usuarios y accesos
-- Corrige la protección de campos del perfil.
--
-- IMPORTANTE: la función es SECURITY DEFINER, por lo que dentro
-- de ella `current_user` es el DUEÑO de la función (postgres),
-- no el rol de la petición. Para distinguir una operación
-- privilegiada hay que mirar `session_user` (el rol real con el
-- que se conecta PostgREST / el panel) o la ausencia de JWT.
--
--   * Procesos privilegiados (service_role, postgres) y admin:
--     pueden gestionar todos los campos.
--   * Chofer (authenticated): solo nombre y teléfono.
-- ============================================================

create or replace function public.protect_profile_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_admin()
     or session_user in ('service_role', 'postgres', 'supabase_admin')
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
