-- 076 - Restore compatibility for pre-choice equipment needs.
-- A need may have neither pack nor additional article while still pending sizes/choice.
begin;

alter table public.equipacion_necesidades
  drop constraint if exists equipacion_necesidades_adicional_ck;

alter table public.equipacion_necesidades
  add constraint equipacion_necesidades_adicional_ck check(
    -- Pre-choice state used by the established season flow.
    (pack_id is null and articulo_id_adicional is null and cantidad_adicional is null
      and estado='pendiente_tallas')
    or
    -- Ordinary pack need.
    (pack_id is not null and articulo_id_adicional is null and cantidad_adicional is null)
    or
    -- Additional single-item need.
    (pack_id is null and articulo_id_adicional is not null and cantidad_adicional is not null)
  );

commit;
