-- 104 - Converge Structure server authorization to capability RBAC.
begin;

-- Teams: writes follow the active profile capability, not role names.
drop policy if exists equipos_club_admin_write on public.equipos;
drop policy if exists equipos_structure_manage_write on public.equipos;
create policy equipos_structure_manage_write
on public.equipos
to authenticated
using (private.has_capability('structure.manage'))
with check (private.has_capability('structure.manage'));

-- Season lifecycle: preserve behavior, replace role authorization with structure.manage.
create or replace function public.activar_temporada(p_temporada_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=auth.uid();
  v_old public.temporadas%rowtype;
  v_prev public.temporadas%rowtype;
begin
  if v_actor is null or not private.has_capability('structure.manage') then
    raise exception 'No tienes capacidad para activar una temporada';
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
  if v_actor is null or not private.has_capability('structure.manage') then
    raise exception 'No tienes capacidad para cerrar una temporada';
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

drop policy if exists historico_estados_temporada_club_read on public.historico_estados_temporada;
drop policy if exists historico_estados_temporada_structure_read on public.historico_estados_temporada;
create policy historico_estados_temporada_structure_read
on public.historico_estados_temporada
for select to authenticated
using (private.has_capability('structure.manage'));

-- Economic configuration is currently part of Structure. Keep its business behavior
-- unchanged, but converge its authorization to the capability used by that UI.
create or replace function public.configurar_economia_equipo(
  p_equipo_id uuid,
  p_importe_inscripcion numeric,
  p_admite_fraccionamiento boolean,
  p_requiere_pago_ficha boolean,
  p_observaciones text default null
) returns uuid
language plpgsql security definer set search_path='' as $$
declare
  v_temporada_id uuid;
  v_id uuid;
  v_ins uuid;
begin
  if not private.has_capability('structure.manage') then
    raise exception 'No tienes capacidad para configurar importes de equipo';
  end if;

  select e.temporada_id into v_temporada_id
    from public.equipos e
   where e.id = p_equipo_id;
  if v_temporada_id is null then raise exception 'Equipo no encontrado'; end if;

  if p_requiere_pago_ficha and (p_importe_inscripcion is null or p_importe_inscripcion <= 0) then
    raise exception 'Indica un importe mayor que cero cuando el pago es obligatorio';
  end if;
  if p_importe_inscripcion is not null and p_importe_inscripcion < 0 then
    raise exception 'El importe no puede ser negativo';
  end if;

  insert into public.configuracion_economica_equipo(
    temporada_id,equipo_id,importe_inscripcion,admite_fraccionamiento,
    requiere_pago_ficha,observaciones,creado_por,actualizado_por
  ) values (
    v_temporada_id,p_equipo_id,p_importe_inscripcion,
    coalesce(p_admite_fraccionamiento,false),coalesce(p_requiere_pago_ficha,true),
    nullif(trim(coalesce(p_observaciones,'')),''),auth.uid(),auth.uid()
  )
  on conflict (temporada_id,equipo_id) do update set
    importe_inscripcion = excluded.importe_inscripcion,
    admite_fraccionamiento = excluded.admite_fraccionamiento,
    requiere_pago_ficha = excluded.requiere_pago_ficha,
    observaciones = excluded.observaciones,
    actualizado_por = auth.uid(),
    updated_at = now()
  returning id into v_id;

  for v_ins in
    select distinct a.inscripcion_id
      from public.asignaciones_jugador_equipo a
      join public.inscripciones i on i.id = a.inscripcion_id
     where a.equipo_id = p_equipo_id
       and i.temporada_id = v_temporada_id
       and (a.fecha_desde is null or a.fecha_desde <= current_date)
       and (a.fecha_hasta is null or a.fecha_hasta >= current_date)
  loop
    perform private.recalcular_situacion_economica(v_ins);
  end loop;

  return v_id;
end $$;

commit;
