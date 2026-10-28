-- V95.0.0 - identidad visual 2026/27 y patrocinadores configurables.
begin;

alter table public.configuracion_visual_club
  add column if not exists color_secundario text not null default '#0069a8',
  add column if not exists color_secundario_oscuro text not null default '#004f82',
  add column if not exists lema_cabecera text not null default 'De Madrid al cielo',
  add column if not exists mostrar_lema boolean not null default true;

create table if not exists public.patrocinadores_club (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  logo_url text,
  url text,
  orden integer not null default 100,
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.patrocinadores_club enable row level security;
drop policy if exists patrocinadores_public_read on public.patrocinadores_club;
create policy patrocinadores_public_read on public.patrocinadores_club for select to anon, authenticated using (true);
drop policy if exists patrocinadores_club_admin_write on public.patrocinadores_club;
create policy patrocinadores_club_admin_write on public.patrocinadores_club to authenticated
  using (private.has_any_role(array['administrador'::text,'club'::text]))
  with check (private.has_any_role(array['administrador'::text,'club'::text]));

grant select on public.patrocinadores_club to anon, authenticated;
grant insert, update, delete on public.patrocinadores_club to authenticated;
grant all on public.patrocinadores_club to service_role;

update public.configuracion_visual_club set
  color_primario='#d20f32', color_primario_oscuro='#9d0b26', color_acento='#f5c542',
  color_secundario='#0069a8', color_secundario_oscuro='#004f82',
  color_fondo='#f4f7fb', color_texto='#17233b',
  lema_cabecera='De Madrid al cielo', mostrar_lema=true, updated_at=now()
where id=1;

commit;
select '046_v95_0_0_identidad_visual_patrocinadores' as migration, 'PASS' as result;
