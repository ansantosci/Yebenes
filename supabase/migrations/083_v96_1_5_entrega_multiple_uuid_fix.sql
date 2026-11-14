-- 083 - Fix UUID aggregation in atomic multi-item delivery.
begin;

create or replace function private.equipacion_entregar_multiple(
 p_asignaciones uuid[],
 p_desplazamiento_autorizado uuid[] default array[]::uuid[]
) returns table(asignacion_id uuid,entrega_id uuid)
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); aid uuid; eid uuid; persona uuid; temporada uuid;
 n_personas integer; n_temporadas integer; total integer; distintos integer;
begin
 if actor is null or not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
 if p_asignaciones is null or cardinality(p_asignaciones)=0 then raise exception 'At least one assignment must be selected'; end if;

 select count(*),count(distinct x) into total,distintos from unnest(p_asignaciones) x;
 if total<>distintos then raise exception 'Duplicate assignments are not allowed'; end if;
 if exists(select 1 from unnest(p_desplazamiento_autorizado) x where not (x=any(p_asignaciones))) then
   raise exception 'Displacement authorization contains an unselected assignment';
 end if;

 -- Lock all selected assignments in deterministic order before any delivery.
 perform 1 from public.equipacion_asignaciones a
 where a.id=any(p_asignaciones) order by a.id for update;
 if (select count(*) from public.equipacion_asignaciones a where a.id=any(p_asignaciones))<>cardinality(p_asignaciones)
 then raise exception 'One or more selected assignments do not exist'; end if;

 select count(distinct n.persona_id),count(distinct n.temporada_id)
 into n_personas,n_temporadas
 from public.equipacion_asignaciones a join public.equipacion_necesidades n on n.id=a.necesidad_id
 where a.id=any(p_asignaciones);
 if n_personas<>1 or n_temporadas<>1 then
   raise exception 'All selected assignments must belong to the same person and season';
 end if;
 select n.persona_id,n.temporada_id into persona,temporada
 from public.equipacion_asignaciones a
 join public.equipacion_necesidades n on n.id=a.necesidad_id
 where a.id=any(p_asignaciones)
 order by a.id
 limit 1;

 -- PL/pgSQL function execution is one transaction: any exception below rolls back all
 -- deliveries, stock movements, debt snapshots and displaced preparations from this call.
 foreach aid in array p_asignaciones loop
   eid:=private.equipacion_entregar_directo(aid,aid=any(p_desplazamiento_autorizado));
   asignacion_id:=aid; entrega_id:=eid; return next;
 end loop;
end $$;

revoke all on function private.equipacion_entregar_multiple(uuid[],uuid[]) from public,anon;
grant execute on function private.equipacion_entregar_multiple(uuid[],uuid[]) to authenticated,service_role;


commit;
