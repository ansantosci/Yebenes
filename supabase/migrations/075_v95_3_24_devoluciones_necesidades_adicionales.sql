-- 075 - Simple returns + additional single-item equipment needs.
begin;

create table if not exists public.equipacion_articulo_precios_temporada (
 id uuid primary key default gen_random_uuid(),
 temporada_id uuid not null references public.temporadas(id) on delete restrict,
 articulo_id uuid not null references public.equipacion_articulos(id) on delete restrict,
 precio numeric(10,2) not null check(precio>=0),
 activo boolean not null default true,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(temporada_id,articulo_id)
);

alter table public.equipacion_necesidades
 add column if not exists articulo_id_adicional uuid references public.equipacion_articulos(id) on delete restrict,
 add column if not exists cantidad_adicional integer check(cantidad_adicional is null or cantidad_adicional>0),
 add column if not exists sin_cargo boolean not null default false,
 add column if not exists precio_unitario_snapshot numeric(10,2) check(precio_unitario_snapshot is null or precio_unitario_snapshot>=0);

alter table public.equipacion_necesidades drop constraint if exists equipacion_necesidades_adicional_ck;
alter table public.equipacion_necesidades add constraint equipacion_necesidades_adicional_ck check(
 (pack_id is not null and articulo_id_adicional is null and cantidad_adicional is null)
 or
 (pack_id is null and articulo_id_adicional is not null and cantidad_adicional is not null)
);

create table if not exists public.equipacion_devoluciones (
 id uuid primary key default gen_random_uuid(),
 entrega_id uuid not null references public.equipacion_entregas(id) on delete restrict,
 cantidad integer not null check(cantidad>0),
 reutilizable boolean not null,
 motivo text,
 observaciones text,
 registrada_por uuid not null references auth.users(id) on delete restrict,
 registrada_at timestamptz not null default now()
);

-- Additional needs participate in the same demand view as pack needs.
create or replace view public.equipacion_demanda_logistica as
select n.temporada_id,n.id necesidad_id,n.persona_id,n.faceta,pa.articulo_id,
 case when not a.usa_talla then 'SIN_TALLA' else coalesce(ex.talla,tp.talla_general) end talla,
 pa.cantidad cantidad_demandada
from public.equipacion_necesidades n
join public.equipacion_packs p on p.id=n.pack_id and p.temporada_id=n.temporada_id
join public.equipacion_pack_articulos pa on pa.pack_id=p.id and pa.obligatorio
join public.equipacion_articulos a on a.id=pa.articulo_id and a.activo
join public.equipacion_tallas_persona tp on tp.persona_id=n.persona_id and tp.temporada_id=n.temporada_id and tp.confirmada_at is not null
left join public.equipacion_tallas_excepcion ex on ex.talla_persona_id=tp.id and ex.articulo_id=pa.articulo_id
where n.confirmada_at is not null and n.estado in ('comunicada','validada','preparacion','completa')
 and n.pack_id is not null and (not a.usa_talla or coalesce(ex.talla,tp.talla_general) is not null)
union all
select n.temporada_id,n.id,n.persona_id,n.faceta,n.articulo_id_adicional,
 case when not a.usa_talla then 'SIN_TALLA' else coalesce(ex.talla,tp.talla_general) end,
 n.cantidad_adicional
from public.equipacion_necesidades n
join public.equipacion_articulos a on a.id=n.articulo_id_adicional and a.activo
join public.equipacion_tallas_persona tp on tp.persona_id=n.persona_id and tp.temporada_id=n.temporada_id and tp.confirmada_at is not null
left join public.equipacion_tallas_excepcion ex on ex.talla_persona_id=tp.id and ex.articulo_id=n.articulo_id_adicional
where n.confirmada_at is not null and n.estado in ('comunicada','validada','preparacion','completa')
 and n.pack_id is null and n.articulo_id_adicional is not null
 and (not a.usa_talla or coalesce(ex.talla,tp.talla_general) is not null);

create or replace function private.equipacion_crear_necesidad_adicional(
 p_persona uuid,p_temporada uuid,p_articulo uuid,p_cantidad integer default 1,
 p_sin_cargo boolean default false,p_motivo text default null
) returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); pt public.equipacion_personas_temporada%rowtype;
 n_id uuid; j uuid; e uuid; talla text; v_precio numeric; concepto uuid; cid uuid;
begin
 if actor is null or not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
 if p_cantidad is null or p_cantidad<=0 then raise exception 'Quantity must be positive'; end if;
 select * into pt from public.equipacion_personas_temporada
 where persona_id=p_persona and temporada_id=p_temporada and estado='validada'
 order by case when faceta='jugador' then 0 else 1 end limit 1;
 if pt.id is null then raise exception 'Validated season equipment person not found'; end if;
 j:=pt.jugador_id; e:=pt.entrenador_id;
 select case when not a.usa_talla then 'SIN_TALLA' else coalesce(ex.talla,tp.talla_general) end
 into talla
 from public.equipacion_articulos a
 join public.equipacion_tallas_persona tp on tp.persona_id=p_persona and tp.temporada_id=p_temporada and tp.confirmada_at is not null
 left join public.equipacion_tallas_excepcion ex on ex.talla_persona_id=tp.id and ex.articulo_id=a.id
 where a.id=p_articulo and a.activo;
 if talla is null then raise exception 'Confirmed size/article not available'; end if;

 if not p_sin_cargo then
  select ap.precio into v_precio from public.equipacion_articulo_precios_temporada ap
   where ap.temporada_id=p_temporada and ap.articulo_id=p_articulo and ap.activo;
  if v_precio is null then raise exception 'Individual article price is not configured'; end if;
 else v_precio:=0; end if;

 insert into public.equipacion_necesidades(persona_id,temporada_id,faceta,jugador_id,entrenador_id,persona_temporada_id,
   pack_id,articulo_id_adicional,cantidad_adicional,sin_cargo,precio_unitario_snapshot,estado,origen,confirmada_at,comunicada_at)
 values(p_persona,p_temporada,pt.faceta,j,e,pt.id,null,p_articulo,p_cantidad,p_sin_cargo,v_precio,'comunicada','manual',now(),now())
 returning id into n_id;

 insert into public.equipacion_asignaciones(necesidad_id,articulo_id,talla,cantidad,estado,origen,asignado_por)
 values(n_id,p_articulo,talla,p_cantidad,'propuesta','manual',actor);

 if not p_sin_cargo then
  select id into concepto from public.economia_conceptos where codigo='EQUIPACION';
  insert into public.economia_cargos(persona_id,temporada_id,concepto_id,importe_base,descripcion,origen,equipacion_necesidad_id,clave_origen,creado_por)
  values(p_persona,p_temporada,concepto,v_precio*p_cantidad,'Necesidad adicional de equipacion','equipacion',n_id,
    'EQUIPACION_ADICIONAL:'||n_id::text,actor) returning id into cid;
 end if;
 return n_id;
end $$;

create or replace function private.equipacion_registrar_devolucion(
 p_entrega uuid,p_cantidad integer,p_reutilizable boolean,p_motivo text default null,p_observaciones text default null
) returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); en public.equipacion_entregas%rowtype; a public.equipacion_asignaciones%rowtype;
 n public.equipacion_necesidades%rowtype; did uuid; prev integer; lid uuid;
begin
 if actor is null or not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
 select * into en from public.equipacion_entregas where id=p_entrega for update;
 if en.id is null then raise exception 'Delivery not found'; end if;
 if p_cantidad is null or p_cantidad<=0 then raise exception 'Return quantity must be positive'; end if;
 select coalesce(sum(cantidad),0) into prev from public.equipacion_devoluciones where entrega_id=en.id;
 if prev+p_cantidad>en.cantidad then raise exception 'Return quantity exceeds delivered quantity'; end if;
 select * into a from public.equipacion_asignaciones where id=en.asignacion_id;
 select * into n from public.equipacion_necesidades where id=a.necesidad_id;
 insert into public.equipacion_devoluciones(entrega_id,cantidad,reutilizable,motivo,observaciones,registrada_por)
 values(en.id,p_cantidad,p_reutilizable,p_motivo,p_observaciones,actor) returning id into did;

 if p_reutilizable then
  -- A reusable return becomes a new traceable lot. We do not pretend that the
  -- physical garment can still be identified with the supplier lot it left from.
  insert into public.equipacion_stock_lotes(
    articulo_id,talla,temporada_origen_id,proveedor_nombre,referencia_proveedor,cantidad_fisica,cantidad_reservada)
  values(a.articulo_id,a.talla,n.temporada_id,null,'DEVOLUCION:'||did::text,p_cantidad,0)
  returning id into lid;
  insert into public.equipacion_stock_lote_vigencia(lote_id,temporada_id,estado,decidido_at,decidido_por,observaciones)
  values(lid,n.temporada_id,'valido',now(),actor,'Prenda reutilizable devuelta por jugador');
  perform private.equipacion_recalcular_stock_legacy(n.temporada_id,a.articulo_id,a.talla);
 end if;
 return did;
end $$;

alter table public.equipacion_articulo_precios_temporada enable row level security;
alter table public.equipacion_devoluciones enable row level security;
create policy equipacion_articulo_precios_read on public.equipacion_articulo_precios_temporada for select to authenticated using(true);
create policy equipacion_articulo_precios_club on public.equipacion_articulo_precios_temporada to authenticated
 using(private.has_any_role(array['administrador','club'])) with check(private.has_any_role(array['administrador','club']));
create policy equipacion_devoluciones_club on public.equipacion_devoluciones to authenticated
 using(private.has_any_role(array['administrador','club'])) with check(private.has_any_role(array['administrador','club']));
grant select on public.equipacion_articulo_precios_temporada,public.equipacion_devoluciones to authenticated,service_role;
grant all on public.equipacion_articulo_precios_temporada,public.equipacion_devoluciones to service_role;
revoke all on public.equipacion_articulo_precios_temporada,public.equipacion_devoluciones from anon;
revoke all on function private.equipacion_crear_necesidad_adicional(uuid,uuid,uuid,integer,boolean,text),
 private.equipacion_registrar_devolucion(uuid,integer,boolean,text,text) from public,anon;
grant execute on function private.equipacion_crear_necesidad_adicional(uuid,uuid,uuid,integer,boolean,text),
 private.equipacion_registrar_devolucion(uuid,integer,boolean,text,text) to authenticated,service_role;

commit;
