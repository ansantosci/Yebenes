-- Contract 069: TEST-S reset mode is private and all 067 recalculation triggers honor it.
do $$
declare src text;
begin
 if to_regprocedure('private.test_set_economia_reset_mode(boolean)') is null then
   raise exception '069: reset-mode helper missing';
 end if;
 if has_function_privilege('anon','private.test_set_economia_reset_mode(boolean)','EXECUTE') then
   raise exception '069: reset-mode helper exposed to anon';
 end if;
 if has_function_privilege('authenticated','private.test_set_economia_reset_mode(boolean)','EXECUTE') then
   raise exception '069: reset-mode helper exposed to authenticated';
 end if;
 select pg_get_functiondef('private.economia_trg_asignacion()'::regprocedure) into src;
 if position('yebenes.test_s_reset_mode' in src)=0 then raise exception '069: assignment trigger ignores reset mode'; end if;
 select pg_get_functiondef('private.economia_trg_participacion_baja()'::regprocedure) into src;
 if position('yebenes.test_s_reset_mode' in src)=0 then raise exception '069: participation trigger ignores reset mode'; end if;
 select pg_get_functiondef('private.economia_trg_config_recalcular()'::regprocedure) into src;
 if position('yebenes.test_s_reset_mode' in src)=0 then raise exception '069: config trigger ignores reset mode'; end if;
end $$;
select '069_test_s_economia_reset_mode_contract' contract,'PASS' result;
