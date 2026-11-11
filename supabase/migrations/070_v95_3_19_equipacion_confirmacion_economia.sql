-- 070 - Confirmed equipment request locks family editing and creates/reconciles equipment debt.
begin;

-- Audit confirmed-request changes made by Club/Admin.
create table if not exists public.equipacion_solicitud_cambios (
  id uuid primary key default gen_random_uuid(),
  necesidad_id uuid not null references public.equipacion_necesidades(id) on delete restrict,
  persona_id uuid not null references public.personas(id) on delete restrict,
  temporada_id uuid not null references public.temporadas(id) on delete restrict,
  campo text not null,
  valor_anterior jsonb,
  valor_nuevo jsonb,
  motivo text not null check (length(trim(motivo))>0),
  pedido_cursado boolean not null default false,
  cambiado_por uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);


-- 056 guard updated for an explicit draft -> confirmed transition.
create or replace function private.equipacion_validar_necesidad_confirmada()
returns trigger language plpgsql set search_path=public,private as $$
declare v_estado text;
begin
 if new.persona_temporada_id is null then
   if new.confirmada_at is not null then raise exception 'Confirmed equipment need requires validated season person'; end if;
   return new;
 end if;
 select estado into v_estado from public.equipacion_personas_temporada
 where id=new.persona_temporada_id and persona_id=new.persona_id and temporada_id=new.temporada_id and faceta=new.faceta;
 if v_estado is distinct from 'validada' then raise exception 'Equipment need requires a club-validated person for the season'; end if;
 if new.confirmada_at is not null and not exists(
   select 1 from public.equipacion_tallas_persona t
   where t.persona_id=new.persona_id and t.temporada_id=new.temporada_id and t.confirmada_at is not null
 ) then raise exception 'Confirmed equipment need requires confirmed sizes'; end if;
 return new;
end $$;

-- Family can edit a size draft, never a confirmed size request.
drop policy if exists equipacion_tallas_write on public.equipacion_tallas_persona;
create policy equipacion_tallas_write on public.equipacion_tallas_persona
for all to authenticated
using (
  private.has_any_role(array['administrador','club'])
  or (confirmada_at is null and private.can_manage_equipacion_tallas(persona_id))
)
with check (
  private.has_any_role(array['administrador','club'])
  or (confirmada_at is null and private.can_manage_equipacion_tallas(persona_id))
);

drop policy if exists equipacion_tallas_excepcion_write on public.equipacion_tallas_excepcion;
create policy equipacion_tallas_excepcion_write on public.equipacion_tallas_excepcion
for all to authenticated
using (
  exists (
    select 1 from public.equipacion_tallas_persona t
    where t.id=talla_persona_id
      and (private.has_any_role(array['administrador','club'])
           or (t.confirmada_at is null and private.can_manage_equipacion_tallas(t.persona_id)))
  )
)
with check (
  exists (
    select 1 from public.equipacion_tallas_persona t
    where t.id=talla_persona_id
      and (private.has_any_role(array['administrador','club'])
           or (t.confirmada_at is null and private.can_manage_equipacion_tallas(t.persona_id)))
  )
);

-- Resolve one active economic modality from the confirmed reuse choice.
-- Current model deliberately supports the two agreed commercial cases; configuration supplies prices.
create or replace function private.equipacion_resolver_modalidad_economica(p_necesidad uuid)
returns uuid
language plpgsql stable security definer set search_path='' as $$
declare n public.equipacion_necesidades%rowtype; mid uuid; cnt integer;
begin
 select * into n from public.equipacion_necesidades where id=p_necesidad;
 if n.id is null or n.faceta<>'jugador' or n.confirmada_at is null then return null; end if;

 select count(*),min(m.id) into cnt,mid
 from public.economia_modalidades_equipacion m
 where m.temporada_id=n.temporada_id and m.activo
   and m.requiere_partido=true
   and m.requiere_entrenamiento=(not n.reutiliza_entrenamiento);

 if cnt=0 then raise exception 'No economic equipment modality configured for confirmed need';
 elsif cnt>1 then raise exception 'Ambiguous economic equipment modality for confirmed need';
 end if;
 return mid;
end $$;

-- Idempotently reconcile the single equipment obligation attached to a confirmed need.
create or replace function private.equipacion_recalcular_cargo(p_necesidad uuid)
returns uuid
language plpgsql security definer set search_path='' as $$
declare n public.equipacion_necesidades%rowtype; mid uuid; m public.economia_modalidades_equipacion%rowtype;
        cid uuid; concept uuid; base numeric; delta numeric; delivered boolean;
begin
 select * into n from public.equipacion_necesidades where id=p_necesidad for update;
 if n.id is null then raise exception 'Equipment need not found'; end if;
 if n.faceta<>'jugador' or n.confirmada_at is null or n.estado='cancelada' then return null; end if;

 select exists(
   select 1 from public.equipacion_asignaciones a
   join public.equipacion_entregas d on d.asignacion_id=a.id
   where a.necesidad_id=n.id
 ) into delivered;

 mid:=private.equipacion_resolver_modalidad_economica(n.id);
 select * into m from public.economia_modalidades_equipacion where id=mid;
 select c.id into cid from public.economia_cargos c
 where c.persona_id=n.persona_id and c.temporada_id=n.temporada_id
   and c.clave_origen='EQUIPACION_NECESIDAD:'||n.id::text;

 if cid is null then
   if delivered then raise exception 'Cannot create/rewrite equipment obligation after delivery'; end if;
   select id into concept from public.economia_conceptos where codigo='EQUIPACION';
   insert into public.economia_cargos(persona_id,temporada_id,concepto_id,importe_base,descripcion,origen,equipacion_necesidad_id,clave_origen)
   values(n.persona_id,n.temporada_id,concept,m.importe,'Equipacion confirmada','equipacion',n.id,'EQUIPACION_NECESIDAD:'||n.id::text)
   returning id into cid;
   insert into public.economia_cargo_equipacion(cargo_id,modalidad_id,
     necesidad_entrenamiento_id,necesidad_partido_id)
   values(cid,mid,case when m.requiere_entrenamiento then n.id else null end,
     case when m.requiere_partido then n.id else null end);
 else
   select importe_base into base from public.economia_cargos where id=cid;
   -- Once anything has been delivered, confirmed history is immutable economically.
   if delivered then
     if exists(select 1 from public.economia_cargo_equipacion ce where ce.cargo_id=cid and ce.modalidad_id<>mid)
        or coalesce((select importe from public.economia_ajustes where cargo_id=cid and clave_origen='EQUIPACION_RECALCULO'),0)<>(m.importe-base)
     then raise exception 'Delivered equipment requires a new logistics/economic operation'; end if;
     return cid;
   end if;
   delta:=m.importe-base;
   if delta=0 then
     delete from public.economia_ajustes where cargo_id=cid and clave_origen='EQUIPACION_RECALCULO';
   else
     insert into public.economia_ajustes(cargo_id,tipo,importe,nombre,motivo,origen,clave_origen)
     values(cid,'regularizacion',delta,'Regularizacion de equipacion','Cambio de solicitud confirmada por Club','automatico','EQUIPACION_RECALCULO')
     on conflict(cargo_id,clave_origen) where clave_origen is not null
     do update set importe=excluded.importe,motivo=excluded.motivo,origen='automatico';
   end if;
   update public.economia_cargo_equipacion
   set modalidad_id=mid,
       necesidad_entrenamiento_id=case when m.requiere_entrenamiento then n.id else null end,
       necesidad_partido_id=case when m.requiere_partido then n.id else null end
   where cargo_id=cid;
 end if;
 return cid;
end $$;

-- Confirmation is the irreversible family action. It locks sizes and creates the debt.
create or replace function private.equipacion_confirmar_solicitud(p_necesidad uuid)
returns uuid
language plpgsql security definer set search_path='' as $$
declare n public.equipacion_necesidades%rowtype; t public.equipacion_tallas_persona%rowtype; actor uuid:=auth.uid(); cid uuid;
begin
 if actor is null then raise exception 'Authentication required'; end if;
 select * into n from public.equipacion_necesidades where id=p_necesidad for update;
 if n.id is null then raise exception 'Equipment need not found'; end if;
 if not private.can_manage_equipacion_tallas(n.persona_id) then raise exception 'Not authorized'; end if;
 if n.faceta<>'jugador' then raise exception '070 family confirmation currently applies to player needs'; end if;
 if n.estado not in ('pendiente_tallas','comunicada','validada') then raise exception 'Equipment request cannot be confirmed in current state'; end if;

 select * into t from public.equipacion_tallas_persona
 where persona_id=n.persona_id and temporada_id=n.temporada_id for update;
 if t.id is null then raise exception 'Sizes must be provided before confirmation'; end if;

 -- Idempotent: once confirmed, family cannot alter data; repeated confirmation returns same charge.
 if t.confirmada_at is null then
   update public.equipacion_tallas_persona
   set confirmada_at=now(),comunicada_por=coalesce(comunicada_por,actor),updated_at=now() where id=t.id;
 end if;
 if n.confirmada_at is null then
   update public.equipacion_necesidades
   set confirmada_at=now(),comunicada_at=coalesce(comunicada_at,now()),estado='comunicada',updated_at=now()
   where id=n.id;
 end if;
 cid:=private.equipacion_recalcular_cargo(n.id);
 return cid;
end $$;

-- Club/Admin may correct a confirmed request. It never reopens family editing.
create or replace function private.equipacion_corregir_solicitud_confirmada(
 p_necesidad uuid,p_talla_general text default null,p_reutiliza_entrenamiento boolean default null,p_motivo text default null
) returns uuid
language plpgsql security definer set search_path='' as $$
declare n public.equipacion_necesidades%rowtype; t public.equipacion_tallas_persona%rowtype; actor uuid:=auth.uid();
        old_talla text; old_reuse boolean; cursado boolean; cid uuid;
begin
 if actor is null or not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
 if nullif(trim(coalesce(p_motivo,'')),'') is null then raise exception 'Change reason is required'; end if;
 select * into n from public.equipacion_necesidades where id=p_necesidad for update;
 if n.id is null or n.confirmada_at is null then raise exception 'Confirmed equipment request not found'; end if;
 select * into t from public.equipacion_tallas_persona where persona_id=n.persona_id and temporada_id=n.temporada_id for update;
 if t.id is null or t.confirmada_at is null then raise exception 'Confirmed sizes not found'; end if;
 if exists(select 1 from public.equipacion_asignaciones a join public.equipacion_entregas d on d.asignacion_id=a.id where a.necesidad_id=n.id)
 then raise exception 'Delivered equipment requires a new logistics/economic operation'; end if;

 -- A formal supplier order is historical: correction is allowed but never rewrites it automatically.
 select exists(
   select 1 from public.equipacion_asignaciones a
   join public.equipacion_pedido_lineas pl on pl.articulo_id=a.articulo_id and pl.talla=a.talla
   join public.equipacion_pedidos p on p.id=pl.pedido_id
   where a.necesidad_id=n.id and p.temporada_id=n.temporada_id and p.estado<>'borrador' and p.estado<>'cancelado'
 ) into cursado;

 old_talla:=t.talla_general; old_reuse:=n.reutiliza_entrenamiento;
 if p_talla_general is not null and p_talla_general<>old_talla then
   if p_talla_general not in ('4XS','3XS','2XS','XS','S','M','L','XL','2XL','3XL') then raise exception 'Invalid size'; end if;
   update public.equipacion_tallas_persona set talla_general=p_talla_general,updated_at=now() where id=t.id;
   insert into public.equipacion_solicitud_cambios(necesidad_id,persona_id,temporada_id,campo,valor_anterior,valor_nuevo,motivo,pedido_cursado,cambiado_por)
   values(n.id,n.persona_id,n.temporada_id,'talla_general',to_jsonb(old_talla),to_jsonb(p_talla_general),trim(p_motivo),cursado,actor);
 end if;
 if p_reutiliza_entrenamiento is not null and p_reutiliza_entrenamiento is distinct from old_reuse then
   update public.equipacion_necesidades set reutiliza_entrenamiento=p_reutiliza_entrenamiento,updated_at=now() where id=n.id;
   insert into public.equipacion_solicitud_cambios(necesidad_id,persona_id,temporada_id,campo,valor_anterior,valor_nuevo,motivo,pedido_cursado,cambiado_por)
   values(n.id,n.persona_id,n.temporada_id,'reutiliza_entrenamiento',to_jsonb(old_reuse),to_jsonb(p_reutiliza_entrenamiento),trim(p_motivo),cursado,actor);
 end if;
 cid:=private.equipacion_recalcular_cargo(n.id);
 return cid;
end $$;

alter table public.equipacion_solicitud_cambios enable row level security;
create policy equipacion_solicitud_cambios_club on public.equipacion_solicitud_cambios
to authenticated using (private.has_any_role(array['administrador','club']))
with check (private.has_any_role(array['administrador','club']));

grant select on public.equipacion_solicitud_cambios to authenticated,service_role;
grant all on public.equipacion_solicitud_cambios to service_role;
revoke all on public.equipacion_solicitud_cambios from anon;

revoke all on function private.equipacion_resolver_modalidad_economica(uuid),private.equipacion_recalcular_cargo(uuid),
 private.equipacion_confirmar_solicitud(uuid),private.equipacion_corregir_solicitud_confirmada(uuid,text,boolean,text)
 from public,anon;
grant execute on function private.equipacion_confirmar_solicitud(uuid) to authenticated,service_role;
grant execute on function private.equipacion_corregir_solicitud_confirmada(uuid,text,boolean,text) to authenticated,service_role;
revoke all on function private.equipacion_resolver_modalidad_economica(uuid),private.equipacion_recalcular_cargo(uuid) from authenticated;
grant execute on function private.equipacion_resolver_modalidad_economica(uuid),private.equipacion_recalcular_cargo(uuid) to service_role;

commit;
