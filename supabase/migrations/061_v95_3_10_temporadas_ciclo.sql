-- 061 - Season lifecycle infrastructure.
-- Additive backend only: no frontend context selector yet.
begin;

alter table public.temporadas drop constraint if exists temporadas_estado_check;
alter table public.temporadas
  add constraint temporadas_estado_check
  check (estado in ('planificacion','activa','en_cierre','cerrada'));

alter table public.temporadas add column if not exists activada_at timestamptz;
alter table public.temporadas add column if not exists en_cierre_at timestamptz;
alter table public.temporadas add column if not exists cerrada_at timestamptz;
alter table public.temporadas add column if not exists estado_cambiado_por uuid references auth.users(id) on delete set null;

-- Reconstruct reliable lifecycle timestamps only where the current state proves the event.
update public.temporadas
set activada_at=coalesce(activada_at,created_at)
where estado='activa' and activada_at is null;
update public.temporadas
set cerrada_at=coalesce(cerrada_at,updated_at,created_at)
where estado='cerrada' and cerrada_at is null;

create table if not exists public.historico_estados_temporada (
  id uuid primary key default gen_random_uuid(),
  temporada_id uuid not null references public.temporadas(id) on delete restrict,
  estado_anterior text check (estado_anterior is null or estado_anterior in ('planificacion','activa','en_cierre','cerrada')),
  estado_nuevo text not null check (estado_nuevo in ('planificacion','activa','en_cierre','cerrada')),
  motivo text,
  cambiado_por uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists historico_estados_temporada_temporada_idx
  on public.historico_estados_temporada(temporada_id,created_at);

create or replace function private.temporada_registrar_cambio(
  p_temporada_id uuid,p_anterior text,p_nuevo text,p_motivo text,p_actor uuid
) returns void language plpgsql security definer set search_path='' as $$
begin
  insert into public.historico_estados_temporada(temporada_id,estado_anterior,estado_nuevo,motivo,cambiado_por)
  values(p_temporada_id,p_anterior,p_nuevo,p_motivo,p_actor);
end $$;

create or replace function public.activar_temporada(p_temporada_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=auth.uid();
  v_old public.temporadas%rowtype;
  v_prev public.temporadas%rowtype;
begin
  if v_actor is null or not private.has_any_role(array['administrador','club']) then
    raise exception 'Solo Club o Administrador puede activar una temporada';
  end if;

  select * into v_old from public.temporadas where id=p_temporada_id for update;
  if not found then raise exception 'Temporada no encontrada'; end if;
  if v_old.estado<>'planificacion' then
    raise exception 'Solo una temporada en planificacion puede activarse';
  end if;

  select * into v_prev
  from public.temporadas
  where estado='activa' and id<>p_temporada_id
  order by fecha_inicio desc nulls last
  limit 1
  for update;

  if v_prev.id is not null then
    update public.temporadas
    set estado='en_cierre',en_cierre_at=now(),estado_cambiado_por=v_actor,updated_at=now()
    where id=v_prev.id;
    perform private.temporada_registrar_cambio(
      v_prev.id,'activa','en_cierre',
      'Paso automatico a cierre al activar la temporada '||v_old.nombre,v_actor
    );
  end if;

  update public.temporadas
  set estado='activa',activada_at=coalesce(activada_at,now()),
      en_cierre_at=null,cerrada_at=null,estado_cambiado_por=v_actor,updated_at=now()
  where id=p_temporada_id;

  perform private.temporada_registrar_cambio(
    p_temporada_id,'planificacion','activa','Activacion de temporada',v_actor
  );
  return p_temporada_id;
end $$;

create or replace function public.cerrar_temporada(p_temporada_id uuid,p_motivo text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=auth.uid();
  v_old public.temporadas%rowtype;
begin
  if v_actor is null or not private.has_any_role(array['administrador','club']) then
    raise exception 'Solo Club o Administrador puede cerrar una temporada';
  end if;
  select * into v_old from public.temporadas where id=p_temporada_id for update;
  if not found then raise exception 'Temporada no encontrada'; end if;
  if v_old.estado<>'en_cierre' then
    raise exception 'Solo una temporada en proceso de cierre puede cerrarse';
  end if;
  update public.temporadas
  set estado='cerrada',cerrada_at=now(),estado_cambiado_por=v_actor,updated_at=now()
  where id=p_temporada_id;
  perform private.temporada_registrar_cambio(
    p_temporada_id,'en_cierre','cerrada',coalesce(nullif(trim(p_motivo),''),'Cierre de temporada'),v_actor
  );
  return p_temporada_id;
end $$;

-- Security parity with existing club-managed administrative data.
alter table public.historico_estados_temporada enable row level security;
drop policy if exists historico_estados_temporada_club_read on public.historico_estados_temporada;
create policy historico_estados_temporada_club_read
on public.historico_estados_temporada for select to authenticated
using (private.has_any_role(array['administrador','club']));

grant select on public.historico_estados_temporada to authenticated;
grant all on public.historico_estados_temporada to service_role;
revoke all on public.historico_estados_temporada from anon;

revoke all on function private.temporada_registrar_cambio(uuid,text,text,text,uuid) from public,anon,authenticated;
grant execute on function private.temporada_registrar_cambio(uuid,text,text,text,uuid) to service_role;

revoke all on function public.activar_temporada(uuid) from public,anon;
grant execute on function public.activar_temporada(uuid) to authenticated,service_role;
revoke all on function public.cerrar_temporada(uuid,text) from public,anon;
grant execute on function public.cerrar_temporada(uuid,text) to authenticated,service_role;

commit;
