-- V95.3.5 backend - season validation before equipment sizing/needs.
begin;
create table if not exists public.equipacion_personas_temporada (
 id uuid primary key default gen_random_uuid(), persona_id uuid not null references public.personas(id) on delete restrict,
 temporada_id uuid not null references public.temporadas(id) on delete restrict,
 faceta text not null check (faceta in ('jugador','entrenador')),
 jugador_id uuid references public.jugadores(id) on delete restrict, entrenador_id uuid references public.entrenadores(id) on delete restrict,
 estado text not null default 'pendiente_validacion' check (estado in ('pendiente_validacion','validada','rechazada','baja')),
 validada_at timestamptz, validada_por uuid references auth.users(id) on delete set null, observaciones text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check ((faceta='jugador' and jugador_id is not null and entrenador_id is null) or (faceta='entrenador' and entrenador_id is not null and jugador_id is null)),
 unique (temporada_id,faceta,jugador_id), unique (temporada_id,faceta,entrenador_id)
);
alter table public.equipacion_necesidades add column if not exists persona_temporada_id uuid references public.equipacion_personas_temporada(id) on delete restrict;
alter table public.equipacion_necesidades add column if not exists confirmada_at timestamptz;
update public.equipacion_necesidades set confirmada_at=coalesce(confirmada_at,comunicada_at,created_at) where confirmada_at is null;
create or replace function private.equipacion_validar_necesidad_confirmada() returns trigger language plpgsql set search_path=public,private as $$
declare v_estado text;
begin
 if new.persona_temporada_id is null then return new; end if;
 select estado into v_estado from public.equipacion_personas_temporada
 where id=new.persona_temporada_id and persona_id=new.persona_id and temporada_id=new.temporada_id and faceta=new.faceta;
 if v_estado is distinct from 'validada' then raise exception 'Equipment need requires a club-validated person for the season'; end if;
 if new.confirmada_at is null then raise exception 'Equipment need is created only after sizes/equipment choice are confirmed'; end if;
 if not exists(select 1 from public.equipacion_tallas_persona t where t.persona_id=new.persona_id and t.temporada_id=new.temporada_id and t.confirmada_at is not null)
 then raise exception 'Equipment need requires confirmed sizes'; end if;
 return new;
end $$;
drop trigger if exists equipacion_necesidades_validacion_temporada on public.equipacion_necesidades;
create trigger equipacion_necesidades_validacion_temporada before insert or update of persona_temporada_id,confirmada_at,pack_id on public.equipacion_necesidades
for each row execute function private.equipacion_validar_necesidad_confirmada();
commit;
