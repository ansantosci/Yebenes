-- Contract 054: reception trigger must not double-count NEW in AFTER INSERT.
begin;
do $$
declare v_def text;
begin
  select pg_get_functiondef('private.equipacion_aplicar_recepcion_linea()'::regprocedure) into v_def;
  if position('id<>new.id' in replace(lower(v_def),' ','')) = 0 then
    raise exception '054 contract: reception trigger must exclude NEW from previous accepted quantity';
  end if;
end $$;
rollback;
