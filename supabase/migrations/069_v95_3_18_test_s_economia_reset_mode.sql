-- 069 - TEST-S economic reset mode without schema DDL in seed.
-- Triggers remain installed; during an administrative TEST-S teardown they short-circuit
-- based on a transaction-local PostgreSQL setting.
begin;

create or replace function private.economia_trg_asignacion()
returns trigger language plpgsql security definer set search_path='' as $$
declare iid uuid; tid uuid; pid uuid;
begin
 if current_setting('yebenes.test_s_reset_mode',true)='on' then
   if tg_op='DELETE' then return old; else return new; end if;
 end if;
 iid:=case when tg_op='DELETE' then old.inscripcion_id else new.inscripcion_id end;
 select i.temporada_id,j.persona_id into tid,pid from public.inscripciones i join public.jugadores j on j.id=i.jugador_id where i.id=iid;
 perform private.economia_recalcular_cuota_inscripcion(iid);
 perform private.economia_recalcular_descuentos_hermanos(pid,tid,'asignacion');
 if tg_op='DELETE' then return old; else return new; end if;
end $$;

create or replace function private.economia_trg_participacion_baja()
returns trigger language plpgsql security definer set search_path='' as $$
declare r record;
begin
 if current_setting('yebenes.test_s_reset_mode',true)='on' then return new; end if;
 if new.faceta='jugador' and new.estado='baja' and old.estado is distinct from new.estado then
   for r in select distinct h.persona_id from private.economia_hermanos_activos(new.persona_id,new.temporada_id) h loop
     perform private.economia_recalcular_descuentos_hermanos(r.persona_id,new.temporada_id,'baja_hermano');
   end loop;
 end if;
 return new;
end $$;

create or replace function private.economia_trg_config_recalcular()
returns trigger language plpgsql security definer set search_path='' as $$
declare tid uuid;
begin
 if current_setting('yebenes.test_s_reset_mode',true)='on' then
   if tg_op='DELETE' then return old; else return new; end if;
 end if;
 if tg_op='DELETE' then tid:=old.temporada_id; else tid:=new.temporada_id; end if;
 perform private.economia_recalcular_temporada(tid);
 if tg_op='DELETE' then return old; else return new; end if;
end $$;

create or replace function private.test_set_economia_reset_mode(p_enabled boolean)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
begin
  if current_user not in ('postgres','service_role') and session_user not in ('postgres','service_role') then
    raise exception 'Not authorized';
  end if;
  perform set_config('yebenes.test_s_reset_mode',case when p_enabled then 'on' else 'off' end,true);
  return p_enabled;
end $$;

revoke all on function private.test_set_economia_reset_mode(boolean) from public,anon,authenticated;
grant execute on function private.test_set_economia_reset_mode(boolean) to service_role;

commit;
