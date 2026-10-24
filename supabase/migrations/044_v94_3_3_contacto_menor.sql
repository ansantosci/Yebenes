-- V94.3.3 - contacto no federativo de menor representado
-- Permite al tutor activo actualizar exclusivamente el telefono de la Persona menor.
-- No modifica inscripciones, estados federativos, documentos ni correo.

create or replace function public.actualizar_contacto_menor_representado(
  p_jugador_id uuid,
  p_telefono text default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth uuid := auth.uid();
  v_tutor uuid;
  v_persona uuid;
  v_old_phone text;
  v_new_phone text := nullif(trim(coalesce(p_telefono,'')),'');
begin
  if v_auth is null or not private.has_role('tutor') then
    raise exception 'Solo Tutor/Familia puede modificar el contacto de menores representados';
  end if;

  select p.id into v_tutor
  from public.personas p
  where p.auth_user_id=v_auth and p.activo=true
  limit 1;

  select j.persona_id into v_persona
  from public.jugadores j
  join public.personas menor on menor.id=j.persona_id and menor.activo=true
  join public.representaciones_jugador r on r.jugador_id=j.id
  where j.id=p_jugador_id
    and r.representante_persona_id=v_tutor
    and r.fecha_desde<=current_date
    and (r.fecha_hasta is null or r.fecha_hasta>=current_date)
    and menor.fecha_nacimiento > (current_date - interval '18 years')::date
  order by r.fecha_desde desc
  limit 1;

  if v_persona is null then
    raise exception 'No representas actualmente a este jugador menor';
  end if;

  select p.telefono into v_old_phone from public.personas p where p.id=v_persona;

  update public.personas p
  set telefono=v_new_phone, updated_at=now()
  where p.id=v_persona;

  insert into public.auditoria(entidad,entidad_id,accion,actor_auth_user_id,datos_nuevos)
  values(
    'jugador',p_jugador_id,'modificacion_contacto_por_tutor',v_auth,
    jsonb_build_object(
      'persona_id',v_persona,
      'telefono_anterior',v_old_phone,
      'telefono_nuevo',v_new_phone,
      'afecta_validacion_federativa',false
    )
  );

  return p_jugador_id;
end;
$$;

alter function public.actualizar_contacto_menor_representado(uuid,text) owner to postgres;
grant execute on function public.actualizar_contacto_menor_representado(uuid,text) to authenticated;

-- Verificacion de contrato: debe existir una unica firma utilizable.
do $$
begin
  if to_regprocedure('public.actualizar_contacto_menor_representado(uuid,text)') is null then
    raise exception 'V94.3.3: RPC actualizar_contacto_menor_representado no instalado';
  end if;
end $$;

select 'rpc_contacto_menor',
       case when to_regprocedure('public.actualizar_contacto_menor_representado(uuid,text)') is not null then 1 else 0 end as ok;
