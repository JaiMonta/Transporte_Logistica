-- ============================================================
-- Módulo 1: Usuarios y accesos
-- Esquema base: rol de usuario, tabla profiles y trigger de alta.
-- ============================================================

-- Rol de usuario del sistema (admin gestiona todo, chofer solo lo suyo).
do $$
begin
  if not exists (
    select 1 from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where t.typname = 'rol_usuario' and n.nspname = 'public'
  ) then
    create type public.rol_usuario as enum ('admin', 'chofer');
  end if;
end$$;

-- Perfil enlazado 1:1 con auth.users (mismo id).
create table if not exists public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  email      text,
  nombre     text not null default '',
  telefono   text,
  rol        public.rol_usuario not null default 'chofer',
  activo     boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- El correo debe ser único (comparación sin distinguir mayúsculas).
create unique index if not exists profiles_email_unique_idx
  on public.profiles (lower(email))
  where email is not null;

comment on table public.profiles is 'Perfiles de usuario enlazados a auth.users (mismo id).';

-- ------------------------------------------------------------
-- Mantener updated_at al día.
-- ------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- Alta automática del perfil al crear un usuario en Auth.
-- El rol se lee de app_metadata (NO de user_metadata, porque el
-- propio usuario puede editar sus user_metadata).
-- ------------------------------------------------------------
create or replace function public.handle_new_user()
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

  insert into public.profiles (id, email, nombre, telefono, rol, activo)
  values (
    new.id,
    new.email,
    coalesce(nullif(new.raw_user_meta_data ->> 'nombre', ''), split_part(coalesce(new.email, ''), '@', 1)),
    nullif(new.raw_user_meta_data ->> 'telefono', ''),
    v_rol,
    true
  )
  on conflict (id) do nothing;

  return new;
exception
  when others then
    -- Nunca bloquear la creación del usuario en Auth por un fallo del perfil.
    return new;
end$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
