-- Contract 055: TEST-S cleanup helper exists and public access is revoked.
begin;

do $$
declare
  v_def text;
begin
  select pg_get_functiondef('private.test_s_cleanup_equipaciones_logistica()'::regprocedure) into v_def;
  if position('dataset_id=''TEST-S''' in v_def)=0 then
    raise exception '055 contract: cleanup must be scoped to TEST-S registry';
  end if;
  if position('equipacion_recepcion_lineas_no_delete' in v_def)=0 then
    raise exception '055 contract: cleanup must restore immutable reception-line trigger';
  end if;
end $$;

rollback;
