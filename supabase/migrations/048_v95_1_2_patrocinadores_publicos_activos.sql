-- V95.1.2 - exposicion publica minima de patrocinadores.
-- Los visitantes anonimos solo pueden consultar patrocinadores activos.
-- Los usuarios autenticados mantienen lectura completa para permitir la administracion.

begin;

drop policy if exists patrocinadores_public_read on public.patrocinadores_club;
drop policy if exists patrocinadores_anon_active_read on public.patrocinadores_club;
drop policy if exists patrocinadores_authenticated_read on public.patrocinadores_club;

create policy patrocinadores_anon_active_read
on public.patrocinadores_club
for select
to anon
using (activo = true);

create policy patrocinadores_authenticated_read
on public.patrocinadores_club
for select
to authenticated
using (true);

grant select on public.patrocinadores_club to anon, authenticated;

commit;

select '048_v95_1_2_patrocinadores_publicos_activos' as migration, 'PASS' as result;
