-- Keep-alive mínimo para evitar que Supabase pause el proyecto por inactividad.
-- No contiene datos de negocio: una sola fila con la última marca de tiempo.
-- El ping debe llegar a PostgREST/Postgres (no a /auth/v1/health, que no
-- ejecuta SQL y por tanto no cuenta como actividad).

create table if not exists public.keepalive (
  id integer primary key default 1,
  pinged_at timestamptz not null default now(),
  constraint keepalive_one_row check (id = 1)
);

insert into public.keepalive (id)
values (1)
on conflict (id) do nothing;

alter table public.keepalive enable row level security;

drop policy if exists "keepalive_public_read" on public.keepalive;
create policy "keepalive_public_read"
  on public.keepalive
  for select
  to anon, authenticated
  using (true);

grant select on public.keepalive to anon, authenticated;
