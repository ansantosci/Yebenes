-- Contract 098: RFFM snapshots are JSON, deduplicated by integration+hash and readable only through RLS.
begin;

do $$
declare v_integration uuid; v_snapshot uuid; v_hash text := repeat('a',64);
begin
  select id into v_integration from public.equipo_integraciones_federacion limit 1;
  if v_integration is null then raise exception '098 contract requires one federation integration'; end if;

  insert into public.rffm_resultados_snapshots(integracion_id,payload,payload_hash)
  values(v_integration,'{"teamName":"CONTRACT"}'::jsonb,v_hash)
  returning id into v_snapshot;

  insert into public.rffm_resultados_estado(integracion_id,ultimo_snapshot_id,ultimo_intento_at,ultimo_exito_at)
  values(v_integration,v_snapshot,now(),now())
  on conflict(integracion_id) do update set ultimo_snapshot_id=excluded.ultimo_snapshot_id,ultimo_exito_at=excluded.ultimo_exito_at;

  begin
    insert into public.rffm_resultados_snapshots(integracion_id,payload,payload_hash)
    values(v_integration,'{"teamName":"DUPLICATE"}'::jsonb,v_hash);
    raise exception '098 contract: duplicate integration/hash was accepted';
  exception when unique_violation then null;
  end;

  if (select jsonb_typeof(payload) from public.rffm_resultados_snapshots where id=v_snapshot) <> 'object' then
    raise exception '098 contract: payload must remain a JSON object';
  end if;
end $$;

rollback;
