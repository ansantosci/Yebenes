-- 066 - General economic ledger by person and season.
-- Keeps legacy registration/federation economics intact; this is the new general source of truth.
begin;

create table if not exists public.economia_conceptos (
  id uuid primary key default gen_random_uuid(),
  codigo text not null unique,
  nombre text not null,
  tipo text not null check (tipo in ('cuota_temporada','equipacion','inscripcion_ficha','manual')),
  sistema boolean not null default false,
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.economia_conceptos(codigo,nombre,tipo,sistema) values
('CUOTA_TEMPORADA','Cuota de temporada','cuota_temporada',true),
('EQUIPACION','Equipacion','equipacion',true),
('INSCRIPCION_FICHA','Inscripcion / ficha','inscripcion_ficha',true),
('OTRO','Otro concepto','manual',true)
on conflict(codigo) do update set nombre=excluded.nombre,tipo=excluded.tipo,sistema=true,activo=true;

create table if not exists public.economia_cargos (
  id uuid primary key default gen_random_uuid(),
  persona_id uuid not null references public.personas(id) on delete restrict,
  temporada_id uuid not null references public.temporadas(id) on delete restrict,
  concepto_id uuid not null references public.economia_conceptos(id) on delete restrict,
  importe_base numeric(10,2) not null check (importe_base>=0),
  descripcion text,
  origen text not null check (origen in ('asignacion_equipo','equipacion','manual','migracion')),
  equipo_origen_id uuid references public.equipos(id) on delete set null,
  inscripcion_id uuid references public.inscripciones(id) on delete set null,
  equipacion_necesidad_id uuid references public.equipacion_necesidades(id) on delete set null,
  clave_origen text,
  estado text not null default 'activo' check (estado in ('activo','anulado')),
  creado_por uuid references auth.users(id) on delete set null,
  anulado_por uuid references auth.users(id) on delete set null,
  anulado_at timestamptz,
  motivo_anulacion text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((estado='activo' and anulado_at is null) or
         (estado='anulado' and anulado_at is not null and nullif(trim(coalesce(motivo_anulacion,'')),'') is not null))
);
-- One season fee obligation per person/season; team is only its calculation origin.
create unique index if not exists economia_cargos_cuota_persona_temporada_uq
on public.economia_cargos(persona_id,temporada_id)
where clave_origen='CUOTA_TEMPORADA';

-- Automatic equipment charges must be idempotent by their explicit business key.
create unique index if not exists economia_cargos_clave_origen_uq
on public.economia_cargos(temporada_id,persona_id,clave_origen)
where clave_origen is not null;

create table if not exists public.economia_ajustes (
  id uuid primary key default gen_random_uuid(),
  cargo_id uuid not null references public.economia_cargos(id) on delete restrict,
  tipo text not null check (tipo in ('descuento','regularizacion','anulacion')),
  importe numeric(10,2) not null check (importe<>0),
  nombre text not null,
  motivo text,
  origen text not null default 'manual' check (origen in ('automatico','manual')),
  creado_por uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.economia_pagos (
  id uuid primary key default gen_random_uuid(),
  cargo_id uuid not null references public.economia_cargos(id) on delete restrict,
  importe numeric(10,2) not null check (importe>0),
  metodo text not null check (metodo in ('efectivo','transferencia','clubber','tarjeta','otro')),
  fecha_pago date not null default current_date,
  referencia_externa text,
  observaciones text,
  registrado_por uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table if not exists public.economia_devoluciones (
  id uuid primary key default gen_random_uuid(),
  cargo_id uuid not null references public.economia_cargos(id) on delete restrict,
  importe numeric(10,2) not null check (importe>0),
  metodo text not null check (metodo in ('efectivo','transferencia','clubber','tarjeta','otro')),
  fecha_devolucion date not null default current_date,
  motivo text not null check (length(trim(motivo))>0),
  referencia_externa text,
  registrado_por uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table if not exists public.economia_modalidades_equipacion (
  id uuid primary key default gen_random_uuid(),
  temporada_id uuid not null references public.temporadas(id) on delete restrict,
  codigo text not null,
  nombre text not null,
  importe numeric(10,2) not null check (importe>=0),
  requiere_entrenamiento boolean not null default false,
  requiere_partido boolean not null default true,
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(temporada_id,codigo)
);

create table if not exists public.economia_cargo_equipacion (
  cargo_id uuid primary key references public.economia_cargos(id) on delete restrict,
  modalidad_id uuid not null references public.economia_modalidades_equipacion(id) on delete restrict,
  necesidad_entrenamiento_id uuid references public.equipacion_necesidades(id) on delete set null,
  necesidad_partido_id uuid references public.equipacion_necesidades(id) on delete set null,
  created_at timestamptz not null default now()
);

create or replace view public.economia_estado_cargos as
select c.id cargo_id,c.persona_id,c.temporada_id,c.concepto_id,c.importe_base,c.estado,
       coalesce(a.ajustes,0)::numeric(10,2) ajustes,
       greatest(c.importe_base+coalesce(a.ajustes,0),0)::numeric(10,2) importe_exigible,
       coalesce(p.pagado,0)::numeric(10,2) importe_pagado,
       coalesce(d.devuelto,0)::numeric(10,2) importe_devuelto,
       (coalesce(p.pagado,0)-coalesce(d.devuelto,0))::numeric(10,2) cobrado_neto,
       (greatest(c.importe_base+coalesce(a.ajustes,0),0)-coalesce(p.pagado,0)+coalesce(d.devuelto,0))::numeric(10,2) saldo_pendiente,
       case
         when c.estado='anulado' then 'anulado'
         when greatest(c.importe_base+coalesce(a.ajustes,0),0)-coalesce(p.pagado,0)+coalesce(d.devuelto,0)<=0 then 'pagado'
         when coalesce(p.pagado,0)-coalesce(d.devuelto,0)>0 then 'parcialmente_pagado'
         else 'pendiente'
       end estado_pago
from public.economia_cargos c
left join lateral (select sum(x.importe) ajustes from public.economia_ajustes x where x.cargo_id=c.id) a on true
left join lateral (select sum(x.importe) pagado from public.economia_pagos x where x.cargo_id=c.id) p on true
left join lateral (select sum(x.importe) devuelto from public.economia_devoluciones x where x.cargo_id=c.id) d on true;

create or replace view public.economia_cuenta_persona_temporada as
select persona_id,temporada_id,
       sum(importe_exigible)::numeric(10,2) total_exigible,
       sum(importe_pagado)::numeric(10,2) total_pagado,
       sum(importe_devuelto)::numeric(10,2) total_devuelto,
       sum(saldo_pendiente)::numeric(10,2) saldo_pendiente
from public.economia_estado_cargos
group by persona_id,temporada_id;

-- Club/Admin only mutation API. No payment exists without a charge.
create or replace function private.economia_registrar_pago(
  p_cargo uuid,p_importe numeric,p_metodo text,p_fecha date default current_date,
  p_referencia text default null,p_observaciones text default null
) returns uuid language plpgsql security definer set search_path='' as $$
declare eid uuid; actor uuid:=auth.uid(); c public.economia_cargos%rowtype;
begin
  if actor is null or not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
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
  if actor is null or not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
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
  if actor is null or not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
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

-- Security: family/player may later receive scoped SELECT policies; mutation stays RPC-only.
do $$ declare t text; begin
 foreach t in array array[
  'economia_conceptos','economia_cargos','economia_ajustes','economia_pagos',
  'economia_devoluciones','economia_modalidades_equipacion','economia_cargo_equipacion'
 ] loop
   execute format('alter table public.%I enable row level security',t);
   execute format('drop policy if exists %I_club_manage on public.%I',t,t);
   execute format('create policy %I_club_manage on public.%I to authenticated using (private.has_any_role(array[''administrador'',''club''])) with check (private.has_any_role(array[''administrador'',''club'']))',t,t);
 end loop;
end $$;

grant select on public.economia_conceptos,public.economia_cargos,public.economia_ajustes,public.economia_pagos,
 public.economia_devoluciones,public.economia_modalidades_equipacion,public.economia_cargo_equipacion,
 public.economia_estado_cargos,public.economia_cuenta_persona_temporada to authenticated,service_role;
grant insert,update,delete on public.economia_conceptos,public.economia_cargos,public.economia_ajustes,
 public.economia_modalidades_equipacion,public.economia_cargo_equipacion to authenticated;
grant all on public.economia_conceptos,public.economia_cargos,public.economia_ajustes,public.economia_pagos,
 public.economia_devoluciones,public.economia_modalidades_equipacion,public.economia_cargo_equipacion to service_role;
revoke all on public.economia_conceptos,public.economia_cargos,public.economia_ajustes,public.economia_pagos,
 public.economia_devoluciones,public.economia_modalidades_equipacion,public.economia_cargo_equipacion from anon;

revoke all on function private.economia_registrar_pago(uuid,numeric,text,date,text,text) from public,anon;
revoke all on function private.economia_aplicar_ajuste(uuid,text,numeric,text,text,text) from public,anon;
revoke all on function private.economia_anular_cargo(uuid,text) from public,anon;
grant execute on function private.economia_registrar_pago(uuid,numeric,text,date,text,text),
 private.economia_aplicar_ajuste(uuid,text,numeric,text,text,text),
 private.economia_anular_cargo(uuid,text) to authenticated,service_role;

commit;
