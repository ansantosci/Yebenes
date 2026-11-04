-- V95.3.0 backend foundation - Equipaciones phase 1.
begin;

create table if not exists public.equipacion_articulos (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  codigo text not null unique,
  tipo_prenda text not null,
  ambito text not null default 'ambos' check (ambito in ('jugador','entrenador','ambos')),
  variante text not null default 'general' check (variante in ('general','campo','portero')),
  usa_talla boolean not null default true,
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.equipacion_config_temporada (
  id uuid primary key default gen_random_uuid(),
  temporada_id uuid not null unique references public.temporadas(id) on delete restrict,
  proveedor_nombre text,
  proveedor_url text,
  proveedor_contacto text,
  precio_pack_completo numeric(10,2) not null default 0 check (precio_pack_completo >= 0),
  precio_solo_partido numeric(10,2) not null default 0 check (precio_solo_partido >= 0),
  politica_tecnicos text not null default 'solo_nuevas_altas' check (politica_tecnicos in ('renovar_todos','solo_nuevas_altas','seleccion_manual')),
  campana_estado text not null default 'no_iniciada' check (campana_estado in ('no_iniciada','abierta','cerrada')),
  campana_abre_at timestamptz,
  campana_limite date,
  campana_mensaje text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.equipacion_packs (
  id uuid primary key default gen_random_uuid(),
  temporada_id uuid not null references public.temporadas(id) on delete restrict,
  codigo text not null,
  nombre text not null,
  destinatario text not null check (destinatario in ('jugador','entrenador')),
  modalidad text not null check (modalidad in ('entrenamiento','partido_campo','partido_portero','tecnico','otro')),
  precio numeric(10,2) not null default 0 check (precio >= 0),
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (temporada_id,codigo)
);

create table if not exists public.equipacion_pack_articulos (
  id uuid primary key default gen_random_uuid(),
  pack_id uuid not null references public.equipacion_packs(id) on delete cascade,
  articulo_id uuid not null references public.equipacion_articulos(id) on delete restrict,
  cantidad integer not null default 1 check (cantidad > 0),
  obligatorio boolean not null default true,
  orden integer not null default 100,
  created_at timestamptz not null default now(),
  unique (pack_id,articulo_id)
);

create table if not exists public.equipacion_tallas_persona (
  id uuid primary key default gen_random_uuid(),
  persona_id uuid not null references public.personas(id) on delete restrict,
  temporada_id uuid not null references public.temporadas(id) on delete restrict,
  talla_general text not null check (talla_general in ('4XS','3XS','2XS','XS','S','M','L','XL','2XL','3XL')),
  aplica_todas boolean not null default true,
  confirmada_at timestamptz,
  comunicada_por uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (persona_id,temporada_id)
);

create table if not exists public.equipacion_tallas_excepcion (
  id uuid primary key default gen_random_uuid(),
  talla_persona_id uuid not null references public.equipacion_tallas_persona(id) on delete cascade,
  articulo_id uuid not null references public.equipacion_articulos(id) on delete restrict,
  talla text not null check (talla in ('4XS','3XS','2XS','XS','S','M','L','XL','2XL','3XL')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (talla_persona_id,articulo_id)
);

create table if not exists public.equipacion_necesidades (
  id uuid primary key default gen_random_uuid(),
  persona_id uuid not null references public.personas(id) on delete restrict,
  temporada_id uuid not null references public.temporadas(id) on delete restrict,
  faceta text not null check (faceta in ('jugador','entrenador')),
  jugador_id uuid references public.jugadores(id) on delete restrict,
  entrenador_id uuid references public.entrenadores(id) on delete restrict,
  pack_id uuid references public.equipacion_packs(id) on delete restrict,
  tipo_partido text check (tipo_partido is null or tipo_partido in ('campo','portero','campo_portero')),
  reutiliza_entrenamiento boolean not null default false,
  reutiliza_tecnico boolean not null default false,
  estado text not null default 'pendiente_tallas' check (estado in ('pendiente_tallas','comunicada','validada','preparacion','completa','cancelada')),
  origen text not null default 'temporada' check (origen in ('temporada','nueva_alta','manual')),
  solicitada_at timestamptz not null default now(),
  comunicada_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((faceta='jugador' and jugador_id is not null and entrenador_id is null) or (faceta='entrenador' and entrenador_id is not null and jugador_id is null)),
  unique (temporada_id,faceta,jugador_id),
  unique (temporada_id,faceta,entrenador_id)
);

create table if not exists public.equipacion_dorsales (
  id uuid primary key default gen_random_uuid(),
  temporada_id uuid not null references public.temporadas(id) on delete restrict,
  equipo_id uuid not null references public.equipos(id) on delete restrict,
  jugador_id uuid not null references public.jugadores(id) on delete restrict,
  dorsal integer not null check (dorsal between 1 and 99),
  es_portero boolean not null default false,
  origen text not null default 'manual' check (origen in ('manual','automatico')),
  asignado_por uuid references auth.users(id) on delete set null,
  asignado_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (temporada_id,equipo_id,jugador_id),
  unique (temporada_id,equipo_id,dorsal)
);

-- Generic updated_at triggers where the shared helper already exists.
drop trigger if exists equipacion_articulos_updated_at on public.equipacion_articulos;
create trigger equipacion_articulos_updated_at before update on public.equipacion_articulos for each row execute function public.set_updated_at();
drop trigger if exists equipacion_config_temporada_updated_at on public.equipacion_config_temporada;
create trigger equipacion_config_temporada_updated_at before update on public.equipacion_config_temporada for each row execute function public.set_updated_at();
drop trigger if exists equipacion_packs_updated_at on public.equipacion_packs;
create trigger equipacion_packs_updated_at before update on public.equipacion_packs for each row execute function public.set_updated_at();
drop trigger if exists equipacion_tallas_persona_updated_at on public.equipacion_tallas_persona;
create trigger equipacion_tallas_persona_updated_at before update on public.equipacion_tallas_persona for each row execute function public.set_updated_at();
drop trigger if exists equipacion_tallas_excepcion_updated_at on public.equipacion_tallas_excepcion;
create trigger equipacion_tallas_excepcion_updated_at before update on public.equipacion_tallas_excepcion for each row execute function public.set_updated_at();
drop trigger if exists equipacion_necesidades_updated_at on public.equipacion_necesidades;
create trigger equipacion_necesidades_updated_at before update on public.equipacion_necesidades for each row execute function public.set_updated_at();
drop trigger if exists equipacion_dorsales_updated_at on public.equipacion_dorsales;
create trigger equipacion_dorsales_updated_at before update on public.equipacion_dorsales for each row execute function public.set_updated_at();

-- Helper: current user may manage sizes for self or a currently represented player/person.
create or replace function private.can_manage_equipacion_tallas(target_persona_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select
    private.has_any_role(array['administrador'::text,'club'::text])
    or target_persona_id = private.current_person_id()
    or exists (
      select 1
      from public.jugadores j
      join public.representaciones_jugador r on r.jugador_id=j.id
      where j.persona_id=target_persona_id
        and r.representante_persona_id=private.current_person_id()
        and r.fecha_desde<=current_date
        and (r.fecha_hasta is null or r.fecha_hasta>=current_date)
    );
$$;

-- Helper: coach assigned to a team may read its dorsals.
create or replace function private.can_read_equipo_dorsales(target_equipo_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select private.has_any_role(array['administrador'::text,'club'::text])
    or exists (
      select 1
      from public.asignaciones_entrenador_equipo a
      join public.entrenadores e on e.id=a.entrenador_id
      where a.equipo_id=target_equipo_id
        and e.persona_id=private.current_person_id()
        and a.cancelada_at is null
        and a.fecha_desde<=current_date
        and (a.fecha_hasta is null or a.fecha_hasta>=current_date)
    );
$$;

-- RLS.
alter table public.equipacion_articulos enable row level security;
alter table public.equipacion_config_temporada enable row level security;
alter table public.equipacion_packs enable row level security;
alter table public.equipacion_pack_articulos enable row level security;
alter table public.equipacion_tallas_persona enable row level security;
alter table public.equipacion_tallas_excepcion enable row level security;
alter table public.equipacion_necesidades enable row level security;
alter table public.equipacion_dorsales enable row level security;

-- Catalog/configuration is readable by authenticated users, writable by Club/Admin.
create policy equipacion_articulos_read on public.equipacion_articulos for select to authenticated using (true);
create policy equipacion_articulos_admin_write on public.equipacion_articulos to authenticated using (private.has_any_role(array['administrador','club'])) with check (private.has_any_role(array['administrador','club']));
create policy equipacion_config_read on public.equipacion_config_temporada for select to authenticated using (true);
create policy equipacion_config_admin_write on public.equipacion_config_temporada to authenticated using (private.has_any_role(array['administrador','club'])) with check (private.has_any_role(array['administrador','club']));
create policy equipacion_packs_read on public.equipacion_packs for select to authenticated using (true);
create policy equipacion_packs_admin_write on public.equipacion_packs to authenticated using (private.has_any_role(array['administrador','club'])) with check (private.has_any_role(array['administrador','club']));
create policy equipacion_pack_articulos_read on public.equipacion_pack_articulos for select to authenticated using (true);
create policy equipacion_pack_articulos_admin_write on public.equipacion_pack_articulos to authenticated using (private.has_any_role(array['administrador','club'])) with check (private.has_any_role(array['administrador','club']));

-- Sizes: self/family/Club may read and communicate. Exceptions inherit access from the parent size record.
create policy equipacion_tallas_read on public.equipacion_tallas_persona for select to authenticated using (private.can_manage_equipacion_tallas(persona_id));
create policy equipacion_tallas_write on public.equipacion_tallas_persona to authenticated using (private.can_manage_equipacion_tallas(persona_id)) with check (private.can_manage_equipacion_tallas(persona_id));
create policy equipacion_tallas_excepcion_read on public.equipacion_tallas_excepcion for select to authenticated using (exists (select 1 from public.equipacion_tallas_persona t where t.id=talla_persona_id and private.can_manage_equipacion_tallas(t.persona_id)));
create policy equipacion_tallas_excepcion_write on public.equipacion_tallas_excepcion to authenticated using (exists (select 1 from public.equipacion_tallas_persona t where t.id=talla_persona_id and private.can_manage_equipacion_tallas(t.persona_id))) with check (exists (select 1 from public.equipacion_tallas_persona t where t.id=talla_persona_id and private.can_manage_equipacion_tallas(t.persona_id)));

-- Needs are visible to the person/family and managed by Club/Admin in phase 1.
create policy equipacion_necesidades_read on public.equipacion_necesidades for select to authenticated using (private.can_manage_equipacion_tallas(persona_id));
create policy equipacion_necesidades_admin_write on public.equipacion_necesidades to authenticated using (private.has_any_role(array['administrador','club'])) with check (private.has_any_role(array['administrador','club']));

-- Dorsals: Club/Admin write; player/family and assigned coaches may read.
create policy equipacion_dorsales_read on public.equipacion_dorsales for select to authenticated using (
  private.can_read_equipo_dorsales(equipo_id)
  or exists (select 1 from public.jugadores j where j.id=jugador_id and private.can_manage_equipacion_tallas(j.persona_id))
);
create policy equipacion_dorsales_admin_write on public.equipacion_dorsales to authenticated using (private.has_any_role(array['administrador','club'])) with check (private.has_any_role(array['administrador','club']));

-- Explicit grants (new public tables must never rely on implicit Data API grants).
grant select,insert,update,delete on public.equipacion_articulos, public.equipacion_config_temporada, public.equipacion_packs, public.equipacion_pack_articulos, public.equipacion_tallas_persona, public.equipacion_tallas_excepcion, public.equipacion_necesidades, public.equipacion_dorsales to authenticated;
grant all on public.equipacion_articulos, public.equipacion_config_temporada, public.equipacion_packs, public.equipacion_pack_articulos, public.equipacion_tallas_persona, public.equipacion_tallas_excepcion, public.equipacion_necesidades, public.equipacion_dorsales to service_role;
revoke all on public.equipacion_articulos, public.equipacion_config_temporada, public.equipacion_packs, public.equipacion_pack_articulos, public.equipacion_tallas_persona, public.equipacion_tallas_excepcion, public.equipacion_necesidades, public.equipacion_dorsales from anon;

commit;
select '051_v95_3_0_equipaciones_fundacion' as migration, 'PASS' as result;
