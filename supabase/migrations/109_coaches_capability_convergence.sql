-- 109_coaches_capability_convergence.sql
-- Phase 2 RBAC: coach-domain writes authorize by effective capability, not role names.

create or replace function public.asignar_rol_entrenador(p_persona_id uuid, p_licencia_tipo text DEFAULT NULL::text, p_licencia_numero text DEFAULT NULL::text, p_curso_delegado boolean DEFAULT false, p_activo boolean DEFAULT true, p_observaciones text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_entrenador_id uuid; v_role_id uuid; v_birth date;
begin
  if auth.uid() is null then raise exception 'Es necesario iniciar sesion'; end if;
  if not private.has_capability('coaches.manage') then raise exception 'No autorizado para asignar el rol entrenador'; end if;
  select fecha_nacimiento into v_birth from public.personas where id=p_persona_id;
  if not found then raise exception 'Persona no encontrada'; end if;
  select id into v_role_id from public.roles where codigo='entrenador' limit 1;
  if v_role_id is null then raise exception 'No existe el rol entrenador'; end if;
  if exists(select 1 from public.persona_roles where persona_id=p_persona_id and rol_id=v_role_id) then
    update public.persona_roles set activo=true,fecha_desde=coalesce(fecha_desde,current_date),fecha_hasta=null,updated_at=now() where persona_id=p_persona_id and rol_id=v_role_id;
  else
    insert into public.persona_roles(persona_id,rol_id,activo,fecha_desde,fecha_hasta,otorgado_por) values(p_persona_id,v_role_id,true,current_date,null,auth.uid());
  end if;
  select id into v_entrenador_id from public.entrenadores where persona_id=p_persona_id limit 1;
  if v_entrenador_id is null then
    insert into public.entrenadores(persona_id,activo,licencia_tipo,licencia_numero,curso_delegado,observaciones)
    values(p_persona_id,p_activo,nullif(trim(coalesce(p_licencia_tipo,'')),''),nullif(trim(coalesce(p_licencia_numero,'')),''),coalesce(p_curso_delegado,false),nullif(trim(coalesce(p_observaciones,'')),'')) returning id into v_entrenador_id;
  else
    update public.entrenadores set activo=p_activo,licencia_tipo=nullif(trim(coalesce(p_licencia_tipo,'')),''),licencia_numero=nullif(trim(coalesce(p_licencia_numero,'')),''),curso_delegado=coalesce(p_curso_delegado,false),observaciones=nullif(trim(coalesce(p_observaciones,'')),'') where id=v_entrenador_id;
  end if;
  if p_activo and v_birth is not null and v_birth>(current_date-interval '18 years')::date then
    perform public.solicitar_autorizacion_entrenador_menor(p_persona_id);
  end if;
  return v_entrenador_id;
end;
$$;

create or replace function public.guardar_asignaciones_entrenador(p_entrenador_id uuid, p_asignaciones jsonb) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  rec jsonb;
  v_team uuid;
  v_start date;
  v_end date;
  v_funcion text;
  v_persona uuid;
  v_temporada uuid;
  v_replace boolean;
  v_conflict record;
  v_existing_id uuid;
  v_same_start record;
begin
  if auth.uid() is null then
    raise exception 'Es necesario iniciar sesion';
  end if;

  if not private.has_capability('coaches.manage') then
    raise exception 'No autorizado para gestionar asignaciones';
  end if;

  select persona_id
    into v_persona
    from public.entrenadores
   where id=p_entrenador_id;

  if v_persona is null then
    raise exception 'Entrenador no encontrado';
  end if;

  if jsonb_array_length(coalesce(p_asignaciones,'[]'::jsonb))>0
     and not private.autorizacion_entrenador_menor_vigente(v_persona) then
    raise exception 'El entrenador es menor y necesita autorizacion expresa de su tutor antes de tener asignaciones activas';
  end if;

  -- Validacion defensiva del payload: una Persona no puede ocupar dos
  -- funciones solapadas en el mismo equipo.
  if exists(
    with x as (
      select
        ord,
        (value->>'team_id')::uuid as team_id,
        coalesce(nullif(value->>'fecha_desde','')::date,current_date) as fecha_desde,
        nullif(value->>'fecha_hasta','')::date as fecha_hasta
      from jsonb_array_elements(coalesce(p_asignaciones,'[]'::jsonb))
           with ordinality j(value,ord)
    )
    select 1
      from x a
      join x b
        on a.ord < b.ord
       and a.team_id=b.team_id
       and daterange(a.fecha_desde,coalesce(a.fecha_hasta,'infinity'::date),'[]')
           && daterange(b.fecha_desde,coalesce(b.fecha_hasta,'infinity'::date),'[]')
  ) then
    raise exception 'El entrenador no puede tener dos asignaciones solapadas para el mismo equipo';
  end if;

  -- V88/V89: aplicar primero cambios explicitos de fecha_hasta sobre una
  -- etapa existente. Esto permite cambios de funcion con fecha posterior:
  -- la etapa anterior queda cerrada el dia previo y la nueva se inserta.
  for rec in
    select value
      from jsonb_array_elements(coalesce(p_asignaciones,'[]'::jsonb))
  loop
    v_team:=(rec->>'team_id')::uuid;
    v_start:=coalesce(nullif(rec->>'fecha_desde','')::date,current_date);
    v_end:=nullif(rec->>'fecha_hasta','')::date;
    v_funcion:=coalesce(nullif(trim(rec->>'funcion'),''),'first');

    update public.asignaciones_entrenador_equipo a
       set fecha_hasta=v_end,
           motivo_fin=case
             when v_end is not null then coalesce(a.motivo_fin,'Cambio de funcion')
             else a.motivo_fin
           end,
           updated_at=now()
     where a.entrenador_id=p_entrenador_id
       and a.equipo_id=v_team
       and a.funcion=v_funcion
       and a.fecha_desde=v_start
       and a.cancelada_at is null
       and a.fecha_hasta is distinct from v_end;
  end loop;

  -- V89: cambio de funcion que empieza exactamente el mismo dia que la
  -- asignacion ya existente. No se crea una segunda fila: se transforma la
  -- fila existente. De este modo se respeta la regla unica legacy de
  -- asignacion activa y no se genera una etapa de duracion cero.
  for rec in
    select value
      from jsonb_array_elements(coalesce(p_asignaciones,'[]'::jsonb))
  loop
    v_team:=(rec->>'team_id')::uuid;
    v_start:=coalesce(nullif(rec->>'fecha_desde','')::date,current_date);
    v_end:=nullif(rec->>'fecha_hasta','')::date;
    v_funcion:=coalesce(nullif(trim(rec->>'funcion'),''),'first');
    v_replace:=coalesce((rec->>'reemplazar_principal')::boolean,false);

    if v_funcion not in ('first','second','goalkeeper','fitness') then
      raise exception 'Funcion de tecnico no valida';
    end if;

    if v_end is not null and v_end<v_start then
      raise exception 'La fecha de fin no puede ser anterior a la fecha de inicio';
    end if;

    select a.*
      into v_same_start
      from public.asignaciones_entrenador_equipo a
     where a.entrenador_id=p_entrenador_id
       and a.equipo_id=v_team
       and a.fecha_desde=v_start
       and a.cancelada_at is null
       and a.funcion<>v_funcion
     order by a.created_at desc nulls last
     limit 1
     for update;

    if not found then
      continue;
    end if;

    -- Si el cambio es a Principal, primero resolvemos al Principal actual.
    -- El trigger de principal unico puede entonces validar el UPDATE de la
    -- propia fila sin encontrar un Principal solapado.
    if v_funcion='first' then
      for v_conflict in
        select a.*
          from public.asignaciones_entrenador_equipo a
         where a.equipo_id=v_team
           and a.entrenador_id<>p_entrenador_id
           and a.funcion='first'
           and a.cancelada_at is null
           and daterange(a.fecha_desde,coalesce(a.fecha_hasta,'infinity'::date),'[]')
               && daterange(v_start,coalesce(v_end,'infinity'::date),'[]')
         for update
      loop
        if not v_replace then
          raise exception 'El equipo ya tiene un entrenador principal vigente en ese periodo';
        end if;

        insert into public.auditoria(
          entidad,
          entidad_id,
          accion,
          actor_auth_user_id,
          datos_anteriores,
          datos_nuevos
        ) values(
          'asignacion_entrenador_equipo',
          v_conflict.id,
          'sustitucion_entrenador_principal',
          auth.uid(),
          to_jsonb(v_conflict),
          jsonb_build_object(
            'nuevo_entrenador_id',p_entrenador_id,
            'equipo_id',v_team,
            'fecha_sustitucion',v_start
          )
        );

        if v_conflict.fecha_desde < v_start then
          update public.asignaciones_entrenador_equipo
             set fecha_hasta=v_start-1,
                 motivo_fin='Sustitucion de entrenador principal',
                 updated_at=now()
           where id=v_conflict.id;
        else
          update public.asignaciones_entrenador_equipo
             set cancelada_at=now(),
                 motivo_fin='Sustitucion de entrenador principal antes de inicio',
                 updated_at=now()
           where id=v_conflict.id;
        end if;
      end loop;
    end if;

    insert into public.auditoria(
      entidad,
      entidad_id,
      accion,
      actor_auth_user_id,
      datos_anteriores,
      datos_nuevos
    ) values(
      'asignacion_entrenador_equipo',
      v_same_start.id,
      'cambio_funcion_entrenador',
      auth.uid(),
      to_jsonb(v_same_start),
      jsonb_build_object(
        'entrenador_id',p_entrenador_id,
        'equipo_id',v_team,
        'funcion_anterior',v_same_start.funcion,
        'funcion_nueva',v_funcion,
        'fecha_desde',v_start,
        'fecha_hasta',v_end
      )
    );

    update public.asignaciones_entrenador_equipo
       set funcion=v_funcion,
           rol=v_funcion,
           fecha_hasta=v_end,
           cancelada_at=null,
           motivo_fin=null,
           updated_at=now()
     where id=v_same_start.id;
  end loop;

  -- Reconciliacion V87: conservar exactamente las filas que siguen en el
  -- estado final del formulario. Las retiradas se cancelan/cierran sin borrar
  -- historico. Tras el preprocesado V89, un cambio de funcion del mismo dia ya
  -- coincide exactamente con el payload y no entra aqui como retirada.
  update public.asignaciones_entrenador_equipo a
     set cancelada_at=now(),
         motivo_fin=coalesce(a.motivo_fin,'Retirada desde la ficha del entrenador'),
         updated_at=now()
   where a.entrenador_id=p_entrenador_id
     and a.cancelada_at is null
     and a.fecha_desde>=current_date
     and not exists(
       select 1
         from jsonb_array_elements(coalesce(p_asignaciones,'[]'::jsonb)) j(value)
        where (j.value->>'team_id')::uuid=a.equipo_id
          and coalesce(nullif(j.value->>'funcion',''),'first')=a.funcion
          and coalesce(nullif(j.value->>'fecha_desde','')::date,current_date)=a.fecha_desde
          and nullif(j.value->>'fecha_hasta','')::date is not distinct from a.fecha_hasta
     );

  update public.asignaciones_entrenador_equipo a
     set fecha_hasta=current_date-1,
         motivo_fin=coalesce(a.motivo_fin,'Finalizada desde la ficha del entrenador'),
         updated_at=now()
   where a.entrenador_id=p_entrenador_id
     and a.cancelada_at is null
     and a.fecha_desde<current_date
     and (a.fecha_hasta is null or a.fecha_hasta>=current_date)
     and not exists(
       select 1
         from jsonb_array_elements(coalesce(p_asignaciones,'[]'::jsonb)) j(value)
        where (j.value->>'team_id')::uuid=a.equipo_id
          and coalesce(nullif(j.value->>'funcion',''),'first')=a.funcion
          and coalesce(nullif(j.value->>'fecha_desde','')::date,current_date)=a.fecha_desde
          and nullif(j.value->>'fecha_hasta','')::date is not distinct from a.fecha_hasta
     );

  -- Procesar el estado final solicitado.
  for rec in
    select value
      from jsonb_array_elements(coalesce(p_asignaciones,'[]'::jsonb))
  loop
    v_team:=(rec->>'team_id')::uuid;
    v_start:=coalesce(nullif(rec->>'fecha_desde','')::date,current_date);
    v_end:=nullif(rec->>'fecha_hasta','')::date;
    v_funcion:=coalesce(nullif(trim(rec->>'funcion'),''),'first');
    v_replace:=coalesce((rec->>'reemplazar_principal')::boolean,false);

    if v_funcion not in ('first','second','goalkeeper','fitness') then
      raise exception 'Funcion de tecnico no valida';
    end if;

    if v_end is not null and v_end<v_start then
      raise exception 'La fecha de fin no puede ser anterior a la fecha de inicio';
    end if;

    select temporada_id
      into v_temporada
      from public.equipos
     where id=v_team;

    if v_temporada is null then
      raise exception 'Equipo no encontrado';
    end if;

    -- Si la asignacion ya existe exactamente (incluido un cambio in-place
    -- realizado arriba), se conserva sin recrearla.
    v_existing_id:=null;
    select a.id
      into v_existing_id
      from public.asignaciones_entrenador_equipo a
     where a.entrenador_id=p_entrenador_id
       and a.equipo_id=v_team
       and a.funcion=v_funcion
       and a.fecha_desde=v_start
       and a.fecha_hasta is not distinct from v_end
       and a.cancelada_at is null
     order by a.created_at desc nulls last
     limit 1;

    if v_existing_id is not null then
      insert into public.entrenador_temporadas(
        entrenador_id,
        temporada_id,
        estado
      ) values(
        p_entrenador_id,
        v_temporada,
        'activo'
      )
      on conflict(entrenador_id,temporada_id)
      do update
        set estado='activo',
            updated_at=now();

      continue;
    end if;

    -- Proteccion adicional contra solapamiento del mismo entrenador/equipo.
    if exists(
      select 1
        from public.asignaciones_entrenador_equipo a
       where a.entrenador_id=p_entrenador_id
         and a.equipo_id=v_team
         and a.cancelada_at is null
         and daterange(a.fecha_desde,coalesce(a.fecha_hasta,'infinity'::date),'[]')
             && daterange(v_start,coalesce(v_end,'infinity'::date),'[]')
    ) then
      raise exception 'Ya existe una asignacion solapada para ese entrenador y equipo';
    end if;

    -- Sustitucion controlada de Principal para los casos que requieren una
    -- nueva fila (por ejemplo, cambio de funcion con una fecha posterior).
    if v_funcion='first' then
      for v_conflict in
        select a.*
          from public.asignaciones_entrenador_equipo a
         where a.equipo_id=v_team
           and a.entrenador_id<>p_entrenador_id
           and a.funcion='first'
           and a.cancelada_at is null
           and daterange(a.fecha_desde,coalesce(a.fecha_hasta,'infinity'::date),'[]')
               && daterange(v_start,coalesce(v_end,'infinity'::date),'[]')
         for update
      loop
        if not v_replace then
          raise exception 'El equipo ya tiene un entrenador principal vigente en ese periodo';
        end if;

        insert into public.auditoria(
          entidad,
          entidad_id,
          accion,
          actor_auth_user_id,
          datos_anteriores,
          datos_nuevos
        ) values(
          'asignacion_entrenador_equipo',
          v_conflict.id,
          'sustitucion_entrenador_principal',
          auth.uid(),
          to_jsonb(v_conflict),
          jsonb_build_object(
            'nuevo_entrenador_id',p_entrenador_id,
            'equipo_id',v_team,
            'fecha_sustitucion',v_start
          )
        );

        if v_conflict.fecha_desde < v_start then
          update public.asignaciones_entrenador_equipo
             set fecha_hasta=v_start-1,
                 motivo_fin='Sustitucion de entrenador principal',
                 updated_at=now()
           where id=v_conflict.id;
        else
          update public.asignaciones_entrenador_equipo
             set cancelada_at=now(),
                 motivo_fin='Sustitucion de entrenador principal antes de inicio',
                 updated_at=now()
           where id=v_conflict.id;
        end if;
      end loop;
    end if;

    insert into public.asignaciones_entrenador_equipo(
      entrenador_id,
      equipo_id,
      rol,
      fecha_desde,
      fecha_hasta,
      funcion,
      asignado_por,
      cancelada_at
    ) values(
      p_entrenador_id,
      v_team,
      v_funcion,
      v_start,
      v_end,
      v_funcion,
      auth.uid(),
      null
    );

    insert into public.entrenador_temporadas(
      entrenador_id,
      temporada_id,
      estado
    ) values(
      p_entrenador_id,
      v_temporada,
      'activo'
    )
    on conflict(entrenador_id,temporada_id)
    do update
      set estado='activo',
          updated_at=now();
  end loop;

  -- Estado derivado en la temporada activa.
  select id
    into v_temporada
    from public.temporadas
   where estado='activa'
   order by fecha_inicio desc
   limit 1;

  if v_temporada is not null then
    insert into public.entrenador_temporadas(
      entrenador_id,
      temporada_id,
      estado
    ) values(
      p_entrenador_id,
      v_temporada,
      case
        when exists(
          select 1
            from public.asignaciones_entrenador_equipo a
            join public.equipos e on e.id=a.equipo_id
           where a.entrenador_id=p_entrenador_id
             and e.temporada_id=v_temporada
             and a.cancelada_at is null
             and a.fecha_desde<=current_date
             and (a.fecha_hasta is null or a.fecha_hasta>=current_date)
        ) then 'activo'
        else 'sin_asignacion'
      end
    )
    on conflict(entrenador_id,temporada_id)
    do update
      set estado=excluded.estado,
          updated_at=now();
  end if;
end;
$$;

revoke all on function public.asignar_rol_entrenador(uuid,text,text,boolean,boolean,text) from public, anon;
grant execute on function public.asignar_rol_entrenador(uuid,text,text,boolean,boolean,text) to authenticated, service_role;
revoke all on function public.guardar_asignaciones_entrenador(uuid,jsonb) from public, anon;
grant execute on function public.guardar_asignaciones_entrenador(uuid,jsonb) to authenticated, service_role;
