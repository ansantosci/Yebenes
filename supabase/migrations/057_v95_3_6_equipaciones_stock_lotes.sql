-- V95.3.6 backend - traceable stock lots and cross-season validity.
begin;
create table if not exists public.equipacion_stock_lotes (
 id uuid primary key default gen_random_uuid(), articulo_id uuid not null references public.equipacion_articulos(id) on delete restrict,
 talla text not null default 'SIN_TALLA' check (talla in ('SIN_TALLA','4XS','3XS','2XS','XS','S','M','L','XL','2XL','3XL')),
 temporada_origen_id uuid not null references public.temporadas(id) on delete restrict, proveedor_nombre text, referencia_proveedor text,
 cantidad_fisica integer not null default 0 check (cantidad_fisica>=0), cantidad_reservada integer not null default 0 check (cantidad_reservada>=0 and cantidad_reservada<=cantidad_fisica),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.equipacion_stock_lote_vigencia (
 id uuid primary key default gen_random_uuid(), lote_id uuid not null references public.equipacion_stock_lotes(id) on delete cascade,
 temporada_id uuid not null references public.temporadas(id) on delete restrict,
 estado text not null default 'pendiente' check (estado in ('pendiente','valido','no_valido')),
 decidido_at timestamptz, decidido_por uuid references auth.users(id) on delete set null, observaciones text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(lote_id,temporada_id)
);
create or replace view public.equipacion_stock_lotes_disponibles as
select l.id lote_id,l.articulo_id,l.talla,l.temporada_origen_id,l.proveedor_nombre,l.referencia_proveedor,l.cantidad_fisica,l.cantidad_reservada,
v.temporada_id,v.estado,case when v.estado='valido' then l.cantidad_fisica-l.cantidad_reservada else 0 end cantidad_disponible
from public.equipacion_stock_lotes l join public.equipacion_stock_lote_vigencia v on v.lote_id=l.id;
commit;
