-- 085 - Atomic multi-assignment equipment preparation for an explicit selection.
-- Reuses 073 FIFO preparation per assignment; no existing business rule is rewritten.
begin;

create or replace function private.equipacion_preparar_multiple(
 p_asignaciones uuid[]
) returns table(asignacion_id uuid,preparacion_id uuid)
language plpgsql security definer set search_path='' as $$
declare
 actor uuid:=auth.uid();
 aid uuid;
 pid uuid;
 n_personas integer;
 n_temporadas integer;
 total integer;
 distintos integer;
begin
 if actor is null or not private.has_any_role(array['administrador','club']) then
   raise exception 'Not authorized';
 end if;
 if p_asignaciones is null or cardinality(p_asignaciones)=0 then
   raise exception 'At least one assignment must be selected';
 end if;

 select count(*),count(distinct x) into total,distintos from unnest(p_asignaciones) x;
 if total<>distintos then raise exception 'Duplicate assignments are not allowed'; end if;

 -- Lock the complete explicit selection in deterministic order before any reservation.
 perform 1
 from public.equipacion_asignaciones a
 where a.id=any(p_asignaciones)
 order by a.id
 for update;
 if (select count(*) from public.equipacion_asignaciones a where a.id=any(p_asignaciones))<>cardinality(p_asignaciones) then
   raise exception 'One or more selected assignments do not exist';
 end if;

 select count(distinct n.persona_id),count(distinct n.temporada_id)
 into n_personas,n_temporadas
 from public.equipacion_asignaciones a
 join public.equipacion_necesidades n on n.id=a.necesidad_id
 where a.id=any(p_asignaciones);
 if n_personas<>1 or n_temporadas<>1 then
   raise exception 'All selected assignments must belong to the same person and season';
 end if;

 -- One function call is one transaction. 073 performs the real FIFO reservation for each
 -- assignment; any exception rolls back every reservation made earlier in this selection.
 foreach aid in array p_asignaciones loop
   pid:=private.equipacion_preparar_asignacion_fifo(aid);
   asignacion_id:=aid;
   preparacion_id:=pid;
   return next;
 end loop;
end $$;

revoke all on function private.equipacion_preparar_multiple(uuid[]) from public,anon;
grant execute on function private.equipacion_preparar_multiple(uuid[]) to authenticated,service_role;

-- Frontend-callable wrapper. Business logic remains private.
create or replace function public.equipacion_preparar_multiple(
 p_asignaciones uuid[]
) returns table(asignacion_id uuid,preparacion_id uuid)
language sql security invoker set search_path='' as $$
  select * from private.equipacion_preparar_multiple(p_asignaciones)
$$;

revoke all on function public.equipacion_preparar_multiple(uuid[]) from public,anon;
grant execute on function public.equipacion_preparar_multiple(uuid[]) to authenticated,service_role;

commit;
