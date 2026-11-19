-- 095 - Catalogo de tallajes y metadatos comerciales de articulos.
-- Incremental sobre 051-094: mantiene talla TEXT operativa y prepara catalogo extensible.
begin;

create table public.equipacion_sistemas_tallaje (
  id uuid primary key default gen_random_uuid(),
  codigo text not null,
  nombre text not null,
  activo boolean not null default true,
  orden integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (btrim(codigo) <> ''),
  check (btrim(nombre) <> '')
);
create unique index equipacion_sistemas_tallaje_codigo_ci_uq on public.equipacion_sistemas_tallaje(lower(btrim(codigo)));

drop trigger if exists equipacion_sistemas_tallaje_updated_at on public.equipacion_sistemas_tallaje;
create trigger equipacion_sistemas_tallaje_updated_at before update on public.equipacion_sistemas_tallaje
for each row execute function public.set_updated_at();

create table public.equipacion_tallaje_valores (
  id uuid primary key default gen_random_uuid(),
  sistema_tallaje_id uuid not null references public.equipacion_sistemas_tallaje(id) on delete restrict,
  codigo text not null,
  nombre text not null,
  orden integer not null default 100,
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (btrim(codigo) <> ''),
  check (btrim(nombre) <> ''),
  unique (sistema_tallaje_id,codigo)
);
create index equipacion_tallaje_valores_sistema_idx on public.equipacion_tallaje_valores(sistema_tallaje_id,orden,id);

drop trigger if exists equipacion_tallaje_valores_updated_at on public.equipacion_tallaje_valores;
create trigger equipacion_tallaje_valores_updated_at before update on public.equipacion_tallaje_valores
for each row execute function public.set_updated_at();

-- Structural catalog. These are application vocabulary, not Club/provider data.
insert into public.equipacion_sistemas_tallaje(codigo,nombre,orden) values
  ('ROPA','Ropa',10),
  ('BALON','Balones',20),
  ('SIN_TALLA','Sin talla',90);

insert into public.equipacion_tallaje_valores(sistema_tallaje_id,codigo,nombre,orden)
select s.id,v.codigo,v.nombre,v.orden
from public.equipacion_sistemas_tallaje s
join (values
 ('ROPA','4XS','4XS',10),('ROPA','3XS','3XS',20),('ROPA','2XS','2XS',30),('ROPA','XS','XS',40),
 ('ROPA','S','S',50),('ROPA','M','M',60),('ROPA','L','L',70),('ROPA','XL','XL',80),('ROPA','2XL','2XL',90),('ROPA','3XL','3XL',100),
 ('BALON','3','3',10),('BALON','4','4',20),('BALON','5','5',30),
 ('SIN_TALLA','SIN_TALLA','Sin talla',10)
) as v(sistema,codigo,nombre,orden) on v.sistema=s.codigo;

alter table public.equipacion_articulos
  add column modelo text,
  add column referencia_fabricante text,
  add column sistema_tallaje_id uuid references public.equipacion_sistemas_tallaje(id) on delete restrict;

update public.equipacion_articulos a
set sistema_tallaje_id=s.id
from public.equipacion_sistemas_tallaje s
where s.codigo=case when a.usa_talla then 'ROPA' else 'SIN_TALLA' end;

alter table public.equipacion_articulos alter column sistema_tallaje_id set not null;

create table public.equipacion_articulo_tallas (
  articulo_id uuid not null references public.equipacion_articulos(id) on delete cascade,
  talla_id uuid not null references public.equipacion_tallaje_valores(id) on delete restrict,
  activa boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (articulo_id,talla_id)
);
create index equipacion_articulo_tallas_talla_idx on public.equipacion_articulo_tallas(talla_id,articulo_id);

drop trigger if exists equipacion_articulo_tallas_updated_at on public.equipacion_articulo_tallas;
create trigger equipacion_articulo_tallas_updated_at before update on public.equipacion_articulo_tallas
for each row execute function public.set_updated_at();

-- Compatibility: legacy inserts that only know usa_talla continue to work after 095.
create or replace function private.equipacion_normalizar_sistema_tallaje_articulo()
returns trigger language plpgsql security definer set search_path to '' as $$
declare v_codigo text;
begin
  if new.sistema_tallaje_id is null then
    select id into new.sistema_tallaje_id
    from public.equipacion_sistemas_tallaje
    where codigo=case when coalesce(new.usa_talla,true) then 'ROPA' else 'SIN_TALLA' end;
  end if;

  select codigo into v_codigo from public.equipacion_sistemas_tallaje where id=new.sistema_tallaje_id;
  if v_codigo is null then raise exception 'Sistema de tallaje inexistente'; end if;
  new.usa_talla := (v_codigo <> 'SIN_TALLA');

  if tg_op='UPDATE' and new.sistema_tallaje_id is distinct from old.sistema_tallaje_id and exists (
    select 1
    from public.equipacion_articulo_tallas at
    join public.equipacion_tallaje_valores tv on tv.id=at.talla_id
    where at.articulo_id=old.id and tv.sistema_tallaje_id<>new.sistema_tallaje_id
  ) then
    raise exception 'El articulo tiene tallas especificas incompatibles con el nuevo sistema';
  end if;
  return new;
end $$;

drop trigger if exists equipacion_articulos_sistema_tallaje on public.equipacion_articulos;
create trigger equipacion_articulos_sistema_tallaje
before insert or update of sistema_tallaje_id,usa_talla on public.equipacion_articulos
for each row execute function private.equipacion_normalizar_sistema_tallaje_articulo();

create or replace function private.equipacion_validar_articulo_talla_catalogo()
returns trigger language plpgsql security definer set search_path to '' as $$
declare v_art_sistema uuid; v_talla_sistema uuid;
begin
  select sistema_tallaje_id into v_art_sistema from public.equipacion_articulos where id=new.articulo_id;
  select sistema_tallaje_id into v_talla_sistema from public.equipacion_tallaje_valores where id=new.talla_id;
  if v_art_sistema is null or v_talla_sistema is null or v_art_sistema<>v_talla_sistema then
    raise exception 'La talla no pertenece al sistema de tallaje del articulo';
  end if;
  return new;
end $$;

drop trigger if exists equipacion_articulo_tallas_validar on public.equipacion_articulo_tallas;
create trigger equipacion_articulo_tallas_validar
before insert or update of articulo_id,talla_id on public.equipacion_articulo_tallas
for each row execute function private.equipacion_validar_articulo_talla_catalogo();

-- Central catalog validation. No specific rows means every active value in the system is allowed.
create or replace function private.equipacion_articulo_admite_talla(p_articulo_id uuid,p_talla text)
returns boolean language sql stable security definer set search_path to '' as $$
  select exists (
    select 1
    from public.equipacion_articulos a
    join public.equipacion_tallaje_valores tv
      on tv.sistema_tallaje_id=a.sistema_tallaje_id
     and tv.codigo=p_talla
     and tv.activo
    where a.id=p_articulo_id
      and (
        not exists (select 1 from public.equipacion_articulo_tallas x where x.articulo_id=a.id and x.activa)
        or exists (select 1 from public.equipacion_articulo_tallas x where x.articulo_id=a.id and x.talla_id=tv.id and x.activa)
      )
  );
$$;

-- RLS follows existing master-data semantics: authenticated may read; Club/Admin manage.
alter table public.equipacion_sistemas_tallaje enable row level security;
alter table public.equipacion_tallaje_valores enable row level security;
alter table public.equipacion_articulo_tallas enable row level security;

create policy equipacion_sistemas_tallaje_read on public.equipacion_sistemas_tallaje for select to authenticated using (true);
create policy equipacion_sistemas_tallaje_insert on public.equipacion_sistemas_tallaje for insert to authenticated with check (private.has_any_role(array['administrador','club']));
create policy equipacion_sistemas_tallaje_update on public.equipacion_sistemas_tallaje for update to authenticated using (private.has_any_role(array['administrador','club'])) with check (private.has_any_role(array['administrador','club']));
create policy equipacion_sistemas_tallaje_delete on public.equipacion_sistemas_tallaje for delete to authenticated using (private.has_any_role(array['administrador','club']));
create policy equipacion_tallaje_valores_read on public.equipacion_tallaje_valores for select to authenticated using (true);
create policy equipacion_tallaje_valores_insert on public.equipacion_tallaje_valores for insert to authenticated with check (private.has_any_role(array['administrador','club']));
create policy equipacion_tallaje_valores_update on public.equipacion_tallaje_valores for update to authenticated using (private.has_any_role(array['administrador','club'])) with check (private.has_any_role(array['administrador','club']));
create policy equipacion_tallaje_valores_delete on public.equipacion_tallaje_valores for delete to authenticated using (private.has_any_role(array['administrador','club']));
create policy equipacion_articulo_tallas_read on public.equipacion_articulo_tallas for select to authenticated using (true);
create policy equipacion_articulo_tallas_insert on public.equipacion_articulo_tallas for insert to authenticated with check (private.has_any_role(array['administrador','club']));
create policy equipacion_articulo_tallas_update on public.equipacion_articulo_tallas for update to authenticated using (private.has_any_role(array['administrador','club'])) with check (private.has_any_role(array['administrador','club']));
create policy equipacion_articulo_tallas_delete on public.equipacion_articulo_tallas for delete to authenticated using (private.has_any_role(array['administrador','club']));

grant select,insert,update,delete on public.equipacion_sistemas_tallaje,public.equipacion_tallaje_valores,public.equipacion_articulo_tallas to authenticated;
grant all on public.equipacion_sistemas_tallaje,public.equipacion_tallaje_valores,public.equipacion_articulo_tallas to service_role;
revoke all on public.equipacion_sistemas_tallaje,public.equipacion_tallaje_valores,public.equipacion_articulo_tallas from anon;

revoke all on function private.equipacion_normalizar_sistema_tallaje_articulo() from public,anon,authenticated;
revoke all on function private.equipacion_validar_articulo_talla_catalogo() from public,anon,authenticated;
revoke all on function private.equipacion_articulo_admite_talla(uuid,text) from public,anon,authenticated;
grant execute on function private.equipacion_normalizar_sistema_tallaje_articulo() to service_role;
grant execute on function private.equipacion_validar_articulo_talla_catalogo() to service_role;
grant execute on function private.equipacion_articulo_admite_talla(uuid,text) to service_role;

commit;
