-- 107 - Sponsors capability enforcement for table and managed logo storage.
begin;

drop policy if exists patrocinadores_club_admin_write on public.patrocinadores_club;
drop policy if exists patrocinadores_capability_write on public.patrocinadores_club;
create policy patrocinadores_capability_write
on public.patrocinadores_club
to authenticated
using (private.has_capability('sponsors.manage'))
with check (private.has_capability('sponsors.manage'));

drop policy if exists patrocinadores_storage_insert on storage.objects;
create policy patrocinadores_storage_insert
on storage.objects
for insert to authenticated
with check (
  bucket_id='patrocinadores'
  and private.has_capability('sponsors.manage')
);

drop policy if exists patrocinadores_storage_update on storage.objects;
create policy patrocinadores_storage_update
on storage.objects
for update to authenticated
using (
  bucket_id='patrocinadores'
  and private.has_capability('sponsors.manage')
)
with check (
  bucket_id='patrocinadores'
  and private.has_capability('sponsors.manage')
);

drop policy if exists patrocinadores_storage_delete on storage.objects;
create policy patrocinadores_storage_delete
on storage.objects
for delete to authenticated
using (
  bucket_id='patrocinadores'
  and private.has_capability('sponsors.manage')
);

commit;
