-- Contract 082: frontend-callable public RPC delegates to private atomic business operation.
do $$
declare src text;
begin
 if to_regprocedure('public.equipacion_entregar_multiple(uuid[],uuid[])') is null then
   raise exception '082: public multi-delivery RPC missing';
 end if;
 if has_function_privilege('anon','public.equipacion_entregar_multiple(uuid[],uuid[])','EXECUTE') then
   raise exception '082: public multi-delivery RPC exposed to anon';
 end if;
 if not has_function_privilege('authenticated','public.equipacion_entregar_multiple(uuid[],uuid[])','EXECUTE') then
   raise exception '082: authenticated cannot execute public multi-delivery RPC';
 end if;
 select pg_get_functiondef('public.equipacion_entregar_multiple(uuid[],uuid[])'::regprocedure) into src;
 if position('private.equipacion_entregar_multiple' in src)=0 then
   raise exception '082: public RPC does not delegate to private atomic operation';
 end if;
end $$;

select '082_entrega_multiple_rpc_publica_contract' contract,'PASS' result;
