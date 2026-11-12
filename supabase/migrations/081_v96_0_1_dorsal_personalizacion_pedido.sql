-- 081 - Dorsal proposal and physical personalization locked when order is placed.
begin;

alter table public.equipacion_articulos
 add column if not exists personalizable_dorsal boolean not null default false;

alter table public.equipacion_pedido_lineas
 add column if not exists jugador_id uuid references public.jugadores(id) on delete restrict,
 add column if not exists dorsal integer check(dorsal between 1 and 99);

alter table public.equipacion_stock_lotes
 add column if not exists dorsal integer check(dorsal between 1 and 99),
 add column if not exists jugador_origen_id uuid references public.jugadores(id) on delete set null;

-- Existing non-personalized lines keep the historical uniqueness. Personalized lines
-- need one line per player/dorsal because the physical garment is no longer fungible.
alter table public.equipacion_pedido_lineas
 drop constraint if exists equipacion_pedido_lineas_pedido_id_articulo_id_talla_key;
create unique index if not exists equipacion_pedido_lineas_no_dorsal_uq
 on public.equipacion_pedido_lineas(pedido_id,articulo_id,talla)
 where dorsal is null;
create unique index if not exists equipacion_pedido_lineas_dorsal_uq
 on public.equipacion_pedido_lineas(pedido_id,articulo_id,talla,dorsal)
 where dorsal is not null;

create or replace function private.equipacion_validar_linea_personalizada()
returns trigger language plpgsql set search_path='' as $$
declare pers boolean; tid uuid; eid uuid;
begin
 select personalizable_dorsal into pers from public.equipacion_articulos where id=new.articulo_id;
 select temporada_id into tid from public.equipacion_pedidos where id=new.pedido_id;
 if pers then
   if new.jugador_id is null or new.dorsal is null or new.cantidad_pedida<>1 then
     raise exception 'Personalized match garment requires player, dorsal and quantity 1';
   end if;
   select equipo_id into eid from public.equipacion_dorsales
    where temporada_id=tid and jugador_id=new.jugador_id and dorsal=new.dorsal;
   if eid is null then raise exception 'Order dorsal must match the player season dorsal proposal'; end if;
 else
   if new.dorsal is not null then raise exception 'Non-personalized garment cannot carry dorsal'; end if;
 end if;
 return new;
end $$;
drop trigger if exists equipacion_pedido_linea_personalizada_guard on public.equipacion_pedido_lineas;
create trigger equipacion_pedido_linea_personalizada_guard
 before insert or update on public.equipacion_pedido_lineas
 for each row execute function private.equipacion_validar_linea_personalizada();

create or replace function private.equipacion_proponer_dorsal(p_temporada uuid,p_equipo uuid,p_jugador uuid,p_es_portero boolean default false)
returns integer language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); d integer; candidates integer[];
begin
 if actor is null or not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
 select dorsal into d from public.equipacion_dorsales
  where temporada_id=p_temporada and equipo_id=p_equipo and jugador_id=p_jugador;
 if d is not null then return d; end if;
 candidates:=case when p_es_portero then array[1,13,25] else array[2,3,4,5,6,7,8,9,10,11,12,14,15,16,17,18,19,20,21,22,23,24,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99] end;
 select x into d from unnest(candidates) x
 where not exists(select 1 from public.equipacion_dorsales e
                  where e.temporada_id=p_temporada and e.equipo_id=p_equipo and e.dorsal=x)
 limit 1;
 if d is null then raise exception 'No dorsal available for team'; end if;
 insert into public.equipacion_dorsales(temporada_id,equipo_id,jugador_id,dorsal,es_portero,origen,asignado_por)
 values(p_temporada,p_equipo,p_jugador,d,p_es_portero,'automatico',actor);
 return d;
end $$;

create or replace function private.equipacion_cambiar_dorsal_propuesto(p_temporada uuid,p_equipo uuid,p_jugador uuid,p_dorsal integer)
returns void language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();
begin
 if actor is null or not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
 if exists(select 1 from public.equipacion_pedido_lineas pl join public.equipacion_pedidos p on p.id=pl.pedido_id
           where p.temporada_id=p_temporada and pl.jugador_id=p_jugador and pl.dorsal is not null and p.estado<>'borrador' and p.estado<>'cancelado')
 then raise exception 'Dorsal cannot change after personalized order is placed'; end if;
 insert into public.equipacion_dorsales(temporada_id,equipo_id,jugador_id,dorsal,origen,asignado_por)
 values(p_temporada,p_equipo,p_jugador,p_dorsal,'manual',actor)
 on conflict(temporada_id,equipo_id,jugador_id) do update
 set dorsal=excluded.dorsal,origen='manual',asignado_por=actor,asignado_at=now(),updated_at=now();
end $$;

-- Reception-created lots inherit the physical dorsal/player from their order line.
create or replace function private.equipacion_aplicar_recepcion_linea_lote_personalizado()
returns trigger language plpgsql security definer set search_path='' as $$
declare lid uuid; tid uuid; aid uuid; talla text; dor integer; jid uuid; prov text;
begin
 select pe.temporada_id,pl.articulo_id,pl.talla,pl.dorsal,pl.jugador_id,pe.proveedor_nombre
 into tid,aid,talla,dor,jid,prov
 from public.equipacion_pedido_lineas pl join public.equipacion_pedidos pe on pe.id=pl.pedido_id
 where pl.id=new.pedido_linea_id;
 if dor is null then return new; end if;
 insert into public.equipacion_stock_lotes(articulo_id,talla,temporada_origen_id,proveedor_nombre,referencia_proveedor,cantidad_fisica,cantidad_reservada,dorsal,jugador_origen_id)
 values(aid,talla,tid,prov,'RECEPCION:'||new.id::text,new.cantidad_aceptada,0,dor,jid) returning id into lid;
 insert into public.equipacion_stock_lote_vigencia(lote_id,temporada_id,estado,decidido_at)
 values(lid,tid,'valido',now());
 return new;
end $$;
drop trigger if exists equipacion_recepcion_personalizada_lote on public.equipacion_recepcion_lineas;
create trigger equipacion_recepcion_personalizada_lote
 after insert on public.equipacion_recepcion_lineas
 for each row execute function private.equipacion_aplicar_recepcion_linea_lote_personalizado();

revoke all on function private.equipacion_proponer_dorsal(uuid,uuid,uuid,boolean),private.equipacion_cambiar_dorsal_propuesto(uuid,uuid,uuid,integer) from public,anon;
grant execute on function private.equipacion_proponer_dorsal(uuid,uuid,uuid,boolean),private.equipacion_cambiar_dorsal_propuesto(uuid,uuid,uuid,integer) to authenticated,service_role;

commit;
