-- 086 - Materialize operational demand before preparation/direct delivery.
-- 084 remains the read model; 085 remains the atomic FIFO preparation primitive.
begin;

create or replace function private.equipacion_materializar_demanda(p_items jsonb)
returns table(asignacion_id uuid,necesidad_id uuid,articulo_id uuid,talla text)
language plpgsql security definer set search_path='' as $$
declare
 actor uuid:=auth.uid();
 elem jsonb; nid uuid; aid uuid; vtalla text; expected integer; existing public.equipacion_asignaciones%rowtype;
 personas integer; temporadas integer;
begin
 if actor is null or not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'At least one demand item must be selected'; end if;

 create temporary table if not exists pg_temp.eq086_items(necesidad_id uuid,articulo_id uuid,talla text,primary key(necesidad_id,articulo_id,talla)) on commit drop;
 truncate pg_temp.eq086_items;
 for elem in select value from jsonb_array_elements(p_items) loop
   begin
     nid:=(elem->>'necesidad_id')::uuid; aid:=(elem->>'articulo_id')::uuid; vtalla:=elem->>'talla';
   exception when others then raise exception 'Invalid demand item payload'; end;
   if nid is null or aid is null or vtalla is null or vtalla='' then raise exception 'Demand item requires necesidad_id, articulo_id and talla'; end if;
   insert into pg_temp.eq086_items values(nid,aid,vtalla) on conflict do nothing;
 end loop;
 if (select count(*) from pg_temp.eq086_items)<>jsonb_array_length(p_items) then raise exception 'Duplicate demand items are not allowed'; end if;

 perform 1 from public.equipacion_necesidades n join pg_temp.eq086_items i on i.necesidad_id=n.id order by n.id for update;
 if (select count(distinct n.persona_id) from public.equipacion_necesidades n join pg_temp.eq086_items i on i.necesidad_id=n.id)<>1
    or (select count(distinct n.temporada_id) from public.equipacion_necesidades n join pg_temp.eq086_items i on i.necesidad_id=n.id)<>1 then
   raise exception 'All selected demand items must belong to the same person and season';
 end if;
 if exists(select 1 from public.equipacion_necesidades n join pg_temp.eq086_items i on i.necesidad_id=n.id where n.confirmada_at is null or n.estado='cancelada') then
   raise exception 'Only confirmed active equipment needs can be materialized';
 end if;
 if exists(
   select 1 from pg_temp.eq086_items i
   left join public.equipacion_demanda_logistica d on d.necesidad_id=i.necesidad_id and d.articulo_id=i.articulo_id and d.talla=i.talla
   where d.necesidad_id is null
 ) then raise exception 'One or more selected items are not current logistical demand'; end if;

 for nid,aid,vtalla,expected in
   select d.necesidad_id,d.articulo_id,d.talla,d.cantidad_demandada
   from public.equipacion_demanda_logistica d join pg_temp.eq086_items i using(necesidad_id,articulo_id,talla)
   order by d.necesidad_id,d.articulo_id,d.talla
 loop
   select * into existing from public.equipacion_asignaciones a
    where a.necesidad_id=nid and a.articulo_id=aid and a.talla=vtalla for update;
   if existing.id is null then
     insert into public.equipacion_asignaciones(necesidad_id,articulo_id,talla,cantidad,estado,origen,asignado_por)
     values(nid,aid,vtalla,expected,'propuesta','automatico',actor)
     returning * into existing;
   elsif existing.estado='cancelada' then
     raise exception 'Cancelled assignment exists for selected demand item';
   elsif existing.cantidad<>expected then
     raise exception 'Existing assignment quantity % does not match current demand %',existing.cantidad,expected;
   end if;
   asignacion_id:=existing.id; necesidad_id:=nid; articulo_id:=aid; talla:=vtalla; return next;
 end loop;
end $$;

create or replace function private.equipacion_preparar_demanda(p_items jsonb)
returns table(asignacion_id uuid,preparacion_id uuid)
language plpgsql security definer set search_path='' as $$
declare ids uuid[];
begin
 select array_agg(x.asignacion_id order by x.asignacion_id) into ids from private.equipacion_materializar_demanda(p_items) x;
 return query select * from private.equipacion_preparar_multiple(ids);
end $$;

create or replace function public.equipacion_preparar_demanda(p_items jsonb)
returns table(asignacion_id uuid,preparacion_id uuid)
language sql security invoker set search_path='' as $$
 select * from private.equipacion_preparar_demanda(p_items)
$$;

-- Direct delivery keeps the established 079 displacement semantics, but can now start from 084 demand.
create or replace function private.equipacion_entregar_demanda(p_item jsonb,p_permitir_desplazar boolean default false)
returns table(asignacion_id uuid,entrega_id uuid)
language plpgsql security definer set search_path='' as $$
declare a uuid; e uuid;
begin
 select x.asignacion_id into a from private.equipacion_materializar_demanda(jsonb_build_array(p_item)) x;
 e:=private.equipacion_entregar_directo(a,p_permitir_desplazar);
 asignacion_id:=a; entrega_id:=e; return next;
end $$;

create or replace function public.equipacion_entregar_demanda(p_item jsonb,p_permitir_desplazar boolean default false)
returns table(asignacion_id uuid,entrega_id uuid)
language sql security invoker set search_path='' as $$
 select * from private.equipacion_entregar_demanda(p_item,p_permitir_desplazar)
$$;

revoke all on function private.equipacion_materializar_demanda(jsonb),private.equipacion_preparar_demanda(jsonb),private.equipacion_entregar_demanda(jsonb,boolean) from public,anon;
revoke all on function public.equipacion_preparar_demanda(jsonb),public.equipacion_entregar_demanda(jsonb,boolean) from public,anon;
grant execute on function private.equipacion_materializar_demanda(jsonb),private.equipacion_preparar_demanda(jsonb),private.equipacion_entregar_demanda(jsonb,boolean) to authenticated,service_role;
grant execute on function public.equipacion_preparar_demanda(jsonb),public.equipacion_entregar_demanda(jsonb,boolean) to authenticated,service_role;

commit;
