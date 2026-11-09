-- 060 - Common person/season/facet participation layer.
-- Additive compatibility migration: existing domain tables remain authoritative for current V95.3.12 flows.
begin;

create table if not exists public.persona_participaciones_temporada (
  id uuid primary key default gen_random_uuid(),
  persona_id uuid not null references public.personas(id) on delete restrict,
  temporada_id uuid not null references public.temporadas(id) on delete restrict,
  faceta text not null check (faceta in ('jugador','entrenador')),
  origen text not null default 'administrativa'
    check (origen in ('continuidad','nueva_alta','administrativa','migracion_inicial')),
  estado text not null default 'propuesta'
    check (estado in ('propuesta','solicitada','en_revision','aceptada','no_aceptada','no_continua','baja')),
  categoria_prevista_id uuid references public.categorias(id) on delete restrict,
  solicitada_at timestamptz,
  aceptada_at timestamptz,
  aceptada_por uuid references auth.users(id) on delete set null,
  baja_at timestamptz,
  motivo_baja text,
  observaciones text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(persona_id,temporada_id,faceta),
  check (faceta='jugador' or categoria_prevista_id is null),
  check ((estado='aceptada' and aceptada_at is not null) or estado<>'aceptada'),
  check ((estado='baja' and baja_at is not null) or estado<>'baja')
);

create table if not exists public.historico_participaciones_temporada (
  id uuid primary key default gen_random_uuid(),
  participacion_id uuid not null references public.persona_participaciones_temporada(id) on delete restrict,
  estado_anterior text check (estado_anterior is null or estado_anterior in ('propuesta','solicitada','en_revision','aceptada','no_aceptada','no_continua','baja')),
  estado_nuevo text not null check (estado_nuevo in ('propuesta','solicitada','en_revision','aceptada','no_aceptada','no_continua','baja')),
  origen_cambio text not null default 'sistema'
    check (origen_cambio in ('familia','persona','club','sistema','migracion')),
  motivo text,
  cambiado_por uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists persona_participaciones_temporada_temporada_estado_idx
  on public.persona_participaciones_temporada(temporada_id,faceta,estado);
create index if not exists historico_participaciones_temporada_participacion_idx
  on public.historico_participaciones_temporada(participacion_id,created_at);

-- Facet integrity without duplicating jugador_id/entrenador_id in the participation row.
create or replace function private.validar_faceta_participacion_temporada()
returns trigger language plpgsql set search_path='' as $$
begin
  if new.faceta='jugador' and not exists(
    select 1 from public.jugadores j where j.persona_id=new.persona_id
  ) then
    raise exception 'Season participation facet jugador requires an existing player facet';
  end if;
  if new.faceta='entrenador' and not exists(
    select 1 from public.entrenadores e where e.persona_id=new.persona_id
  ) then
    raise exception 'Season participation facet entrenador requires an existing coach facet';
  end if;
  if new.categoria_prevista_id is not null and not exists(
    select 1 from public.reglas_categoria_temporada r
    where r.temporada_id=new.temporada_id and r.categoria_id=new.categoria_prevista_id and r.activo=true
  ) then
    raise exception 'Expected category must be configured for the participation season';
  end if;
  new.updated_at=now();
  return new;
end $$;

drop trigger if exists persona_participaciones_temporada_faceta_guard on public.persona_participaciones_temporada;
create trigger persona_participaciones_temporada_faceta_guard
before insert or update of persona_id,temporada_id,faceta,categoria_prevista_id
on public.persona_participaciones_temporada
for each row execute function private.validar_faceta_participacion_temporada();

create or replace function private.registrar_historico_participacion_temporada()
returns trigger language plpgsql set search_path='' as $$
begin
  if tg_op='INSERT' then
    insert into public.historico_participaciones_temporada(
      participacion_id,estado_anterior,estado_nuevo,origen_cambio,motivo,cambiado_por
    ) values(new.id,null,new.estado,
      case when new.origen='migracion_inicial' then 'migracion' else 'sistema' end,
      'Creacion de participacion de temporada',auth.uid());
  elsif new.estado is distinct from old.estado then
    insert into public.historico_participaciones_temporada(
      participacion_id,estado_anterior,estado_nuevo,origen_cambio,motivo,cambiado_por
    ) values(new.id,old.estado,new.estado,'sistema','Cambio de estado',auth.uid());
  end if;
  return new;
end $$;

drop trigger if exists persona_participaciones_temporada_history on public.persona_participaciones_temporada;
create trigger persona_participaciones_temporada_history
after insert or update of estado on public.persona_participaciones_temporada
for each row execute function private.registrar_historico_participacion_temporada();

-- Backfill from player season registrations. Existing non-cancelled registrations prove participation;
-- cancelled historical registrations are conservatively reconstructed as baja without inventing dates.
insert into public.persona_participaciones_temporada(
  persona_id,temporada_id,faceta,origen,estado,categoria_prevista_id,aceptada_at,baja_at,observaciones
)
select j.persona_id,i.temporada_id,'jugador','migracion_inicial',
       case when i.estado='cancelada' then 'baja' else 'aceptada' end,
       i.categoria_id,
       case when i.estado<>'cancelada' then coalesce(i.fecha_validacion,i.created_at) end,
       case when i.estado='cancelada' then i.updated_at end,
       'Backfill 060 desde inscripciones'
from public.inscripciones i join public.jugadores j on j.id=i.jugador_id
on conflict(persona_id,temporada_id,faceta) do nothing;

-- Backfill coach season participation.
insert into public.persona_participaciones_temporada(
  persona_id,temporada_id,faceta,origen,estado,aceptada_at,baja_at,observaciones
)
select e.persona_id,et.temporada_id,'entrenador','migracion_inicial',
       case when et.estado='baja' then 'baja' else 'aceptada' end,
       case when et.estado<>'baja' then et.created_at end,
       case when et.estado='baja' then et.updated_at end,
       'Backfill 060 desde entrenador_temporadas'
from public.entrenador_temporadas et join public.entrenadores e on e.id=et.entrenador_id
on conflict(persona_id,temporada_id,faceta) do nothing;

-- Reconcile any equipment-only season validations not represented by the two primary sources.
insert into public.persona_participaciones_temporada(
  persona_id,temporada_id,faceta,origen,estado,aceptada_at,baja_at,observaciones
)
select ep.persona_id,ep.temporada_id,ep.faceta,'migracion_inicial',
       case ep.estado when 'validada' then 'aceptada' when 'rechazada' then 'no_aceptada'
                      when 'baja' then 'baja' else 'en_revision' end,
       case when ep.estado='validada' then coalesce(ep.validada_at,ep.created_at) end,
       case when ep.estado='baja' then ep.updated_at end,
       'Backfill 060 desde equipacion_personas_temporada'
from public.equipacion_personas_temporada ep
on conflict(persona_id,temporada_id,faceta) do nothing;

-- Security: club/admin manages; a person can read only their own participation rows.
alter table public.persona_participaciones_temporada enable row level security;
alter table public.historico_participaciones_temporada enable row level security;

drop policy if exists persona_participaciones_temporada_club_manage on public.persona_participaciones_temporada;
create policy persona_participaciones_temporada_club_manage
on public.persona_participaciones_temporada to authenticated
using (private.has_any_role(array['administrador','club']))
with check (private.has_any_role(array['administrador','club']));

drop policy if exists persona_participaciones_temporada_self_read on public.persona_participaciones_temporada;
create policy persona_participaciones_temporada_self_read
on public.persona_participaciones_temporada for select to authenticated
using (persona_id=private.current_person_id());

drop policy if exists historico_participaciones_temporada_club_read on public.historico_participaciones_temporada;
create policy historico_participaciones_temporada_club_read
on public.historico_participaciones_temporada for select to authenticated
using (private.has_any_role(array['administrador','club']));

drop policy if exists historico_participaciones_temporada_self_read on public.historico_participaciones_temporada;
create policy historico_participaciones_temporada_self_read
on public.historico_participaciones_temporada for select to authenticated
using (exists(select 1 from public.persona_participaciones_temporada p
             where p.id=participacion_id and p.persona_id=private.current_person_id()));

grant select,insert,update,delete on public.persona_participaciones_temporada to authenticated;
grant select on public.historico_participaciones_temporada to authenticated;
grant all on public.persona_participaciones_temporada,public.historico_participaciones_temporada to service_role;
revoke all on public.persona_participaciones_temporada,public.historico_participaciones_temporada from anon;

revoke all on function private.validar_faceta_participacion_temporada() from public,anon,authenticated;
revoke all on function private.registrar_historico_participacion_temporada() from public,anon,authenticated;
grant execute on function private.validar_faceta_participacion_temporada() to service_role;
grant execute on function private.registrar_historico_participacion_temporada() to service_role;

commit;
