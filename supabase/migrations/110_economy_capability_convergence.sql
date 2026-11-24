-- 110: Economy capability convergence.
-- Preserve ledger/business behavior; replace historical role/borrowed-capability authorization.
begin;

insert into private.capacidades(codigo,nombre,descripcion) values
 ('economy.read_all','Consultar economia del club','Consulta administrativa de cuentas, cargos, pagos y estado economico del club.'),
 ('economy.read_own','Consultar economia propia','Capacidad reservada para futura lectura propia/representada con scope backend explicito.'),
 ('economy.config.manage','Configurar economia','Gestion de cuotas, reglas, descuentos, modalidades y configuracion economica.'),
 ('economy.payments.manage','Gestionar cobros','Registro y gestion operativa de cobros y vinculacion Cluber.'),
 ('economy.adjustments.manage','Gestionar ajustes economicos','Ajustes, regularizaciones, anulaciones, devoluciones y correcciones economicas auditadas.')
on conflict (codigo) do update set nombre=excluded.nombre, descripcion=excluded.descripcion;

-- Initial matrix preserves current Club/Admin mutation/read behavior.
-- economy.read_own is intentionally NOT assigned until own/represented scope is explicitly contracted.
with matrix(rol_codigo,capacidad_codigo) as (values
 ('administrador','economy.read_all'),('administrador','economy.config.manage'),('administrador','economy.payments.manage'),('administrador','economy.adjustments.manage'),
 ('club','economy.read_all'),('club','economy.config.manage'),('club','economy.payments.manage'),('club','economy.adjustments.manage')
)
insert into private.rol_capacidades(rol_id,capacidad_codigo)
select r.id,m.capacidad_codigo from matrix m join public.roles r on r.codigo=m.rol_codigo
on conflict do nothing;

-- Remove accidental economy assignments outside the explicit initial matrix.
delete from private.rol_capacidades rc
using public.roles r
where r.id=rc.rol_id
  and rc.capacidad_codigo like 'economy.%'
  and not (
    r.codigo in ('administrador','club')
    and rc.capacidad_codigo in ('economy.read_all','economy.config.manage','economy.payments.manage','economy.adjustments.manage')
  );

-- 066 ledger tables: read and mutation are separate capabilities.
do $$
declare t text; cap text;
begin
  foreach t in array array[
    'economia_conceptos','economia_cargos','economia_ajustes','economia_pagos',
    'economia_devoluciones','economia_modalidades_equipacion','economia_cargo_equipacion'
  ] loop
    execute format('drop policy if exists %I_club_manage on public.%I',t,t);
    execute format('drop policy if exists %I_economy_read_all on public.%I',t,t);
    execute format('create policy %I_economy_read_all on public.%I for select to authenticated using (private.has_capability(''economy.read_all''))',t,t);
  end loop;

  foreach t in array array['economia_conceptos','economia_modalidades_equipacion','economia_cargo_equipacion'] loop
    execute format('drop policy if exists %I_economy_write on public.%I',t,t);
    execute format('create policy %I_economy_write on public.%I for all to authenticated using (private.has_capability(''economy.config.manage'')) with check (private.has_capability(''economy.config.manage''))',t,t);
  end loop;

  foreach t in array array['economia_cargos','economia_ajustes'] loop
    execute format('drop policy if exists %I_economy_write on public.%I',t,t);
    execute format('create policy %I_economy_write on public.%I for all to authenticated using (private.has_capability(''economy.adjustments.manage'')) with check (private.has_capability(''economy.adjustments.manage''))',t,t);
  end loop;
end $$;

-- 067 configuration/decision tables.
do $$
declare t text;
begin
  foreach t in array array[
    'economia_cuota_temporada_config','economia_cuota_categoria_config','economia_cuota_equipo_config',
    'economia_cuota_estado','economia_descuento_hermanos_reglas','economia_hermanos_vinculos_manuales',
    'economia_regularizaciones_pendientes'
  ] loop
    execute format('drop policy if exists %I_club_manage on public.%I',t,t);
    execute format('drop policy if exists %I_economy_read_all on public.%I',t,t);
    execute format('create policy %I_economy_read_all on public.%I for select to authenticated using (private.has_capability(''economy.read_all''))',t,t);
  end loop;

  foreach t in array array['economia_cuota_temporada_config','economia_cuota_categoria_config','economia_cuota_equipo_config','economia_descuento_hermanos_reglas'] loop
    execute format('drop policy if exists %I_economy_write on public.%I',t,t);
    execute format('create policy %I_economy_write on public.%I for all to authenticated using (private.has_capability(''economy.config.manage'')) with check (private.has_capability(''economy.config.manage''))',t,t);
  end loop;

  foreach t in array array['economia_hermanos_vinculos_manuales','economia_regularizaciones_pendientes'] loop
    execute format('drop policy if exists %I_economy_write on public.%I',t,t);
    execute format('create policy %I_economy_write on public.%I for all to authenticated using (private.has_capability(''economy.adjustments.manage'')) with check (private.has_capability(''economy.adjustments.manage''))',t,t);
  end loop;
end $$;

-- Preserve existing own/represented reads on legacy operational tables; only replace the admin branch.
drop policy if exists pagos_inscripcion_read_authorized on public.pagos_inscripcion;
create policy pagos_inscripcion_read_authorized on public.pagos_inscripcion for select to authenticated
using (private.has_capability('economy.read_all') or private.can_access_inscription_personal(inscripcion_id));

drop policy if exists situacion_economica_read_authorized on public.situacion_economica_inscripcion;
create policy situacion_economica_read_authorized on public.situacion_economica_inscripcion for select to authenticated
using (private.has_capability('economy.read_all') or private.can_access_inscription_personal(inscripcion_id));

drop policy if exists vinculos_clubber_club_read on public.vinculos_clubber;
create policy vinculos_clubber_club_read on public.vinculos_clubber for select to authenticated
using (
  private.has_capability('economy.read_all')
  or (tipo='tutor' and persona_id=private.current_person_id())
  or (tipo='deportista' and exists (
    select 1 from public.jugadores j
    where j.id=vinculos_clubber.jugador_id and private.can_access_player_personal(j.id)
  ))
);

-- Core ledger mutation API.
create or replace function private.economia_registrar_pago(
  p_cargo uuid,p_importe numeric,p_metodo text,p_fecha date default current_date,
  p_referencia text default null,p_observaciones text default null
) returns uuid language plpgsql security definer set search_path='' as $$
declare eid uuid; actor uuid:=auth.uid(); c public.economia_cargos%rowtype;
begin
  if actor is null or not private.has_capability('economy.payments.manage') then raise exception 'Not authorized'; end if;
  select * into c from public.economia_cargos where id=p_cargo for update;
  if c.id is null or c.estado<>'activo' then raise exception 'Active economic charge not found'; end if;
  if p_importe is null or p_importe<=0 then raise exception 'Payment amount must be positive'; end if;
  if p_metodo not in ('efectivo','transferencia','clubber','tarjeta','otro') then raise exception 'Invalid payment method'; end if;
  insert into public.economia_pagos(cargo_id,importe,metodo,fecha_pago,referencia_externa,observaciones,registrado_por)
  values(c.id,p_importe,p_metodo,coalesce(p_fecha,current_date),p_referencia,p_observaciones,actor)
  returning id into eid;
  return eid;
end $$;

create or replace function private.economia_aplicar_ajuste(
  p_cargo uuid,p_tipo text,p_importe numeric,p_nombre text,p_motivo text default null,p_origen text default 'manual'
) returns uuid language plpgsql security definer set search_path='' as $$
declare eid uuid; actor uuid:=auth.uid(); c public.economia_cargos%rowtype;
begin
  if actor is null or not private.has_capability('economy.adjustments.manage') then raise exception 'Not authorized'; end if;
  select * into c from public.economia_cargos where id=p_cargo for update;
  if c.id is null or c.estado<>'activo' then raise exception 'Active economic charge not found'; end if;
  if p_tipo not in ('descuento','regularizacion') then raise exception 'Invalid adjustment type'; end if;
  if p_importe is null or p_importe=0 then raise exception 'Adjustment amount cannot be zero'; end if;
  if nullif(trim(coalesce(p_nombre,'')),'') is null then raise exception 'Adjustment name is required'; end if;
  insert into public.economia_ajustes(cargo_id,tipo,importe,nombre,motivo,origen,creado_por)
  values(c.id,p_tipo,p_importe,trim(p_nombre),p_motivo,p_origen,actor) returning id into eid;
  return eid;
end $$;

create or replace function private.economia_anular_cargo(
  p_cargo uuid,p_motivo text
) returns void language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); c public.economia_cargos%rowtype; net numeric;
begin
  if actor is null or not private.has_capability('economy.adjustments.manage') then raise exception 'Not authorized'; end if;
  if nullif(trim(coalesce(p_motivo,'')),'') is null then raise exception 'Cancellation reason is required'; end if;
  select * into c from public.economia_cargos where id=p_cargo for update;
  if c.id is null then raise exception 'Economic charge not found'; end if;
  if c.estado='anulado' then return; end if;
  select greatest(importe_exigible,0) into net from public.economia_estado_cargos where cargo_id=c.id;
  if net<>0 then
    insert into public.economia_ajustes(cargo_id,tipo,importe,nombre,motivo,origen,creado_por)
    values(c.id,'anulacion',-net,'Anulacion de cargo',trim(p_motivo),'manual',actor);
  end if;
  update public.economia_cargos set estado='anulado',anulado_por=actor,anulado_at=now(),
    motivo_anulacion=trim(p_motivo),updated_at=now() where id=c.id;
end $$;

-- Manual sibling economic decisions.
create or replace function private.economia_decidir_regularizacion_hermano(p_id uuid,p_aplicar boolean,p_motivo text)
returns void language plpgsql security definer set search_path='' as $$
declare r public.economia_regularizaciones_pendientes%rowtype; actor uuid:=auth.uid();
begin
 if actor is null or not private.has_capability('economy.adjustments.manage') then raise exception 'Not authorized'; end if;
 if nullif(trim(coalesce(p_motivo,'')),'') is null then raise exception 'Decision reason is required'; end if;
 select * into r from public.economia_regularizaciones_pendientes where id=p_id for update;
 if r.id is null or r.estado<>'pendiente' then raise exception 'Pending sibling regularisation not found'; end if;
 if p_aplicar then
   if r.ajuste_objetivo=0 then delete from public.economia_ajustes where cargo_id=r.cargo_id and clave_origen='DESCUENTO_HERMANO';
   else update public.economia_ajustes set importe=r.ajuste_objetivo,motivo='Regularizacion aplicada por perdida de descuento' where cargo_id=r.cargo_id and clave_origen='DESCUENTO_HERMANO'; end if;
 end if;
 update public.economia_regularizaciones_pendientes set estado=case when p_aplicar then 'aplicada' else 'omitida' end,
   decidido_por=actor,decidido_at=now(),motivo_decision=trim(p_motivo) where id=r.id;
end $$;

create or replace function private.economia_vincular_hermanos_manual(p_temporada uuid,p_jugador_a uuid,p_jugador_b uuid,p_motivo text)
returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); eid uuid;
begin
 if actor is null or not private.has_capability('economy.adjustments.manage') then raise exception 'Not authorized'; end if;
 if p_jugador_a=p_jugador_b or nullif(trim(coalesce(p_motivo,'')),'') is null then raise exception 'Invalid sibling link'; end if;
 insert into public.economia_hermanos_vinculos_manuales(temporada_id,jugador_a_id,jugador_b_id,motivo,creado_por)
 values(p_temporada,p_jugador_a,p_jugador_b,trim(p_motivo),actor) returning id into eid;
 return eid;
end $$;

-- Current UI entry points.
create or replace function public.configurar_economia_equipo(
  p_equipo_id uuid,
  p_importe_inscripcion numeric,
  p_admite_fraccionamiento boolean,
  p_requiere_pago_ficha boolean,
  p_observaciones text default null
) returns uuid
language plpgsql security definer set search_path='' as $$
declare
  v_temporada_id uuid;
  v_id uuid;
  v_ins uuid;
begin
  if not private.has_capability('economy.config.manage') then
    raise exception 'No tienes capacidad para configurar importes de equipo';
  end if;
  select e.temporada_id into v_temporada_id from public.equipos e where e.id=p_equipo_id;
  if v_temporada_id is null then raise exception 'Equipo no encontrado'; end if;
  if p_requiere_pago_ficha and (p_importe_inscripcion is null or p_importe_inscripcion<=0) then raise exception 'Indica un importe mayor que cero cuando el pago es obligatorio'; end if;
  if p_importe_inscripcion is not null and p_importe_inscripcion<0 then raise exception 'El importe no puede ser negativo'; end if;
  insert into public.configuracion_economica_equipo(temporada_id,equipo_id,importe_inscripcion,admite_fraccionamiento,requiere_pago_ficha,observaciones,creado_por,actualizado_por)
  values(v_temporada_id,p_equipo_id,p_importe_inscripcion,coalesce(p_admite_fraccionamiento,false),coalesce(p_requiere_pago_ficha,true),nullif(trim(coalesce(p_observaciones,'')),''),auth.uid(),auth.uid())
  on conflict(temporada_id,equipo_id) do update set importe_inscripcion=excluded.importe_inscripcion,admite_fraccionamiento=excluded.admite_fraccionamiento,requiere_pago_ficha=excluded.requiere_pago_ficha,observaciones=excluded.observaciones,actualizado_por=auth.uid(),updated_at=now()
  returning id into v_id;
  for v_ins in select distinct a.inscripcion_id from public.asignaciones_jugador_equipo a join public.inscripciones i on i.id=a.inscripcion_id where a.equipo_id=p_equipo_id and i.temporada_id=v_temporada_id and (a.fecha_desde is null or a.fecha_desde<=current_date) and (a.fecha_hasta is null or a.fecha_hasta>=current_date)
  loop perform private.recalcular_situacion_economica(v_ins); end loop;
  return v_id;
end $$;

create or replace function public.registrar_pago_inscripcion(p_inscripcion_id uuid,p_importe numeric,p_metodo text,p_fecha_pago date default current_date,p_referencia_externa text default null,p_clubber_pago_id text default null,p_observaciones text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_sit public.situacion_economica_inscripcion%rowtype;
begin
  if not private.has_capability('economy.payments.manage') then raise exception 'No tienes capacidad para registrar pagos'; end if;
  if p_importe is null or p_importe<=0 then raise exception 'El importe debe ser mayor que cero'; end if;
  if p_metodo not in ('efectivo','clubber','otro') then raise exception 'Metodo de pago no valido'; end if;
  perform private.recalcular_situacion_economica(p_inscripcion_id);
  select * into v_sit from public.situacion_economica_inscripcion where inscripcion_id=p_inscripcion_id;
  if v_sit.configuracion_id is null then raise exception 'Configura primero el importe de inscripcion del equipo'; end if;
  insert into public.pagos_inscripcion(inscripcion_id,importe,metodo,fecha_pago,referencia_externa,clubber_pago_id,observaciones,registrado_por)
  values(p_inscripcion_id,p_importe,p_metodo,coalesce(p_fecha_pago,current_date),nullif(trim(coalesce(p_referencia_externa,'')),''),nullif(trim(coalesce(p_clubber_pago_id,'')),''),nullif(trim(coalesce(p_observaciones,'')),''),auth.uid()) returning id into v_id;
  perform private.recalcular_situacion_economica(p_inscripcion_id);
  return v_id;
end $$;

create or replace function public.anular_pago_inscripcion(p_pago_id uuid,p_motivo text)
returns void language plpgsql security definer set search_path='' as $$
declare v_ins uuid;
begin
  if not private.has_capability('economy.adjustments.manage') then raise exception 'No tienes capacidad para anular pagos'; end if;
  if trim(coalesce(p_motivo,''))='' then raise exception 'Indica el motivo de anulacion'; end if;
  update public.pagos_inscripcion set estado='anulado',observaciones=concat_ws(' · ',observaciones,'Anulado: '||trim(p_motivo)),updated_at=now() where id=p_pago_id returning inscripcion_id into v_ins;
  if v_ins is null then raise exception 'Pago no encontrado'; end if;
  perform private.recalcular_situacion_economica(v_ins);
end $$;

create or replace function public.actualizar_vinculos_clubber(p_jugador_id uuid,p_clubber_deportista_id text default null,p_tutor_persona_id uuid default null,p_clubber_tutor_id text default null)
returns void language plpgsql security definer set search_path='' as $$
begin
  if not private.has_capability('economy.payments.manage') then raise exception 'No tienes capacidad para gestionar IDs Clubber'; end if;
  if p_clubber_deportista_id is null or trim(p_clubber_deportista_id)='' then update public.vinculos_clubber set activo=false,actualizado_por=auth.uid(),updated_at=now() where tipo='deportista' and jugador_id=p_jugador_id and activo=true;
  else insert into public.vinculos_clubber(tipo,jugador_id,clubber_id,creado_por,actualizado_por) values('deportista',p_jugador_id,trim(p_clubber_deportista_id),auth.uid(),auth.uid()) on conflict(jugador_id) where tipo='deportista' and activo=true do update set clubber_id=excluded.clubber_id,actualizado_por=auth.uid(),updated_at=now(); end if;
  if p_tutor_persona_id is not null then
    if p_clubber_tutor_id is null or trim(p_clubber_tutor_id)='' then update public.vinculos_clubber set activo=false,actualizado_por=auth.uid(),updated_at=now() where tipo='tutor' and persona_id=p_tutor_persona_id and activo=true;
    else insert into public.vinculos_clubber(tipo,persona_id,clubber_id,creado_por,actualizado_por) values('tutor',p_tutor_persona_id,trim(p_clubber_tutor_id),auth.uid(),auth.uid()) on conflict(persona_id) where tipo='tutor' and activo=true do update set clubber_id=excluded.clubber_id,actualizado_por=auth.uid(),updated_at=now(); end if;
  end if;
end $$;

create or replace function public.validar_fraccionamiento_clubber(p_inscripcion_id uuid,p_validado boolean,p_observaciones text default null)
returns void language plpgsql security definer set search_path='' as $$
declare v_sit public.situacion_economica_inscripcion%rowtype; v_cfg public.configuracion_economica_equipo%rowtype;
begin
  if not private.has_capability('economy.payments.manage') then raise exception 'No tienes capacidad para validar fraccionamientos'; end if;
  perform private.recalcular_situacion_economica(p_inscripcion_id);
  select * into v_sit from public.situacion_economica_inscripcion where inscripcion_id=p_inscripcion_id;
  if not found or v_sit.configuracion_id is null then raise exception 'Configura primero la economia del equipo'; end if;
  select * into v_cfg from public.configuracion_economica_equipo where id=v_sit.configuracion_id;
  if p_validado and not v_cfg.admite_fraccionamiento then raise exception 'Este equipo no admite fraccionamiento'; end if;
  update public.situacion_economica_inscripcion set fraccionamiento_clubber_validado=coalesce(p_validado,false),fecha_validacion_fraccionamiento=case when p_validado then now() else null end,validado_fraccionamiento_por=case when p_validado then auth.uid() else null end,origen_validacion_fraccionamiento=case when p_validado then 'manual_club' else null end,updated_at=now() where inscripcion_id=p_inscripcion_id;
  insert into public.auditoria(entidad,entidad_id,accion,actor_auth_user_id,datos_nuevos) values('inscripcion',p_inscripcion_id,case when p_validado then 'fraccionamiento_clubber_validado' else 'fraccionamiento_clubber_revocado' end,auth.uid(),jsonb_build_object('observaciones',nullif(trim(coalesce(p_observaciones,'')),'')));
  perform private.recalcular_situacion_economica(p_inscripcion_id);
end $$;

-- Preserve invocation privileges: capability checks complement SQL EXECUTE privileges.
revoke all on function private.economia_registrar_pago(uuid,numeric,text,date,text,text),private.economia_aplicar_ajuste(uuid,text,numeric,text,text,text),private.economia_anular_cargo(uuid,text),private.economia_decidir_regularizacion_hermano(uuid,boolean,text),private.economia_vincular_hermanos_manual(uuid,uuid,uuid,text) from public,anon;
grant execute on function private.economia_registrar_pago(uuid,numeric,text,date,text,text),private.economia_aplicar_ajuste(uuid,text,numeric,text,text,text),private.economia_anular_cargo(uuid,text),private.economia_decidir_regularizacion_hermano(uuid,boolean,text),private.economia_vincular_hermanos_manual(uuid,uuid,uuid,text) to authenticated,service_role;

revoke execute on function public.configurar_economia_equipo(uuid,numeric,boolean,boolean,text),public.registrar_pago_inscripcion(uuid,numeric,text,date,text,text,text),public.anular_pago_inscripcion(uuid,text),public.actualizar_vinculos_clubber(uuid,text,uuid,text),public.validar_fraccionamiento_clubber(uuid,boolean,text) from public,anon;
grant execute on function public.configurar_economia_equipo(uuid,numeric,boolean,boolean,text),public.registrar_pago_inscripcion(uuid,numeric,text,date,text,text,text),public.anular_pago_inscripcion(uuid,text),public.actualizar_vinculos_clubber(uuid,text,uuid,text),public.validar_fraccionamiento_clubber(uuid,boolean,text) to authenticated,service_role;

commit;
