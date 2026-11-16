-- Contract 086: operational demand can be materialized and prepared atomically without changing 084/085 semantics.
do $$
declare s text; p text; d text;
begin
 if to_regprocedure('private.equipacion_materializar_demanda(jsonb)') is null then raise exception '086: private materializer missing'; end if;
 if to_regprocedure('public.equipacion_preparar_demanda(jsonb)') is null then raise exception '086: public preparation RPC missing'; end if;
 if to_regprocedure('public.equipacion_entregar_demanda(jsonb,boolean)') is null then raise exception '086: public direct-delivery RPC missing'; end if;
 if has_function_privilege('anon','public.equipacion_preparar_demanda(jsonb)','EXECUTE') or has_function_privilege('anon','public.equipacion_entregar_demanda(jsonb,boolean)','EXECUTE') then raise exception '086: RPC exposed to anon'; end if;
 if not has_function_privilege('authenticated','public.equipacion_preparar_demanda(jsonb)','EXECUTE') then raise exception '086: authenticated cannot prepare demand'; end if;
 select pg_get_functiondef('private.equipacion_materializar_demanda(jsonb)'::regprocedure) into s;
 select pg_get_functiondef('private.equipacion_preparar_demanda(jsonb)'::regprocedure) into p;
 select pg_get_functiondef('private.equipacion_entregar_demanda(jsonb,boolean)'::regprocedure) into d;
 if position('equipacion_demanda_logistica' in s)=0 or position('for update' in lower(s))=0 or position('equipacion_asignaciones' in s)=0 then raise exception '086: materialization contract incomplete'; end if;
 if position('equipacion_preparar_multiple' in p)=0 or position('equipacion_materializar_demanda' in p)=0 then raise exception '086: preparation does not compose materialization + 085'; end if;
 if position('equipacion_entregar_directo' in d)=0 or position('equipacion_materializar_demanda' in d)=0 then raise exception '086: direct delivery does not compose materialization + 079'; end if;
end $$;
select '086_materializacion_demanda_preparacion_contract' contract,'PASS' result;
