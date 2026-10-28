-- V95.1.1 - almacenamiento administrado de logos de patrocinadores.
begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'patrocinadores',
  'patrocinadores',
  true,
  2097152,
  array['image/png','image/jpeg','image/webp','image/svg+xml']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;


drop policy if exists patrocinadores_storage_insert on storage.objects;
create policy patrocinadores_storage_insert
on storage.objects for insert to authenticated
with check (
  bucket_id = 'patrocinadores'
  and private.has_any_role(array['administrador'::text,'club'::text])
);

drop policy if exists patrocinadores_storage_update on storage.objects;
create policy patrocinadores_storage_update
on storage.objects for update to authenticated
using (
  bucket_id = 'patrocinadores'
  and private.has_any_role(array['administrador'::text,'club'::text])
)
with check (
  bucket_id = 'patrocinadores'
  and private.has_any_role(array['administrador'::text,'club'::text])
);

drop policy if exists patrocinadores_storage_delete on storage.objects;
create policy patrocinadores_storage_delete
on storage.objects for delete to authenticated
using (
  bucket_id = 'patrocinadores'
  and private.has_any_role(array['administrador'::text,'club'::text])
);

commit;
select '047_v95_1_1_patrocinadores_storage' as migration, 'PASS' as result;
