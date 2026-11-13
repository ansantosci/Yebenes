-- 082 - Public API wrapper for atomic multi-item equipment delivery.
-- PostgREST/Supabase RPC exposes the public API schema; business logic remains private.
begin;

create or replace function public.equipacion_entregar_multiple(
 p_asignaciones uuid[],
 p_desplazamiento_autorizado uuid[] default array[]::uuid[]
) returns table(asignacion_id uuid,entrega_id uuid)
language sql security invoker set search_path='' as $$
  select * from private.equipacion_entregar_multiple(p_asignaciones,p_desplazamiento_autorizado)
$$;

revoke all on function public.equipacion_entregar_multiple(uuid[],uuid[]) from public,anon;
grant execute on function public.equipacion_entregar_multiple(uuid[],uuid[]) to authenticated,service_role;

commit;
