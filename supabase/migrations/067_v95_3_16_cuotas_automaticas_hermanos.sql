-- 067 - Automatic season fee resolution and sibling discounts over the 066 ledger.
begin;

alter table public.economia_ajustes add column if not exists clave_origen text;
create unique index if not exists economia_ajustes_cargo_clave_uq
  on public.economia_ajustes(cargo_id,clave_origen) where clave_origen is not null;

create table if not exists public.economia_cuota_temporada_config (
  temporada_id uuid primary key references public.temporadas(id) on delete restrict,
  importe_general numeric(10,2) check (importe_general is null or importe_general>=0),
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);
create table if not exists public.economia_cuota_categoria_config (
  temporada_id uuid not null references public.temporadas(id) on delete restrict,
  categoria_id uuid not null references public.categorias(id) on delete restrict,
  importe numeric(10,2) check (importe is null or importe>=0),
  exenta boolean not null default false,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  primary key(temporada_id,categoria_id),
  check (not exenta or importe is null)
);
create table if not exists public.economia_cuota_equipo_config (
  temporada_id uuid not null references public.temporadas(id) on delete restrict,
  equipo_id uuid not null references public.equipos(id) on delete restrict,
  importe numeric(10,2) check (importe is null or importe>=0),
  exenta boolean not null default false,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  primary key(temporada_id,equipo_id),
  check (not exenta or importe is null)
);

create table if not exists public.economia_cuota_estado (
  persona_id uuid not null references public.personas(id) on delete restrict,
  temporada_id uuid not null references public.temporadas(id) on delete restrict,
  cargo_id uuid references public.economia_cargos(id) on delete set null,
  equipo_id uuid references public.equipos(id) on delete set null,
  estado_calculo text not null check (estado_calculo in ('sin_equipo','pendiente_configuracion','calculada')),
  importe_objetivo numeric(10,2),
  origen_regla text check (origen_regla is null or origen_regla in ('equipo','categoria','temporada','exento_equipo','exento_categoria')),
  regla_id uuid,
  calculado_at timestamptz not null default now(),
  primary key(persona_id,temporada_id)
);

create table if not exists public.economia_descuento_hermanos_reglas (
  temporada_id uuid not null references public.temporadas(id) on delete restrict,
  posicion integer not null check (posicion>=2),
  tipo text not null check (tipo in ('fijo','porcentaje')),
  valor numeric(10,2) not null check (valor>=0),
  activo boolean not null default true,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  primary key(temporada_id,posicion),
  check (tipo<>'porcentaje' or valor<=100)
);

create table if not exists public.economia_hermanos_vinculos_manuales (
  id uuid primary key default gen_random_uuid(),
  temporada_id uuid not null references public.temporadas(id) on delete restrict,
  jugador_a_id uuid not null references public.jugadores(id) on delete restrict,
  jugador_b_id uuid not null references public.jugadores(id) on delete restrict,
  activo boolean not null default true,
  motivo text not null check (length(trim(motivo))>0),
  creado_por uuid not null references auth.users(id) on delete restrict,
  revocado_por uuid references auth.users(id) on delete set null,
  revocado_at timestamptz,
  motivo_revocacion text,
  created_at timestamptz not null default now(),
  check (jugador_a_id<>jugador_b_id),
  check ((activo and revocado_at is null) or (not activo and revocado_at is not null and nullif(trim(coalesce(motivo_revocacion,'')),'') is not null))
);
create unique index if not exists economia_hermanos_vinculos_manual_activo_uq
on public.economia_hermanos_vinculos_manuales(temporada_id,least(jugador_a_id,jugador_b_id),greatest(jugador_a_id,jugador_b_id))
where activo;

create table if not exists public.economia_regularizaciones_pendientes (
  id uuid primary key default gen_random_uuid(),
  persona_id uuid not null references public.personas(id) on delete restrict,
  temporada_id uuid not null references public.temporadas(id) on delete restrict,
  cargo_id uuid not null references public.economia_cargos(id) on delete restrict,
  tipo text not null check (tipo='perdida_descuento_hermano'),
  importe_calculado numeric(10,2) not null check (importe_calculado>0),
  ajuste_objetivo numeric(10,2) not null,
  causa text not null,
  estado text not null default 'pendiente' check (estado in ('pendiente','aplicada','omitida')),
  decidido_por uuid references auth.users(id) on delete set null,
  decidido_at timestamptz,
  motivo_decision text,
  created_at timestamptz not null default now(),
  check ((estado='pendiente' and decidido_at is null) or
         (estado in ('aplicada','omitida') and decidido_at is not null and nullif(trim(coalesce(motivo_decision,'')),'') is not null))
);
create unique index if not exists economia_regularizacion_hermano_pendiente_uq
on public.economia_regularizaciones_pendientes(cargo_id,tipo) where estado='pendiente';

create or replace function private.economia_resolver_cuota(p_equipo uuid)
returns table(estado text,importe numeric,origen text,regla_id uuid)
language plpgsql stable security definer set search_path='' as $$
declare e public.equipos%rowtype; x record;
begin
 select * into e from public.equipos where id=p_equipo;
 if e.id is null then return query select 'pendiente_configuracion'::text,null::numeric,null::text,null::uuid; return; end if;
 select c.exenta,c.importe into x from public.economia_cuota_equipo_config c where c.temporada_id=e.temporada_id and c.equipo_id=e.id;
 if found then
   if x.exenta then return query select 'calculada',0::numeric,'exento_equipo',e.id; return; end if;
   if x.importe is not null then return query select 'calculada',x.importe,'equipo',e.id; return; end if;
 end if;
 select c.exenta,c.importe into x from public.economia_cuota_categoria_config c where c.temporada_id=e.temporada_id and c.categoria_id=e.categoria_id;
 if found then
   if x.exenta then return query select 'calculada',0::numeric,'exento_categoria',e.categoria_id; return; end if;
   if x.importe is not null then return query select 'calculada',x.importe,'categoria',e.categoria_id; return; end if;
 end if;
 select c.importe_general into x from public.economia_cuota_temporada_config c where c.temporada_id=e.temporada_id;
 if found and x.importe_general is not null then return query select 'calculada',x.importe_general,'temporada',e.temporada_id; return; end if;
 return query select 'pendiente_configuracion'::text,null::numeric,null::text,null::uuid;
end $$;

create or replace function private.economia_recalcular_cuota_inscripcion(p_inscripcion uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare i public.inscripciones%rowtype; j public.jugadores%rowtype; a public.asignaciones_jugador_equipo%rowtype;
        rr record; cid uuid; concept uuid; base numeric; delta numeric;
begin
 select * into i from public.inscripciones where id=p_inscripcion;
 if i.id is null then return null; end if;
 select * into j from public.jugadores where id=i.jugador_id;
 select * into a from public.asignaciones_jugador_equipo x where x.inscripcion_id=i.id
   and x.fecha_desde<=current_date and (x.fecha_hasta is null or x.fecha_hasta>=current_date)
   order by x.fecha_desde desc,x.created_at desc limit 1;
 if a.id is null then
   insert into public.economia_cuota_estado(persona_id,temporada_id,equipo_id,estado_calculo,calculado_at)
   values(j.persona_id,i.temporada_id,null,'sin_equipo',now())
   on conflict(persona_id,temporada_id) do update set equipo_id=null,estado_calculo='sin_equipo',calculado_at=now();
   return null;
 end if;
 select * into rr from private.economia_resolver_cuota(a.equipo_id);
 select id into cid from public.economia_cargos where persona_id=j.persona_id and temporada_id=i.temporada_id and clave_origen='CUOTA_TEMPORADA';
 if rr.estado='pendiente_configuracion' then
   insert into public.economia_cuota_estado(persona_id,temporada_id,cargo_id,equipo_id,estado_calculo,importe_objetivo,origen_regla,regla_id,calculado_at)
   values(j.persona_id,i.temporada_id,cid,a.equipo_id,'pendiente_configuracion',null,null,null,now())
   on conflict(persona_id,temporada_id) do update set cargo_id=excluded.cargo_id,equipo_id=excluded.equipo_id,
     estado_calculo='pendiente_configuracion',importe_objetivo=null,origen_regla=null,regla_id=null,calculado_at=now();
   return cid;
 end if;
 if cid is null then
   select id into concept from public.economia_conceptos where codigo='CUOTA_TEMPORADA';
   insert into public.economia_cargos(persona_id,temporada_id,concepto_id,importe_base,descripcion,origen,equipo_origen_id,inscripcion_id,clave_origen)
   values(j.persona_id,i.temporada_id,concept,rr.importe,'Cuota de temporada','asignacion_equipo',a.equipo_id,i.id,'CUOTA_TEMPORADA') returning id into cid;
 else
   select importe_base into base from public.economia_cargos where id=cid;
   delta:=rr.importe-base;
   if delta=0 then delete from public.economia_ajustes where cargo_id=cid and clave_origen='CUOTA_RECALCULO';
   else
     insert into public.economia_ajustes(cargo_id,tipo,importe,nombre,motivo,origen,clave_origen)
     values(cid,'regularizacion',delta,'Regularizacion de cuota','Recalculo por configuracion/equipo','automatico','CUOTA_RECALCULO')
     on conflict(cargo_id,clave_origen) where clave_origen is not null do update set importe=excluded.importe,motivo=excluded.motivo,origen='automatico';
   end if;
   update public.economia_cargos set equipo_origen_id=a.equipo_id,inscripcion_id=i.id,updated_at=now() where id=cid;
 end if;
 insert into public.economia_cuota_estado(persona_id,temporada_id,cargo_id,equipo_id,estado_calculo,importe_objetivo,origen_regla,regla_id,calculado_at)
 values(j.persona_id,i.temporada_id,cid,a.equipo_id,'calculada',rr.importe,rr.origen,rr.regla_id,now())
 on conflict(persona_id,temporada_id) do update set cargo_id=excluded.cargo_id,equipo_id=excluded.equipo_id,estado_calculo='calculada',
   importe_objetivo=excluded.importe_objetivo,origen_regla=excluded.origen_regla,regla_id=excluded.regla_id,calculado_at=now();
 return cid;
end $$;

-- Active sibling candidates: automatic only through a shared current representative; manual links are explicit exceptions.
create or replace function private.economia_hermanos_activos(p_persona uuid,p_temporada uuid)
returns table(persona_id uuid,jugador_id uuid,primera_asignacion date,fuente text)
language sql stable security definer set search_path='' as $$
with me as (
 select j.id jugador_id from public.jugadores j where j.persona_id=p_persona
), active as (
 select distinct j.persona_id,j.id jugador_id,min(a.fecha_desde) over(partition by j.id) primera_asignacion
 from public.jugadores j
 join public.inscripciones i on i.jugador_id=j.id and i.temporada_id=p_temporada and i.estado<>'cancelada'
 join public.asignaciones_jugador_equipo a on a.inscripcion_id=i.id and a.fecha_desde<=current_date and (a.fecha_hasta is null or a.fecha_hasta>=current_date)
 join public.persona_participaciones_temporada pt on pt.persona_id=j.persona_id and pt.temporada_id=p_temporada and pt.faceta='jugador' and pt.estado='aceptada'
), auto_ids as (
 select distinct a2.jugador_id
 from me m join public.representaciones_jugador r1 on r1.jugador_id=m.jugador_id and r1.fecha_desde<=current_date and (r1.fecha_hasta is null or r1.fecha_hasta>=current_date)
 join public.representaciones_jugador r2 on r2.representante_persona_id=r1.representante_persona_id and r2.fecha_desde<=current_date and (r2.fecha_hasta is null or r2.fecha_hasta>=current_date)
 join active a2 on a2.jugador_id=r2.jugador_id
), manual_ids as (
 with recursive links(a,b) as (
   select jugador_a_id,jugador_b_id from public.economia_hermanos_vinculos_manuales where temporada_id=p_temporada and activo
   union all select jugador_b_id,jugador_a_id from public.economia_hermanos_vinculos_manuales where temporada_id=p_temporada and activo
 ), reach(jid) as (
   select jugador_id from me union
   select l.b from reach r join links l on l.a=r.jid
 ) select jid from reach
), ids as (select jugador_id,'automatico' fuente from auto_ids union select jid,'manual' from manual_ids)
select a.persona_id,a.jugador_id,a.primera_asignacion,min(ids.fuente) fuente from ids join active a on a.jugador_id=ids.jugador_id
group by a.persona_id,a.jugador_id,a.primera_asignacion
union
select a.persona_id,a.jugador_id,a.primera_asignacion,'propio' from active a where a.persona_id=p_persona
$$;

create or replace function private.economia_recalcular_descuentos_hermanos(p_persona uuid,p_temporada uuid,p_causa text default 'recalculo')
returns void language plpgsql security definer set search_path='' as $$
declare rec record; pos integer:=0; cid uuid; cuota numeric; regla record; objetivo numeric; actual numeric; delta numeric;
begin
 for rec in select * from private.economia_hermanos_activos(p_persona,p_temporada) order by primera_asignacion,jugador_id loop
   pos:=pos+1;
   select c.id,e.importe_objetivo into cid,cuota from public.economia_cargos c join public.economia_cuota_estado e on e.cargo_id=c.id
    where c.persona_id=rec.persona_id and c.temporada_id=p_temporada and c.clave_origen='CUOTA_TEMPORADA' and e.estado_calculo='calculada';
   if cid is null then continue; end if;
   select * into regla from public.economia_descuento_hermanos_reglas r where r.temporada_id=p_temporada and r.posicion=pos and r.activo;
   if regla.temporada_id is null then objetivo:=0;
   elsif regla.tipo='fijo' then objetivo:=-least(regla.valor,cuota);
   else objetivo:=-round((cuota*regla.valor/100.0)::numeric,2); end if;
   select coalesce(importe,0) into actual from public.economia_ajustes where cargo_id=cid and clave_origen='DESCUENTO_HERMANO';
   delta:=objetivo-actual;
   if delta>0 and p_causa='baja_hermano' then
     insert into public.economia_regularizaciones_pendientes(persona_id,temporada_id,cargo_id,tipo,importe_calculado,ajuste_objetivo,causa)
     values(rec.persona_id,p_temporada,cid,'perdida_descuento_hermano',delta,objetivo,'Baja de hermano activo')
     on conflict(cargo_id,tipo) where estado='pendiente' do update set importe_calculado=excluded.importe_calculado,ajuste_objetivo=excluded.ajuste_objetivo,causa=excluded.causa;
   else
     delete from public.economia_regularizaciones_pendientes where cargo_id=cid and tipo='perdida_descuento_hermano' and estado='pendiente';
     if objetivo=0 then delete from public.economia_ajustes where cargo_id=cid and clave_origen='DESCUENTO_HERMANO';
     else insert into public.economia_ajustes(cargo_id,tipo,importe,nombre,motivo,origen,clave_origen)
       values(cid,'descuento',objetivo,'Descuento por hermanos','Posicion activa '||pos,'automatico','DESCUENTO_HERMANO')
       on conflict(cargo_id,clave_origen) where clave_origen is not null do update set importe=excluded.importe,motivo=excluded.motivo,origen='automatico'; end if;
   end if;
 end loop;
end $$;

create or replace function private.economia_decidir_regularizacion_hermano(p_id uuid,p_aplicar boolean,p_motivo text)
returns void language plpgsql security definer set search_path='' as $$
declare r public.economia_regularizaciones_pendientes%rowtype; actor uuid:=auth.uid();
begin
 if actor is null or not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
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
 if actor is null or not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
 if p_jugador_a=p_jugador_b or nullif(trim(coalesce(p_motivo,'')),'') is null then raise exception 'Invalid sibling link'; end if;
 insert into public.economia_hermanos_vinculos_manuales(temporada_id,jugador_a_id,jugador_b_id,motivo,creado_por)
 values(p_temporada,p_jugador_a,p_jugador_b,trim(p_motivo),actor) returning id into eid;
 return eid;
end $$;

create or replace function private.economia_recalcular_temporada(p_temporada uuid)
returns void language plpgsql security definer set search_path='' as $$
declare r record;
begin
 for r in select i.id,j.persona_id from public.inscripciones i join public.jugadores j on j.id=i.jugador_id where i.temporada_id=p_temporada and i.estado<>'cancelada' loop
   perform private.economia_recalcular_cuota_inscripcion(r.id);
 end loop;
 for r in select distinct j.persona_id from public.inscripciones i join public.jugadores j on j.id=i.jugador_id where i.temporada_id=p_temporada and i.estado<>'cancelada' loop
   perform private.economia_recalcular_descuentos_hermanos(r.persona_id,p_temporada,'configuracion');
 end loop;
end $$;

create or replace function private.economia_trg_asignacion()
returns trigger language plpgsql security definer set search_path='' as $$
declare iid uuid; tid uuid; pid uuid;
begin
 iid:=case when tg_op='DELETE' then old.inscripcion_id else new.inscripcion_id end;
 select i.temporada_id,j.persona_id into tid,pid from public.inscripciones i join public.jugadores j on j.id=i.jugador_id where i.id=iid;
 perform private.economia_recalcular_cuota_inscripcion(iid);
 perform private.economia_recalcular_descuentos_hermanos(pid,tid,'asignacion');
 if tg_op='DELETE' then return old; else return new; end if;
end $$;
drop trigger if exists economia_067_asignacion on public.asignaciones_jugador_equipo;
create trigger economia_067_asignacion after insert or update or delete on public.asignaciones_jugador_equipo
for each row execute function private.economia_trg_asignacion();

create or replace function private.economia_trg_participacion_baja()
returns trigger language plpgsql security definer set search_path='' as $$
declare r record;
begin
 if new.faceta='jugador' and new.estado='baja' and old.estado is distinct from new.estado then
   for r in select distinct h.persona_id from private.economia_hermanos_activos(new.persona_id,new.temporada_id) h loop
     perform private.economia_recalcular_descuentos_hermanos(r.persona_id,new.temporada_id,'baja_hermano');
   end loop;
 end if;
 return new;
end $$;
drop trigger if exists economia_067_participacion_baja on public.persona_participaciones_temporada;
create trigger economia_067_participacion_baja after update of estado on public.persona_participaciones_temporada
for each row execute function private.economia_trg_participacion_baja();

create or replace function private.economia_trg_config_recalcular()
returns trigger language plpgsql security definer set search_path='' as $$
declare tid uuid;
begin
 if tg_op='DELETE' then tid:=old.temporada_id; else tid:=new.temporada_id; end if;
 perform private.economia_recalcular_temporada(tid);
 if tg_op='DELETE' then return old; else return new; end if;
end $$;
create trigger economia_067_cfg_temporada after insert or update or delete on public.economia_cuota_temporada_config for each row execute function private.economia_trg_config_recalcular();
create trigger economia_067_cfg_categoria after insert or update or delete on public.economia_cuota_categoria_config for each row execute function private.economia_trg_config_recalcular();
create trigger economia_067_cfg_equipo after insert or update or delete on public.economia_cuota_equipo_config for each row execute function private.economia_trg_config_recalcular();
create trigger economia_067_cfg_hermanos after insert or update or delete on public.economia_descuento_hermanos_reglas for each row execute function private.economia_trg_config_recalcular();

-- Security: Club/Admin manages configuration and decisions; mutation is never available to anon.
do $$ declare t text; begin
 foreach t in array array['economia_cuota_temporada_config','economia_cuota_categoria_config','economia_cuota_equipo_config','economia_cuota_estado','economia_descuento_hermanos_reglas','economia_hermanos_vinculos_manuales','economia_regularizaciones_pendientes'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('create policy %I_club_manage on public.%I to authenticated using (private.has_any_role(array[''administrador'',''club''])) with check (private.has_any_role(array[''administrador'',''club'']))',t,t);
 end loop;
end $$;
grant select,insert,update,delete on public.economia_cuota_temporada_config,public.economia_cuota_categoria_config,public.economia_cuota_equipo_config,
 public.economia_descuento_hermanos_reglas,public.economia_hermanos_vinculos_manuales,public.economia_regularizaciones_pendientes to authenticated;
grant select on public.economia_cuota_estado to authenticated;
grant all on public.economia_cuota_temporada_config,public.economia_cuota_categoria_config,public.economia_cuota_equipo_config,public.economia_cuota_estado,
 public.economia_descuento_hermanos_reglas,public.economia_hermanos_vinculos_manuales,public.economia_regularizaciones_pendientes to service_role;
revoke all on public.economia_cuota_temporada_config,public.economia_cuota_categoria_config,public.economia_cuota_equipo_config,public.economia_cuota_estado,
 public.economia_descuento_hermanos_reglas,public.economia_hermanos_vinculos_manuales,public.economia_regularizaciones_pendientes from anon;

revoke all on function private.economia_decidir_regularizacion_hermano(uuid,boolean,text),private.economia_vincular_hermanos_manual(uuid,uuid,uuid,text) from public,anon;
grant execute on function private.economia_decidir_regularizacion_hermano(uuid,boolean,text),private.economia_vincular_hermanos_manual(uuid,uuid,uuid,text) to authenticated,service_role;
revoke all on function private.economia_resolver_cuota(uuid),private.economia_recalcular_cuota_inscripcion(uuid),private.economia_hermanos_activos(uuid,uuid),
 private.economia_recalcular_descuentos_hermanos(uuid,uuid,text),private.economia_recalcular_temporada(uuid),private.economia_trg_asignacion(),private.economia_trg_participacion_baja(),private.economia_trg_config_recalcular() from public,anon,authenticated;
grant execute on function private.economia_resolver_cuota(uuid),private.economia_recalcular_cuota_inscripcion(uuid),private.economia_hermanos_activos(uuid,uuid),
 private.economia_recalcular_descuentos_hermanos(uuid,uuid,text),private.economia_recalcular_temporada(uuid),private.economia_trg_asignacion(),private.economia_trg_participacion_baja(),private.economia_trg_config_recalcular() to service_role;

commit;
