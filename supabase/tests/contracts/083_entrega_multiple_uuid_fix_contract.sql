-- Contract 083: no unsupported min(uuid) in multi-delivery.
do $$
declare src text;
begin
 select pg_get_functiondef('private.equipacion_entregar_multiple(uuid[],uuid[])'::regprocedure) into src;
 if position('min(n.persona_id)' in lower(src))>0 or position('min(n.temporada_id)' in lower(src))>0 then
   raise exception '083: UUID min() regression remains';
 end if;
 if position('count(distinct n.persona_id)' in lower(src))=0
 or position('count(distinct n.temporada_id)' in lower(src))=0
 or position('order by a.id' in lower(src))=0 then
   raise exception '083: grouping guard incomplete';
 end if;
 if to_regprocedure('public.equipacion_entregar_multiple(uuid[],uuid[])') is null then
   raise exception '083: public wrapper from 082 missing';
 end if;
end $$;
select '083_entrega_multiple_uuid_fix_contract' contract,'PASS' result;
