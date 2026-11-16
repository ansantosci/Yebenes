-- 088_security_hardening_contract.sql
do $$
declare
  r record;
begin
  -- No anonymous access to economic views.
  if has_table_privilege('anon','public.economia_estado_cargos','SELECT') then
    raise exception '088: anon still has SELECT on economia_estado_cargos';
  end if;
  if has_table_privilege('anon','public.economia_cuenta_persona_temporada','SELECT') then
    raise exception '088: anon still has SELECT on economia_cuenta_persona_temporada';
  end if;

  -- Signed-in access required by the application remains available.
  if not has_table_privilege('authenticated','public.economia_estado_cargos','SELECT')
     or not has_table_privilege('authenticated','public.economia_cuenta_persona_temporada','SELECT') then
    raise exception '088: authenticated lost economic-view SELECT';
  end if;

  -- Representative sensitive RPCs must not be callable anonymously.
  if has_function_privilege('anon','public.actualizar_perfiles_persona_admin(uuid,boolean,boolean,boolean,boolean)','EXECUTE')
     or has_function_privilege('anon','public.configurar_economia_equipo(uuid,numeric,boolean,boolean,text)','EXECUTE')
     or has_function_privilege('anon','public.registrar_pago_inscripcion(uuid,numeric,text,date,text,text,text)','EXECUTE')
     or has_function_privilege('anon','public.guardar_persona_admin(uuid,text,text,text,text,text,date,boolean)','EXECUTE')
     or has_function_privilege('anon','public.vincular_auth_persona_por_email_admin(uuid)','EXECUTE') then
    raise exception '088: sensitive RPC remains executable by anon';
  end if;

  -- Internal Equipaciones helpers found exposed by default ACL must be closed.
  if has_function_privilege('anon','private.equipacion_ajustar_stock(uuid,uuid,text,integer)','EXECUTE')
     or has_function_privilege('anon','private.equipacion_reservar_asignacion(uuid)','EXECUTE')
     or has_function_privilege('anon','private.equipacion_recalcular_estado_pedido(uuid)','EXECUTE') then
    raise exception '088: internal Equipaciones helper remains executable by anon';
  end if;

  -- Deliberate exception: pre-auth client telemetry remains callable by anon.
  if not has_function_privilege(
      'anon',
      'public.registrar_telemetria_sesion(uuid,text,text,boolean,text,boolean,jsonb)',
      'EXECUTE'
  ) then
    raise exception '088: pre-auth telemetry unexpectedly lost anon EXECUTE';
  end if;

  -- Duplicate index must be gone while the UNIQUE constraint-backed index remains.
  if to_regclass('public.entrenadores_persona_id_uniq') is not null then
    raise exception '088: duplicate entrenadores_persona_id_uniq still exists';
  end if;
  if to_regclass('public.entrenadores_persona_id_key') is null then
    raise exception '088: constraint-backed entrenadores_persona_id_key missing';
  end if;

  -- Full regression: every SECURITY DEFINER that was intentionally closed by 088
  -- must remain unavailable to anon, except the documented telemetry exception.
  for r in
    select p.oid, n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) args
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where p.prosecdef
      and n.nspname in ('public','private')
      and has_function_privilege('anon',p.oid,'EXECUTE')
      and not (
        n.nspname='public'
        and p.proname='registrar_telemetria_sesion'
        and pg_get_function_identity_arguments(p.oid)=
          'p_device_id uuid, p_event text, p_app_version text, p_auth_token_present boolean, p_visibility text, p_online boolean, p_metadata jsonb'
      )
  loop
    raise exception '088: unexpected anon SECURITY DEFINER remains: %.%(%)',
      r.nspname,r.proname,r.args;
  end loop;
end $$;

select 'security_hardening_acl_views_indexes_contract' contract,'PASS' result;
