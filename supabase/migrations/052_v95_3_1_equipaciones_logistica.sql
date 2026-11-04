-- V95.3.1 backend logistics - Equipaciones phase 2.
begin;

create table if not exists public.equipacion_stock (
  id uuid primary key default gen_random_uuid(),
  temporada_id uuid not null references public.temporadas(id) on delete restrict,
  articulo_id uuid not null references public.equipacion_articulos(id) on delete restrict,
  talla text not null default 'SIN_TALLA' check (talla in ('SIN_TALLA','4XS','3XS','2XS','XS','S','M','L','XL','2XL','3XL')),
  cantidad_fisica integer not null default 0 check (cantidad_fisica >= 0),
  cantidad_reservada integer not null default 0 check (cantidad_reservada >= 0 and cantidad_reservada <= cantidad_fisica),
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (temporada_id,articulo_id,talla)
);

create table if not exists public.equipacion_pedidos (
  id uuid primary key default gen_random_uuid(),
  temporada_id uuid not null references public.temporadas(id) on delete restrict,
  numero text,
  proveedor_nombre text not null,
  proveedor_contacto text,
  fecha_pedido date not null,
  estado text not null default 'borrador' check (estado in ('borrador','pedido','parcialmente_recibido','recibido','cerrado','cancelado')),
  observaciones text,
  creado_por uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.equipacion_pedido_lineas (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid not null references public.equipacion_pedidos(id) on delete cascade,
  articulo_id uuid not null references public.equipacion_articulos(id) on delete restrict,
  talla text not null default 'SIN_TALLA' check (talla in ('SIN_TALLA','4XS','3XS','2XS','XS','S','M','L','XL','2XL','3XL')),
  cantidad_pedida integer not null check (cantidad_pedida > 0),
  precio_unitario numeric(10,2) check (precio_unitario is null or precio_unitario >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (pedido_id,articulo_id,talla)
);

create table if not exists public.equipacion_recepciones (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid not null references public.equipacion_pedidos(id) on delete restrict,
  fecha_recepcion date not null default current_date,
  referencia text,
  observaciones text,
  recibido_por uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.equipacion_recepcion_lineas (
  id uuid primary key default gen_random_uuid(),
  recepcion_id uuid not null references public.equipacion_recepciones(id) on delete cascade,
  pedido_linea_id uuid not null references public.equipacion_pedido_lineas(id) on delete restrict,
  cantidad_recibida integer not null check (cantidad_recibida > 0),
  cantidad_aceptada integer not null check (cantidad_aceptada >= 0 and cantidad_aceptada <= cantidad_recibida),
  observaciones text,
  created_at timestamptz not null default now(),
  unique (recepcion_id,pedido_linea_id)
);

create table if not exists public.equipacion_asignaciones (
  id uuid primary key default gen_random_uuid(),
  necesidad_id uuid not null references public.equipacion_necesidades(id) on delete restrict,
  articulo_id uuid not null references public.equipacion_articulos(id) on delete restrict,
  talla text not null default 'SIN_TALLA' check (talla in ('SIN_TALLA','4XS','3XS','2XS','XS','S','M','L','XL','2XL','3XL')),
  cantidad integer not null default 1 check (cantidad > 0),
  estado text not null default 'propuesta' check (estado in ('propuesta','reservada','entregada','cancelada')),
  origen text not null default 'automatico' check (origen in ('automatico','manual')),
  reservado_at timestamptz,
  asignado_por uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (necesidad_id,articulo_id,talla)
);

create table if not exists public.equipacion_entregas (
  id uuid primary key default gen_random_uuid(),
  asignacion_id uuid not null unique references public.equipacion_asignaciones(id) on delete restrict,
  cantidad integer not null check (cantidad > 0),
  entregada_at timestamptz not null default now(),
  entregada_por uuid references auth.users(id) on delete set null,
  observaciones text,
  created_at timestamptz not null default now()
);

create table if not exists public.equipacion_traspasos_stock (
  id uuid primary key default gen_random_uuid(),
  temporada_origen_id uuid not null references public.temporadas(id) on delete restrict,
  temporada_destino_id uuid not null references public.temporadas(id) on delete restrict,
  articulo_id uuid not null references public.equipacion_articulos(id) on delete restrict,
  talla text not null default 'SIN_TALLA' check (talla in ('SIN_TALLA','4XS','3XS','2XS','XS','S','M','L','XL','2XL','3XL')),
  cantidad integer not null check (cantidad > 0),
  realizado_por uuid references auth.users(id) on delete set null,
  realizado_at timestamptz not null default now(),
  observaciones text,
  check (temporada_origen_id <> temporada_destino_id)
);

-- Demand is derived from validated needs + pack composition + effective size.
create or replace view public.equipacion_demanda_logistica as
select
  n.temporada_id,
  n.id as necesidad_id,
  n.persona_id,
  n.faceta,
  pa.articulo_id,
  case
    when not a.usa_talla then 'SIN_TALLA'
    else coalesce(ex.talla,tp.talla_general)
  end as talla,
  pa.cantidad as cantidad_demandada
from public.equipacion_necesidades n
join public.equipacion_packs p on p.id=n.pack_id and p.temporada_id=n.temporada_id
join public.equipacion_pack_articulos pa on pa.pack_id=p.id and pa.obligatorio
join public.equipacion_articulos a on a.id=pa.articulo_id and a.activo
left join public.equipacion_tallas_persona tp on tp.persona_id=n.persona_id and tp.temporada_id=n.temporada_id
left join public.equipacion_tallas_excepcion ex on ex.talla_persona_id=tp.id and ex.articulo_id=pa.articulo_id
where n.estado in ('comunicada','validada','preparacion','completa')
  and n.pack_id is not null
  and (not a.usa_talla or coalesce(ex.talla,tp.talla_general) is not null);

create or replace view public.equipacion_stock_resumen as
select s.*, (s.cantidad_fisica-s.cantidad_reservada) as cantidad_disponible
from public.equipacion_stock s;

create or replace view public.equipacion_compra_sugerida as
with d as (
  select temporada_id,articulo_id,talla,sum(cantidad_demandada)::integer demanda
  from public.equipacion_demanda_logistica group by 1,2,3
), e as (
  select n.temporada_id,a.articulo_id,a.talla,sum(en.cantidad)::integer entregado
  from public.equipacion_entregas en
  join public.equipacion_asignaciones a on a.id=en.asignacion_id
  join public.equipacion_necesidades n on n.id=a.necesidad_id
  group by 1,2,3
), p as (
  select pe.temporada_id,pl.articulo_id,pl.talla,
         greatest(sum(pl.cantidad_pedida)-coalesce(sum(r.cantidad_aceptada),0),0)::integer pendiente_proveedor
  from public.equipacion_pedidos pe
  join public.equipacion_pedido_lineas pl on pl.pedido_id=pe.id
  left join public.equipacion_recepcion_lineas r on r.pedido_linea_id=pl.id
  where pe.estado in ('pedido','parcialmente_recibido')
  group by 1,2,3
)
select d.temporada_id,d.articulo_id,d.talla,d.demanda,
       coalesce(e.entregado,0) entregado,
       coalesce(s.cantidad_fisica,0) stock_fisico,
       coalesce(s.cantidad_reservada,0) reservado,
       coalesce(p.pendiente_proveedor,0) pendiente_proveedor,
       greatest(d.demanda-coalesce(e.entregado,0)-coalesce(s.cantidad_fisica,0)-coalesce(p.pendiente_proveedor,0),0)::integer falta_comprar
from d
left join e using (temporada_id,articulo_id,talla)
left join public.equipacion_stock s using (temporada_id,articulo_id,talla)
left join p using (temporada_id,articulo_id,talla);

-- Stock changes are performed through controlled functions so physical and reserved quantities stay coherent.
create or replace function private.equipacion_ajustar_stock(p_temporada uuid,p_articulo uuid,p_talla text,p_delta integer)
returns void language plpgsql security definer set search_path=public,private as $$
declare v_fisica integer; v_res integer;
begin
  if not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
  insert into public.equipacion_stock(temporada_id,articulo_id,talla,cantidad_fisica)
  values(p_temporada,p_articulo,p_talla,greatest(p_delta,0))
  on conflict (temporada_id,articulo_id,talla) do update
    set cantidad_fisica=public.equipacion_stock.cantidad_fisica+p_delta, updated_at=now()
  returning cantidad_fisica,cantidad_reservada into v_fisica,v_res;
  if v_fisica < 0 or v_fisica < v_res then raise exception 'Stock adjustment would invalidate reservations'; end if;
end $$;

create or replace function private.equipacion_reservar_asignacion(p_asignacion uuid)
returns void language plpgsql security definer set search_path=public,private as $$
declare arow public.equipacion_asignaciones%rowtype; nrow public.equipacion_necesidades%rowtype; affected integer;
begin
  if not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
  select * into arow from public.equipacion_asignaciones where id=p_asignacion for update;
  if arow.id is null then raise exception 'Assignment not found'; end if;
  if arow.estado='reservada' then return; end if;
  if arow.estado <> 'propuesta' then raise exception 'Only proposed assignments can be reserved'; end if;
  select * into nrow from public.equipacion_necesidades where id=arow.necesidad_id;
  update public.equipacion_stock set cantidad_reservada=cantidad_reservada+arow.cantidad,updated_at=now()
   where temporada_id=nrow.temporada_id and articulo_id=arow.articulo_id and talla=arow.talla
     and cantidad_fisica-cantidad_reservada >= arow.cantidad;
  get diagnostics affected=row_count;
  if affected<>1 then raise exception 'Insufficient available stock'; end if;
  update public.equipacion_asignaciones set estado='reservada',reservado_at=now(),updated_at=now() where id=p_asignacion;
end $$;

create or replace function private.equipacion_confirmar_entrega(p_asignacion uuid,p_usuario uuid default null)
returns uuid language plpgsql security definer set search_path=public,private as $$
declare arow public.equipacion_asignaciones%rowtype; nrow public.equipacion_necesidades%rowtype; eid uuid;
begin
  if not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
  select * into arow from public.equipacion_asignaciones where id=p_asignacion for update;
  if arow.estado='entregada' then select id into eid from public.equipacion_entregas where asignacion_id=p_asignacion; return eid; end if;
  if arow.estado<>'reservada' then raise exception 'Assignment must be reserved before delivery'; end if;
  select * into nrow from public.equipacion_necesidades where id=arow.necesidad_id;
  update public.equipacion_stock set cantidad_fisica=cantidad_fisica-arow.cantidad,cantidad_reservada=cantidad_reservada-arow.cantidad,updated_at=now()
   where temporada_id=nrow.temporada_id and articulo_id=arow.articulo_id and talla=arow.talla and cantidad_reservada>=arow.cantidad;
  insert into public.equipacion_entregas(asignacion_id,cantidad,entregada_por) values(p_asignacion,arow.cantidad,p_usuario) returning id into eid;
  update public.equipacion_asignaciones set estado='entregada',updated_at=now() where id=p_asignacion;
  return eid;
end $$;

-- updated_at helpers.
do $$ declare t text; begin
  foreach t in array array['equipacion_stock','equipacion_pedidos','equipacion_pedido_lineas','equipacion_asignaciones'] loop
    execute format('drop trigger if exists %I_updated_at on public.%I',t,t);
    execute format('create trigger %I_updated_at before update on public.%I for each row execute function public.set_updated_at()',t,t);
  end loop;
end $$;

-- RLS: logistics are club/admin operations. Authenticated users may read derived demand only through their existing need visibility later in UI/API.
alter table public.equipacion_stock enable row level security;
alter table public.equipacion_pedidos enable row level security;
alter table public.equipacion_pedido_lineas enable row level security;
alter table public.equipacion_recepciones enable row level security;
alter table public.equipacion_recepcion_lineas enable row level security;
alter table public.equipacion_asignaciones enable row level security;
alter table public.equipacion_entregas enable row level security;
alter table public.equipacion_traspasos_stock enable row level security;

do $$ declare t text; begin
  foreach t in array array['equipacion_stock','equipacion_pedidos','equipacion_pedido_lineas','equipacion_recepciones','equipacion_recepcion_lineas','equipacion_asignaciones','equipacion_entregas','equipacion_traspasos_stock'] loop
    execute format('drop policy if exists %I_club_manage on public.%I',t,t);
    execute format('create policy %I_club_manage on public.%I to authenticated using (private.has_any_role(array[''administrador'',''club''])) with check (private.has_any_role(array[''administrador'',''club'']))',t,t);
  end loop;
end $$;

grant select,insert,update,delete on public.equipacion_stock,public.equipacion_pedidos,public.equipacion_pedido_lineas,public.equipacion_recepciones,public.equipacion_recepcion_lineas,public.equipacion_asignaciones,public.equipacion_entregas,public.equipacion_traspasos_stock to authenticated;
grant all on public.equipacion_stock,public.equipacion_pedidos,public.equipacion_pedido_lineas,public.equipacion_recepciones,public.equipacion_recepcion_lineas,public.equipacion_asignaciones,public.equipacion_entregas,public.equipacion_traspasos_stock to service_role;
revoke all on public.equipacion_stock,public.equipacion_pedidos,public.equipacion_pedido_lineas,public.equipacion_recepciones,public.equipacion_recepcion_lineas,public.equipacion_asignaciones,public.equipacion_entregas,public.equipacion_traspasos_stock from anon;
grant select on public.equipacion_demanda_logistica,public.equipacion_stock_resumen,public.equipacion_compra_sugerida to authenticated,service_role;
revoke all on public.equipacion_demanda_logistica,public.equipacion_stock_resumen,public.equipacion_compra_sugerida from anon;
grant execute on function private.equipacion_ajustar_stock(uuid,uuid,text,integer),private.equipacion_reservar_asignacion(uuid),private.equipacion_confirmar_entrega(uuid,uuid) to authenticated,service_role;

commit;
