-- Contract 100: RFFM coach authorization primitives and RLS policies exist.
begin;

do $$
begin
  if to_regprocedure('private.can_read_rffm_equipo(uuid)') is null then
    raise exception '100 contract: private.can_read_rffm_equipo(uuid) missing';
  end if;
  if to_regprocedure('public.puede_consultar_rffm_equipo(uuid)') is null then
    raise exception '100 contract: public.puede_consultar_rffm_equipo(uuid) missing';
  end if;
  if to_regprocedure('public.puede_gestionar_rffm()') is null then
    raise exception '100 contract: public.puede_gestionar_rffm() missing';
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='rffm_resultados_snapshots'
      and policyname='rffm_resultados_snapshots_authorized_read'
  ) then raise exception '100 contract: snapshots authorized read policy missing'; end if;
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='rffm_resultados_estado'
      and policyname='rffm_resultados_estado_authorized_read'
  ) then raise exception '100 contract: state authorized read policy missing'; end if;
end $$;

rollback;
