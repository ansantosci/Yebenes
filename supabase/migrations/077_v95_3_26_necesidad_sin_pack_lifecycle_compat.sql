-- 077 - A normal season need may legitimately exist without a selected pack
-- across its lifecycle. Additional-item fields remain mutually exclusive with pack.
begin;

alter table public.equipacion_necesidades
  drop constraint if exists equipacion_necesidades_adicional_ck;

alter table public.equipacion_necesidades
  add constraint equipacion_necesidades_adicional_ck check(
    -- Ordinary need: pack may still be unknown; no additional-item payload exists.
    (articulo_id_adicional is null and cantidad_adicional is null)
    or
    -- Additional single-item need: never mixed with a pack.
    (pack_id is null and articulo_id_adicional is not null and cantidad_adicional is not null)
  );

commit;
