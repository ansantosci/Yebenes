-- Contract 099: bulk RFFM refresh summaries keep coherent totals and status.
begin;

do $$
declare v_season uuid;
begin
  select id into v_season from public.temporadas order by fecha_inicio desc limit 1;
  if v_season is null then raise exception '099 contract requires one season'; end if;

  insert into public.rffm_actualizaciones_generales(temporada_id,equipos_total,equipos_ok,equipos_error,estado)
  values(v_season,23,21,2,'parcial');

  begin
    insert into public.rffm_actualizaciones_generales(temporada_id,equipos_total,equipos_ok,equipos_error,estado)
    values(v_season,23,23,0,'parcial');
    raise exception '099 contract: incoherent partial status was accepted';
  exception when check_violation then null;
  end;
end $$;

rollback;
