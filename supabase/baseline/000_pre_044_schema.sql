


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "private";


ALTER SCHEMA "private" OWNER TO "postgres";


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE OR REPLACE FUNCTION "private"."ajustar_requisitos_por_mayoria_edad"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if new.motivo_fin='Mayoria de edad' and new.fecha_hasta is not null then
    update public.requisitos_federativos_inscripcion r
       set obligatorio=false,
           updated_at=now()
      from public.inscripciones i
     where i.jugador_id=new.jugador_id
       and r.inscripcion_id=i.id
       and r.codigo='autorizacion_tutor';
  end if;
  return new;
end;
$$;


ALTER FUNCTION "private"."ajustar_requisitos_por_mayoria_edad"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."autorizacion_entrenador_menor_vigente"("p_persona_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select exists(
    select 1 from public.personas p
    where p.id=p_persona_id
      and (
        p.fecha_nacimiento <= (current_date - interval '18 years')::date
        or exists(select 1 from public.autorizaciones_menor a where a.persona_menor_id=p_persona_id and a.tipo='entrenador_menor' and a.estado='aceptada' and (a.fecha_desde is null or a.fecha_desde<=current_date) and (a.fecha_hasta is null or a.fecha_hasta>=current_date))
      )
  );
$$;


ALTER FUNCTION "private"."autorizacion_entrenador_menor_vigente"("p_persona_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."can_access_inscription"("target_inscription_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
    select exists (
        select 1
        from public.inscripciones i
        where i.id = target_inscription_id
          and (
            select private.can_access_player(i.jugador_id)
          )
    );
$$;


ALTER FUNCTION "private"."can_access_inscription"("target_inscription_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."can_access_inscription_personal"("target_inscription_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
    select exists (
        select 1
        from public.inscripciones i
        where i.id = target_inscription_id
          and (
            select private.can_access_player_personal(
                i.jugador_id
            )
          )
    );
$$;


ALTER FUNCTION "private"."can_access_inscription_personal"("target_inscription_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."can_access_player"("target_player_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
    select

      (select private.can_access_player_personal(
          target_player_id
      ))

      or

      (
        (select private.has_role('entrenador'))

        and

        (select private.is_trainer_of_player(
            target_player_id
        ))
      );
$$;


ALTER FUNCTION "private"."can_access_player"("target_player_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."can_access_player_personal"("target_player_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select
    private.has_any_role(array['administrador','club']::text[])
    or exists (
      select 1
      from public.jugadores j
      join public.personas p on p.id=j.persona_id
      where j.id=target_player_id
        and j.persona_id=private.current_person_id()
        and p.fecha_nacimiento is not null
        and p.fecha_nacimiento <= (current_date - interval '18 years')::date
        and private.has_role('jugador')
    )
    or (
      private.has_role('tutor')
      and exists (
        select 1
        from public.representaciones_jugador rep
        where rep.jugador_id=target_player_id
          and rep.representante_persona_id=private.current_person_id()
          and rep.fecha_desde<=current_date
          and (rep.fecha_hasta is null or rep.fecha_hasta>=current_date)
      )
    );
$$;


ALTER FUNCTION "private"."can_access_player_personal"("target_player_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."can_read_document"("target_document_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    d public.documentos%rowtype;
    v_player_id uuid;
begin

    select *
    into d
    from public.documentos
    where id = target_document_id;

    if not found then
        return false;
    end if;


    -- Administrador / Club
    if (
        select private.has_any_role(
            array['administrador','club']::text[]
        )
    ) then
        return true;
    end if;


    -- Documento de persona
    if d.persona_id is not null then
        return (
            select private.can_read_person(
                d.persona_id
            )
        );
    end if;


    -- Documento de jugador
    if d.jugador_id is not null then
        return (
            select private.can_access_player_personal(
                d.jugador_id
            )
        );
    end if;


    -- Documento de inscripcion
    if d.inscripcion_id is not null then
        return (
            select private.can_access_inscription_personal(
                d.inscripcion_id
            )
        );
    end if;


    -- Documento de reconocimiento medico
    if d.reconocimiento_medico_id is not null then

        select rm.jugador_id
        into v_player_id
        from public.reconocimientos_medicos rm
        where rm.id = d.reconocimiento_medico_id;

        return (
            select private.can_access_player_personal(
                v_player_id
            )
        );

    end if;


    return false;

end;
$$;


ALTER FUNCTION "private"."can_read_document"("target_document_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."can_read_person"("target_person_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
    select

      -- Administrador / Club
      (select private.has_any_role(
          array['administrador','club']::text[]
      ))

      or

      -- Uno mismo
      target_person_id =
          (select private.current_person_id())

      or

      -- Tutor del menor
      (
        (select private.has_role('tutor'))

        and exists (

            select 1

            from public.jugadores j

            join public.representaciones_jugador rep
              on rep.jugador_id = j.id

            where j.persona_id = target_person_id

              and rep.representante_persona_id =
                  (select private.current_person_id())

              and rep.fecha_desde <= current_date

              and (
                  rep.fecha_hasta is null
                  or rep.fecha_hasta >= current_date
              )
        )
      );
$$;


ALTER FUNCTION "private"."can_read_person"("target_person_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."current_person_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
    select p.id
    from public.personas p
    where p.auth_user_id = (select auth.uid())
      and p.activo = true
    limit 1;
$$;


ALTER FUNCTION "private"."current_person_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."documento_espanol_valido"("p_tipo" "text", "p_numero" "text") RETURNS boolean
    LANGUAGE "plpgsql" IMMUTABLE
    SET "search_path" TO ''
    AS $_$
declare
  v_tipo text:=lower(trim(coalesce(p_tipo,'')));
  v text:=upper(regexp_replace(coalesce(p_numero,''),'[^A-Za-z0-9]','','g'));
  v_num_text text;
  v_num bigint;
  v_letter text;
  v_expected text;
  v_letters constant text:='TRWAGMYFPDXBNJZSQVHLCKE';
begin
  if v_tipo='dni' then
    if v !~ '^[0-9]{8}[A-Z]$' then return false; end if;
    v_num_text:=substring(v from 1 for 8);
    v_letter:=substring(v from 9 for 1);
  elsif v_tipo='nie' then
    if v !~ '^[XYZ][0-9]{7}[A-Z]$' then return false; end if;
    v_num_text:=case substring(v from 1 for 1) when 'X' then '0' when 'Y' then '1' else '2' end || substring(v from 2 for 7);
    v_letter:=substring(v from 9 for 1);
  else
    return true;
  end if;
  v_num:=v_num_text::bigint;
  v_expected:=substring(v_letters from ((v_num % 23)::int + 1) for 1);
  return v_letter=v_expected;
end;
$_$;


ALTER FUNCTION "private"."documento_espanol_valido"("p_tipo" "text", "p_numero" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."encolar_notificaciones_cita"("p_cita_id" "uuid", "p_evento" "text") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_jugador_id uuid;
  v_persona_id uuid;
  v_fecha_hora timestamptz;
  v_lugar text;
  v_direccion text;
  v_indicaciones text;
  v_nombre text;
  v_es_adulto boolean;
  v_fecha text;
  v_asunto text;
  v_cuerpo text;
  v_count integer:=0;
  v_rows integer:=0;
begin
  select
    c.jugador_id,
    coalesce(c.persona_id,j.persona_id),
    c.fecha_hora,
    c.lugar,
    c.direccion,
    c.indicaciones,
    concat_ws(' ',p.nombre,p.primer_apellido,p.segundo_apellido),
    (p.fecha_nacimiento is not null and p.fecha_nacimiento <= (current_date-interval '18 years')::date)
  into
    v_jugador_id,v_persona_id,v_fecha_hora,v_lugar,v_direccion,v_indicaciones,
    v_nombre,v_es_adulto
  from public.citas_reconocimiento_medico c
  left join public.jugadores j on j.id=c.jugador_id
  join public.personas p on p.id=coalesce(c.persona_id,j.persona_id)
  where c.id=p_cita_id;

  if v_persona_id is null then
    raise exception 'Cita no encontrada';
  end if;

  v_fecha:=to_char(v_fecha_hora at time zone 'Europe/Madrid','DD/MM/YYYY HH24:MI');

  if p_evento='cancelada' then
    v_asunto:='Cita de reconocimiento medico cancelada - C.D. Los Yebenes San Bruno';
    v_cuerpo:='Se ha cancelado la cita de reconocimiento medico de '||v_nombre
      ||E'\nFecha que estaba programada: '||v_fecha||E'\nLugar: '||coalesce(v_lugar,'');
  elsif p_evento='modificada' then
    v_asunto:='Cambio de cita de reconocimiento medico - C.D. Los Yebenes San Bruno';
    v_cuerpo:='Se ha modificado la cita de reconocimiento medico de '||v_nombre
      ||E'\nNueva fecha: '||v_fecha||E'\nLugar: '||coalesce(v_lugar,'');
  else
    v_asunto:='Cita de reconocimiento medico - C.D. Los Yebenes San Bruno';
    v_cuerpo:='Cita de reconocimiento medico de '||v_nombre
      ||E'\nFecha: '||v_fecha||E'\nLugar: '||coalesce(v_lugar,'');
  end if;

  if nullif(trim(coalesce(v_direccion,'')),'') is not null then
    v_cuerpo:=v_cuerpo||E'\nDireccion: '||trim(v_direccion);
  end if;
  if nullif(trim(coalesce(v_indicaciones,'')),'') is not null then
    v_cuerpo:=v_cuerpo||E'\nIndicaciones: '||trim(v_indicaciones);
  end if;

  if v_jugador_id is not null then
    -- Mantiene el flujo validado de jugador/tutor.
    if v_es_adulto then
      insert into public.notificaciones_salida(
        tipo,jugador_id,cita_id,destinatario_tipo,destinatario_persona_id,
        destinatario_email,asunto,cuerpo
      )
      select 'cita_rrmm_'||p_evento,v_jugador_id,p_cita_id,'jugador',p.id,
             p.email_contacto,v_asunto,v_cuerpo
        from public.personas p
       where p.id=v_persona_id
         and nullif(trim(coalesce(p.email_contacto,'')),'') is not null;
      get diagnostics v_rows=row_count;
      v_count:=v_count+v_rows;
    else
      insert into public.notificaciones_salida(
        tipo,jugador_id,cita_id,destinatario_tipo,destinatario_persona_id,
        destinatario_email,asunto,cuerpo
      )
      select 'cita_rrmm_'||p_evento,v_jugador_id,p_cita_id,'tutor',p.id,
             p.email_contacto,v_asunto,v_cuerpo
        from public.representaciones_jugador r
        join public.personas p on p.id=r.representante_persona_id
       where r.jugador_id=v_jugador_id
         and r.fecha_desde<=current_date
         and (r.fecha_hasta is null or r.fecha_hasta>=current_date)
         and nullif(trim(coalesce(p.email_contacto,'')),'') is not null;
      get diagnostics v_rows=row_count;
      v_count:=v_count+v_rows;
    end if;

    -- Entrenadores activos del equipo del jugador, como hasta ahora.
    insert into public.notificaciones_salida(
      tipo,jugador_id,cita_id,destinatario_tipo,destinatario_persona_id,
      destinatario_email,asunto,cuerpo
    )
    select distinct
      'cita_rrmm_'||p_evento,v_jugador_id,p_cita_id,'entrenador',p.id,
      p.email_contacto,
      case when p_evento='cancelada'
        then 'Cita RRMM cancelada de jugador de tu equipo - C.D. Los Yebenes San Bruno'
        when p_evento='modificada'
        then 'Cambio de cita RRMM de jugador de tu equipo - C.D. Los Yebenes San Bruno'
        else 'Cita RRMM de jugador de tu equipo - C.D. Los Yebenes San Bruno' end,
      v_cuerpo
      from public.inscripciones i
      join public.asignaciones_jugador_equipo aje on aje.inscripcion_id=i.id
      join public.asignaciones_entrenador_equipo aee on aee.equipo_id=aje.equipo_id
      join public.entrenadores e on e.id=aee.entrenador_id and e.activo=true
      join public.personas p on p.id=e.persona_id
     where i.jugador_id=v_jugador_id
       and aje.fecha_desde<=current_date and (aje.fecha_hasta is null or aje.fecha_hasta>=current_date)
       and aee.fecha_desde<=current_date and (aee.fecha_hasta is null or aee.fecha_hasta>=current_date)
       and nullif(trim(coalesce(p.email_contacto,'')),'') is not null
       and p.id<>v_persona_id;
    get diagnostics v_rows=row_count;
    v_count:=v_count+v_rows;

  else
    -- Persona sin ficha de jugador (p.ej. entrenador puro).
    if v_es_adulto then
      insert into public.notificaciones_salida(
        tipo,jugador_id,cita_id,destinatario_tipo,destinatario_persona_id,
        destinatario_email,asunto,cuerpo
      )
      select 'cita_rrmm_'||p_evento,null,p_cita_id,'entrenador',p.id,
             p.email_contacto,v_asunto,v_cuerpo
        from public.personas p
       where p.id=v_persona_id
         and nullif(trim(coalesce(p.email_contacto,'')),'') is not null;
      get diagnostics v_rows=row_count;
      v_count:=v_count+v_rows;
    else
      insert into public.notificaciones_salida(
        tipo,jugador_id,cita_id,destinatario_tipo,destinatario_persona_id,
        destinatario_email,asunto,cuerpo
      )
      select 'cita_rrmm_'||p_evento,null,p_cita_id,'tutor',p.id,
             p.email_contacto,v_asunto,v_cuerpo
        from public.autorizaciones_menor a
        join public.personas p on p.id=a.tutor_persona_id
       where a.persona_menor_id=v_persona_id
         and a.tipo='entrenador_menor'
         and a.estado='aceptada'
         and a.fecha_desde<=current_date
         and (a.fecha_hasta is null or a.fecha_hasta>=current_date)
         and nullif(trim(coalesce(p.email_contacto,'')),'') is not null;
      get diagnostics v_rows=row_count;
      v_count:=v_count+v_rows;
    end if;
  end if;

  return v_count;
end;
$$;


ALTER FUNCTION "private"."encolar_notificaciones_cita"("p_cita_id" "uuid", "p_evento" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."has_any_role"("role_codes" "text"[]) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
    select exists (
        select 1
        from public.personas p
        join public.persona_roles pr
          on pr.persona_id = p.id
        join public.roles r
          on r.id = pr.rol_id

        where p.auth_user_id = (select auth.uid())
          and p.activo = true
          and pr.activo = true
          and pr.fecha_desde <= current_date
          and (
                pr.fecha_hasta is null
                or pr.fecha_hasta >= current_date
              )
          and r.codigo = any(role_codes)
    );
$$;


ALTER FUNCTION "private"."has_any_role"("role_codes" "text"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."has_role"("role_code" "text") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
    select exists (
        select 1
        from public.personas p
        join public.persona_roles pr
          on pr.persona_id = p.id
        join public.roles r
          on r.id = pr.rol_id

        where p.auth_user_id = (select auth.uid())
          and p.activo = true
          and pr.activo = true
          and pr.fecha_desde <= current_date
          and (
                pr.fecha_hasta is null
                or pr.fecha_hasta >= current_date
              )
          and r.codigo = role_code
    );
$$;


ALTER FUNCTION "private"."has_role"("role_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."is_trainer_of_player"("target_player_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
    select exists (

        select 1

        from public.jugadores j

        join public.inscripciones i
          on i.jugador_id = j.id

        join public.asignaciones_jugador_equipo aje
          on aje.inscripcion_id = i.id

        join public.asignaciones_entrenador_equipo aee
          on aee.equipo_id = aje.equipo_id

        join public.entrenadores e
          on e.id = aee.entrenador_id

        where j.id = target_player_id

          and j.activo = true
          and e.activo = true

          and e.persona_id =
              (select private.current_person_id())

          and i.estado <> 'cancelada'

          and aje.fecha_desde <= current_date

          and (
              aje.fecha_hasta is null
              or aje.fecha_hasta >= current_date
          )

          and aee.fecha_desde <= current_date

          and (
              aee.fecha_hasta is null
              or aee.fecha_hasta >= current_date
          )
    );
$$;


ALTER FUNCTION "private"."is_trainer_of_player"("target_player_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."normalizar_documento"("p_numero" "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO ''
    AS $$
    select upper(
        regexp_replace(
            coalesce(p_numero, ''),
            '[^A-Za-z0-9]',
            '',
            'g'
        )
    );
$$;


ALTER FUNCTION "private"."normalizar_documento"("p_numero" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."recalcular_estado_inscripcion"("p_inscripcion_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_estado text; v_jugador uuid; v_persona uuid; v_adulto boolean:=false;
  v_docs_ok boolean:=false; v_equipo_ok boolean:=false; v_rrmm_ok boolean:=false; v_econ_ok boolean:=false; v_target text;
begin
  select i.estado,i.jugador_id,j.persona_id,
         (p.fecha_nacimiento is not null and p.fecha_nacimiento <= (current_date-interval '18 years')::date)
    into v_estado,v_jugador,v_persona,v_adulto
    from public.inscripciones i
    join public.jugadores j on j.id=i.jugador_id
    join public.personas p on p.id=j.persona_id
   where i.id=p_inscripcion_id;
  if v_jugador is null then return null; end if;
  if v_estado in ('pendiente_revision_inicial','devuelta_familia','cancelada','ficha_tramitada') then return v_estado; end if;

  select exists(select 1 from public.requisitos_federativos_inscripcion r where r.inscripcion_id=p_inscripcion_id and r.obligatorio=true and not (v_adulto and r.codigo='autorizacion_tutor'))
     and not exists(select 1 from public.requisitos_federativos_inscripcion r where r.inscripcion_id=p_inscripcion_id and r.obligatorio=true and not (v_adulto and r.codigo='autorizacion_tutor') and r.estado<>'validado')
    into v_docs_ok;
  select exists(select 1 from public.asignaciones_jugador_equipo a where a.inscripcion_id=p_inscripcion_id and (a.fecha_desde is null or a.fecha_desde<=current_date) and (a.fecha_hasta is null or a.fecha_hasta>=current_date)) into v_equipo_ok;
  select exists(select 1 from public.reconocimientos_medicos m where (m.persona_id=v_persona or m.jugador_id=v_jugador) and m.fecha_reconocimiento<=current_date and m.fecha_valido_hasta>=current_date) into v_rrmm_ok;
  select coalesce(s.apto_para_ficha,false) into v_econ_ok from public.situacion_economica_inscripcion s where s.inscripcion_id=p_inscripcion_id limit 1;
  v_econ_ok:=coalesce(v_econ_ok,false);
  if v_docs_ok and v_equipo_ok and v_rrmm_ok and v_econ_ok then v_target:='lista_para_federar';
  elsif v_docs_ok then v_target:='documentacion_validada'; else v_target:='datos_validados'; end if;
  if v_target is distinct from v_estado then
    update public.inscripciones set estado=v_target,updated_at=now() where id=p_inscripcion_id;
    insert into public.historico_estados_inscripcion(inscripcion_id,estado_anterior,estado_nuevo,comentario,cambiado_por)
    values(p_inscripcion_id,v_estado,v_target,'Estado recalculado automaticamente a partir de requisitos validados',auth.uid());
  end if;
  return v_target;
end; $$;


ALTER FUNCTION "private"."recalcular_estado_inscripcion"("p_inscripcion_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."recalcular_situacion_economica"("p_inscripcion_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    v_ins public.inscripciones%rowtype;
    v_asign public.asignaciones_jugador_equipo%rowtype;
    v_cfg public.configuracion_economica_equipo%rowtype;
    v_sum numeric(10,2) := 0;
    v_prev public.situacion_economica_inscripcion%rowtype;
    v_estado text := 'pendiente';
    v_apto boolean := false;
begin
    select * into v_ins from public.inscripciones where id = p_inscripcion_id;
    if not found then return; end if;

    select * into v_asign
      from public.asignaciones_jugador_equipo a
     where a.inscripcion_id = p_inscripcion_id
       and (a.fecha_desde is null or a.fecha_desde <= current_date)
       and (a.fecha_hasta is null or a.fecha_hasta >= current_date)
     order by a.fecha_desde desc nulls last, a.created_at desc
     limit 1;

    if v_asign.id is not null then
        select * into v_cfg
          from public.configuracion_economica_equipo c
         where c.temporada_id = v_ins.temporada_id
           and c.equipo_id = v_asign.equipo_id
         limit 1;
    end if;

    select coalesce(sum(p.importe),0)::numeric(10,2)
      into v_sum
      from public.pagos_inscripcion p
     where p.inscripcion_id = p_inscripcion_id
       and p.estado = 'confirmado';

    select * into v_prev
      from public.situacion_economica_inscripcion s
     where s.inscripcion_id = p_inscripcion_id;

    if v_cfg.id is null then
        v_estado := case when v_sum > 0 then 'parcial' else 'pendiente' end;
        v_apto := false;
    elsif v_cfg.requiere_pago_ficha = false then
        v_estado := case
            when v_cfg.importe_inscripcion is not null and v_cfg.importe_inscripcion > 0 and v_sum >= v_cfg.importe_inscripcion then 'pagado'
            when v_sum > 0 then 'parcial'
            else 'pendiente'
        end;
        v_apto := true;
    elsif v_cfg.importe_inscripcion is null or v_cfg.importe_inscripcion <= 0 then
        v_estado := case when v_sum > 0 then 'parcial' else 'pendiente' end;
        v_apto := false;
    else
        v_estado := case
            when v_sum >= v_cfg.importe_inscripcion then 'pagado'
            when v_sum > 0 then 'parcial'
            else 'pendiente'
        end;
        v_apto := (v_sum >= v_cfg.importe_inscripcion)
                  or (coalesce(v_prev.fraccionamiento_clubber_validado,false) and v_cfg.admite_fraccionamiento);
    end if;

    insert into public.situacion_economica_inscripcion(
        inscripcion_id, configuracion_id, equipo_id, importe_total, importe_pagado,
        estado_economico, fraccionamiento_clubber_validado,
        fecha_validacion_fraccionamiento, validado_fraccionamiento_por,
        origen_validacion_fraccionamiento, apto_para_ficha, calculado_at
    ) values (
        p_inscripcion_id,
        v_cfg.id,
        v_asign.equipo_id,
        v_cfg.importe_inscripcion,
        v_sum,
        v_estado,
        coalesce(v_prev.fraccionamiento_clubber_validado,false),
        v_prev.fecha_validacion_fraccionamiento,
        v_prev.validado_fraccionamiento_por,
        v_prev.origen_validacion_fraccionamiento,
        v_apto,
        now()
    )
    on conflict (inscripcion_id) do update set
        configuracion_id = excluded.configuracion_id,
        equipo_id = excluded.equipo_id,
        importe_total = excluded.importe_total,
        importe_pagado = excluded.importe_pagado,
        estado_economico = excluded.estado_economico,
        apto_para_ficha = excluded.apto_para_ficha,
        calculado_at = now(),
        updated_at = now();
end;
$$;


ALTER FUNCTION "private"."recalcular_situacion_economica"("p_inscripcion_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."trg_entrenador_legacy_v84"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_tipo_formacion text;
  v_tipo_licencia text;
  v_temporada uuid;
begin
  if coalesce(new.curso_delegado,false)=true then
    insert into public.entrenador_formaciones(
      entrenador_id,tipo,estado,verificacion_estado,verificado_at,creado_por
    )
    select new.id,'delegado','vigente','verificada',now(),auth.uid()
    where not exists(
      select 1 from public.entrenador_formaciones f
       where f.entrenador_id=new.id and f.tipo='delegado' and f.estado='vigente'
    );
  end if;

  v_tipo_formacion:=case upper(trim(coalesce(new.licencia_tipo,'')))
    when 'UEFA C' then 'uefa_c'
    when 'UEFA B' then 'uefa_b'
    when 'UEFA A' then 'uefa_a'
    when 'UEFA PRO' then 'uefa_pro'
    else null
  end;
  if v_tipo_formacion is not null then
    insert into public.entrenador_formaciones(
      entrenador_id,tipo,estado,numero_acreditacion,verificacion_estado,verificado_at,creado_por
    )
    select new.id,v_tipo_formacion,'vigente',new.licencia_numero,'verificada',now(),auth.uid()
    where not exists(
      select 1 from public.entrenador_formaciones f
       where f.entrenador_id=new.id and f.tipo=v_tipo_formacion and f.estado='vigente'
    );
  end if;

  v_tipo_licencia:=case upper(trim(coalesce(new.licencia_tipo,'')))
    when 'D' then 'D' when 'ET' then 'ET' when 'EA' then 'EA'
    when 'EPR' then 'EPR' when 'CTC' then 'CTC' when 'EP' then 'EP'
    when 'PF' then 'PF' else null
  end;
  if v_tipo_licencia is not null then
    select id into v_temporada
      from public.temporadas
     where estado='activa'
     order by fecha_inicio desc
     limit 1;
    if v_temporada is not null then
      insert into public.entrenador_licencias_rffm(
        entrenador_id,temporada_id,tipo,numero,verificacion_estado,verificado_at,creado_por
      )
      select new.id,v_temporada,v_tipo_licencia,new.licencia_numero,'verificada',now(),auth.uid()
      where not exists(
        select 1 from public.entrenador_licencias_rffm l
         where l.entrenador_id=new.id and l.temporada_id=v_temporada and l.tipo=v_tipo_licencia
      );
    end if;
  end if;
  return new;
end;
$$;


ALTER FUNCTION "private"."trg_entrenador_legacy_v84"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."trg_recalcular_economia_asignacion"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
    if tg_op = 'DELETE' then
        perform private.recalcular_situacion_economica(old.inscripcion_id);
        return old;
    else
        perform private.recalcular_situacion_economica(new.inscripcion_id);
        return new;
    end if;
end;
$$;


ALTER FUNCTION "private"."trg_recalcular_economia_asignacion"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."trg_recalcular_economia_pago"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
    if tg_op = 'DELETE' then
        perform private.recalcular_situacion_economica(old.inscripcion_id);
        return old;
    else
        perform private.recalcular_situacion_economica(new.inscripcion_id);
        return new;
    end if;
end;
$$;


ALTER FUNCTION "private"."trg_recalcular_economia_pago"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."trg_recalcular_estado_economia"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  perform private.recalcular_estado_inscripcion(coalesce(new.inscripcion_id,old.inscripcion_id));
  return coalesce(new,old);
end; $$;


ALTER FUNCTION "private"."trg_recalcular_estado_economia"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."trg_recalcular_estado_equipo"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  perform private.recalcular_estado_inscripcion(coalesce(new.inscripcion_id,old.inscripcion_id));
  return coalesce(new,old);
end; $$;


ALTER FUNCTION "private"."trg_recalcular_estado_equipo"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."trg_recalcular_estado_inscripcion_estado"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if pg_trigger_depth()=1 and new.estado in ('datos_validados','documentacion_validada','lista_para_federar') then
    perform private.recalcular_estado_inscripcion(new.id);
  end if;
  return new;
end; $$;


ALTER FUNCTION "private"."trg_recalcular_estado_inscripcion_estado"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."trg_recalcular_estado_requisito"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  perform private.recalcular_estado_inscripcion(coalesce(new.inscripcion_id,old.inscripcion_id));
  return coalesce(new,old);
end; $$;


ALTER FUNCTION "private"."trg_recalcular_estado_requisito"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."trg_rrmm_persona_v84"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if new.persona_id is null and new.jugador_id is not null then
    select j.persona_id into new.persona_id from public.jugadores j where j.id=new.jugador_id;
  end if;
  if new.fecha_valido_hasta < new.fecha_reconocimiento then
    raise exception 'La fecha de validez no puede ser anterior a la fecha del reconocimiento';
  end if;
  return new;
end; $$;


ALTER FUNCTION "private"."trg_rrmm_persona_v84"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."trg_rrmm_v83"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  rec record;
  v_ins uuid;
  v_persona uuid;
begin
  v_persona:=new.persona_id;
  if v_persona is null and new.jugador_id is not null then
    select persona_id into v_persona from public.jugadores where id=new.jugador_id;
  end if;

  if v_persona is not null then
    for rec in
      select *
        from public.citas_reconocimiento_medico c
       where c.persona_id=v_persona
         and c.estado='programada'
         and c.fecha_hora::date<=new.fecha_reconocimiento
    loop
      update public.citas_reconocimiento_medico
         set estado='realizada',reconocimiento_medico_id=new.id,updated_at=now()
       where id=rec.id;

      update public.notificaciones_salida
         set estado='cancelado'
       where cita_id=rec.id and estado='pendiente';

      insert into public.historico_citas_rrmm(
        cita_id,accion,datos_anteriores,datos_nuevos,actor_auth_user_id
      )
      select rec.id,'realizada_por_registro_rrmm',to_jsonb(rec),to_jsonb(c),auth.uid()
        from public.citas_reconocimiento_medico c
       where c.id=rec.id;
    end loop;

    for v_ins in
      select i.id
        from public.inscripciones i
        join public.jugadores j on j.id=i.jugador_id
       where j.persona_id=v_persona
    loop
      perform private.recalcular_estado_inscripcion(v_ins);
    end loop;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "private"."trg_rrmm_v83"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."validar_documento_identidad_espanol_trigger"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  if lower(coalesce(new.tipo,'')) in ('dni','nie') and not private.documento_espanol_valido(new.tipo,new.numero) then
    raise exception '% no valido: el formato o la letra de control no corresponden al numero', upper(new.tipo);
  end if;
  return new;
end;
$$;


ALTER FUNCTION "private"."validar_documento_identidad_espanol_trigger"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."validar_principal_unico_equipo"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if new.cancelada_at is null and new.funcion='first' then
    if exists(
      select 1
        from public.asignaciones_entrenador_equipo a
       where a.equipo_id=new.equipo_id
         and a.id is distinct from new.id
         and a.funcion='first'
         and a.cancelada_at is null
         and daterange(a.fecha_desde,coalesce(a.fecha_hasta,'infinity'::date),'[]')
             && daterange(new.fecha_desde,coalesce(new.fecha_hasta,'infinity'::date),'[]')
    ) then
      raise exception 'El equipo ya tiene un entrenador principal en ese periodo';
    end if;
  end if;
  return new;
end;
$$;


ALTER FUNCTION "private"."validar_principal_unico_equipo"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."actualizar_jugador_autorrepresentado"("p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_telefono" "text" DEFAULT NULL::"text", "p_tipo_documento" "text" DEFAULT NULL::"text", "p_numero_documento" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_auth uuid:=auth.uid();
  v_persona uuid;
  v_jugador uuid;
  v_ins uuid;
  v_old text;
  v_norm text;
  v_owner uuid;
  v_cat uuid;
  v_temp uuid;
  v_old_nombre text;
  v_old_apellido1 text;
  v_old_apellido2 text;
  v_old_birth date;
  v_old_phone text;
  v_old_doc_type text;
  v_old_doc_number text;
  v_sensitive_changed boolean:=false;
begin
  if v_auth is null then
    raise exception 'Es necesario iniciar sesion';
  end if;
  if not private.has_role('jugador') then
    raise exception 'Solo el perfil Jugador puede modificar sus propios datos';
  end if;

  select
    p.id,
    p.nombre,
    p.primer_apellido,
    p.segundo_apellido,
    p.fecha_nacimiento,
    p.telefono
  into
    v_persona,
    v_old_nombre,
    v_old_apellido1,
    v_old_apellido2,
    v_old_birth,
    v_old_phone
  from public.personas p
  where p.auth_user_id=v_auth
    and p.activo=true
  limit 1;

  if v_persona is null then
    raise exception 'No existe Persona vinculada';
  end if;
  if p_fecha_nacimiento is null
     or p_fecha_nacimiento > (current_date - interval '18 years')::date then
    raise exception 'Este flujo solo permite jugadores mayores de edad';
  end if;
  if trim(coalesce(p_nombre,''))=''
     or trim(coalesce(p_primer_apellido,''))='' then
    raise exception 'Nombre y primer apellido son obligatorios';
  end if;

  select j.id
  into v_jugador
  from public.jugadores j
  where j.persona_id=v_persona
    and j.activo=true
  limit 1;

  if v_jugador is null then
    raise exception 'No existe Jugador activo vinculado';
  end if;

  if nullif(trim(coalesce(p_numero_documento,'')),'') is null
     or p_tipo_documento not in ('dni','nie') then
    raise exception 'El DNI o NIE propio es obligatorio';
  end if;
  if not private.documento_espanol_valido(
    p_tipo_documento,
    p_numero_documento
  ) then
    raise exception '% no valido: la letra no corresponde al numero',
      upper(p_tipo_documento);
  end if;

  v_norm:=private.normalizar_documento(p_numero_documento);

  select d.tipo, private.normalizar_documento(d.numero)
  into v_old_doc_type, v_old_doc_number
  from public.documentos_identidad d
  where d.persona_id=v_persona
    and d.activo=true
    and d.es_principal=true
  order by d.created_at desc
  limit 1;

  select d.persona_id
  into v_owner
  from public.documentos_identidad d
  where d.tipo=p_tipo_documento
    and private.normalizar_documento(d.numero)=v_norm
  limit 1;

  if v_owner is not null and v_owner<>v_persona then
    raise exception 'El documento ya pertenece a otra Persona';
  end if;

  v_sensitive_changed :=
       coalesce(trim(v_old_nombre),'')
         is distinct from coalesce(trim(p_nombre),'')
    or coalesce(trim(v_old_apellido1),'')
         is distinct from coalesce(trim(p_primer_apellido),'')
    or coalesce(trim(v_old_apellido2),'')
         is distinct from coalesce(trim(p_segundo_apellido),'')
    or v_old_birth is distinct from p_fecha_nacimiento
    or coalesce(v_old_doc_type,'')
         is distinct from coalesce(p_tipo_documento,'')
    or coalesce(v_old_doc_number,'')
         is distinct from coalesce(v_norm,'');

  update public.personas p
  set
    nombre=trim(p_nombre),
    primer_apellido=trim(p_primer_apellido),
    segundo_apellido=nullif(trim(coalesce(p_segundo_apellido,'')),''),
    fecha_nacimiento=p_fecha_nacimiento,
    telefono=nullif(trim(coalesce(p_telefono,'')),''),
    updated_at=now()
  where p.id=v_persona;

  if coalesce(v_old_doc_type,'') is distinct from coalesce(p_tipo_documento,'')
     or coalesce(v_old_doc_number,'') is distinct from coalesce(v_norm,'') then
    update public.documentos_identidad d
    set es_principal=false
    where d.persona_id=v_persona
      and d.activo=true
      and d.es_principal=true;

    if exists(
      select 1
      from public.documentos_identidad d
      where d.persona_id=v_persona
        and d.tipo=p_tipo_documento
        and private.normalizar_documento(d.numero)=v_norm
    ) then
      update public.documentos_identidad d
      set activo=true,
          es_principal=true
      where d.persona_id=v_persona
        and d.tipo=p_tipo_documento
        and private.normalizar_documento(d.numero)=v_norm;
    else
      insert into public.documentos_identidad(
        persona_id,
        tipo,
        numero,
        es_principal,
        activo
      ) values (
        v_persona,
        p_tipo_documento,
        v_norm,
        true,
        true
      );
    end if;
  end if;

  if v_sensitive_changed then
    select t.id
    into v_temp
    from public.temporadas t
    where t.estado='activa'
    order by t.fecha_inicio desc
    limit 1;

    if v_temp is not null then
      select r.categoria_id
      into v_cat
      from public.reglas_categoria_temporada r
      where r.temporada_id=v_temp
        and r.activo=true
        and extract(year from p_fecha_nacimiento)::int
          between r.anio_nacimiento_desde and r.anio_nacimiento_hasta
      order by r.anio_nacimiento_desde desc
      limit 1;

      select i.id, i.estado
      into v_ins, v_old
      from public.inscripciones i
      where i.jugador_id=v_jugador
        and i.temporada_id=v_temp
      limit 1;

      if v_ins is not null then
        update public.inscripciones i
        set
          categoria_id=coalesce(v_cat,i.categoria_id),
          estado='pendiente_revision_inicial',
          observaciones='Datos identificativos modificados por el jugador adulto. Pendiente de nueva revision.',
          updated_at=now()
        where i.id=v_ins;

        insert into public.historico_estados_inscripcion(
          inscripcion_id,
          estado_anterior,
          estado_nuevo,
          comentario,
          cambiado_por
        ) values (
          v_ins,
          v_old,
          'pendiente_revision_inicial',
          'Datos identificativos modificados por el jugador adulto',
          v_auth
        );
      end if;
    end if;
  end if;

  insert into public.auditoria(
    entidad,
    entidad_id,
    accion,
    actor_auth_user_id,
    datos_nuevos
  ) values (
    'jugador',
    v_jugador,
    case
      when v_sensitive_changed then 'modificacion_autorrepresentada_sensible'
      else 'modificacion_contacto_autorrepresentada'
    end,
    v_auth,
    jsonb_build_object(
      'persona_id',v_persona,
      'cambio_sensible',v_sensitive_changed,
      'telefono_anterior',v_old_phone,
      'telefono_nuevo',nullif(trim(coalesce(p_telefono,'')),'')
    )
  );

  return v_jugador;
end;
$$;


ALTER FUNCTION "public"."actualizar_jugador_autorrepresentado"("p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_telefono" "text", "p_tipo_documento" "text", "p_numero_documento" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."actualizar_menor_representado"("p_jugador_id" "uuid", "p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_tipo_documento" "text" DEFAULT NULL::"text", "p_numero_documento" "text" DEFAULT NULL::"text", "p_email_jugador" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_auth uuid:=auth.uid();
  v_tutor uuid;
  v_persona uuid;
  v_ins uuid;
  v_old text;
  v_norm text;
  v_owner uuid;
  v_email text:=nullif(lower(trim(coalesce(p_email_jugador,''))),'');
  v_name text;
  v_tutor_email text;
  v_authz uuid;
  v_age integer;
  v_existing_doc uuid;
begin
  if v_auth is null or not private.has_role('tutor') then
    raise exception 'Solo Tutor/Familia puede modificar menores representados';
  end if;

  select p.id into v_tutor
  from public.personas p
  where p.auth_user_id=v_auth
  limit 1;

  select j.persona_id into v_persona
  from public.jugadores j
  join public.representaciones_jugador r on r.jugador_id=j.id
  where j.id=p_jugador_id
    and r.representante_persona_id=v_tutor
    and r.fecha_desde<=current_date
    and (r.fecha_hasta is null or r.fecha_hasta>=current_date)
  order by r.fecha_desde desc
  limit 1;
  if v_persona is null then raise exception 'No representas actualmente a este jugador'; end if;

  if p_fecha_nacimiento is null or p_fecha_nacimiento <= (current_date - interval '18 years')::date then
    raise exception 'El jugador ya no puede editarse como menor representado';
  end if;
  v_age:=extract(year from age(current_date,p_fecha_nacimiento));

  if v_age>=16 and v_email is null then
    raise exception 'A partir de los 16 anos es obligatorio informar un correo propio del jugador';
  end if;

  select d.id into v_existing_doc
  from public.documentos_identidad d
  where d.persona_id=v_persona and d.activo=true and d.es_principal=true
  order by d.created_at desc
  limit 1;

  if v_age>=14 and v_existing_doc is null and nullif(trim(coalesce(p_numero_documento,'')),'') is null then
    raise exception 'A partir de los 14 anos es obligatorio informar el DNI o NIE propio del jugador';
  end if;
  if v_age>=14 and nullif(trim(coalesce(p_numero_documento,'')),'') is not null and p_tipo_documento not in ('dni','nie') then
    raise exception 'A partir de los 14 anos el documento propio debe ser DNI o NIE';
  end if;
  if nullif(trim(coalesce(p_numero_documento,'')),'') is not null
     and p_tipo_documento in ('dni','nie')
     and not private.documento_espanol_valido(p_tipo_documento,p_numero_documento) then
    raise exception '% no valido: la letra no corresponde al numero', upper(p_tipo_documento);
  end if;

  if v_email is not null and exists(
    select 1 from public.personas p
    where lower(trim(coalesce(p.email_contacto,'')))=v_email
      and p.id<>v_persona
  ) then
    raise exception 'Ese correo ya pertenece a otra Persona';
  end if;

  update public.personas p
  set nombre=trim(p_nombre),
      primer_apellido=trim(p_primer_apellido),
      segundo_apellido=nullif(trim(coalesce(p_segundo_apellido,'')),''),
      fecha_nacimiento=p_fecha_nacimiento,
      email_contacto=v_email,
      updated_at=now()
  where p.id=v_persona;

  if nullif(trim(coalesce(p_numero_documento,'')),'') is not null then
    if p_tipo_documento not in ('dni','nie','pasaporte','otro') then raise exception 'Tipo de documento no valido'; end if;
    v_norm:=private.normalizar_documento(p_numero_documento);
    select d.persona_id into v_owner
    from public.documentos_identidad d
    where d.tipo=p_tipo_documento
      and private.normalizar_documento(d.numero)=v_norm
    limit 1;
    if v_owner is not null and v_owner<>v_persona then raise exception 'El documento ya pertenece a otra persona'; end if;

    update public.documentos_identidad d
    set es_principal=false
    where d.persona_id=v_persona and d.activo=true and d.es_principal=true;

    if exists(
      select 1 from public.documentos_identidad d
      where d.persona_id=v_persona
        and d.tipo=p_tipo_documento
        and private.normalizar_documento(d.numero)=v_norm
    ) then
      update public.documentos_identidad d
      set activo=true,es_principal=true
      where d.persona_id=v_persona
        and d.tipo=p_tipo_documento
        and private.normalizar_documento(d.numero)=v_norm;
    else
      insert into public.documentos_identidad(persona_id,tipo,numero,es_principal,activo)
      values(v_persona,p_tipo_documento,v_norm,true,true);
    end if;
  end if;

  select i.id,i.estado into v_ins,v_old
  from public.inscripciones i
  join public.temporadas t on t.id=i.temporada_id
  where i.jugador_id=p_jugador_id and t.estado='activa'
  limit 1;
  if v_ins is null then raise exception 'No existe una inscripcion en la temporada activa'; end if;

  update public.inscripciones i
  set estado='pendiente_revision_inicial',
      observaciones='Datos modificados por la familia. Pendiente de nueva revision.',
      updated_at=now()
  where i.id=v_ins;

  insert into public.historico_estados_inscripcion(inscripcion_id,estado_anterior,estado_nuevo,comentario,cambiado_por)
  values(v_ins,v_old,'pendiente_revision_inicial','Datos modificados por el tutor',v_auth);

  select concat_ws(' ',p.nombre,p.primer_apellido,p.segundo_apellido),tp.email_contacto
  into v_name,v_tutor_email
  from public.personas p
  left join public.personas tp on tp.id=v_tutor
  where p.id=v_persona;

  select a.id into v_authz
  from public.autorizaciones_menor a
  where a.persona_menor_id=v_persona
    and a.tipo='entrenador_menor'
    and a.estado='pendiente_email'
  order by a.solicitada_at desc
  limit 1;

  if v_authz is not null and v_email is not null then
    update public.autorizaciones_menor a
    set estado='pendiente',updated_at=now(),actualizado_por=v_auth
    where a.id=v_authz;
    if nullif(trim(coalesce(v_tutor_email,'')),'') is not null then
      insert into public.notificaciones_salida(tipo,destinatario_tipo,destinatario_persona_id,destinatario_email,asunto,cuerpo)
      values(
        'autorizacion_entrenador_menor','tutor',v_tutor,v_tutor_email,
        'Autorizacion necesaria para entrenador menor - C.D. Los Yebenes San Bruno',
        'El club solicita tu autorizacion para que '||v_name||' pueda desempenar funciones de entrenador siendo menor de edad. Accede a la plataforma con tu perfil Tutor/Familia para aceptar o rechazar la autorizacion.'
      );
    end if;
  end if;

  insert into public.auditoria(entidad,entidad_id,accion,actor_auth_user_id,datos_nuevos)
  values('jugador',p_jugador_id,'modificacion_por_tutor',v_auth,
    jsonb_build_object('persona_id',v_persona,'email_jugador',v_email));

  return p_jugador_id;
end;
$$;


ALTER FUNCTION "public"."actualizar_menor_representado"("p_jugador_id" "uuid", "p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_tipo_documento" "text", "p_numero_documento" "text", "p_email_jugador" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."actualizar_perfiles_persona_admin"("p_persona_id" "uuid", "p_administrador" boolean DEFAULT NULL::boolean, "p_club" boolean DEFAULT NULL::boolean, "p_entrenador" boolean DEFAULT NULL::boolean, "p_jugador" boolean DEFAULT NULL::boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare v_auth uuid; v_role uuid; v_code text; v_value boolean; v_ent uuid; v_birth date;
begin
  if auth.uid() is null or not private.has_role('administrador') then
    raise exception 'Solo un administrador puede modificar perfiles';
  end if;

  select auth_user_id,fecha_nacimiento into v_auth,v_birth
    from public.personas where id=p_persona_id;
  if not found then raise exception 'Persona no encontrada'; end if;

  for v_code,v_value in
    select * from (values
      ('administrador'::text,p_administrador),
      ('club'::text,p_club),
      ('entrenador'::text,p_entrenador)
    ) x(code,value)
  loop
    if v_value is null then continue; end if;

    select id into v_role from public.roles where codigo=v_code limit 1;

    if v_code='administrador' and v_value=false and v_auth=auth.uid() then
      raise exception 'No puedes retirarte a ti mismo el perfil Administrador';
    end if;

    if v_code='entrenador' and v_value=false then
      select id into v_ent from public.entrenadores where persona_id=p_persona_id limit 1;
      if v_ent is not null and exists(
        select 1 from public.asignaciones_entrenador_equipo a
         where a.entrenador_id=v_ent
           and a.fecha_desde<=current_date
           and (a.fecha_hasta is null or a.fecha_hasta>=current_date)
      ) then
        raise exception 'No se puede retirar Entrenador mientras tenga asignaciones activas';
      end if;
    end if;

    if exists(select 1 from public.persona_roles where persona_id=p_persona_id and rol_id=v_role) then
      update public.persona_roles
         set activo=v_value,
             fecha_desde=case when v_value then coalesce(fecha_desde,current_date) else fecha_desde end,
             fecha_hasta=case when v_value then null else current_date end,
             updated_at=now()
       where persona_id=p_persona_id and rol_id=v_role;
    elsif v_value then
      insert into public.persona_roles(persona_id,rol_id,fecha_desde,activo,otorgado_por)
      values(p_persona_id,v_role,current_date,true,auth.uid());
    end if;

    if v_code='entrenador' then
      select id into v_ent from public.entrenadores where persona_id=p_persona_id limit 1;
      if v_value then
        if v_ent is null then
          insert into public.entrenadores(persona_id,activo,curso_delegado)
          values(p_persona_id,true,false) returning id into v_ent;
        else
          update public.entrenadores set activo=true where id=v_ent;
        end if;
        if v_birth is not null and v_birth>(current_date-interval '18 years')::date then
          perform public.solicitar_autorizacion_entrenador_menor(p_persona_id);
        end if;
      elsif v_ent is not null then
        update public.entrenadores set activo=false where id=v_ent;
        update public.autorizaciones_menor
           set estado='revocada',fecha_hasta=current_date,actualizado_por=auth.uid(),updated_at=now()
         where persona_menor_id=p_persona_id
           and tipo='entrenador_menor'
           and estado in ('pendiente','aceptada');
      end if;
    end if;
  end loop;

  -- p_jugador NO se procesa. Tutor/Jugador son perfiles personales.
end;
$$;


ALTER FUNCTION "public"."actualizar_perfiles_persona_admin"("p_persona_id" "uuid", "p_administrador" boolean, "p_club" boolean, "p_entrenador" boolean, "p_jugador" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."actualizar_vinculos_clubber"("p_jugador_id" "uuid", "p_clubber_deportista_id" "text" DEFAULT NULL::"text", "p_tutor_persona_id" "uuid" DEFAULT NULL::"uuid", "p_clubber_tutor_id" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
    if not private.has_any_role(array['administrador','club']::text[]) then
        raise exception 'Solo Club/Administrador puede gestionar IDs Clubber';
    end if;

    if p_clubber_deportista_id is null or trim(p_clubber_deportista_id)='' then
        update public.vinculos_clubber set activo=false,actualizado_por=auth.uid(),updated_at=now()
         where tipo='deportista' and jugador_id=p_jugador_id and activo=true;
    else
        insert into public.vinculos_clubber(tipo,jugador_id,clubber_id,creado_por,actualizado_por)
        values ('deportista',p_jugador_id,trim(p_clubber_deportista_id),auth.uid(),auth.uid())
        on conflict (jugador_id) where tipo='deportista' and activo=true
        do update set clubber_id=excluded.clubber_id,actualizado_por=auth.uid(),updated_at=now();
    end if;

    if p_tutor_persona_id is not null then
        if p_clubber_tutor_id is null or trim(p_clubber_tutor_id)='' then
            update public.vinculos_clubber set activo=false,actualizado_por=auth.uid(),updated_at=now()
             where tipo='tutor' and persona_id=p_tutor_persona_id and activo=true;
        else
            insert into public.vinculos_clubber(tipo,persona_id,clubber_id,creado_por,actualizado_por)
            values ('tutor',p_tutor_persona_id,trim(p_clubber_tutor_id),auth.uid(),auth.uid())
            on conflict (persona_id) where tipo='tutor' and activo=true
            do update set clubber_id=excluded.clubber_id,actualizado_por=auth.uid(),updated_at=now();
        end if;
    end if;
end;
$$;


ALTER FUNCTION "public"."actualizar_vinculos_clubber"("p_jugador_id" "uuid", "p_clubber_deportista_id" "text", "p_tutor_persona_id" "uuid", "p_clubber_tutor_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."anular_pago_inscripcion"("p_pago_id" "uuid", "p_motivo" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    v_ins uuid;
begin
    if not private.has_any_role(array['administrador','club']::text[]) then
        raise exception 'Solo Club/Administrador puede anular pagos';
    end if;
    if trim(coalesce(p_motivo,''))='' then raise exception 'Indica el motivo de anulacion'; end if;

    update public.pagos_inscripcion
       set estado='anulado', observaciones=concat_ws(' · ',observaciones,'Anulado: '||trim(p_motivo)), updated_at=now()
     where id=p_pago_id
     returning inscripcion_id into v_ins;
    if v_ins is null then raise exception 'Pago no encontrado'; end if;
    perform private.recalcular_situacion_economica(v_ins);
end;
$$;


ALTER FUNCTION "public"."anular_pago_inscripcion"("p_pago_id" "uuid", "p_motivo" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."asignar_rol_entrenador"("p_persona_id" "uuid", "p_licencia_tipo" "text" DEFAULT NULL::"text", "p_licencia_numero" "text" DEFAULT NULL::"text", "p_curso_delegado" boolean DEFAULT false, "p_activo" boolean DEFAULT true, "p_observaciones" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_entrenador_id uuid; v_role_id uuid; v_birth date;
begin
  if auth.uid() is null then raise exception 'Es necesario iniciar sesion'; end if;
  if not private.has_any_role(array['administrador','club']::text[]) then raise exception 'No autorizado para asignar el rol entrenador'; end if;
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


ALTER FUNCTION "public"."asignar_rol_entrenador"("p_persona_id" "uuid", "p_licencia_tipo" "text", "p_licencia_numero" "text", "p_curso_delegado" boolean, "p_activo" boolean, "p_observaciones" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."auditar_cambios_entrenador_v92"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_entidad text := TG_TABLE_NAME;
  v_id uuid;
  v_accion text;
begin
  if TG_OP='UPDATE' then
    if to_jsonb(OLD) = to_jsonb(NEW) then
      return NEW;
    end if;

    v_id := NEW.id;

    v_accion := case TG_TABLE_NAME
      when 'entrenador_formaciones' then 'formacion_modificada'
      when 'entrenador_licencias_rffm' then 'licencia_rffm_modificada'
      when 'reconocimientos_medicos' then 'rrmm_modificado'
      else 'registro_modificado'
    end;

    insert into public.auditoria(
      entidad,
      entidad_id,
      accion,
      actor_auth_user_id,
      datos_anteriores,
      datos_nuevos,
      metadata
    )
    values(
      v_entidad,
      v_id,
      v_accion,
      auth.uid(),
      to_jsonb(OLD),
      to_jsonb(NEW),
      jsonb_build_object(
        'version','v92',
        'origen','trigger'
      )
    );

    return NEW;

  elsif TG_OP='DELETE' then

    v_id := OLD.id;

    v_accion := case TG_TABLE_NAME
      when 'entrenador_formaciones' then 'formacion_eliminada'
      when 'entrenador_licencias_rffm' then 'licencia_rffm_eliminada'
      when 'reconocimientos_medicos' then 'rrmm_eliminado'
      else 'registro_eliminado'
    end;

    insert into public.auditoria(
      entidad,
      entidad_id,
      accion,
      actor_auth_user_id,
      datos_anteriores,
      datos_nuevos,
      metadata
    )
    values(
      v_entidad,
      v_id,
      v_accion,
      auth.uid(),
      to_jsonb(OLD),
      null,
      jsonb_build_object(
        'version','v92',
        'origen','trigger'
      )
    );

    return OLD;
  end if;

  return null;
end;
$$;


ALTER FUNCTION "public"."auditar_cambios_entrenador_v92"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calcular_categoria_inscripcion"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare

  v_fecha_nacimiento date;
  v_categoria_id uuid;

begin

  select p.fecha_nacimiento
  into v_fecha_nacimiento

  from public.jugadores j

  join public.personas p
    on p.id = j.persona_id

  where j.id = new.jugador_id;

  if v_fecha_nacimiento is null then
    return new;
  end if;

  select r.categoria_id
  into v_categoria_id

  from public.reglas_categoria_temporada r

  where r.temporada_id = new.temporada_id

    and r.activo = true

    and (
      r.anio_nacimiento_desde is null
      or
      extract(year from v_fecha_nacimiento)
        >= r.anio_nacimiento_desde
    )

    and (
      r.anio_nacimiento_hasta is null
      or
      extract(year from v_fecha_nacimiento)
        <= r.anio_nacimiento_hasta
    )

  limit 1;

  new.categoria_id = v_categoria_id;

  return new;

end;
$$;


ALTER FUNCTION "public"."calcular_categoria_inscripcion"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancelar_cita_rrmm"("p_cita_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_old public.citas_reconocimiento_medico%rowtype;
begin
  if auth.uid() is null then raise exception 'Es necesario iniciar sesion'; end if;
  if not private.has_any_role(array['administrador','club']::text[]) then
    raise exception 'No autorizado para cancelar citas';
  end if;

  perform pg_advisory_xact_lock(hashtext('rrmm-cita:'||p_cita_id::text));

  select * into v_old
    from public.citas_reconocimiento_medico
   where id=p_cita_id;

  if not found then raise exception 'Cita no encontrada'; end if;
  if v_old.estado='cancelada' then return p_cita_id; end if;
  if v_old.estado<>'programada' then
    raise exception 'La cita ya no esta programada';
  end if;

  update public.notificaciones_salida
     set estado='cancelado'
   where cita_id=p_cita_id and estado='pendiente';

  update public.citas_reconocimiento_medico
     set estado='cancelada', comunicada_at=null, updated_at=now()
   where id=p_cita_id;

  insert into public.historico_citas_rrmm(
    cita_id,accion,datos_anteriores,datos_nuevos,actor_auth_user_id
  )
  select p_cita_id,'cancelada',to_jsonb(v_old),to_jsonb(c),auth.uid()
    from public.citas_reconocimiento_medico c
   where c.id=p_cita_id;

  perform private.encolar_notificaciones_cita(p_cita_id,'cancelada');
  return p_cita_id;
end;
$$;


ALTER FUNCTION "public"."cancelar_cita_rrmm"("p_cita_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."configurar_economia_equipo"("p_equipo_id" "uuid", "p_importe_inscripcion" numeric, "p_admite_fraccionamiento" boolean, "p_requiere_pago_ficha" boolean, "p_observaciones" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    v_temporada_id uuid;
    v_id uuid;
    v_ins uuid;
begin
    if not private.has_any_role(array['administrador','club']::text[]) then
        raise exception 'Solo Club/Administrador puede configurar importes';
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
end;
$$;


ALTER FUNCTION "public"."configurar_economia_equipo"("p_equipo_id" "uuid", "p_importe_inscripcion" numeric, "p_admite_fraccionamiento" boolean, "p_requiere_pago_ficha" boolean, "p_observaciones" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."crear_inscripcion_jugador_adulto"() RETURNS TABLE("jugador_id" "uuid", "inscripcion_id" "uuid", "categoria_id" "uuid")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    v_auth_user_id uuid;
    v_persona_id uuid;
    v_fecha_nacimiento date;
    v_jugador_id uuid;
    v_temporada_id uuid;
    v_inscripcion_id uuid;
    v_categoria_id uuid;
    v_documento_id uuid;
begin
    v_auth_user_id := auth.uid();

    if v_auth_user_id is null then
        raise exception 'Es necesario iniciar sesion';
    end if;

    if not private.has_role('jugador') then
        raise exception 'El usuario no tiene perfil de jugador';
    end if;

    select p.id, p.fecha_nacimiento
      into v_persona_id, v_fecha_nacimiento
    from public.personas p
    where p.auth_user_id = v_auth_user_id
      and p.activo = true
    limit 1;

    if v_persona_id is null then
        raise exception 'No existe una persona asociada al usuario';
    end if;

    if v_fecha_nacimiento is null then
        raise exception 'La persona debe tener fecha de nacimiento';
    end if;

    if v_fecha_nacimiento > (current_date - interval '18 years')::date then
        raise exception 'Un menor de 18 anos necesita representante legal';
    end if;

    select j.id
      into v_jugador_id
    from public.jugadores j
    where j.persona_id = v_persona_id
    limit 1;

    if v_jugador_id is null then
        insert into public.jugadores (
            persona_id,
            activo,
            fecha_alta
        )
        values (
            v_persona_id,
            true,
            current_date
        )
        returning id into v_jugador_id;
    end if;

    select t.id
      into v_temporada_id
    from public.temporadas t
    where t.estado = 'activa'
    limit 1;

    if v_temporada_id is null then
        raise exception 'No existe una temporada activa';
    end if;

    select i.id, i.categoria_id
      into v_inscripcion_id, v_categoria_id
    from public.inscripciones i
    where i.jugador_id = v_jugador_id
      and i.temporada_id = v_temporada_id
    limit 1;

    if v_inscripcion_id is not null then
        return query
        select v_jugador_id, v_inscripcion_id, v_categoria_id;
        return;
    end if;

    select d.id
      into v_documento_id
    from public.documentos_identidad d
    where d.persona_id = v_persona_id
      and d.activo = true
      and d.es_principal = true
    limit 1;

    insert into public.inscripciones (
        jugador_id,
        temporada_id,
        fecha_solicitud,
        estado,
        documento_identidad_usado_id,
        representacion_usada_id
    )
    values (
        v_jugador_id,
        v_temporada_id,
        current_date,
        'pendiente_revision_inicial',
        v_documento_id,
        null
    )
    returning id, public.inscripciones.categoria_id
      into v_inscripcion_id, v_categoria_id;

    insert into public.historico_estados_inscripcion (
        inscripcion_id,
        estado_anterior,
        estado_nuevo,
        comentario,
        cambiado_por
    )
    values (
        v_inscripcion_id,
        null,
        'pendiente_revision_inicial',
        'Alta inicial realizada por jugador adulto',
        v_auth_user_id
    );

    insert into public.auditoria (
        entidad,
        entidad_id,
        accion,
        actor_auth_user_id,
        datos_nuevos
    )
    values (
        'inscripcion',
        v_inscripcion_id,
        'alta_jugador_adulto',
        v_auth_user_id,
        jsonb_build_object(
            'jugador_id', v_jugador_id,
            'temporada_id', v_temporada_id
        )
    );

    return query
    select v_jugador_id, v_inscripcion_id, v_categoria_id;
end;
$$;


ALTER FUNCTION "public"."crear_inscripcion_jugador_adulto"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."declarar_requisito_rffm_realizado"("p_requisito_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_req public.requisitos_federativos_inscripcion%rowtype;
  v_persona_id uuid; v_autorizado boolean:=false;
  v_jugador uuid; v_nombre text; v_actor_nombre text; v_tipo_label text;
  rec record;
begin
  if auth.uid() is null then raise exception 'Es necesario iniciar sesion'; end if;
  select * into v_req from public.requisitos_federativos_inscripcion where id=p_requisito_id;
  if not found then raise exception 'Requisito no encontrado'; end if;
  if v_req.requiere_archivo then raise exception 'Este requisito se acredita mediante documento'; end if;
  if v_req.codigo not in ('autorizacion_tutor','firma_rffm') then raise exception 'Este requisito no admite comunicacion desde familia/jugador'; end if;
  if v_req.estado='validado' then raise exception 'El requisito ya esta validado por el club'; end if;
  if v_req.estado='declarado_realizado' then return; end if;
  if v_req.estado not in ('pendiente','rechazado') then raise exception 'El requisito no se encuentra en un estado comunicable'; end if;

  v_persona_id:=private.current_person_id();
  if v_persona_id is null then raise exception 'No existe una persona asociada al usuario'; end if;
  if exists(select 1 from public.inscripciones i join public.jugadores j on j.id=i.jugador_id where i.id=v_req.inscripcion_id and j.persona_id=v_persona_id) then v_autorizado:=true; end if;
  if not v_autorizado and exists(select 1 from public.inscripciones i join public.representaciones_jugador r on r.jugador_id=i.jugador_id where i.id=v_req.inscripcion_id and r.representante_persona_id=v_persona_id and (r.fecha_desde is null or r.fecha_desde<=current_date) and (r.fecha_hasta is null or r.fecha_hasta>=current_date)) then v_autorizado:=true; end if;
  if not v_autorizado then raise exception 'No autorizado para comunicar este requisito'; end if;

  select i.jugador_id,concat_ws(' ',p.nombre,p.primer_apellido,p.segundo_apellido)
    into v_jugador,v_nombre from public.inscripciones i join public.jugadores j on j.id=i.jugador_id join public.personas p on p.id=j.persona_id where i.id=v_req.inscripcion_id;
  select concat_ws(' ',p.nombre,p.primer_apellido,p.segundo_apellido) into v_actor_nombre from public.personas p where p.id=v_persona_id;
  v_tipo_label:=case when v_req.codigo='autorizacion_tutor' then 'la autorizacion del padre, madre o tutor' else 'la firma online de licencia RFFM' end;

  update public.requisitos_federativos_inscripcion set estado='declarado_realizado',declarado_realizado_at=now(),declarado_realizado_por=auth.uid(),motivo_rechazo=null,revisado_at=null,revisado_por=null,updated_at=now() where id=v_req.id;
  insert into public.historial_requisitos_federativos(requisito_id,inscripcion_id,estado_anterior,estado_nuevo,accion,motivo,actor_auth_user_id)
  values(v_req.id,v_req.inscripcion_id,v_req.estado,'declarado_realizado','familia_declara_realizado_rffm',null,auth.uid());

  for rec in
    select distinct p.id as persona_id,p.email_contacto,r.codigo
      from public.personas p join public.persona_roles pr on pr.persona_id=p.id join public.roles r on r.id=pr.rol_id
     where pr.activo=true and r.codigo in ('administrador','club') and nullif(trim(p.email_contacto),'') is not null
       and (pr.fecha_desde is null or pr.fecha_desde<=current_date) and (pr.fecha_hasta is null or pr.fecha_hasta>=current_date)
  loop
    insert into public.notificaciones_salida(tipo,jugador_id,destinatario_tipo,destinatario_persona_id,destinatario_email,asunto,cuerpo)
    values('requisito_rffm_por_verificar',v_jugador,rec.codigo,rec.persona_id,lower(trim(rec.email_contacto)),
      'Requisito RFFM pendiente de verificacion - '||v_nombre||' - C.D. Los Yebenes San Bruno',
      coalesce(v_actor_nombre,'Tutor/jugador')||' ha comunicado que '||v_tipo_label||' ya se ha realizado en la RFFM. Accede a la ficha de '||v_nombre||' para comprobarlo y validarlo.');
  end loop;
end; $$;


ALTER FUNCTION "public"."declarar_requisito_rffm_realizado"("p_requisito_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."guardar_asignaciones_entrenador"("p_entrenador_id" "uuid", "p_asignaciones" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
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

  if not private.has_any_role(array['administrador','club']::text[]) then
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


ALTER FUNCTION "public"."guardar_asignaciones_entrenador"("p_entrenador_id" "uuid", "p_asignaciones" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."guardar_disponibilidad_entrenador"("p_entrenador_id" "uuid", "p_temporada_id" "uuid", "p_disponibilidad" "jsonb", "p_confirmar" boolean DEFAULT false) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_persona_id uuid;
  v_owner_auth uuid;
  v_estado text;

  rec jsonb;

  v_day integer;
  v_tipo text;
  v_from time;
  v_to time;
  v_min time;
  v_count integer;

  v_old_schedule jsonb;
  v_new_schedule jsonb;

  v_old_confirmed timestamptz;
  v_new_confirmed timestamptz;
begin

  if auth.uid() is null then
    raise exception 'Es necesario iniciar sesion';
  end if;

  select
    e.persona_id,
    p.auth_user_id
  into
    v_persona_id,
    v_owner_auth
  from public.entrenadores e
  join public.personas p
    on p.id=e.persona_id
  where e.id=p_entrenador_id;

  if v_persona_id is null then
    raise exception 'Entrenador no encontrado';
  end if;

  if v_owner_auth is null
     or v_owner_auth is distinct from auth.uid()
  then
    raise exception
      'Solo el propio entrenador puede gestionar su disponibilidad';
  end if;

  if not exists(
    select 1
    from public.temporadas t
    where t.id=p_temporada_id
  ) then
    raise exception 'Temporada no encontrada';
  end if;

  if jsonb_typeof(
    coalesce(p_disponibilidad,'[]'::jsonb)
  ) <> 'array' then
    raise exception
      'Formato de disponibilidad no valido';
  end if;

  -- No se permiten dias duplicados.
  if exists(
    select 1
    from (
      select
        (x.value->>'dia_semana')::integer as dia,
        count(*) as n
      from jsonb_array_elements(
        coalesce(p_disponibilidad,'[]'::jsonb)
      ) x(value)
      group by
        (x.value->>'dia_semana')::integer
    ) q
    where q.n > 1
  ) then
    raise exception
      'No puede haber mas de una franja por dia';
  end if;

  select jsonb_array_length(
    coalesce(p_disponibilidad,'[]'::jsonb)
  )
  into v_count;

  if coalesce(p_confirmar,false)
     and v_count <> 7
  then
    raise exception
      'Para confirmar la disponibilidad hay que indicar los siete dias';
  end if;

  -- Validacion completa del payload.
  for rec in
    select value
    from jsonb_array_elements(
      coalesce(p_disponibilidad,'[]'::jsonb)
    )
  loop

    v_day :=
      (rec->>'dia_semana')::integer;

    v_tipo :=
      trim(coalesce(rec->>'tipo',''));

    v_from :=
      nullif(rec->>'hora_desde','')::time;

    v_to :=
      nullif(rec->>'hora_hasta','')::time;

    if v_day not between 1 and 7 then
      raise exception 'Dia de semana no valido';
    end if;

    if v_tipo not in (
      'no_disponible',
      'todo_dia',
      'desde',
      'franja'
    ) then
      raise exception
        'Tipo de disponibilidad no valido';
    end if;

    v_min :=
      case
        when v_day between 1 and 5
          then time '16:00'
        else time '08:00'
      end;

    if v_tipo in (
      'no_disponible',
      'todo_dia'
    ) then

      if v_from is not null
         or v_to is not null
      then
        raise exception
          'No disponible/Todo el dia no admiten horas';
      end if;

    elsif v_tipo='desde' then

      if v_from is null
         or v_to is not null
         or v_from<v_min
      then
        raise exception
          'Hora no valida para disponibilidad Desde';
      end if;

    elsif v_tipo='franja' then

      if v_from is null
         or v_to is null
         or v_from<v_min
         or not (
           v_to=time '00:00'
           or v_to>v_from
         )
      then
        raise exception
          'Franja horaria no valida';
      end if;

    end if;

  end loop;


  -- Estado anterior de disponibilidad.
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'dia_semana',d.dia_semana,
          'tipo',d.tipo,
          'hora_desde',
            case
              when d.hora_desde is null then null
              else to_char(d.hora_desde,'HH24:MI')
            end,
          'hora_hasta',
            case
              when d.hora_hasta is null then null
              else to_char(d.hora_hasta,'HH24:MI')
            end
        )
        order by d.dia_semana
      ),
      '[]'::jsonb
    )
  into v_old_schedule
  from public.entrenador_disponibilidad d
  where d.entrenador_id=p_entrenador_id
    and d.temporada_id=p_temporada_id;


  select et.disponibilidad_confirmada_at
  into v_old_confirmed
  from public.entrenador_temporadas et
  where et.entrenador_id=p_entrenador_id
    and et.temporada_id=p_temporada_id;


  -- Normaliza el nuevo payload.
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'dia_semana',
            (x.value->>'dia_semana')::integer,
          'tipo',
            x.value->>'tipo',
          'hora_desde',
            nullif(x.value->>'hora_desde',''),
          'hora_hasta',
            nullif(x.value->>'hora_hasta','')
        )
        order by
          (x.value->>'dia_semana')::integer
      ),
      '[]'::jsonb
    )
  into v_new_schedule
  from jsonb_array_elements(
    coalesce(p_disponibilidad,'[]'::jsonb)
  ) x(value);


  -- Estado operativo de temporada.
  v_estado :=
    case
      when exists(
        select 1
        from public.asignaciones_entrenador_equipo a
        join public.equipos e
          on e.id=a.equipo_id
        where a.entrenador_id=p_entrenador_id
          and e.temporada_id=p_temporada_id
          and a.cancelada_at is null
          and a.fecha_desde<=current_date
          and (
            a.fecha_hasta is null
            or a.fecha_hasta>=current_date
          )
      )
      then 'activo'
      else 'sin_asignacion'
    end;


  v_new_confirmed :=
    case
      when coalesce(p_confirmar,false)
        then now()
      else null
    end;


  insert into public.entrenador_temporadas(
    entrenador_id,
    temporada_id,
    estado,
    disponibilidad_confirmada_at
  )
  values(
    p_entrenador_id,
    p_temporada_id,
    v_estado,
    v_new_confirmed
  )
  on conflict(
    entrenador_id,
    temporada_id
  )
  do update set
    disponibilidad_confirmada_at=
      excluded.disponibilidad_confirmada_at,
    updated_at=now();


  delete
  from public.entrenador_disponibilidad
  where entrenador_id=p_entrenador_id
    and temporada_id=p_temporada_id;


  for rec in
    select value
    from jsonb_array_elements(
      coalesce(p_disponibilidad,'[]'::jsonb)
    )
  loop

    insert into public.entrenador_disponibilidad(
      entrenador_id,
      temporada_id,
      dia_semana,
      tipo,
      hora_desde,
      hora_hasta
    )
    values(
      p_entrenador_id,
      p_temporada_id,
      (rec->>'dia_semana')::integer,
      rec->>'tipo',
      nullif(rec->>'hora_desde','')::time,
      nullif(rec->>'hora_hasta','')::time
    );

  end loop;


  -- Solo registra auditoria si realmente cambia
  -- la disponibilidad o el estado confirmado/pendiente.
  if v_old_schedule is distinct from v_new_schedule
     or
     (v_old_confirmed is null)
       is distinct from
     (v_new_confirmed is null)
  then

    insert into public.auditoria(
      entidad,
      entidad_id,
      accion,
      actor_auth_user_id,
      datos_anteriores,
      datos_nuevos,
      metadata
    )
    values(
      'entrenador_disponibilidad',
      p_entrenador_id,
      case
        when p_confirmar
          then 'disponibilidad_confirmada'
        else 'disponibilidad_borrador_guardado'
      end,
      auth.uid(),

      jsonb_build_object(
        'temporada_id',
          p_temporada_id,
        'confirmada_at',
          v_old_confirmed,
        'disponibilidad',
          v_old_schedule
      ),

      jsonb_build_object(
        'temporada_id',
          p_temporada_id,
        'confirmada_at',
          v_new_confirmed,
        'disponibilidad',
          v_new_schedule
      ),

      jsonb_build_object(
        'version','v92',
        'origen',
          'guardar_disponibilidad_entrenador'
      )
    );

  end if;

end;
$$;


ALTER FUNCTION "public"."guardar_disponibilidad_entrenador"("p_entrenador_id" "uuid", "p_temporada_id" "uuid", "p_disponibilidad" "jsonb", "p_confirmar" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."guardar_entrenador"("p_entrenador_id" "uuid", "p_persona_id" "uuid", "p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text" DEFAULT NULL::"text", "p_email" "text" DEFAULT NULL::"text", "p_telefono" "text" DEFAULT NULL::"text", "p_licencia_tipo" "text" DEFAULT NULL::"text", "p_licencia_numero" "text" DEFAULT NULL::"text", "p_curso_delegado" boolean DEFAULT false, "p_activo" boolean DEFAULT true, "p_observaciones" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_persona_id uuid := p_persona_id;
  v_entrenador_id uuid := p_entrenador_id;
  v_result uuid;
begin
  if auth.uid() is null then
    raise exception 'Es necesario iniciar sesion';
  end if;

  if not private.has_any_role(array['administrador','club']::text[]) then
    raise exception 'No autorizado para gestionar entrenadores';
  end if;

  if v_entrenador_id is not null then
    select e.persona_id into v_persona_id
      from public.entrenadores e
     where e.id=v_entrenador_id;
    if v_persona_id is null then
      raise exception 'Entrenador no encontrado';
    end if;
  end if;

  if v_persona_id is null then
    raise exception 'El alta de entrenador debe partir de una Persona existente';
  end if;

  if not exists(select 1 from public.personas p where p.id=v_persona_id) then
    raise exception 'Persona no encontrada';
  end if;

  -- Los datos personales pertenecen a Persona y pueden mantenerse desde aqui en
  -- edicion por compatibilidad, pero nunca se crea una Persona nueva.
  update public.personas
     set nombre=coalesce(nullif(trim(coalesce(p_nombre,'')),''),nombre),
         primer_apellido=coalesce(nullif(trim(coalesce(p_primer_apellido,'')),''),primer_apellido),
         segundo_apellido=nullif(trim(coalesce(p_segundo_apellido,'')),''),
         email_contacto=nullif(lower(trim(coalesce(p_email,''))),''),
         telefono=nullif(trim(coalesce(p_telefono,'')),'')
   where id=v_persona_id;

  v_result := public.asignar_rol_entrenador(
    v_persona_id,
    p_licencia_tipo,
    p_licencia_numero,
    p_curso_delegado,
    p_activo,
    p_observaciones
  );

  return v_result;
end;
$$;


ALTER FUNCTION "public"."guardar_entrenador"("p_entrenador_id" "uuid", "p_persona_id" "uuid", "p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_email" "text", "p_telefono" "text", "p_licencia_tipo" "text", "p_licencia_numero" "text", "p_curso_delegado" boolean, "p_activo" boolean, "p_observaciones" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."guardar_persona_admin"("p_persona_id" "uuid" DEFAULT NULL::"uuid", "p_nombre" "text" DEFAULT NULL::"text", "p_primer_apellido" "text" DEFAULT NULL::"text", "p_segundo_apellido" "text" DEFAULT NULL::"text", "p_email" "text" DEFAULT NULL::"text", "p_telefono" "text" DEFAULT NULL::"text", "p_fecha_nacimiento" "date" DEFAULT NULL::"date", "p_activo" boolean DEFAULT true) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_id uuid := p_persona_id;
  v_email text := nullif(lower(trim(coalesce(p_email,''))), '');
  v_nombre text := trim(coalesce(p_nombre,''));
  v_ap1 text := trim(coalesce(p_primer_apellido,''));
  v_ap2 text := nullif(trim(coalesce(p_segundo_apellido,'')), '');
begin
  if auth.uid() is null or not private.has_role('administrador') then
    raise exception 'Solo un administrador puede gestionar Personas';
  end if;
  if v_nombre='' or v_ap1='' then
    raise exception 'Nombre y primer apellido son obligatorios';
  end if;

  if v_email is not null and exists(
    select 1 from public.personas p
    where lower(coalesce(p.email_contacto,''))=v_email
      and (v_id is null or p.id<>v_id)
  ) then
    raise exception 'Ya existe otra Persona con ese correo';
  end if;

  if p_fecha_nacimiento is not null and exists(
    select 1 from public.personas p
    where lower(trim(coalesce(p.nombre,'')))=lower(v_nombre)
      and lower(trim(coalesce(p.primer_apellido,'')))=lower(v_ap1)
      and lower(trim(coalesce(p.segundo_apellido,'')))=lower(coalesce(v_ap2,''))
      and p.fecha_nacimiento=p_fecha_nacimiento
      and (v_id is null or p.id<>v_id)
  ) then
    raise exception 'Posible duplicado: ya existe una Persona con el mismo nombre y fecha de nacimiento';
  end if;

  if v_id is null then
    insert into public.personas(
      nombre,primer_apellido,segundo_apellido,email_contacto,telefono,fecha_nacimiento,activo
    ) values(
      v_nombre,v_ap1,v_ap2,v_email,nullif(trim(coalesce(p_telefono,'')),''),p_fecha_nacimiento,coalesce(p_activo,true)
    ) returning id into v_id;
  else
    if not exists(select 1 from public.personas where id=v_id) then
      raise exception 'Persona no encontrada';
    end if;
    update public.personas
       set nombre=v_nombre,
           primer_apellido=v_ap1,
           segundo_apellido=v_ap2,
           email_contacto=v_email,
           telefono=nullif(trim(coalesce(p_telefono,'')),''),
           fecha_nacimiento=p_fecha_nacimiento,
           activo=coalesce(p_activo,true),
           updated_at=now()
     where id=v_id;
  end if;
  return v_id;
end;
$$;


ALTER FUNCTION "public"."guardar_persona_admin"("p_persona_id" "uuid", "p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_email" "text", "p_telefono" "text", "p_fecha_nacimiento" "date", "p_activo" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."inicializar_requisitos_federativos"("p_inscripcion_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
    if not exists (
        select 1 from public.inscripciones i where i.id = p_inscripcion_id
    ) then
        raise exception 'La inscripcion no existe';
    end if;

    insert into public.requisitos_federativos_inscripcion
        (inscripcion_id,codigo,nombre,obligatorio,requiere_archivo)
    values
        (p_inscripcion_id,'foto_jugador','Fotografia reciente del jugador',true,true),
        (p_inscripcion_id,'identidad_rffm','Identificacion del jugador para RFFM',true,true),
        (p_inscripcion_id,'autorizacion_tutor','Autorizacion del padre, madre o tutor',true,false),
        (p_inscripcion_id,'firma_rffm','Firma online de licencia RFFM',true,false)
    on conflict (inscripcion_id,codigo) do nothing;
end;
$$;


ALTER FUNCTION "public"."inicializar_requisitos_federativos"("p_inscripcion_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."marcar_no_asiste_cita_rrmm"("p_cita_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_old public.citas_reconocimiento_medico%rowtype;
begin
  if auth.uid() is null then raise exception 'Es necesario iniciar sesion'; end if;
  if not private.has_any_role(array['administrador','club']::text[]) then
    raise exception 'No autorizado para marcar no asistencia';
  end if;

  perform pg_advisory_xact_lock(hashtext('rrmm-cita:'||p_cita_id::text));

  select * into v_old
    from public.citas_reconocimiento_medico
   where id=p_cita_id;

  if not found then raise exception 'Cita no encontrada'; end if;
  if v_old.estado='no_asiste' then return p_cita_id; end if;
  if v_old.estado<>'programada' then
    raise exception 'Solo se puede marcar no asistencia sobre una cita programada';
  end if;
  if v_old.fecha_hora>now() then
    raise exception 'No se puede marcar no asistencia antes de la fecha de la cita';
  end if;

  update public.notificaciones_salida
     set estado='cancelado'
   where cita_id=p_cita_id and estado='pendiente';

  update public.citas_reconocimiento_medico
     set estado='no_asiste',comunicada_at=null,updated_at=now()
   where id=p_cita_id;

  insert into public.historico_citas_rrmm(
    cita_id,accion,datos_anteriores,datos_nuevos,actor_auth_user_id
  )
  select p_cita_id,'no_asiste',to_jsonb(v_old),to_jsonb(c),auth.uid()
    from public.citas_reconocimiento_medico c
   where c.id=p_cita_id;

  return p_cita_id;
end;
$$;


ALTER FUNCTION "public"."marcar_no_asiste_cita_rrmm"("p_cita_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."modificar_cita_rrmm"("p_cita_id" "uuid", "p_fecha_hora" timestamp with time zone, "p_lugar" "text", "p_direccion" "text" DEFAULT NULL::"text", "p_indicaciones" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_old public.citas_reconocimiento_medico%rowtype;
  v_lugar text := trim(coalesce(p_lugar,''));
  v_direccion text := nullif(trim(coalesce(p_direccion,'')),'');
  v_indicaciones text := nullif(trim(coalesce(p_indicaciones,'')),'');
begin
  if auth.uid() is null then raise exception 'Es necesario iniciar sesion'; end if;
  if not private.has_any_role(array['administrador','club']::text[]) then
    raise exception 'No autorizado para modificar citas';
  end if;
  if p_fecha_hora is null or v_lugar='' then
    raise exception 'Fecha/hora y lugar son obligatorios';
  end if;

  perform pg_advisory_xact_lock(hashtext('rrmm-cita:'||p_cita_id::text));

  select * into v_old
    from public.citas_reconocimiento_medico
   where id=p_cita_id;

  if not found then raise exception 'Cita no encontrada'; end if;
  if v_old.estado<>'programada' then
    raise exception 'Solo se puede modificar una cita programada';
  end if;

  -- Proteccion backend frente a doble pulsacion/reintento identico.
  if v_old.fecha_hora = p_fecha_hora
     and v_old.lugar is not distinct from v_lugar
     and v_old.direccion is not distinct from v_direccion
     and v_old.indicaciones is not distinct from v_indicaciones then
    return p_cita_id;
  end if;

  update public.notificaciones_salida
     set estado='cancelado'
   where cita_id=p_cita_id and estado='pendiente';

  update public.citas_reconocimiento_medico
     set fecha_hora=p_fecha_hora,
         lugar=v_lugar,
         direccion=v_direccion,
         indicaciones=v_indicaciones,
         comunicada_at=null,
         updated_at=now()
   where id=p_cita_id;

  insert into public.historico_citas_rrmm(
    cita_id,accion,datos_anteriores,datos_nuevos,actor_auth_user_id
  )
  select p_cita_id,'modificada',to_jsonb(v_old),to_jsonb(c),auth.uid()
    from public.citas_reconocimiento_medico c
   where c.id=p_cita_id;

  perform private.encolar_notificaciones_cita(p_cita_id,'modificada');
  return p_cita_id;
end;
$$;


ALTER FUNCTION "public"."modificar_cita_rrmm"("p_cita_id" "uuid", "p_fecha_hora" timestamp with time zone, "p_lugar" "text", "p_direccion" "text", "p_indicaciones" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."obtener_historico_entrenador"("p_entrenador_id" "uuid") RETURNS TABLE("evento_at" timestamp with time zone, "fecha_referencia" "date", "categoria" "text", "titulo" "text", "detalle" "text", "actor_nombre" "text", "actor_email" "text", "origen" "text", "origen_id" "uuid", "metadata" "jsonb")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_persona_id uuid;
  v_owner_auth uuid;
begin
  if auth.uid() is null then raise exception 'Es necesario iniciar sesion'; end if;

  select e.persona_id,p.auth_user_id
    into v_persona_id,v_owner_auth
    from public.entrenadores e
    join public.personas p on p.id=e.persona_id
   where e.id=p_entrenador_id;

  if v_persona_id is null then raise exception 'Entrenador no encontrado'; end if;
  if not private.has_any_role(array['administrador','club']::text[])
     and v_owner_auth is distinct from auth.uid() then
    raise exception 'No autorizado para consultar este historico';
  end if;

  return query
  with actor as (
    select p.auth_user_id,
           concat_ws(' ',nullif(trim(p.nombre),''),nullif(trim(p.primer_apellido),''),nullif(trim(p.segundo_apellido),'')) as nombre,
           p.email_contacto
      from public.personas p
     where p.auth_user_id is not null
  ),
  asignaciones as (
    select a.*,
           eq.nombre as equipo_nombre,
           ac.nombre as actor_nombre,
           ac.email_contacto as actor_email,
           coalesce(
             (
               select coalesce(
                 nullif(au.datos_anteriores->>'funcion',''),
                 nullif(au.datos_anteriores->>'rol',''),
                 nullif(au.datos_nuevos->>'funcion_anterior','')
               )
                 from public.auditoria au
                where au.entidad='asignacion_entrenador_equipo'
                  and au.entidad_id=a.id
                  and au.accion='cambio_funcion_entrenador'
                order by au.created_at
                limit 1
             ),
             a.funcion,a.rol,'first'
           ) as funcion_inicial
      from public.asignaciones_entrenador_equipo a
      left join public.equipos eq on eq.id=a.equipo_id
      left join actor ac on ac.auth_user_id=a.asignado_por
     where a.entrenador_id=p_entrenador_id
  ),
  eventos(evento_at,fecha_referencia,categoria,titulo,detalle,actor_nombre,actor_email,origen,origen_id,metadata) as (
    -- Alta/asignacion inicial. Si la fila fue mutada in-place, recupera la funcion inicial desde auditoria.
    select
      a.created_at as evento_at,
      a.fecha_desde as fecha_referencia,
      'equipo'::text as categoria,
      ('Alta en '||coalesce(a.equipo_nombre,'equipo'))::text as titulo,
      (case a.funcion_inicial
         when 'first' then 'Entrenador principal'
         when 'second' then 'Segundo entrenador'
         when 'goalkeeper' then 'Entrenador de porteros'
         when 'fitness' then 'Preparador fisico'
         else a.funcion_inicial
       end || ' · Desde ' || to_char(a.fecha_desde,'DD/MM/YYYY') ||
       case when a.fecha_hasta is not null then ' · Hasta '||to_char(a.fecha_hasta,'DD/MM/YYYY') else '' end)::text as detalle,
      a.actor_nombre,a.actor_email,
      'asignaciones_entrenador_equipo'::text as origen,
      a.id as origen_id,
      jsonb_build_object('equipo_id',a.equipo_id,'funcion_inicial',a.funcion_inicial,'fecha_hasta',a.fecha_hasta,'motivo_fin',a.motivo_fin)
    from asignaciones a

    union all

    -- Finalizaciones reales ya producidas. No muestra como evento un fin futuro planificado.
    select
      coalesce(a.cancelada_at,a.updated_at,(a.fecha_hasta::timestamp at time zone 'UTC')),
      a.fecha_hasta,
      'equipo',
      ('Fin de etapa en '||coalesce(a.equipo_nombre,'equipo')),
      coalesce(nullif(a.motivo_fin,''),'Asignacion finalizada'),
      null::text,null::text,
      'asignaciones_entrenador_equipo',a.id,
      jsonb_build_object('equipo_id',a.equipo_id,'fecha_hasta',a.fecha_hasta,'cancelada_at',a.cancelada_at,'motivo_fin',a.motivo_fin)
    from asignaciones a
    where a.cancelada_at is not null
       or (a.fecha_hasta is not null and a.fecha_hasta<current_date)
       or nullif(a.motivo_fin,'') is not null

    union all

    -- Auditoria explicita asociada a este entrenador o sus entidades.
    select
      au.created_at,
      coalesce(
        nullif(au.datos_nuevos->>'fecha_desde','')::date,
        nullif(au.datos_nuevos->>'fecha_sustitucion','')::date,
        au.created_at::date
      ),
      case
        when au.entidad='asignacion_entrenador_equipo' then 'equipo'
        when au.entidad='entrenador_formaciones' then 'formacion'
        when au.entidad='entrenador_licencias_rffm' then 'licencia'
        when au.entidad='reconocimientos_medicos' then 'rrmm'
        when au.entidad='entrenador_disponibilidad' then 'disponibilidad'
        else 'administracion'
      end,
      case au.accion
        when 'cambio_funcion_entrenador' then 'Cambio de funcion'
        when 'sustitucion_entrenador_principal' then 'Sustitucion de entrenador principal'
        when 'formacion_modificada' then 'Formacion modificada'
        when 'formacion_eliminada' then 'Formacion eliminada'
        when 'licencia_rffm_modificada' then 'Licencia RFFM modificada'
        when 'licencia_rffm_eliminada' then 'Licencia RFFM eliminada'
        when 'rrmm_modificado' then 'Reconocimiento medico modificado'
        when 'rrmm_eliminado' then 'Reconocimiento medico eliminado'
        when 'disponibilidad_confirmada' then 'Disponibilidad confirmada'
        when 'disponibilidad_borrador_guardado' then 'Disponibilidad guardada como borrador'
        else replace(initcap(replace(au.accion,'_',' ')),'Rrmm','RRMM')
      end,
      case au.accion
        when 'cambio_funcion_entrenador' then
          concat(
            case coalesce(au.datos_nuevos->>'funcion_anterior',au.datos_anteriores->>'funcion',au.datos_anteriores->>'rol')
              when 'first' then 'Entrenador principal'
              when 'second' then 'Segundo entrenador'
              when 'goalkeeper' then 'Entrenador de porteros'
              when 'fitness' then 'Preparador fisico'
              else coalesce(au.datos_nuevos->>'funcion_anterior',au.datos_anteriores->>'funcion',au.datos_anteriores->>'rol','—')
            end,
            ' → ',
            case au.datos_nuevos->>'funcion_nueva'
              when 'first' then 'Entrenador principal'
              when 'second' then 'Segundo entrenador'
              when 'goalkeeper' then 'Entrenador de porteros'
              when 'fitness' then 'Preparador fisico'
              else coalesce(au.datos_nuevos->>'funcion_nueva','—')
            end
          )
        when 'disponibilidad_confirmada' then 'El entrenador confirmo su disponibilidad semanal.'
        when 'disponibilidad_borrador_guardado' then 'La disponibilidad quedo pendiente de confirmar.'
        else coalesce(nullif(au.metadata->>'resumen',''),'Cambio administrativo registrado')
      end,
      ac.nombre,ac.email_contacto,
      'auditoria',au.id,
      jsonb_build_object('entidad',au.entidad,'entidad_id',au.entidad_id,'accion',au.accion,'datos_anteriores',au.datos_anteriores,'datos_nuevos',au.datos_nuevos,'metadata',au.metadata)
    from public.auditoria au
    left join actor ac on ac.auth_user_id=au.actor_auth_user_id
    where
      (au.entidad='entrenador_disponibilidad' and au.entidad_id=p_entrenador_id)
      or au.entidad_id in (
        select a.id from public.asignaciones_entrenador_equipo a where a.entrenador_id=p_entrenador_id
        union select f.id from public.entrenador_formaciones f where f.entrenador_id=p_entrenador_id
        union select l.id from public.entrenador_licencias_rffm l where l.entrenador_id=p_entrenador_id
        union select r.id from public.reconocimientos_medicos r where r.persona_id=v_persona_id
      )

    union all

    -- Formaciones/titulaciones como hitos de negocio.
    select
      f.created_at,
      coalesce(f.fecha_obtencion,f.fecha_inicio,f.created_at::date),
      'formacion',
      case f.tipo
        when 'delegado' then 'Curso de Delegado'
        when 'uefa_c' then 'UEFA C'
        when 'uefa_b' then 'UEFA B'
        when 'uefa_a' then 'UEFA A'
        when 'uefa_pro' then 'UEFA PRO'
        when 'tecnico_deportivo' then 'Tecnico Deportivo'
        when 'tecnico_deportivo_superior' then 'Tecnico Deportivo Superior'
        else coalesce(f.nombre_otro,'Otra formacion')
      end,
      concat(
        case f.estado when 'en_curso' then 'En curso' when 'vigente' then 'Vigente' when 'caducada' then 'Caducada' when 'abandonada' then 'Abandonada' else f.estado end,
        ' · Verificacion: ',case f.verificacion_estado when 'verificada' then 'verificada' when 'rechazada' then 'rechazada' else 'pendiente' end
      ),
      ac.nombre,ac.email_contacto,
      'entrenador_formaciones',f.id,
      jsonb_build_object('tipo',f.tipo,'estado',f.estado,'fecha_inicio',f.fecha_inicio,'fecha_obtencion',f.fecha_obtencion,'fecha_caducidad',f.fecha_caducidad,'verificacion_estado',f.verificacion_estado,'verificado_at',f.verificado_at)
    from public.entrenador_formaciones f
    left join actor ac on ac.auth_user_id=f.creado_por
    where f.entrenador_id=p_entrenador_id

    union all

    -- Verificacion posterior de formacion, solo si fue un hito temporal distinto.
    select
      f.verificado_at,
      f.verificado_at::date,
      'formacion',
      'Formacion verificada',
      concat(case f.tipo when 'delegado' then 'Curso de Delegado' else upper(replace(f.tipo,'_',' ')) end,' · ',f.verificacion_estado),
      ac.nombre,ac.email_contacto,
      'entrenador_formaciones',f.id,
      jsonb_build_object('tipo',f.tipo,'verificacion_estado',f.verificacion_estado)
    from public.entrenador_formaciones f
    left join actor ac on ac.auth_user_id=f.verificado_por
    where f.entrenador_id=p_entrenador_id
      and f.verificado_at is not null
      and abs(extract(epoch from (f.verificado_at-f.created_at)))>2

    union all

    -- Licencias federativas.
    select
      l.created_at,
      coalesce(l.fecha_expedicion,l.created_at::date),
      'licencia',
      ('Licencia RFFM '||coalesce(nullif(l.tipo,'OTRA'),nullif(l.nombre_otro,''),'OTRA')),
      concat(
        'Temporada ',coalesce(t.nombre,'—'),
        ' · Verificacion: ',case l.verificacion_estado when 'verificada' then 'verificada' when 'rechazada' then 'rechazada' else 'pendiente' end,
        case when l.fecha_caducidad is not null then ' · Hasta '||to_char(l.fecha_caducidad,'DD/MM/YYYY') else '' end
      ),
      ac.nombre,ac.email_contacto,
      'entrenador_licencias_rffm',l.id,
      jsonb_build_object('tipo',l.tipo,'temporada_id',l.temporada_id,'numero',l.numero,'fecha_expedicion',l.fecha_expedicion,'fecha_caducidad',l.fecha_caducidad,'estado_excepcional',l.estado_excepcional,'verificacion_estado',l.verificacion_estado)
    from public.entrenador_licencias_rffm l
    left join public.temporadas t on t.id=l.temporada_id
    left join actor ac on ac.auth_user_id=l.creado_por
    where l.entrenador_id=p_entrenador_id

    union all

    -- RRMM transversal de la Persona.
    select
      r.created_at,
      r.fecha_reconocimiento,
      'rrmm',
      'Reconocimiento medico',
      concat('Realizado ',to_char(r.fecha_reconocimiento,'DD/MM/YYYY'),case when r.fecha_valido_hasta is not null then ' · Valido hasta '||to_char(r.fecha_valido_hasta,'DD/MM/YYYY') else '' end),
      ac.nombre,ac.email_contacto,
      'reconocimientos_medicos',r.id,
      jsonb_build_object('fecha_reconocimiento',r.fecha_reconocimiento,'fecha_valido_hasta',r.fecha_valido_hasta,'fecha_validacion_rffm',r.fecha_validacion_rffm,'centro_medico',r.centro_medico)
    from public.reconocimientos_medicos r
    left join actor ac on ac.auth_user_id=r.registrado_por
    where r.persona_id=v_persona_id

    union all

    -- Citas RRMM creadas para la Persona. Se muestra el alta de la cita una sola vez;
    -- la accion 'creada' del historico se omite mas abajo para evitar duplicados.
    select
      c.created_at,
      c.fecha_hora::date,
      'rrmm',
      'Cita RRMM programada',
      concat('Cita para ',to_char(c.fecha_hora at time zone 'Europe/Madrid','DD/MM/YYYY HH24:MI'),case when nullif(c.lugar,'') is not null then ' · '||c.lugar else '' end),
      ac.nombre,ac.email_contacto,
      'citas_reconocimiento_medico',c.id,
      jsonb_build_object('estado',c.estado,'fecha_hora',c.fecha_hora,'lugar',c.lugar,'direccion',c.direccion,'indicaciones',c.indicaciones)
    from public.citas_reconocimiento_medico c
    left join actor ac on ac.auth_user_id=c.creado_por
    where c.persona_id=v_persona_id

    union all

    -- Transiciones posteriores de la cita: modificacion, cancelacion, reprogramacion o no asistencia.
    select
      h.created_at,
      h.created_at::date,
      'rrmm',
      case h.accion
        when 'modificada' then 'Cita RRMM modificada'
        when 'cancelada' then 'Cita RRMM cancelada'
        when 'cancelada_por_reprogramacion' then 'Cita RRMM reprogramada'
        when 'no_asiste' then 'No asistio a la cita RRMM'
        when 'realizada_por_registro_rrmm' then 'Cita RRMM completada'
        else 'Cambio en cita RRMM'
      end,
      concat('Cita ',to_char(c.fecha_hora at time zone 'Europe/Madrid','DD/MM/YYYY HH24:MI'),case when nullif(c.lugar,'') is not null then ' · '||c.lugar else '' end),
      ac.nombre,ac.email_contacto,
      'historico_citas_rrmm',h.id,
      jsonb_build_object('cita_id',h.cita_id,'accion',h.accion,'datos_anteriores',h.datos_anteriores,'datos_nuevos',h.datos_nuevos)
    from public.historico_citas_rrmm h
    join public.citas_reconocimiento_medico c on c.id=h.cita_id
    left join actor ac on ac.auth_user_id=h.actor_auth_user_id
    where c.persona_id=v_persona_id
      and h.accion<>'creada'

    union all

    -- Estado actual de confirmacion de disponibilidad, util para datos previos a V92.
    select
      et.disponibilidad_confirmada_at,
      et.disponibilidad_confirmada_at::date,
      'disponibilidad',
      'Disponibilidad confirmada',
      concat('Temporada ',coalesce(t.nombre,'—')),
      null::text,null::text,
      'entrenador_temporadas',et.id,
      jsonb_build_object('temporada_id',et.temporada_id,'estado',et.estado,'origen_legacy',true)
    from public.entrenador_temporadas et
    left join public.temporadas t on t.id=et.temporada_id
    where et.entrenador_id=p_entrenador_id
      and et.disponibilidad_confirmada_at is not null
      and not exists(
        select 1 from public.auditoria au
         where au.entidad='entrenador_disponibilidad'
           and au.entidad_id=p_entrenador_id
           and au.accion='disponibilidad_confirmada'
           and au.created_at between et.disponibilidad_confirmada_at-interval '5 seconds' and et.disponibilidad_confirmada_at+interval '5 seconds'
      )
  )
  select e.evento_at,e.fecha_referencia,e.categoria,e.titulo,e.detalle,e.actor_nombre,e.actor_email,e.origen,e.origen_id,e.metadata
    from eventos e
   where e.evento_at is not null
   order by e.evento_at desc,e.categoria,e.titulo;
end;
$$;


ALTER FUNCTION "public"."obtener_historico_entrenador"("p_entrenador_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."procesar_mayorias_edad"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare rec record; v_role uuid; v_count integer:=0; v_birthday date; v_tutor_email text; v_player_email text; v_body text;
begin
  select id into v_role from public.roles where codigo='jugador' limit 1;
  for rec in
    select r.id rep_id,r.jugador_id,r.representante_persona_id,j.persona_id,p.fecha_nacimiento,p.auth_user_id,p.email_contacto,
           concat_ws(' ',p.nombre,p.primer_apellido,p.segundo_apellido) nombre
      from public.representaciones_jugador r
      join public.jugadores j on j.id=r.jugador_id
      join public.personas p on p.id=j.persona_id
     where r.fecha_hasta is null
       and coalesce(r.excepcion_representacion_adulto,false)=false
       and p.fecha_nacimiento is not null
       and p.fecha_nacimiento <= (current_date - interval '18 years')::date
  loop
    v_birthday:=(rec.fecha_nacimiento+interval '18 years')::date;
    v_player_email:=nullif(lower(trim(coalesce(rec.email_contacto,''))),'');
    select email_contacto into v_tutor_email from public.personas where id=rec.representante_persona_id;

    if v_player_email is null then
      if nullif(trim(coalesce(v_tutor_email,'')),'') is not null and not exists(
        select 1 from public.notificaciones_salida n where n.tipo='mayoria_edad_bloqueada_sin_email' and n.jugador_id=rec.jugador_id and n.destinatario_persona_id=rec.representante_persona_id
      ) then
        insert into public.notificaciones_salida(tipo,jugador_id,destinatario_tipo,destinatario_persona_id,destinatario_email,asunto,cuerpo)
        values('mayoria_edad_bloqueada_sin_email',rec.jugador_id,'tutor',rec.representante_persona_id,v_tutor_email,
          'Accion necesaria: correo propio de '||rec.nombre,
          rec.nombre||' ya ha alcanzado la mayoria de edad, pero la representacion no se cerrara hasta disponer de un correo propio que permita preparar su acceso autonomo. Informalo cuanto antes desde la ficha del jugador.');
      end if;
      continue;
    end if;

    update public.representaciones_jugador set fecha_hasta=greatest(fecha_desde,v_birthday-1),motivo_fin='Mayoria de edad',finalizado_por=auth.uid(),updated_at=now() where id=rec.rep_id and fecha_hasta is null;
    if exists(select 1 from public.persona_roles where persona_id=rec.persona_id and rol_id=v_role) then
      update public.persona_roles set activo=true,fecha_desde=coalesce(fecha_desde,v_birthday),fecha_hasta=null,updated_at=now() where persona_id=rec.persona_id and rol_id=v_role;
    else
      insert into public.persona_roles(persona_id,rol_id,fecha_desde,activo,otorgado_por) values(rec.persona_id,v_role,v_birthday,true,auth.uid());
    end if;
    update public.autorizaciones_menor set estado='finalizada_mayoria_edad',fecha_hasta=v_birthday-1,actualizado_por=auth.uid(),updated_at=now() where persona_menor_id=rec.persona_id and estado in ('pendiente_email','pendiente','aceptada');

    if not exists(select 1 from public.notificaciones_salida n where n.tipo='mayoria_edad_jugador' and n.jugador_id=rec.jugador_id) then
      v_body:='Has cumplido 18 anos. Desde hoy finaliza la representacion ordinaria de tu tutor en la plataforma del C.D. Los Yebenes San Bruno. '||case when rec.auth_user_id is null then 'Crea tu propia cuenta con este mismo correo y selecciona el alta como Jugador. El sistema reutilizara tu Persona y todo tu historial.' else 'Ya dispones de cuenta: inicia sesion y utiliza tu perfil Jugador. Tus demas perfiles se mantienen.' end;
      insert into public.notificaciones_salida(tipo,jugador_id,destinatario_tipo,destinatario_persona_id,destinatario_email,asunto,cuerpo)
      values('mayoria_edad_jugador',rec.jugador_id,'jugador',rec.persona_id,v_player_email,'Has alcanzado la mayoria de edad - C.D. Los Yebenes San Bruno',v_body);
    end if;
    if nullif(trim(coalesce(v_tutor_email,'')),'') is not null and not exists(select 1 from public.notificaciones_salida n where n.tipo='fin_representacion_mayoria_edad' and n.jugador_id=rec.jugador_id and n.destinatario_persona_id=rec.representante_persona_id) then
      insert into public.notificaciones_salida(tipo,jugador_id,destinatario_tipo,destinatario_persona_id,destinatario_email,asunto,cuerpo)
      values('fin_representacion_mayoria_edad',rec.jugador_id,'tutor',rec.representante_persona_id,v_tutor_email,'Fin de representacion por mayoria de edad - C.D. Los Yebenes San Bruno','La representacion ordinaria de '||rec.nombre||' ha finalizado al alcanzar los 18 anos. Su ficha deja de aparecer entre tus jugadores representados activos.');
    end if;
    insert into public.auditoria(entidad,entidad_id,accion,actor_auth_user_id,datos_nuevos)
    values('jugador',rec.jugador_id,'mayoria_edad_procesada',auth.uid(),jsonb_build_object('persona_id',rec.persona_id,'fecha_18',v_birthday,'email',v_player_email));
    v_count:=v_count+1;
  end loop;
  return v_count;
end;
$$;


ALTER FUNCTION "public"."procesar_mayorias_edad"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."procesar_preparacion_mayoria_edad"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare rec record; v_count integer:=0; v_days integer; v_tutor_email text; v_player_email text; v_type text; v_subject text; v_body text;
begin
  for rec in
    select r.jugador_id,r.representante_persona_id,j.persona_id,p.fecha_nacimiento,p.email_contacto,
           concat_ws(' ',p.nombre,p.primer_apellido,p.segundo_apellido) nombre
      from public.representaciones_jugador r
      join public.jugadores j on j.id=r.jugador_id and j.activo=true
      join public.personas p on p.id=j.persona_id
     where r.fecha_desde<=current_date
       and (r.fecha_hasta is null or r.fecha_hasta>=current_date)
       and coalesce(r.excepcion_representacion_adulto,false)=false
       and p.fecha_nacimiento is not null
       and p.fecha_nacimiento > (current_date - interval '18 years')::date
       and p.fecha_nacimiento <= (current_date - interval '16 years')::date
  loop
    v_days:=((rec.fecha_nacimiento+interval '18 years')::date-current_date);
    v_player_email:=nullif(lower(trim(coalesce(rec.email_contacto,''))),'');
    select email_contacto into v_tutor_email from public.personas where id=rec.representante_persona_id;

    if v_player_email is null then
      v_type:='email_jugador_16_requerido';
      if nullif(trim(coalesce(v_tutor_email,'')),'') is not null and not exists(
        select 1 from public.notificaciones_salida n where n.tipo=v_type and n.jugador_id=rec.jugador_id and n.destinatario_persona_id=rec.representante_persona_id
      ) then
        insert into public.notificaciones_salida(tipo,jugador_id,destinatario_tipo,destinatario_persona_id,destinatario_email,asunto,cuerpo)
        values(v_type,rec.jugador_id,'tutor',rec.representante_persona_id,v_tutor_email,
          'Correo propio necesario para '||rec.nombre||' - C.D. Los Yebenes San Bruno',
          rec.nombre||' tiene 16 anos o mas. Informa un correo propio desde su ficha en Familia > Datos. Se utilizara para comunicaciones directas y para preparar su acceso autonomo al cumplir 18 anos.');
        v_count:=v_count+1;
      end if;
    end if;

    if v_days between 61 and 90 then
      v_type:='pre_mayoria_90'; v_subject='Preparacion para la mayoria de edad - C.D. Los Yebenes San Bruno';
    elsif v_days between 0 and 30 then
      v_type:='pre_mayoria_30'; v_subject='Proxima mayoria de edad - C.D. Los Yebenes San Bruno';
    else
      v_type:=null;
    end if;

    if v_type is not null then
      if nullif(trim(coalesce(v_tutor_email,'')),'') is not null and not exists(select 1 from public.notificaciones_salida n where n.tipo=v_type and n.jugador_id=rec.jugador_id and n.destinatario_persona_id=rec.representante_persona_id) then
        v_body:=rec.nombre||' cumplira 18 anos en aproximadamente '||v_days||' dias. '||case when v_player_email is null then 'Antes de finalizar la representacion necesitamos que informes un correo propio del jugador en Familia > Datos.' else 'El correo propio ya consta en la ficha. Al cumplir 18 anos finalizara la representacion ordinaria y el jugador podra gestionar su acceso directamente.' end;
        insert into public.notificaciones_salida(tipo,jugador_id,destinatario_tipo,destinatario_persona_id,destinatario_email,asunto,cuerpo)
        values(v_type,rec.jugador_id,'tutor',rec.representante_persona_id,v_tutor_email,v_subject,v_body);
        v_count:=v_count+1;
      end if;
      if v_player_email is not null and not exists(select 1 from public.notificaciones_salida n where n.tipo=v_type and n.jugador_id=rec.jugador_id and n.destinatario_persona_id=rec.persona_id) then
        insert into public.notificaciones_salida(tipo,jugador_id,destinatario_tipo,destinatario_persona_id,destinatario_email,asunto,cuerpo)
        values(v_type,rec.jugador_id,'jugador',rec.persona_id,v_player_email,v_subject,
          'Estas proximo a cumplir 18 anos. Al alcanzar la mayoria de edad dejaras de estar representado de forma ordinaria por tu tutor en la plataforma del C.D. Los Yebenes San Bruno. Mantendremos tu misma Persona, historial deportivo, documentos y perfiles.');
        v_count:=v_count+1;
      end if;
    end if;
  end loop;
  return v_count;
end;
$$;


ALTER FUNCTION "public"."procesar_preparacion_mayoria_edad"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."programar_cita_rrmm"("p_jugador_id" "uuid", "p_fecha_hora" timestamp with time zone, "p_lugar" "text", "p_direccion" "text" DEFAULT NULL::"text", "p_indicaciones" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_persona_id uuid;
begin
  select j.persona_id into v_persona_id
    from public.jugadores j
   where j.id=p_jugador_id;
  if v_persona_id is null then raise exception 'Jugador no encontrado'; end if;
  return public.programar_cita_rrmm_persona(
    v_persona_id,p_fecha_hora,p_lugar,p_direccion,p_indicaciones
  );
end;
$$;


ALTER FUNCTION "public"."programar_cita_rrmm"("p_jugador_id" "uuid", "p_fecha_hora" timestamp with time zone, "p_lugar" "text", "p_direccion" "text", "p_indicaciones" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."programar_cita_rrmm_persona"("p_persona_id" "uuid", "p_fecha_hora" timestamp with time zone, "p_lugar" "text", "p_direccion" "text" DEFAULT NULL::"text", "p_indicaciones" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_cita_id uuid;
  v_jugador_id uuid;
  v_existing public.citas_reconocimiento_medico%rowtype;
  v_lugar text:=trim(coalesce(p_lugar,''));
  v_direccion text:=nullif(trim(coalesce(p_direccion,'')),'');
  v_indicaciones text:=nullif(trim(coalesce(p_indicaciones,'')),'');
  rec record;
begin
  if auth.uid() is null then raise exception 'Es necesario iniciar sesion'; end if;
  if not private.has_any_role(array['administrador','club']::text[]) then
    raise exception 'No autorizado para programar citas';
  end if;
  if p_fecha_hora is null or v_lugar='' then
    raise exception 'Fecha/hora y lugar son obligatorios';
  end if;
  if not exists(select 1 from public.personas p where p.id=p_persona_id) then
    raise exception 'Persona no encontrada';
  end if;

  select j.id into v_jugador_id
    from public.jugadores j
   where j.persona_id=p_persona_id and j.activo=true
   order by j.id
   limit 1;

  perform pg_advisory_xact_lock(hashtext('rrmm-person:'||p_persona_id::text));

  select * into v_existing
    from public.citas_reconocimiento_medico c
   where c.persona_id=p_persona_id
     and c.estado='programada'
   order by c.created_at desc
   limit 1;

  if found
     and v_existing.fecha_hora=p_fecha_hora
     and v_existing.lugar is not distinct from v_lugar
     and v_existing.direccion is not distinct from v_direccion
     and v_existing.indicaciones is not distinct from v_indicaciones then
    return v_existing.id;
  end if;

  for rec in
    select * from public.citas_reconocimiento_medico c
     where c.persona_id=p_persona_id and c.estado='programada'
  loop
    update public.citas_reconocimiento_medico
       set estado='cancelada',updated_at=now()
     where id=rec.id;

    update public.notificaciones_salida
       set estado='cancelado'
     where cita_id=rec.id and estado='pendiente';

    insert into public.historico_citas_rrmm(
      cita_id,accion,datos_anteriores,datos_nuevos,actor_auth_user_id
    ) values(
      rec.id,'cancelada_por_reprogramacion',to_jsonb(rec),
      jsonb_build_object('estado','cancelada'),auth.uid()
    );
  end loop;

  insert into public.citas_reconocimiento_medico(
    persona_id,jugador_id,fecha_hora,lugar,direccion,indicaciones,
    estado,comunicada_at,creado_por
  ) values(
    p_persona_id,v_jugador_id,p_fecha_hora,v_lugar,v_direccion,v_indicaciones,
    'programada',null,auth.uid()
  ) returning id into v_cita_id;

  insert into public.historico_citas_rrmm(
    cita_id,accion,datos_nuevos,actor_auth_user_id
  )
  select c.id,'creada',to_jsonb(c),auth.uid()
    from public.citas_reconocimiento_medico c
   where c.id=v_cita_id;

  perform private.encolar_notificaciones_cita(v_cita_id,'programada');
  return v_cita_id;
end;
$$;


ALTER FUNCTION "public"."programar_cita_rrmm_persona"("p_persona_id" "uuid", "p_fecha_hora" timestamp with time zone, "p_lugar" "text", "p_direccion" "text", "p_indicaciones" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."registrar_documento_federativo"("p_requisito_id" "uuid", "p_storage_path" "text", "p_nombre_original" "text", "p_mime_type" "text", "p_subtipo" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    v_req public.requisitos_federativos_inscripcion%rowtype;
    v_ins public.inscripciones%rowtype;
    v_cat_nombre text;
    v_doc_id uuid;
    v_estado_anterior text;
begin
    select * into v_req
    from public.requisitos_federativos_inscripcion r
    where r.id = p_requisito_id;

    if not found then raise exception 'Requisito no encontrado'; end if;

    if not (
        private.can_access_inscription_personal(v_req.inscripcion_id)
        or private.has_any_role(array['administrador','club']::text[])
    ) then
        raise exception 'No autorizado';
    end if;

    if not v_req.requiere_archivo then
        raise exception 'Este requisito no admite archivo';
    end if;

    -- Regla V35: la familia no puede sustituir unilateralmente un
    -- documento ya validado. Primero el club debe solicitar nueva version.
    if v_req.estado = 'validado' then
        raise exception 'El documento esta validado y bloqueado. El club debe solicitar una nueva version antes de poder sustituirlo';
    end if;

    select * into v_ins
    from public.inscripciones i
    where i.id = v_req.inscripcion_id;

    if split_part(p_storage_path,'/',1) <> v_req.inscripcion_id::text then
        raise exception 'Ruta de almacenamiento no valida';
    end if;

    if v_req.codigo = 'foto_jugador' then
        if coalesce(p_mime_type,'') not in ('image/jpeg','image/png','image/webp') then
            raise exception 'La fotografia debe ser JPG, PNG o WEBP';
        end if;
    end if;

    if v_req.codigo = 'identidad_rffm' then
        if p_subtipo not in ('dni','nie','pasaporte','partida_nacimiento','libro_familia') then
            raise exception 'Indica el tipo de documento de identificacion';
        end if;

        select c.nombre into v_cat_nombre
        from public.categorias c
        where c.id = v_ins.categoria_id;

        if p_subtipo in ('partida_nacimiento','libro_familia')
           and lower(coalesce(v_cat_nombre,'')) not in
              ('chupetin','prebenjamin','benjamin','alevin','infantil') then
            raise exception 'Partida de nacimiento o Libro de Familia solo se admite en categorias de base autorizadas';
        end if;
    end if;

    v_estado_anterior := v_req.estado;

    -- Solo al existir una nueva version real se sustituye el archivo anterior.
    update public.documentos_federativos d
       set estado = 'sustituido'
     where d.id = v_req.current_documento_id
       and d.estado <> 'sustituido';

    insert into public.documentos_federativos(
        requisito_id,inscripcion_id,jugador_id,storage_path,
        nombre_original,mime_type,subtipo,estado,aportado_por
    ) values (
        v_req.id,v_req.inscripcion_id,v_ins.jugador_id,p_storage_path,
        p_nombre_original,p_mime_type,p_subtipo,'aportado',auth.uid()
    ) returning id into v_doc_id;

    update public.requisitos_federativos_inscripcion
       set current_documento_id = v_doc_id,
           estado = 'aportado',
           motivo_rechazo = null,
           revisado_at = null,
           revisado_por = null,
           nueva_version_solicitada_at = null,
           nueva_version_solicitada_por = null,
           motivo_nueva_version = null,
           updated_at = now()
     where id = v_req.id;

    insert into public.historial_requisitos_federativos(
        requisito_id,inscripcion_id,estado_anterior,estado_nuevo,accion,motivo,actor_auth_user_id
    ) values (
        v_req.id,v_req.inscripcion_id,v_estado_anterior,'aportado',
        case when v_estado_anterior='rechazado' then 'documento_corregido_aportado'
             when v_estado_anterior='nueva_version_solicitada' then 'nueva_version_aportada'
             else 'documento_aportado' end,
        null,auth.uid()
    );

    return v_doc_id;
end;
$$;


ALTER FUNCTION "public"."registrar_documento_federativo"("p_requisito_id" "uuid", "p_storage_path" "text", "p_nombre_original" "text", "p_mime_type" "text", "p_subtipo" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."registrar_menor"("p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_tipo_documento" "text" DEFAULT NULL::"text", "p_numero_documento" "text" DEFAULT NULL::"text", "p_email_jugador" "text" DEFAULT NULL::"text") RETURNS TABLE("persona_id" "uuid", "jugador_id" "uuid", "inscripcion_id" "uuid", "categoria_id" "uuid")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_auth uuid:=auth.uid();
  v_tutor uuid;
  v_tutor_doc uuid;
  v_temp uuid;
  v_persona uuid;
  v_jugador uuid;
  v_rep uuid;
  v_ins uuid;
  v_cat uuid;
  v_doc uuid;
  v_doc_used uuid;
  v_doc_norm text;
  v_email text:=nullif(lower(trim(coalesce(p_email_jugador,''))),'');
  v_age integer;
begin
  if v_auth is null then raise exception 'Es necesario iniciar sesion'; end if;
  if not private.has_role('tutor') then raise exception 'Solo Tutor/Familia puede registrar menores'; end if;

  select p.id into v_tutor
  from public.personas p
  where p.auth_user_id=v_auth
  limit 1;
  if v_tutor is null then raise exception 'No existe Persona vinculada al tutor'; end if;

  if p_fecha_nacimiento is null or p_fecha_nacimiento <= (current_date - interval '18 years')::date then
    raise exception 'Este flujo solo permite menores de 18 anos';
  end if;
  v_age:=extract(year from age(current_date,p_fecha_nacimiento));

  if v_age>=16 and v_email is null then
    raise exception 'A partir de los 16 anos es obligatorio informar un correo propio del jugador';
  end if;

  if v_age>=14 then
    if nullif(trim(coalesce(p_numero_documento,'')),'') is null
       or p_tipo_documento not in ('dni','nie') then
      raise exception 'A partir de los 14 anos es obligatorio informar el DNI o NIE propio del jugador';
    end if;
  end if;
  if nullif(trim(coalesce(p_numero_documento,'')),'') is not null
     and p_tipo_documento in ('dni','nie')
     and not private.documento_espanol_valido(p_tipo_documento,p_numero_documento) then
    raise exception '% no valido: la letra no corresponde al numero', upper(p_tipo_documento);
  end if;

  if trim(coalesce(p_nombre,''))='' or trim(coalesce(p_primer_apellido,''))='' then
    raise exception 'Nombre y primer apellido son obligatorios';
  end if;

  select t.id into v_temp
  from public.temporadas t
  where t.estado='activa'
  order by t.fecha_inicio desc
  limit 1;
  if v_temp is null then raise exception 'No hay temporada activa'; end if;

  select d.id into v_tutor_doc
  from public.documentos_identidad d
  where d.persona_id=v_tutor
    and d.activo=true
    and d.es_principal=true
  order by d.created_at desc
  limit 1;
  if v_tutor_doc is null then raise exception 'El tutor necesita un documento de identidad principal'; end if;

  if v_email is not null and exists(
    select 1 from public.personas p
    where lower(trim(coalesce(p.email_contacto,'')))=v_email
  ) then
    raise exception 'Ya existe otra Persona con ese correo';
  end if;

  if nullif(trim(coalesce(p_numero_documento,'')),'') is not null then
    if p_tipo_documento not in ('dni','nie','pasaporte','otro') then
      raise exception 'Tipo de documento no valido';
    end if;
    v_doc_norm:=private.normalizar_documento(p_numero_documento);
    if exists(
      select 1 from public.documentos_identidad d
      where d.tipo=p_tipo_documento
        and private.normalizar_documento(d.numero)=v_doc_norm
    ) then
      raise exception 'Ese documento ya pertenece a otra Persona';
    end if;
  end if;

  if exists(
    select 1 from public.personas p
    where lower(p.nombre)=lower(trim(p_nombre))
      and lower(p.primer_apellido)=lower(trim(p_primer_apellido))
      and p.fecha_nacimiento=p_fecha_nacimiento
  ) then
    raise exception 'Posible duplicado: ya existe una Persona con el mismo nombre y fecha de nacimiento';
  end if;

  select r.categoria_id into v_cat
  from public.reglas_categoria_temporada r
  where r.temporada_id=v_temp
    and r.activo=true
    and extract(year from p_fecha_nacimiento)::int between r.anio_nacimiento_desde and r.anio_nacimiento_hasta
  order by r.anio_nacimiento_desde desc
  limit 1;
  if v_cat is null then raise exception 'La fecha de nacimiento no corresponde a una categoria configurada'; end if;

  insert into public.personas(nombre,primer_apellido,segundo_apellido,fecha_nacimiento,email_contacto,activo)
  values(trim(p_nombre),trim(p_primer_apellido),nullif(trim(coalesce(p_segundo_apellido,'')),''),p_fecha_nacimiento,v_email,true)
  returning id into v_persona;

  if v_doc_norm is not null then
    insert into public.documentos_identidad(persona_id,tipo,numero,es_principal,activo)
    values(v_persona,p_tipo_documento,v_doc_norm,true,true)
    returning id into v_doc;
  end if;

  insert into public.jugadores(persona_id,activo,fecha_alta)
  values(v_persona,true,current_date)
  returning id into v_jugador;

  insert into public.representaciones_jugador(jugador_id,representante_persona_id,fecha_desde,motivo_alta,creado_por)
  values(v_jugador,v_tutor,current_date,'Alta por tutor',v_auth)
  returning id into v_rep;

  v_doc_used:=coalesce(v_doc,v_tutor_doc);
  insert into public.inscripciones(jugador_id,temporada_id,categoria_id,estado,documento_identidad_usado_id,representacion_usada_id)
  values(v_jugador,v_temp,v_cat,'pendiente_revision_inicial',v_doc_used,v_rep)
  returning id into v_ins;

  insert into public.historico_estados_inscripcion(inscripcion_id,estado_anterior,estado_nuevo,comentario,cambiado_por)
  values(v_ins,null,'pendiente_revision_inicial','Inscripcion creada por tutor',v_auth);

  insert into public.auditoria(entidad,entidad_id,accion,actor_auth_user_id,datos_nuevos)
  values('jugador',v_jugador,'alta_menor',v_auth,
    jsonb_build_object('persona_id',v_persona,'inscripcion_id',v_ins,'temporada_id',v_temp,'email_jugador',v_email));

  return query select v_persona,v_jugador,v_ins,v_cat;
end;
$$;


ALTER FUNCTION "public"."registrar_menor"("p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_tipo_documento" "text", "p_numero_documento" "text", "p_email_jugador" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."registrar_mi_perfil"("p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_telefono" "text", "p_tipo_alta" "text", "p_tipo_documento" "text" DEFAULT NULL::"text", "p_numero_documento" "text" DEFAULT NULL::"text") RETURNS TABLE("out_persona_id" "uuid", "out_jugador_id" "uuid", "out_rol_codigo" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_auth_user_id uuid := auth.uid();
  v_email text;
  v_persona_id uuid;
  v_jugador_id uuid;
  v_rol_id uuid;
  v_doc_norm text;
  v_doc_owner uuid;
  v_count integer;
begin
  if v_auth_user_id is null then raise exception 'Es necesario iniciar sesion'; end if;
  select lower(trim(au.email)) into v_email from auth.users au where au.id=v_auth_user_id;
  if v_email is null then raise exception 'La cuenta no tiene correo electronico'; end if;
  if trim(coalesce(p_nombre,''))='' or trim(coalesce(p_primer_apellido,''))='' or p_fecha_nacimiento is null then
    raise exception 'Nombre, primer apellido y fecha de nacimiento son obligatorios';
  end if;
  if p_tipo_alta not in ('tutor','jugador') then raise exception 'Tipo de alta no valido'; end if;
  if p_fecha_nacimiento > (current_date - interval '18 years')::date then
    raise exception 'Esta modalidad de registro solo esta disponible para mayores de 18 anos';
  end if;
  if p_tipo_alta='tutor' then
    if trim(coalesce(p_numero_documento,''))='' or p_tipo_documento not in ('dni','nie') then
      raise exception 'El tutor debe identificarse mediante DNI o NIE';
    end if;
  end if;

  select p.id into v_persona_id from public.personas p where p.auth_user_id=v_auth_user_id limit 1;

  if v_persona_id is null then
    select count(*) into v_count from public.personas p where lower(trim(coalesce(p.email_contacto,'')))=v_email;
    if v_count>1 then
      raise exception 'Hay varias Personas con este correo. Contacta con el club para consolidar la identidad';
    elsif v_count=1 then
      select p.id into v_persona_id from public.personas p where lower(trim(coalesce(p.email_contacto,'')))=v_email limit 1;
      if exists(select 1 from public.personas p where p.id=v_persona_id and p.auth_user_id is not null and p.auth_user_id<>v_auth_user_id) then
        raise exception 'Este correo ya esta vinculado a otra cuenta. Inicia sesion con esa cuenta o contacta con el club';
      end if;
      update public.personas set auth_user_id=v_auth_user_id,activo=true,updated_at=now() where id=v_persona_id;
    else
      insert into public.personas(auth_user_id,nombre,primer_apellido,segundo_apellido,fecha_nacimiento,email_contacto,telefono,activo)
      values(v_auth_user_id,trim(p_nombre),trim(p_primer_apellido),nullif(trim(coalesce(p_segundo_apellido,'')),''),p_fecha_nacimiento,v_email,nullif(trim(coalesce(p_telefono,'')),''),true)
      returning id into v_persona_id;
    end if;
  end if;

  update public.personas p set
    nombre=trim(p_nombre),
    primer_apellido=trim(p_primer_apellido),
    segundo_apellido=nullif(trim(coalesce(p_segundo_apellido,'')),''),
    fecha_nacimiento=p_fecha_nacimiento,
    email_contacto=v_email,
    telefono=coalesce(nullif(trim(coalesce(p_telefono,'')),''),p.telefono),
    activo=true,
    updated_at=now()
  where p.id=v_persona_id;

  if trim(coalesce(p_numero_documento,''))<>'' then
    if p_tipo_documento not in ('dni','nie','pasaporte','otro') then raise exception 'Tipo de documento no valido'; end if;
    v_doc_norm:=private.normalizar_documento(p_numero_documento);
    select di.persona_id into v_doc_owner from public.documentos_identidad di
     where di.tipo=p_tipo_documento and private.normalizar_documento(di.numero)=v_doc_norm limit 1;
    if v_doc_owner is not null and v_doc_owner<>v_persona_id then
      raise exception 'El documento indicado ya pertenece a otra persona. Contacta con el club';
    end if;
    if not exists(select 1 from public.documentos_identidad di where di.persona_id=v_persona_id and di.tipo=p_tipo_documento and private.normalizar_documento(di.numero)=v_doc_norm) then
      update public.documentos_identidad set es_principal=false where persona_id=v_persona_id and activo=true and es_principal=true;
      insert into public.documentos_identidad(persona_id,tipo,numero,es_principal,activo)
      values(v_persona_id,p_tipo_documento,v_doc_norm,true,true);
    end if;
  end if;

  select id into v_rol_id from public.roles where codigo=p_tipo_alta limit 1;
  if v_rol_id is null then raise exception 'No existe el rol solicitado'; end if;

  if exists(select 1 from public.persona_roles where persona_id=v_persona_id and rol_id=v_rol_id) then
    update public.persona_roles set activo=true,fecha_desde=coalesce(fecha_desde,current_date),fecha_hasta=null,updated_at=now()
     where persona_id=v_persona_id and rol_id=v_rol_id;
  else
    insert into public.persona_roles(persona_id,rol_id,fecha_desde,activo)
    values(v_persona_id,v_rol_id,current_date,true);
  end if;

  if p_tipo_alta='jugador' then
    select id into v_jugador_id from public.jugadores where persona_id=v_persona_id limit 1;
    if v_jugador_id is null then
      insert into public.jugadores(persona_id,activo,fecha_alta) values(v_persona_id,true,current_date) returning id into v_jugador_id;
    else
      update public.jugadores set activo=true,fecha_baja=null,updated_at=now() where id=v_jugador_id;
    end if;
  end if;

  insert into public.auditoria(entidad,entidad_id,accion,actor_auth_user_id,datos_nuevos)
  values('persona',v_persona_id,'registro_perfil_'||p_tipo_alta,v_auth_user_id,jsonb_build_object('rol',p_tipo_alta));

  return query select v_persona_id,v_jugador_id,p_tipo_alta;
end;
$$;


ALTER FUNCTION "public"."registrar_mi_perfil"("p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_telefono" "text", "p_tipo_alta" "text", "p_tipo_documento" "text", "p_numero_documento" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."registrar_pago_inscripcion"("p_inscripcion_id" "uuid", "p_importe" numeric, "p_metodo" "text", "p_fecha_pago" "date" DEFAULT CURRENT_DATE, "p_referencia_externa" "text" DEFAULT NULL::"text", "p_clubber_pago_id" "text" DEFAULT NULL::"text", "p_observaciones" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    v_id uuid;
    v_sit public.situacion_economica_inscripcion%rowtype;
begin
    if not private.has_any_role(array['administrador','club']::text[]) then
        raise exception 'Solo Club/Administrador puede registrar pagos';
    end if;
    if p_importe is null or p_importe <= 0 then raise exception 'El importe debe ser mayor que cero'; end if;
    if p_metodo not in ('efectivo','clubber','otro') then raise exception 'Metodo de pago no valido'; end if;

    perform private.recalcular_situacion_economica(p_inscripcion_id);
    select * into v_sit from public.situacion_economica_inscripcion where inscripcion_id=p_inscripcion_id;
    if v_sit.configuracion_id is null then
        raise exception 'Configura primero el importe de inscripcion del equipo';
    end if;

    insert into public.pagos_inscripcion(
        inscripcion_id,importe,metodo,fecha_pago,referencia_externa,
        clubber_pago_id,observaciones,registrado_por
    ) values (
        p_inscripcion_id,p_importe,p_metodo,coalesce(p_fecha_pago,current_date),
        nullif(trim(coalesce(p_referencia_externa,'')),''),
        nullif(trim(coalesce(p_clubber_pago_id,'')),''),
        nullif(trim(coalesce(p_observaciones,'')),''),auth.uid()
    ) returning id into v_id;

    perform private.recalcular_situacion_economica(p_inscripcion_id);
    return v_id;
end;
$$;


ALTER FUNCTION "public"."registrar_pago_inscripcion"("p_inscripcion_id" "uuid", "p_importe" numeric, "p_metodo" "text", "p_fecha_pago" "date", "p_referencia_externa" "text", "p_clubber_pago_id" "text", "p_observaciones" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."registrar_telemetria_sesion"("p_device_id" "uuid", "p_event" "text", "p_app_version" "text", "p_auth_token_present" boolean, "p_visibility" "text" DEFAULT NULL::"text", "p_online" boolean DEFAULT NULL::boolean, "p_metadata" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare
  v_allowed constant text[] := array[
    'DIAGNOSTIC_BOOT_STORAGE',
    'AUTH_STATE_SIGNED_IN',
    'AUTH_STATE_TOKEN_REFRESHED',
    'AUTH_STATE_SIGNED_OUT',
    'SIGNOUT_REQUESTED',
    'SIGNOUT_COMPLETED',
    'SIGNOUT_THROWN',
    'PAGEHIDE',
    'VISIBILITY_HIDDEN',
    'AUTH_TOKEN_STORAGE_APPEARED',
    'AUTH_TOKEN_STORAGE_DISAPPEARED',
    'RESTORE_NO_SESSION',
    'LOGIN_SUCCESS'
  ];
  v_meta jsonb := coalesce(p_metadata,'{}'::jsonb);
begin
  if p_device_id is null then
    raise exception 'device_id obligatorio';
  end if;

  if p_event is null or not (p_event = any(v_allowed)) then
    raise exception 'evento no permitido';
  end if;

  if length(coalesce(p_app_version,'')) > 32 then
    raise exception 'version no valida';
  end if;

  if length(coalesce(p_visibility,'')) > 32 then
    raise exception 'visibility no valida';
  end if;

  if length(v_meta::text) > 2000 then
    raise exception 'metadata demasiado grande';
  end if;

  insert into public.telemetria_sesion_cliente(
    device_id,
    auth_user_id,
    evento,
    app_version,
    auth_token_present,
    visibility,
    online,
    metadata
  ) values (
    p_device_id,
    auth.uid(),
    p_event,
    coalesce(p_app_version,''),
    coalesce(p_auth_token_present,false),
    nullif(p_visibility,''),
    p_online,
    v_meta
  );

  -- Retencion diagnostica limitada.
  delete from public.telemetria_sesion_cliente
  where created_at < now() - interval '14 days';
end;
$$;


ALTER FUNCTION "public"."registrar_telemetria_sesion"("p_device_id" "uuid", "p_event" "text", "p_app_version" "text", "p_auth_token_present" boolean, "p_visibility" "text", "p_online" boolean, "p_metadata" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."responder_autorizacion_entrenador_menor"("p_autorizacion_id" "uuid", "p_aceptar" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare v_a public.autorizaciones_menor%rowtype; v_name text; v_email text;
begin
  if auth.uid() is null or not private.has_role('tutor') then raise exception 'Solo el tutor puede responder esta autorizacion'; end if;
  select * into v_a from public.autorizaciones_menor where id=p_autorizacion_id;
  if not found then raise exception 'Autorizacion no encontrada'; end if;
  if v_a.tutor_persona_id<>private.current_person_id() then raise exception 'No eres el tutor autorizado para responder'; end if;
  if v_a.estado<>'pendiente' then raise exception 'La autorizacion ya ha sido respondida'; end if;
  update public.autorizaciones_menor set estado=case when p_aceptar then 'aceptada' else 'rechazada' end,respondida_at=now(),fecha_desde=case when p_aceptar then current_date else null end,fecha_hasta=null,actualizado_por=auth.uid(),updated_at=now() where id=p_autorizacion_id;
  select concat_ws(' ',nombre,primer_apellido,segundo_apellido),email_contacto into v_name,v_email from public.personas where id=v_a.persona_menor_id;
  insert into public.auditoria(entidad,entidad_id,accion,actor_auth_user_id,datos_nuevos) values('autorizacion_menor',p_autorizacion_id,case when p_aceptar then 'autorizacion_entrenador_aceptada' else 'autorizacion_entrenador_rechazada' end,auth.uid(),jsonb_build_object('persona_menor_id',v_a.persona_menor_id));
end;
$$;


ALTER FUNCTION "public"."responder_autorizacion_entrenador_menor"("p_autorizacion_id" "uuid", "p_aceptar" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."responder_correcciones_jugador"("p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_telefono" "text" DEFAULT NULL::"text", "p_tipo_documento" "text" DEFAULT NULL::"text", "p_numero_documento" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_auth uuid:=auth.uid();
  v_persona uuid;
  v_jugador uuid;
  v_ins uuid;
  v_estado_antes text;
  v_estado_actual text;
  v_temporada uuid;
  v_nombre text;
begin
  if v_auth is null or not private.has_role('jugador') then
    raise exception 'Solo el perfil Jugador puede responder sus correcciones';
  end if;

  select p.id
  into v_persona
  from public.personas p
  where p.auth_user_id=v_auth and p.activo=true
  limit 1;

  select j.id
  into v_jugador
  from public.jugadores j
  where j.persona_id=v_persona and j.activo=true
  limit 1;

  select t.id
  into v_temporada
  from public.temporadas t
  where t.estado='activa'
  order by t.fecha_inicio desc
  limit 1;

  select i.id,i.estado
  into v_ins,v_estado_antes
  from public.inscripciones i
  where i.jugador_id=v_jugador
    and i.temporada_id=v_temporada
  limit 1;

  if v_ins is null then
    raise exception 'No existe una inscripcion activa';
  end if;
  if v_estado_antes <> 'devuelta_familia' then
    raise exception 'No hay una solicitud de correcciones activa';
  end if;

  perform public.actualizar_jugador_autorrepresentado(
    p_nombre,
    p_primer_apellido,
    p_segundo_apellido,
    p_fecha_nacimiento,
    p_telefono,
    p_tipo_documento,
    p_numero_documento
  );

  select i.estado into v_estado_actual
  from public.inscripciones i where i.id=v_ins;

  update public.inscripciones i
  set estado='pendiente_revision_inicial',
      observaciones='Correcciones respondidas por el jugador. Pendiente de revision por el club.',
      updated_at=now()
  where i.id=v_ins;

  insert into public.historico_estados_inscripcion(
    inscripcion_id,estado_anterior,estado_nuevo,comentario,cambiado_por
  ) values (
    v_ins,
    v_estado_actual,
    'pendiente_revision_inicial',
    'Correcciones respondidas por el jugador adulto',
    v_auth
  );

  select concat_ws(' ',p.nombre,p.primer_apellido,p.segundo_apellido)
  into v_nombre
  from public.personas p
  where p.id=v_persona;

  insert into public.notificaciones_salida(
    tipo,jugador_id,destinatario_tipo,destinatario_persona_id,
    destinatario_email,asunto,cuerpo
  )
  select distinct on (p.id)
    'correcciones_respondidas',
    v_jugador,
    case when r.codigo='administrador' then 'administrador' else 'club' end,
    p.id,
    p.email_contacto,
    'Correcciones respondidas - C.D. Los Yebenes San Bruno',
    v_nombre||' ha respondido la solicitud de correcciones. La ficha vuelve a estar pendiente de revision por el club.'
  from public.personas p
  join public.persona_roles pr on pr.persona_id=p.id and pr.activo=true
  join public.roles r on r.id=pr.rol_id and r.codigo in ('club','administrador')
  where p.activo=true
    and nullif(trim(coalesce(p.email_contacto,'')),'') is not null
    and (pr.fecha_desde is null or pr.fecha_desde<=current_date)
    and (pr.fecha_hasta is null or pr.fecha_hasta>=current_date)
  order by p.id, case when r.codigo='club' then 0 else 1 end;

  insert into public.auditoria(
    entidad,entidad_id,accion,actor_auth_user_id,datos_nuevos
  ) values (
    'inscripcion',v_ins,'correcciones_respondidas_jugador',v_auth,
    jsonb_build_object('jugador_id',v_jugador,'estado_anterior',v_estado_antes)
  );

  return v_jugador;
end;
$$;


ALTER FUNCTION "public"."responder_correcciones_jugador"("p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_telefono" "text", "p_tipo_documento" "text", "p_numero_documento" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."responder_correcciones_menor"("p_jugador_id" "uuid", "p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_tipo_documento" "text" DEFAULT NULL::"text", "p_numero_documento" "text" DEFAULT NULL::"text", "p_email_jugador" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_auth uuid:=auth.uid();
  v_tutor uuid;
  v_ins uuid;
  v_estado_antes text;
  v_estado_actual text;
  v_nombre text;
begin
  if v_auth is null or not private.has_role('tutor') then
    raise exception 'Solo Tutor/Familia puede responder correcciones';
  end if;

  select p.id into v_tutor
  from public.personas p
  where p.auth_user_id=v_auth and p.activo=true
  limit 1;

  if not exists(
    select 1
    from public.representaciones_jugador r
    where r.jugador_id=p_jugador_id
      and r.representante_persona_id=v_tutor
      and r.fecha_desde<=current_date
      and (r.fecha_hasta is null or r.fecha_hasta>=current_date)
  ) then
    raise exception 'No representas actualmente a este jugador';
  end if;

  select i.id,i.estado
  into v_ins,v_estado_antes
  from public.inscripciones i
  join public.temporadas t on t.id=i.temporada_id
  where i.jugador_id=p_jugador_id
    and t.estado='activa'
  limit 1;

  if v_ins is null then
    raise exception 'No existe una inscripcion activa';
  end if;
  if v_estado_antes <> 'devuelta_familia' then
    raise exception 'No hay una solicitud de correcciones activa';
  end if;

  perform public.actualizar_menor_representado(
    p_jugador_id,
    p_nombre,
    p_primer_apellido,
    p_segundo_apellido,
    p_fecha_nacimiento,
    p_tipo_documento,
    p_numero_documento,
    p_email_jugador
  );

  select i.estado into v_estado_actual
  from public.inscripciones i where i.id=v_ins;

  update public.inscripciones i
  set estado='pendiente_revision_inicial',
      observaciones='Correcciones respondidas por la familia. Pendiente de revision por el club.',
      updated_at=now()
  where i.id=v_ins;

  insert into public.historico_estados_inscripcion(
    inscripcion_id,estado_anterior,estado_nuevo,comentario,cambiado_por
  ) values (
    v_ins,
    v_estado_actual,
    'pendiente_revision_inicial',
    'Correcciones respondidas por la familia',
    v_auth
  );

  select concat_ws(' ',p.nombre,p.primer_apellido,p.segundo_apellido)
  into v_nombre
  from public.jugadores j
  join public.personas p on p.id=j.persona_id
  where j.id=p_jugador_id;

  insert into public.notificaciones_salida(
    tipo,jugador_id,destinatario_tipo,destinatario_persona_id,
    destinatario_email,asunto,cuerpo
  )
  select distinct on (p.id)
    'correcciones_respondidas',
    p_jugador_id,
    case when r.codigo='administrador' then 'administrador' else 'club' end,
    p.id,
    p.email_contacto,
    'Correcciones respondidas - C.D. Los Yebenes San Bruno',
    'La familia ha respondido la solicitud de correcciones de '||v_nombre||'. La ficha vuelve a estar pendiente de revision por el club.'
  from public.personas p
  join public.persona_roles pr on pr.persona_id=p.id and pr.activo=true
  join public.roles r on r.id=pr.rol_id and r.codigo in ('club','administrador')
  where p.activo=true
    and nullif(trim(coalesce(p.email_contacto,'')),'') is not null
    and (pr.fecha_desde is null or pr.fecha_desde<=current_date)
    and (pr.fecha_hasta is null or pr.fecha_hasta>=current_date)
  order by p.id, case when r.codigo='club' then 0 else 1 end;

  insert into public.auditoria(
    entidad,entidad_id,accion,actor_auth_user_id,datos_nuevos
  ) values (
    'inscripcion',v_ins,'correcciones_respondidas_familia',v_auth,
    jsonb_build_object('jugador_id',p_jugador_id,'estado_anterior',v_estado_antes)
  );

  return p_jugador_id;
end;
$$;


ALTER FUNCTION "public"."responder_correcciones_menor"("p_jugador_id" "uuid", "p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_tipo_documento" "text", "p_numero_documento" "text", "p_email_jugador" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."revisar_requisito_federativo"("p_requisito_id" "uuid", "p_estado" "text", "p_motivo" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare v_req public.requisitos_federativos_inscripcion%rowtype; v_doc_estado text;
begin
  if not private.has_any_role(array['administrador','club']::text[]) then raise exception 'Solo el club puede revisar documentacion federativa'; end if;
  if p_estado not in ('validado','rechazado','pendiente') then raise exception 'Estado de revision no valido'; end if;
  select * into v_req from public.requisitos_federativos_inscripcion where id=p_requisito_id;
  if not found then raise exception 'Requisito no encontrado'; end if;
  if v_req.estado='nueva_version_solicitada' then raise exception 'La nueva version aun no ha sido aportada por la familia'; end if;
  if v_req.requiere_archivo and p_estado='validado' then
    if v_req.current_documento_id is null then raise exception 'No se puede validar un requisito sin documento aportado'; end if;
    select estado into v_doc_estado from public.documentos_federativos where id=v_req.current_documento_id;
    if v_doc_estado<>'aportado' then raise exception 'Solo se puede validar la version actualmente pendiente de revision'; end if;
  end if;
  if not v_req.requiere_archivo and p_estado='validado' and v_req.estado<>'declarado_realizado' then raise exception 'El tutor/jugador debe comunicar primero que ha realizado este paso en RFFM'; end if;
  if not v_req.requiere_archivo and p_estado='rechazado' and v_req.estado not in ('declarado_realizado','validado') then raise exception 'Solo se puede rechazar un requisito comunicado o previamente validado'; end if;
  if p_estado='rechazado' and trim(coalesce(p_motivo,''))='' then raise exception 'Indica el motivo del rechazo'; end if;
  update public.requisitos_federativos_inscripcion set estado=p_estado,motivo_rechazo=case when p_estado='rechazado' then trim(p_motivo) else null end,revisado_at=now(),revisado_por=auth.uid(),nueva_version_solicitada_at=null,nueva_version_solicitada_por=null,motivo_nueva_version=null,updated_at=now() where id=p_requisito_id;
  if v_req.current_documento_id is not null then update public.documentos_federativos set estado=case when p_estado='validado' then 'validado' when p_estado='rechazado' then 'rechazado' else 'aportado' end,motivo_rechazo=case when p_estado='rechazado' then trim(p_motivo) else null end,revisado_at=now(),revisado_por=auth.uid() where id=v_req.current_documento_id; end if;
  insert into public.historial_requisitos_federativos(requisito_id,inscripcion_id,estado_anterior,estado_nuevo,accion,motivo,actor_auth_user_id)
  values(v_req.id,v_req.inscripcion_id,v_req.estado,p_estado,case when p_estado='validado' then 'requisito_validado' when p_estado='rechazado' then 'requisito_rechazado' else 'requisito_reabierto' end,case when p_estado='rechazado' then trim(p_motivo) else null end,auth.uid());
  perform private.recalcular_estado_inscripcion(v_req.inscripcion_id);
end; $$;


ALTER FUNCTION "public"."revisar_requisito_federativo"("p_requisito_id" "uuid", "p_estado" "text", "p_motivo" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."revocar_autorizacion_entrenador_menor"("p_autorizacion_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_a public.autorizaciones_menor%rowtype;
  v_entrenador_id uuid;
  v_asig public.asignaciones_entrenador_equipo%rowtype;
begin
  if auth.uid() is null or not private.has_role('tutor') then
    raise exception 'Solo el tutor puede revocar esta autorizacion';
  end if;

  select * into v_a
    from public.autorizaciones_menor
   where id=p_autorizacion_id
   for update;

  if not found then raise exception 'Autorizacion no encontrada'; end if;
  if v_a.tipo<>'entrenador_menor' then raise exception 'Tipo de autorizacion no valido'; end if;
  if v_a.tutor_persona_id<>private.current_person_id() then
    raise exception 'No eres el tutor autorizado para revocar esta autorizacion';
  end if;
  if v_a.estado<>'aceptada' then
    raise exception 'Solo puede revocarse una autorizacion vigente';
  end if;

  update public.autorizaciones_menor
     set estado='revocada',
         fecha_hasta=current_date,
         actualizado_por=auth.uid(),
         updated_at=now()
   where id=p_autorizacion_id;

  select id into v_entrenador_id
    from public.entrenadores
   where persona_id=v_a.persona_menor_id
   limit 1;

  if v_entrenador_id is not null then
    for v_asig in
      select *
        from public.asignaciones_entrenador_equipo
       where entrenador_id=v_entrenador_id
         and cancelada_at is null
         and (fecha_hasta is null or fecha_hasta>=current_date)
    loop
      insert into public.auditoria(
        entidad,entidad_id,accion,actor_auth_user_id,datos_nuevos
      ) values(
        'asignacion_entrenador_equipo',v_asig.id,
        'cancelada_por_revocacion_tutor',auth.uid(),
        to_jsonb(v_asig)
      );
    end loop;

    -- No se borra ninguna fila. La marca cancelada_at es la fuente de verdad
    -- para excluirla de la operativa, conservando fechas y equipo originales.
    update public.asignaciones_entrenador_equipo
       set cancelada_at=now(),
           motivo_fin='Revocacion de autorizacion del tutor',
           updated_at=now()
     where entrenador_id=v_entrenador_id
       and cancelada_at is null
       and (fecha_hasta is null or fecha_hasta>=current_date);
  end if;

  insert into public.auditoria(
    entidad,entidad_id,accion,actor_auth_user_id,datos_nuevos
  ) values(
    'autorizacion_menor',p_autorizacion_id,
    'autorizacion_entrenador_revocada',auth.uid(),
    jsonb_build_object(
      'persona_menor_id',v_a.persona_menor_id,
      'tutor_persona_id',v_a.tutor_persona_id,
      'fecha_revocacion',current_date
    )
  );
end;
$$;


ALTER FUNCTION "public"."revocar_autorizacion_entrenador_menor"("p_autorizacion_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rls_auto_enable"() RETURNS "event_trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."rls_auto_enable"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."solicitar_autorizacion_entrenador_menor"("p_persona_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_birth date; v_tutor uuid; v_id uuid; v_jugador uuid;
  v_name text; v_player_email text; v_tutor_email text; v_texto text; v_state text;
begin
  if auth.uid() is null or not private.has_any_role(array['administrador','club']::text[]) then
    raise exception 'No autorizado';
  end if;

  select fecha_nacimiento,email_contacto,concat_ws(' ',nombre,primer_apellido,segundo_apellido)
    into v_birth,v_player_email,v_name
    from public.personas where id=p_persona_id;
  if not found then raise exception 'Persona no encontrada'; end if;
  if v_birth is null then raise exception 'La Persona debe tener fecha de nacimiento'; end if;
  if v_birth <= (current_date - interval '18 years')::date then return null; end if;

  select id into v_jugador
    from public.jugadores
   where persona_id=p_persona_id and activo=true
   limit 1;
  if v_jugador is null then
    raise exception 'Un entrenador menor debe estar registrado tambien como jugador para disponer de representante legal';
  end if;

  select representante_persona_id into v_tutor
    from public.representaciones_jugador
   where jugador_id=v_jugador
     and fecha_desde<=current_date
     and (fecha_hasta is null or fecha_hasta>=current_date)
   order by fecha_desde desc
   limit 1;
  if v_tutor is null then raise exception 'El entrenador menor necesita un tutor/representante activo'; end if;

  select id,estado into v_id,v_state
    from public.autorizaciones_menor
   where persona_menor_id=p_persona_id
     and tipo='entrenador_menor'
     and estado in ('pendiente_email','pendiente','aceptada')
   limit 1;

  select email_contacto into v_tutor_email from public.personas where id=v_tutor;
  v_player_email:=nullif(lower(trim(coalesce(v_player_email,''))),'');

  if v_id is not null then
    update public.autorizaciones_menor
       set tutor_persona_id=v_tutor,updated_at=now(),actualizado_por=auth.uid()
     where id=v_id;

    -- Si estaba esperando email y ya existe, activa la solicitud real.
    if v_state='pendiente_email' and v_player_email is not null then
      update public.autorizaciones_menor
         set estado='pendiente',solicitada_at=now(),updated_at=now(),actualizado_por=auth.uid()
       where id=v_id;
      if nullif(trim(coalesce(v_tutor_email,'')),'') is not null then
        insert into public.notificaciones_salida(
          tipo,destinatario_tipo,destinatario_persona_id,destinatario_email,asunto,cuerpo
        ) values(
          'autorizacion_entrenador_menor','tutor',v_tutor,v_tutor_email,
          'Autorizacion necesaria para entrenador menor - C.D. Los Yebenes San Bruno',
          'El club solicita tu autorizacion para que '||v_name||' pueda desempenar funciones de entrenador siendo menor de edad. Accede a la plataforma con tu perfil Tutor/Familia para aceptar o rechazar la autorizacion.'
        );
      end if;
    end if;
    return v_id;
  end if;

  v_texto := 'Autorizo a '||v_name||' a desempenar funciones de entrenador en el C.D. Los Yebenes San Bruno mientras sea menor de edad. Esta autorizacion es independiente de la representacion del menor como jugador.';

  insert into public.autorizaciones_menor(
    persona_menor_id,tutor_persona_id,tipo,estado,version_texto,
    creado_por,actualizado_por,motivo
  ) values(
    p_persona_id,v_tutor,'entrenador_menor',
    case when v_player_email is null then 'pendiente_email' else 'pendiente' end,
    'v3',auth.uid(),auth.uid(),v_texto
  ) returning id into v_id;

  if nullif(trim(coalesce(v_tutor_email,'')),'') is not null then
    if v_player_email is null then
      insert into public.notificaciones_salida(
        tipo,destinatario_tipo,destinatario_persona_id,destinatario_email,asunto,cuerpo
      ) values(
        'email_entrenador_menor_requerido','tutor',v_tutor,v_tutor_email,
        'Correo propio necesario para entrenador menor - C.D. Los Yebenes San Bruno',
        'Para continuar con la autorizacion de '||v_name||' como entrenador menor necesitamos un correo propio del jugador. Accede a su ficha en Familia > Datos e informa el correo. Despues se activara la solicitud de autorizacion.'
      );
    else
      insert into public.notificaciones_salida(
        tipo,destinatario_tipo,destinatario_persona_id,destinatario_email,asunto,cuerpo
      ) values(
        'autorizacion_entrenador_menor','tutor',v_tutor,v_tutor_email,
        'Autorizacion necesaria para entrenador menor - C.D. Los Yebenes San Bruno',
        'El club solicita tu autorizacion para que '||v_name||' pueda desempenar funciones de entrenador siendo menor de edad. Accede a la plataforma con tu perfil Tutor/Familia para aceptar o rechazar la autorizacion.'
      );
    end if;
  end if;
  return v_id;
end;
$$;


ALTER FUNCTION "public"."solicitar_autorizacion_entrenador_menor"("p_persona_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."solicitar_correcciones_inscripcion"("p_inscripcion_id" "uuid", "p_mensaje" "text") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_auth uuid:=auth.uid();
  v_old text;
  v_old_observaciones text;
  v_jugador uuid;
  v_persona uuid;
  v_birth date;
  v_player_name text;
  v_player_email text;
  v_tutor uuid;
  v_tutor_email text;
  v_dest_tipo text;
  v_dest_persona uuid;
  v_dest_email text;
  v_comment text;
begin
  if v_auth is null
     or not private.has_any_role(array['administrador','club']::text[]) then
    raise exception 'No autorizado';
  end if;

  if nullif(trim(coalesce(p_mensaje,'')),'') is null then
    raise exception 'Indica que informacion debe corregirse';
  end if;

  select
    i.estado,
    i.observaciones,
    i.jugador_id,
    j.persona_id,
    p.fecha_nacimiento,
    concat_ws(' ',p.nombre,p.primer_apellido,p.segundo_apellido),
    p.email_contacto
  into
    v_old,
    v_old_observaciones,
    v_jugador,
    v_persona,
    v_birth,
    v_player_name,
    v_player_email
  from public.inscripciones i
  join public.jugadores j on j.id=i.jugador_id
  join public.personas p on p.id=j.persona_id
  where i.id=p_inscripcion_id;

  if v_jugador is null then
    raise exception 'Inscripcion no encontrada';
  end if;

  select r.representante_persona_id, p.email_contacto
  into v_tutor, v_tutor_email
  from public.representaciones_jugador r
  join public.personas p on p.id=r.representante_persona_id
  where r.jugador_id=v_jugador
    and r.fecha_desde<=current_date
    and (r.fecha_hasta is null or r.fecha_hasta>=current_date)
  order by r.fecha_desde desc
  limit 1;

  if v_tutor is not null then
    v_dest_tipo:='tutor';
    v_dest_persona:=v_tutor;
    v_dest_email:=nullif(lower(trim(coalesce(v_tutor_email,''))),'');
    v_comment:='Correcciones solicitadas a la familia: '||trim(p_mensaje);
  elsif v_birth is not null
        and v_birth <= (current_date - interval '18 years')::date then
    v_dest_tipo:='jugador';
    v_dest_persona:=v_persona;
    v_dest_email:=nullif(lower(trim(coalesce(v_player_email,''))),'');
    v_comment:='Correcciones solicitadas al jugador adulto: '||trim(p_mensaje);
  else
    raise exception 'El jugador no tiene tutor activo ni puede autorrepresentarse';
  end if;

  -- Idempotencia V82: si la misma ficha ya está devuelta con el
  -- mismo mensaje, la petición repetida se considera atendida y
  -- no genera otro histórico ni otro correo.
  if v_old='devuelta_familia'
     and trim(coalesce(v_old_observaciones,''))=trim(p_mensaje) then
    return v_dest_tipo;
  end if;

  update public.inscripciones i
  set
    estado='devuelta_familia',
    observaciones=trim(p_mensaje),
    updated_at=now()
  where i.id=p_inscripcion_id;

  insert into public.historico_estados_inscripcion(
    inscripcion_id,
    estado_anterior,
    estado_nuevo,
    comentario,
    cambiado_por
  ) values (
    p_inscripcion_id,
    v_old,
    'devuelta_familia',
    v_comment,
    v_auth
  );

  if v_dest_email is not null then
    insert into public.notificaciones_salida(
      tipo,
      jugador_id,
      destinatario_tipo,
      destinatario_persona_id,
      destinatario_email,
      asunto,
      cuerpo
    ) values (
      'correcciones_inscripcion',
      v_jugador,
      v_dest_tipo,
      v_dest_persona,
      v_dest_email,
      'Correcciones necesarias en la ficha - C.D. Los Yebenes San Bruno',
      'El club solicita revisar la ficha de '||v_player_name||'. '||
      'Indicaciones: '||trim(p_mensaje)||
      '. Accede a la plataforma para revisar y corregir la informacion.'
    );
  end if;

  insert into public.auditoria(
    entidad,
    entidad_id,
    accion,
    actor_auth_user_id,
    datos_nuevos
  ) values (
    'inscripcion',
    p_inscripcion_id,
    'solicitud_correcciones',
    v_auth,
    jsonb_build_object(
      'jugador_id',v_jugador,
      'destinatario_tipo',v_dest_tipo,
      'destinatario_persona_id',v_dest_persona,
      'mensaje',trim(p_mensaje)
    )
  );

  return v_dest_tipo;
end;
$$;


ALTER FUNCTION "public"."solicitar_correcciones_inscripcion"("p_inscripcion_id" "uuid", "p_mensaje" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."solicitar_nueva_version_requisito"("p_requisito_id" "uuid", "p_motivo" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    v_req public.requisitos_federativos_inscripcion%rowtype;
begin
    if not private.has_any_role(array['administrador','club']::text[]) then
        raise exception 'Solo el club puede solicitar una nueva version';
    end if;

    if trim(coalesce(p_motivo,'')) = '' then
        raise exception 'Indica el motivo de la solicitud de nueva version';
    end if;

    select * into v_req
    from public.requisitos_federativos_inscripcion r
    where r.id = p_requisito_id;

    if not found then raise exception 'Requisito no encontrado'; end if;
    if not v_req.requiere_archivo then raise exception 'Este requisito no utiliza archivo'; end if;
    if v_req.estado <> 'validado' then raise exception 'Solo se puede solicitar nueva version de un documento validado'; end if;
    if v_req.current_documento_id is null then raise exception 'No existe documento validado que sustituir'; end if;

    update public.requisitos_federativos_inscripcion
       set estado = 'nueva_version_solicitada',
           nueva_version_solicitada_at = now(),
           nueva_version_solicitada_por = auth.uid(),
           motivo_nueva_version = trim(p_motivo),
           motivo_rechazo = null,
           updated_at = now()
     where id = p_requisito_id;

    -- El documento anterior sigue siendo la ultima version validada
    -- hasta que la familia aporte efectivamente el nuevo archivo.
    insert into public.historial_requisitos_federativos(
        requisito_id,inscripcion_id,estado_anterior,estado_nuevo,accion,motivo,actor_auth_user_id
    ) values (
        v_req.id,v_req.inscripcion_id,'validado','nueva_version_solicitada',
        'nueva_version_solicitada',trim(p_motivo),auth.uid()
    );
end;
$$;


ALTER FUNCTION "public"."solicitar_nueva_version_requisito"("p_requisito_id" "uuid", "p_motivo" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_inicializar_requisitos_federativos"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
    perform public.inicializar_requisitos_federativos(new.id);
    return new;
end;
$$;


ALTER FUNCTION "public"."trg_inicializar_requisitos_federativos"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validar_fraccionamiento_clubber"("p_inscripcion_id" "uuid", "p_validado" boolean, "p_observaciones" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    v_sit public.situacion_economica_inscripcion%rowtype;
    v_cfg public.configuracion_economica_equipo%rowtype;
begin
    if not private.has_any_role(array['administrador','club']::text[]) then
        raise exception 'Solo Club/Administrador puede validar fraccionamientos';
    end if;

    perform private.recalcular_situacion_economica(p_inscripcion_id);
    select * into v_sit from public.situacion_economica_inscripcion where inscripcion_id=p_inscripcion_id;
    if not found or v_sit.configuracion_id is null then
        raise exception 'Configura primero la economia del equipo';
    end if;
    select * into v_cfg from public.configuracion_economica_equipo where id=v_sit.configuracion_id;
    if p_validado and not v_cfg.admite_fraccionamiento then
        raise exception 'Este equipo no admite fraccionamiento';
    end if;

    update public.situacion_economica_inscripcion
       set fraccionamiento_clubber_validado=coalesce(p_validado,false),
           fecha_validacion_fraccionamiento=case when p_validado then now() else null end,
           validado_fraccionamiento_por=case when p_validado then auth.uid() else null end,
           origen_validacion_fraccionamiento=case when p_validado then 'manual_club' else null end,
           updated_at=now()
     where inscripcion_id=p_inscripcion_id;

    insert into public.auditoria(entidad,entidad_id,accion,actor_auth_user_id,datos_nuevos)
    values ('inscripcion',p_inscripcion_id,
            case when p_validado then 'fraccionamiento_clubber_validado' else 'fraccionamiento_clubber_revocado' end,
            auth.uid(),jsonb_build_object('observaciones',nullif(trim(coalesce(p_observaciones,'')),'')));

    perform private.recalcular_situacion_economica(p_inscripcion_id);
end;
$$;


ALTER FUNCTION "public"."validar_fraccionamiento_clubber"("p_inscripcion_id" "uuid", "p_validado" boolean, "p_observaciones" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validar_tutor_menor_inscripcion"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare

  v_fecha_nacimiento date;
  v_fecha_18 date;
  v_representacion uuid;

begin

  select p.fecha_nacimiento

  into v_fecha_nacimiento

  from public.jugadores j

  join public.personas p
    on p.id = j.persona_id

  where j.id = new.jugador_id;

  if v_fecha_nacimiento is null then

    raise exception
    'El jugador debe tener fecha de nacimiento';

  end if;

  v_fecha_18 :=
    (v_fecha_nacimiento + interval '18 years')::date;

  if new.fecha_solicitud < v_fecha_18 then

    select id

    into v_representacion

    from public.representaciones_jugador

    where jugador_id = new.jugador_id

      and fecha_desde <= new.fecha_solicitud

      and (
        fecha_hasta is null
        or fecha_hasta >= new.fecha_solicitud
      )

    order by fecha_desde desc

    limit 1;

    if v_representacion is null then

      raise exception
      'Un menor necesita un representante legal activo';

    end if;

    if new.representacion_usada_id is null then

      new.representacion_usada_id :=
        v_representacion;

    end if;

  end if;

  return new;

end;
$$;


ALTER FUNCTION "public"."validar_tutor_menor_inscripcion"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."vincular_auth_persona_por_email_admin"("p_persona_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_email text;
  v_auth uuid;
begin
  if auth.uid() is null or not private.has_role('administrador') then
    raise exception 'Solo un administrador puede vincular cuentas';
  end if;
  select lower(nullif(trim(email_contacto),'')) into v_email from public.personas where id=p_persona_id;
  if v_email is null then raise exception 'La Persona no tiene correo de contacto'; end if;
  select u.id into v_auth from auth.users u where lower(u.email)=v_email limit 1;
  if v_auth is null then raise exception 'No existe todavía una cuenta Auth con ese correo'; end if;
  if exists(select 1 from public.personas p where p.auth_user_id=v_auth and p.id<>p_persona_id) then
    raise exception 'Esa cuenta Auth ya está vinculada a otra Persona';
  end if;
  update public.personas set auth_user_id=v_auth, updated_at=now() where id=p_persona_id;
  return v_auth;
end;
$$;


ALTER FUNCTION "public"."vincular_auth_persona_por_email_admin"("p_persona_id" "uuid") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."asignaciones_entrenador_equipo" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "entrenador_id" "uuid" NOT NULL,
    "equipo_id" "uuid" NOT NULL,
    "rol" "text" NOT NULL,
    "fecha_desde" "date" DEFAULT CURRENT_DATE NOT NULL,
    "fecha_hasta" "date",
    "motivo_fin" "text",
    "asignado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "funcion" "text" DEFAULT 'first'::"text" NOT NULL,
    "cancelada_at" timestamp with time zone,
    CONSTRAINT "asignaciones_entrenador_equipo_check" CHECK ((("fecha_hasta" IS NULL) OR ("fecha_hasta" >= "fecha_desde"))),
    CONSTRAINT "asignaciones_entrenador_equipo_funcion_check" CHECK (("funcion" = ANY (ARRAY['first'::"text", 'second'::"text", 'goalkeeper'::"text", 'fitness'::"text"])))
);


ALTER TABLE "public"."asignaciones_entrenador_equipo" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."asignaciones_jugador_equipo" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "inscripcion_id" "uuid" NOT NULL,
    "equipo_id" "uuid" NOT NULL,
    "fecha_desde" "date" DEFAULT CURRENT_DATE NOT NULL,
    "fecha_hasta" "date",
    "motivo_cambio" "text",
    "asignado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "asignaciones_jugador_equipo_check" CHECK ((("fecha_hasta" IS NULL) OR ("fecha_hasta" >= "fecha_desde")))
);


ALTER TABLE "public"."asignaciones_jugador_equipo" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."auditoria" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "entidad" "text" NOT NULL,
    "entidad_id" "uuid",
    "accion" "text" NOT NULL,
    "actor_auth_user_id" "uuid",
    "datos_anteriores" "jsonb",
    "datos_nuevos" "jsonb",
    "metadata" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."auditoria" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."autorizaciones_menor" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "persona_menor_id" "uuid" NOT NULL,
    "tutor_persona_id" "uuid" NOT NULL,
    "tipo" "text" NOT NULL,
    "estado" "text" DEFAULT 'pendiente'::"text" NOT NULL,
    "version_texto" "text" DEFAULT 'v1'::"text" NOT NULL,
    "solicitada_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "respondida_at" timestamp with time zone,
    "fecha_desde" "date",
    "fecha_hasta" "date",
    "creado_por" "uuid",
    "actualizado_por" "uuid",
    "motivo" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "autorizaciones_menor_check" CHECK ((("fecha_hasta" IS NULL) OR ("fecha_desde" IS NULL) OR ("fecha_hasta" >= "fecha_desde"))),
    CONSTRAINT "autorizaciones_menor_estado_check" CHECK (("estado" = ANY (ARRAY['pendiente_email'::"text", 'pendiente'::"text", 'aceptada'::"text", 'rechazada'::"text", 'revocada'::"text", 'finalizada_mayoria_edad'::"text"]))),
    CONSTRAINT "autorizaciones_menor_tipo_check" CHECK (("tipo" = 'entrenador_menor'::"text"))
);


ALTER TABLE "public"."autorizaciones_menor" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."categorias" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "codigo" "text" NOT NULL,
    "nombre" "text" NOT NULL,
    "orden" smallint NOT NULL,
    "modalidad" "text",
    "genero" "text",
    "activo" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "categorias_genero_check" CHECK ((("genero" = ANY (ARRAY['masculino'::"text", 'femenino'::"text", 'mixto'::"text"])) OR ("genero" IS NULL)))
);


ALTER TABLE "public"."categorias" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."citas_reconocimiento_medico" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "jugador_id" "uuid",
    "fecha_hora" timestamp with time zone NOT NULL,
    "lugar" "text" NOT NULL,
    "direccion" "text",
    "indicaciones" "text",
    "estado" "text" DEFAULT 'programada'::"text" NOT NULL,
    "comunicada_at" timestamp with time zone,
    "recordatorio_enviado_at" timestamp with time zone,
    "reconocimiento_medico_id" "uuid",
    "creado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "persona_id" "uuid",
    CONSTRAINT "citas_reconocimiento_medico_estado_check" CHECK (("estado" = ANY (ARRAY['programada'::"text", 'realizada'::"text", 'cancelada'::"text", 'no_asiste'::"text"]))),
    CONSTRAINT "citas_rrmm_persona_requerida_check" CHECK ((("persona_id" IS NOT NULL) OR ("jugador_id" IS NOT NULL)))
);


ALTER TABLE "public"."citas_reconocimiento_medico" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."configuracion_economica_equipo" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "temporada_id" "uuid" NOT NULL,
    "equipo_id" "uuid" NOT NULL,
    "importe_inscripcion" numeric(10,2),
    "admite_fraccionamiento" boolean DEFAULT true NOT NULL,
    "requiere_pago_ficha" boolean DEFAULT true NOT NULL,
    "observaciones" "text",
    "creado_por" "uuid",
    "actualizado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "configuracion_economica_equipo_importe_inscripcion_check" CHECK ((("importe_inscripcion" IS NULL) OR ("importe_inscripcion" >= (0)::numeric)))
);


ALTER TABLE "public"."configuracion_economica_equipo" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."configuracion_visual_club" (
    "id" smallint DEFAULT 1 NOT NULL,
    "nombre_club" "text" NOT NULL,
    "logo_url" "text" NOT NULL,
    "color_primario" "text" NOT NULL,
    "color_primario_oscuro" "text" NOT NULL,
    "color_acento" "text" NOT NULL,
    "color_fondo" "text" NOT NULL,
    "color_tarjeta" "text" NOT NULL,
    "color_texto" "text" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "configuracion_visual_club_id_check" CHECK (("id" = 1))
);


ALTER TABLE "public"."configuracion_visual_club" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."documentos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "persona_id" "uuid",
    "jugador_id" "uuid",
    "inscripcion_id" "uuid",
    "reconocimiento_medico_id" "uuid",
    "tipo" "text" NOT NULL,
    "nombre_original" "text",
    "storage_bucket" "text",
    "storage_path" "text",
    "estado" "text" DEFAULT 'pendiente'::"text" NOT NULL,
    "fecha_subida" timestamp with time zone,
    "fecha_revision" timestamp with time zone,
    "revisado_por" "uuid",
    "motivo_rechazo" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "documentos_check" CHECK (("num_nonnulls"("persona_id", "jugador_id", "inscripcion_id", "reconocimiento_medico_id") = 1)),
    CONSTRAINT "documentos_estado_check" CHECK (("estado" = ANY (ARRAY['pendiente'::"text", 'subido'::"text", 'en_revision'::"text", 'aceptado'::"text", 'rechazado'::"text", 'caducado'::"text"])))
);


ALTER TABLE "public"."documentos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."documentos_federativos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "requisito_id" "uuid" NOT NULL,
    "inscripcion_id" "uuid" NOT NULL,
    "jugador_id" "uuid" NOT NULL,
    "storage_path" "text" NOT NULL,
    "nombre_original" "text" NOT NULL,
    "mime_type" "text",
    "subtipo" "text",
    "estado" "text" DEFAULT 'aportado'::"text" NOT NULL,
    "motivo_rechazo" "text",
    "aportado_por" "uuid",
    "aportado_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "revisado_por" "uuid",
    "revisado_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "documentos_federativos_estado_check" CHECK (("estado" = ANY (ARRAY['aportado'::"text", 'validado'::"text", 'rechazado'::"text", 'sustituido'::"text"])))
);


ALTER TABLE "public"."documentos_federativos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."documentos_identidad" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "persona_id" "uuid" NOT NULL,
    "tipo" "text" NOT NULL,
    "numero" "text" NOT NULL,
    "pais_emisor" "text" DEFAULT 'ES'::"text",
    "es_principal" boolean DEFAULT true NOT NULL,
    "fecha_desde" "date",
    "fecha_hasta" "date",
    "activo" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "documentos_identidad_check" CHECK ((("fecha_hasta" IS NULL) OR ("fecha_desde" IS NULL) OR ("fecha_hasta" >= "fecha_desde"))),
    CONSTRAINT "documentos_identidad_tipo_check" CHECK (("tipo" = ANY (ARRAY['dni'::"text", 'nie'::"text", 'pasaporte'::"text", 'otro'::"text"])))
);


ALTER TABLE "public"."documentos_identidad" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."entrenador_disponibilidad" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "entrenador_id" "uuid" NOT NULL,
    "temporada_id" "uuid" NOT NULL,
    "dia_semana" smallint NOT NULL,
    "tipo" "text" NOT NULL,
    "hora_desde" time without time zone,
    "hora_hasta" time without time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "entrenador_disponibilidad_dia_semana_check" CHECK ((("dia_semana" >= 1) AND ("dia_semana" <= 7))),
    CONSTRAINT "entrenador_disponibilidad_tipo_check" CHECK (("tipo" = ANY (ARRAY['no_disponible'::"text", 'todo_dia'::"text", 'desde'::"text", 'franja'::"text"]))),
    CONSTRAINT "entrenador_disponibilidad_v90_check" CHECK (((("tipo" = ANY (ARRAY['no_disponible'::"text", 'todo_dia'::"text"])) AND ("hora_desde" IS NULL) AND ("hora_hasta" IS NULL)) OR (("tipo" = 'desde'::"text") AND ("hora_desde" IS NOT NULL) AND ("hora_hasta" IS NULL) AND ("hora_desde" >=
CASE
    WHEN (("dia_semana" >= 1) AND ("dia_semana" <= 5)) THEN '16:00:00'::time without time zone
    ELSE '08:00:00'::time without time zone
END)) OR (("tipo" = 'franja'::"text") AND ("hora_desde" IS NOT NULL) AND ("hora_hasta" IS NOT NULL) AND ("hora_desde" >=
CASE
    WHEN (("dia_semana" >= 1) AND ("dia_semana" <= 5)) THEN '16:00:00'::time without time zone
    ELSE '08:00:00'::time without time zone
END) AND (("hora_hasta" = '00:00:00'::time without time zone) OR ("hora_hasta" > "hora_desde")))))
);


ALTER TABLE "public"."entrenador_disponibilidad" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."entrenador_formaciones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "entrenador_id" "uuid" NOT NULL,
    "tipo" "text" NOT NULL,
    "nombre_otro" "text",
    "estado" "text" DEFAULT 'en_curso'::"text" NOT NULL,
    "fecha_inicio" "date",
    "fecha_obtencion" "date",
    "entidad_emisora" "text",
    "numero_acreditacion" "text",
    "fecha_caducidad" "date",
    "documento_path" "text",
    "observaciones" "text",
    "verificacion_estado" "text" DEFAULT 'pendiente'::"text" NOT NULL,
    "verificado_por" "uuid",
    "verificado_at" timestamp with time zone,
    "creado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "entrenador_formaciones_estado_check" CHECK (("estado" = ANY (ARRAY['en_curso'::"text", 'vigente'::"text", 'caducada'::"text", 'abandonada'::"text"]))),
    CONSTRAINT "entrenador_formaciones_tipo_check" CHECK (("tipo" = ANY (ARRAY['delegado'::"text", 'uefa_c'::"text", 'uefa_b'::"text", 'uefa_a'::"text", 'uefa_pro'::"text", 'tecnico_deportivo'::"text", 'tecnico_deportivo_superior'::"text", 'otra'::"text"]))),
    CONSTRAINT "entrenador_formaciones_verificacion_estado_check" CHECK (("verificacion_estado" = ANY (ARRAY['pendiente'::"text", 'verificada'::"text", 'rechazada'::"text"])))
);


ALTER TABLE "public"."entrenador_formaciones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."entrenador_licencia_equipos" (
    "licencia_id" "uuid" NOT NULL,
    "equipo_id" "uuid" NOT NULL
);


ALTER TABLE "public"."entrenador_licencia_equipos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."entrenador_licencias_rffm" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "entrenador_id" "uuid" NOT NULL,
    "temporada_id" "uuid" NOT NULL,
    "tipo" "text" NOT NULL,
    "nombre_otro" "text",
    "numero" "text",
    "fecha_expedicion" "date",
    "fecha_caducidad" "date",
    "estado_excepcional" "text",
    "documento_path" "text",
    "observaciones" "text",
    "verificacion_estado" "text" DEFAULT 'pendiente'::"text" NOT NULL,
    "verificado_por" "uuid",
    "verificado_at" timestamp with time zone,
    "creado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "entrenador_licencias_rffm_estado_excepcional_check" CHECK ((("estado_excepcional" IS NULL) OR ("estado_excepcional" = ANY (ARRAY['revocada'::"text", 'anulada'::"text"])))),
    CONSTRAINT "entrenador_licencias_rffm_tipo_check" CHECK (("tipo" = ANY (ARRAY['D'::"text", 'ET'::"text", 'EA'::"text", 'EPR'::"text", 'CTC'::"text", 'EP'::"text", 'PF'::"text", 'OTRA'::"text"]))),
    CONSTRAINT "entrenador_licencias_rffm_verificacion_estado_check" CHECK (("verificacion_estado" = ANY (ARRAY['pendiente'::"text", 'verificada'::"text", 'rechazada'::"text"])))
);


ALTER TABLE "public"."entrenador_licencias_rffm" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."entrenador_privacidad" (
    "entrenador_id" "uuid" NOT NULL,
    "compartir_email" boolean DEFAULT false NOT NULL,
    "compartir_telefono" boolean DEFAULT false NOT NULL,
    "compartir_foto" boolean DEFAULT false NOT NULL,
    "decidido_por" "uuid",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."entrenador_privacidad" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."entrenador_temporadas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "entrenador_id" "uuid" NOT NULL,
    "temporada_id" "uuid" NOT NULL,
    "estado" "text" DEFAULT 'sin_asignacion'::"text" NOT NULL,
    "disponibilidad_confirmada_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "entrenador_temporadas_estado_check" CHECK (("estado" = ANY (ARRAY['activo'::"text", 'sin_asignacion'::"text", 'baja'::"text"])))
);


ALTER TABLE "public"."entrenador_temporadas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."entrenadores" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "persona_id" "uuid" NOT NULL,
    "tiene_licencia" boolean DEFAULT false NOT NULL,
    "tipo_licencia" "text",
    "numero_licencia" "text",
    "curso_delegado" boolean DEFAULT false NOT NULL,
    "activo" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "licencia_tipo" "text",
    "licencia_numero" "text",
    "observaciones" "text"
);


ALTER TABLE "public"."entrenadores" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."equipos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "temporada_id" "uuid" NOT NULL,
    "categoria_id" "uuid" NOT NULL,
    "nombre" "text" NOT NULL,
    "codigo" "text",
    "genero" "text",
    "activo" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "modalidad" "text",
    CONSTRAINT "equipos_genero_check" CHECK ((("genero" = ANY (ARRAY['masculino'::"text", 'femenino'::"text", 'mixto'::"text"])) OR ("genero" IS NULL))),
    CONSTRAINT "equipos_modalidad_check" CHECK ((("modalidad" IS NULL) OR ("modalidad" = ANY (ARRAY['F7'::"text", 'F11'::"text"]))))
);


ALTER TABLE "public"."equipos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."historial_requisitos_federativos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "requisito_id" "uuid" NOT NULL,
    "inscripcion_id" "uuid" NOT NULL,
    "estado_anterior" "text",
    "estado_nuevo" "text" NOT NULL,
    "accion" "text" NOT NULL,
    "motivo" "text",
    "actor_auth_user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."historial_requisitos_federativos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."historico_citas_rrmm" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cita_id" "uuid" NOT NULL,
    "accion" "text" NOT NULL,
    "datos_anteriores" "jsonb",
    "datos_nuevos" "jsonb",
    "actor_auth_user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "historico_citas_rrmm_accion_check" CHECK (("accion" = ANY (ARRAY['creada'::"text", 'modificada'::"text", 'cancelada'::"text", 'cancelada_por_reprogramacion'::"text", 'realizada_por_registro_rrmm'::"text", 'no_asiste'::"text"])))
);


ALTER TABLE "public"."historico_citas_rrmm" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."historico_estados_inscripcion" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "inscripcion_id" "uuid" NOT NULL,
    "estado_anterior" "text",
    "estado_nuevo" "text" NOT NULL,
    "comentario" "text",
    "cambiado_por" "uuid",
    "fecha" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."historico_estados_inscripcion" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."horarios_equipo" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "equipo_id" "uuid" NOT NULL,
    "dia_semana" smallint NOT NULL,
    "hora_inicio" time without time zone NOT NULL,
    "hora_fin" time without time zone NOT NULL,
    "activo" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "horarios_equipo_check" CHECK (("hora_fin" > "hora_inicio")),
    CONSTRAINT "horarios_equipo_dia_semana_check" CHECK ((("dia_semana" >= 1) AND ("dia_semana" <= 7)))
);


ALTER TABLE "public"."horarios_equipo" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inscripciones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "jugador_id" "uuid" NOT NULL,
    "temporada_id" "uuid" NOT NULL,
    "categoria_id" "uuid",
    "fecha_solicitud" "date" DEFAULT CURRENT_DATE NOT NULL,
    "estado" "text" DEFAULT 'pendiente_revision_inicial'::"text" NOT NULL,
    "documento_identidad_usado_id" "uuid",
    "representacion_usada_id" "uuid",
    "observaciones" "text",
    "validada_por" "uuid",
    "fecha_validacion" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "inscripciones_estado_check" CHECK (("estado" = ANY (ARRAY['pendiente_revision_inicial'::"text", 'devuelta_familia'::"text", 'datos_validados'::"text", 'documentacion_validada'::"text", 'lista_para_federar'::"text", 'ficha_tramitada'::"text", 'cancelada'::"text"])))
);


ALTER TABLE "public"."inscripciones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."jugadores" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "persona_id" "uuid" NOT NULL,
    "activo" boolean DEFAULT true NOT NULL,
    "fecha_alta" "date" DEFAULT CURRENT_DATE NOT NULL,
    "fecha_baja" "date",
    "motivo_baja" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "jugadores_check" CHECK ((("fecha_baja" IS NULL) OR ("fecha_baja" >= "fecha_alta")))
);


ALTER TABLE "public"."jugadores" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notificaciones_salida" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tipo" "text" NOT NULL,
    "jugador_id" "uuid",
    "cita_id" "uuid",
    "destinatario_tipo" "text" NOT NULL,
    "destinatario_persona_id" "uuid",
    "destinatario_email" "text",
    "asunto" "text" NOT NULL,
    "cuerpo" "text" NOT NULL,
    "estado" "text" DEFAULT 'pendiente'::"text" NOT NULL,
    "intentos" integer DEFAULT 0 NOT NULL,
    "enviado_at" timestamp with time zone,
    "ultimo_error" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "disponible_desde" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "notificaciones_salida_destinatario_tipo_check" CHECK (("destinatario_tipo" = ANY (ARRAY['tutor'::"text", 'jugador'::"text", 'entrenador'::"text", 'club'::"text", 'administrador'::"text"]))),
    CONSTRAINT "notificaciones_salida_estado_check" CHECK (("estado" = ANY (ARRAY['pendiente'::"text", 'enviado'::"text", 'error'::"text", 'cancelado'::"text"])))
);


ALTER TABLE "public"."notificaciones_salida" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pagos_inscripcion" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "inscripcion_id" "uuid" NOT NULL,
    "importe" numeric(10,2) NOT NULL,
    "metodo" "text" NOT NULL,
    "fecha_pago" "date" DEFAULT CURRENT_DATE NOT NULL,
    "estado" "text" DEFAULT 'confirmado'::"text" NOT NULL,
    "referencia_externa" "text",
    "clubber_pago_id" "text",
    "observaciones" "text",
    "registrado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "pagos_inscripcion_estado_check" CHECK (("estado" = ANY (ARRAY['confirmado'::"text", 'anulado'::"text", 'devuelto'::"text"]))),
    CONSTRAINT "pagos_inscripcion_importe_check" CHECK (("importe" > (0)::numeric)),
    CONSTRAINT "pagos_inscripcion_metodo_check" CHECK (("metodo" = ANY (ARRAY['efectivo'::"text", 'clubber'::"text", 'otro'::"text"])))
);


ALTER TABLE "public"."pagos_inscripcion" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."persona_roles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "persona_id" "uuid" NOT NULL,
    "rol_id" "uuid" NOT NULL,
    "fecha_desde" "date" DEFAULT CURRENT_DATE NOT NULL,
    "fecha_hasta" "date",
    "activo" boolean DEFAULT true NOT NULL,
    "otorgado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "persona_roles_check" CHECK ((("fecha_hasta" IS NULL) OR ("fecha_hasta" >= "fecha_desde")))
);


ALTER TABLE "public"."persona_roles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."personas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "auth_user_id" "uuid",
    "nombre" "text" NOT NULL,
    "primer_apellido" "text" NOT NULL,
    "segundo_apellido" "text",
    "fecha_nacimiento" "date",
    "email_contacto" "text",
    "telefono" "text",
    "activo" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."personas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."reconocimientos_medicos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "jugador_id" "uuid",
    "fecha_reconocimiento" "date" NOT NULL,
    "fecha_valido_hasta" "date" NOT NULL,
    "fecha_validacion_rffm" "date",
    "centro_medico" "text",
    "observaciones" "text",
    "registrado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "persona_id" "uuid",
    CONSTRAINT "reconocimientos_medicos_check" CHECK (("fecha_valido_hasta" >= "fecha_reconocimiento")),
    CONSTRAINT "reconocimientos_medicos_persona_o_jugador_check" CHECK ((("persona_id" IS NOT NULL) OR ("jugador_id" IS NOT NULL)))
);


ALTER TABLE "public"."reconocimientos_medicos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."reglas_categoria_temporada" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "temporada_id" "uuid" NOT NULL,
    "categoria_id" "uuid" NOT NULL,
    "anio_nacimiento_desde" smallint,
    "anio_nacimiento_hasta" smallint,
    "activo" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "reglas_categoria_temporada_check" CHECK ((("anio_nacimiento_desde" IS NULL) OR ("anio_nacimiento_hasta" IS NULL) OR ("anio_nacimiento_hasta" >= "anio_nacimiento_desde")))
);


ALTER TABLE "public"."reglas_categoria_temporada" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."representaciones_jugador" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "jugador_id" "uuid" NOT NULL,
    "representante_persona_id" "uuid" NOT NULL,
    "fecha_desde" "date" DEFAULT CURRENT_DATE NOT NULL,
    "fecha_hasta" "date",
    "motivo_alta" "text",
    "motivo_fin" "text",
    "excepcion_representacion_adulto" boolean DEFAULT false NOT NULL,
    "creado_por" "uuid",
    "finalizado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "representaciones_jugador_check" CHECK ((("fecha_hasta" IS NULL) OR ("fecha_hasta" >= "fecha_desde")))
);


ALTER TABLE "public"."representaciones_jugador" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."requisitos_federativos_inscripcion" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "inscripcion_id" "uuid" NOT NULL,
    "codigo" "text" NOT NULL,
    "nombre" "text" NOT NULL,
    "obligatorio" boolean DEFAULT true NOT NULL,
    "requiere_archivo" boolean DEFAULT true NOT NULL,
    "estado" "text" DEFAULT 'pendiente'::"text" NOT NULL,
    "current_documento_id" "uuid",
    "motivo_rechazo" "text",
    "revisado_at" timestamp with time zone,
    "revisado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "nueva_version_solicitada_at" timestamp with time zone,
    "nueva_version_solicitada_por" "uuid",
    "motivo_nueva_version" "text",
    "declarado_realizado_at" timestamp with time zone,
    "declarado_realizado_por" "uuid",
    CONSTRAINT "requisitos_federativos_inscripcion_estado_check" CHECK (("estado" = ANY (ARRAY['pendiente'::"text", 'aportado'::"text", 'declarado_realizado'::"text", 'validado'::"text", 'rechazado'::"text", 'nueva_version_solicitada'::"text"])))
);


ALTER TABLE "public"."requisitos_federativos_inscripcion" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."roles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "codigo" "text" NOT NULL,
    "nombre" "text" NOT NULL,
    "descripcion" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."roles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."situacion_economica_inscripcion" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "inscripcion_id" "uuid" NOT NULL,
    "configuracion_id" "uuid",
    "equipo_id" "uuid",
    "importe_total" numeric(10,2),
    "importe_pagado" numeric(10,2) DEFAULT 0 NOT NULL,
    "estado_economico" "text" DEFAULT 'pendiente'::"text" NOT NULL,
    "fraccionamiento_clubber_validado" boolean DEFAULT false NOT NULL,
    "fecha_validacion_fraccionamiento" timestamp with time zone,
    "validado_fraccionamiento_por" "uuid",
    "origen_validacion_fraccionamiento" "text",
    "apto_para_ficha" boolean DEFAULT false NOT NULL,
    "calculado_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "situacion_economica_inscripc_origen_validacion_fraccionam_check" CHECK ((("origen_validacion_fraccionamiento" IS NULL) OR ("origen_validacion_fraccionamiento" = ANY (ARRAY['manual_club'::"text", 'clubber_api'::"text"])))),
    CONSTRAINT "situacion_economica_inscripcion_estado_economico_check" CHECK (("estado_economico" = ANY (ARRAY['pendiente'::"text", 'parcial'::"text", 'pagado'::"text", 'devuelto'::"text"]))),
    CONSTRAINT "situacion_economica_inscripcion_importe_pagado_check" CHECK (("importe_pagado" >= (0)::numeric)),
    CONSTRAINT "situacion_economica_inscripcion_importe_total_check" CHECK ((("importe_total" IS NULL) OR ("importe_total" >= (0)::numeric)))
);


ALTER TABLE "public"."situacion_economica_inscripcion" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."telemetria_sesion_cliente" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "device_id" "uuid" NOT NULL,
    "auth_user_id" "uuid",
    "evento" "text" NOT NULL,
    "app_version" "text" NOT NULL,
    "auth_token_present" boolean NOT NULL,
    "visibility" "text",
    "online" boolean,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL
);


ALTER TABLE "public"."telemetria_sesion_cliente" OWNER TO "postgres";


COMMENT ON TABLE "public"."telemetria_sesion_cliente" IS 'V93.7.2: telemetria tecnica temporal para diagnosticar persistencia de sesion Safari/Supabase; retencion 14 dias.';



ALTER TABLE "public"."telemetria_sesion_cliente" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."telemetria_sesion_cliente_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."temporadas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nombre" "text" NOT NULL,
    "anio_inicio" smallint NOT NULL,
    "anio_fin" smallint NOT NULL,
    "fecha_inicio" "date",
    "fecha_fin" "date",
    "estado" "text" DEFAULT 'planificacion'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "temporadas_check" CHECK (("anio_fin" = ("anio_inicio" + 1))),
    CONSTRAINT "temporadas_check1" CHECK ((("fecha_fin" IS NULL) OR ("fecha_inicio" IS NULL) OR ("fecha_fin" >= "fecha_inicio"))),
    CONSTRAINT "temporadas_estado_check" CHECK (("estado" = ANY (ARRAY['planificacion'::"text", 'activa'::"text", 'cerrada'::"text"])))
);


ALTER TABLE "public"."temporadas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."vinculos_clubber" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tipo" "text" NOT NULL,
    "persona_id" "uuid",
    "jugador_id" "uuid",
    "clubber_id" "text" NOT NULL,
    "activo" boolean DEFAULT true NOT NULL,
    "creado_por" "uuid",
    "actualizado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "vinculos_clubber_destino_ck" CHECK (((("tipo" = 'tutor'::"text") AND ("persona_id" IS NOT NULL) AND ("jugador_id" IS NULL)) OR (("tipo" = 'deportista'::"text") AND ("jugador_id" IS NOT NULL) AND ("persona_id" IS NULL)))),
    CONSTRAINT "vinculos_clubber_tipo_check" CHECK (("tipo" = ANY (ARRAY['tutor'::"text", 'deportista'::"text"])))
);


ALTER TABLE "public"."vinculos_clubber" OWNER TO "postgres";


ALTER TABLE ONLY "public"."asignaciones_entrenador_equipo"
    ADD CONSTRAINT "asignaciones_entrenador_equipo_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."asignaciones_jugador_equipo"
    ADD CONSTRAINT "asignaciones_jugador_equipo_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."auditoria"
    ADD CONSTRAINT "auditoria_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."autorizaciones_menor"
    ADD CONSTRAINT "autorizaciones_menor_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."categorias"
    ADD CONSTRAINT "categorias_codigo_key" UNIQUE ("codigo");



ALTER TABLE ONLY "public"."categorias"
    ADD CONSTRAINT "categorias_nombre_key" UNIQUE ("nombre");



ALTER TABLE ONLY "public"."categorias"
    ADD CONSTRAINT "categorias_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."citas_reconocimiento_medico"
    ADD CONSTRAINT "citas_reconocimiento_medico_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."configuracion_economica_equipo"
    ADD CONSTRAINT "configuracion_economica_equipo_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."configuracion_economica_equipo"
    ADD CONSTRAINT "configuracion_economica_equipo_temporada_id_equipo_id_key" UNIQUE ("temporada_id", "equipo_id");



ALTER TABLE ONLY "public"."configuracion_visual_club"
    ADD CONSTRAINT "configuracion_visual_club_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."documentos_federativos"
    ADD CONSTRAINT "documentos_federativos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."documentos_federativos"
    ADD CONSTRAINT "documentos_federativos_storage_path_key" UNIQUE ("storage_path");



ALTER TABLE ONLY "public"."documentos_identidad"
    ADD CONSTRAINT "documentos_identidad_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."documentos"
    ADD CONSTRAINT "documentos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."entrenador_disponibilidad"
    ADD CONSTRAINT "entrenador_disponibilidad_entrenador_id_temporada_id_dia_se_key" UNIQUE ("entrenador_id", "temporada_id", "dia_semana");



ALTER TABLE ONLY "public"."entrenador_disponibilidad"
    ADD CONSTRAINT "entrenador_disponibilidad_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."entrenador_formaciones"
    ADD CONSTRAINT "entrenador_formaciones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."entrenador_licencia_equipos"
    ADD CONSTRAINT "entrenador_licencia_equipos_pkey" PRIMARY KEY ("licencia_id", "equipo_id");



ALTER TABLE ONLY "public"."entrenador_licencias_rffm"
    ADD CONSTRAINT "entrenador_licencias_rffm_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."entrenador_privacidad"
    ADD CONSTRAINT "entrenador_privacidad_pkey" PRIMARY KEY ("entrenador_id");



ALTER TABLE ONLY "public"."entrenador_temporadas"
    ADD CONSTRAINT "entrenador_temporadas_entrenador_id_temporada_id_key" UNIQUE ("entrenador_id", "temporada_id");



ALTER TABLE ONLY "public"."entrenador_temporadas"
    ADD CONSTRAINT "entrenador_temporadas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."entrenadores"
    ADD CONSTRAINT "entrenadores_persona_id_key" UNIQUE ("persona_id");



ALTER TABLE ONLY "public"."entrenadores"
    ADD CONSTRAINT "entrenadores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."equipos"
    ADD CONSTRAINT "equipos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."equipos"
    ADD CONSTRAINT "equipos_temporada_id_nombre_key" UNIQUE ("temporada_id", "nombre");



ALTER TABLE ONLY "public"."historial_requisitos_federativos"
    ADD CONSTRAINT "historial_requisitos_federativos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."historico_citas_rrmm"
    ADD CONSTRAINT "historico_citas_rrmm_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."historico_estados_inscripcion"
    ADD CONSTRAINT "historico_estados_inscripcion_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."horarios_equipo"
    ADD CONSTRAINT "horarios_equipo_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inscripciones"
    ADD CONSTRAINT "inscripciones_jugador_id_temporada_id_key" UNIQUE ("jugador_id", "temporada_id");



ALTER TABLE ONLY "public"."inscripciones"
    ADD CONSTRAINT "inscripciones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."jugadores"
    ADD CONSTRAINT "jugadores_persona_id_key" UNIQUE ("persona_id");



ALTER TABLE ONLY "public"."jugadores"
    ADD CONSTRAINT "jugadores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notificaciones_salida"
    ADD CONSTRAINT "notificaciones_salida_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pagos_inscripcion"
    ADD CONSTRAINT "pagos_inscripcion_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."persona_roles"
    ADD CONSTRAINT "persona_roles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."personas"
    ADD CONSTRAINT "personas_auth_user_id_key" UNIQUE ("auth_user_id");



ALTER TABLE ONLY "public"."personas"
    ADD CONSTRAINT "personas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reconocimientos_medicos"
    ADD CONSTRAINT "reconocimientos_medicos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reglas_categoria_temporada"
    ADD CONSTRAINT "reglas_categoria_temporada_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reglas_categoria_temporada"
    ADD CONSTRAINT "reglas_categoria_temporada_temporada_id_categoria_id_key" UNIQUE ("temporada_id", "categoria_id");



ALTER TABLE ONLY "public"."representaciones_jugador"
    ADD CONSTRAINT "representaciones_jugador_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."requisitos_federativos_inscripcion"
    ADD CONSTRAINT "requisitos_federativos_inscripcion_inscripcion_id_codigo_key" UNIQUE ("inscripcion_id", "codigo");



ALTER TABLE ONLY "public"."requisitos_federativos_inscripcion"
    ADD CONSTRAINT "requisitos_federativos_inscripcion_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."roles"
    ADD CONSTRAINT "roles_codigo_key" UNIQUE ("codigo");



ALTER TABLE ONLY "public"."roles"
    ADD CONSTRAINT "roles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."situacion_economica_inscripcion"
    ADD CONSTRAINT "situacion_economica_inscripcion_inscripcion_id_key" UNIQUE ("inscripcion_id");



ALTER TABLE ONLY "public"."situacion_economica_inscripcion"
    ADD CONSTRAINT "situacion_economica_inscripcion_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."telemetria_sesion_cliente"
    ADD CONSTRAINT "telemetria_sesion_cliente_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."temporadas"
    ADD CONSTRAINT "temporadas_nombre_key" UNIQUE ("nombre");



ALTER TABLE ONLY "public"."temporadas"
    ADD CONSTRAINT "temporadas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vinculos_clubber"
    ADD CONSTRAINT "vinculos_clubber_pkey" PRIMARY KEY ("id");



CREATE UNIQUE INDEX "asignacion_entrenador_activa_uq" ON "public"."asignaciones_entrenador_equipo" USING "btree" ("entrenador_id", "equipo_id") WHERE ("fecha_hasta" IS NULL);



CREATE UNIQUE INDEX "asignacion_jugador_activa_uq" ON "public"."asignaciones_jugador_equipo" USING "btree" ("inscripcion_id") WHERE ("fecha_hasta" IS NULL);



CREATE INDEX "asignaciones_entrenador_equipo_cancelada_idx" ON "public"."asignaciones_entrenador_equipo" USING "btree" ("entrenador_id", "cancelada_at");



CREATE INDEX "asignaciones_jugador_equipo_idx" ON "public"."asignaciones_jugador_equipo" USING "btree" ("equipo_id", "fecha_desde", "fecha_hasta");



CREATE INDEX "auditoria_entidad_idx" ON "public"."auditoria" USING "btree" ("entidad", "entidad_id", "created_at" DESC);



CREATE UNIQUE INDEX "autorizacion_menor_activa_uq" ON "public"."autorizaciones_menor" USING "btree" ("persona_menor_id", "tipo") WHERE ("estado" = ANY (ARRAY['pendiente_email'::"text", 'pendiente'::"text", 'aceptada'::"text"]));



CREATE INDEX "autorizaciones_menor_tutor_idx" ON "public"."autorizaciones_menor" USING "btree" ("tutor_persona_id", "estado", "solicitada_at" DESC);



CREATE INDEX "citas_rrmm_jugador_idx" ON "public"."citas_reconocimiento_medico" USING "btree" ("jugador_id", "fecha_hora" DESC);



CREATE INDEX "citas_rrmm_persona_idx" ON "public"."citas_reconocimiento_medico" USING "btree" ("persona_id", "fecha_hora" DESC);



CREATE UNIQUE INDEX "documentos_identidad_numero_uq" ON "public"."documentos_identidad" USING "btree" ("tipo", "upper"("regexp_replace"("numero", '[^A-Za-z0-9]'::"text", ''::"text", 'g'::"text")));



CREATE UNIQUE INDEX "documentos_identidad_principal_uq" ON "public"."documentos_identidad" USING "btree" ("persona_id") WHERE (("es_principal" = true) AND ("activo" = true));



CREATE INDEX "entrenador_equipo_idx" ON "public"."asignaciones_entrenador_equipo" USING "btree" ("equipo_id", "fecha_desde", "fecha_hasta");



CREATE UNIQUE INDEX "entrenadores_persona_id_uniq" ON "public"."entrenadores" USING "btree" ("persona_id");



CREATE INDEX "equipos_temporada_categoria_idx" ON "public"."equipos" USING "btree" ("temporada_id", "categoria_id");



CREATE INDEX "historico_citas_rrmm_cita_idx" ON "public"."historico_citas_rrmm" USING "btree" ("cita_id", "created_at" DESC);



CREATE INDEX "historico_inscripcion_idx" ON "public"."historico_estados_inscripcion" USING "btree" ("inscripcion_id", "fecha" DESC);



CREATE INDEX "idx_documentos_fed_inscripcion" ON "public"."documentos_federativos" USING "btree" ("inscripcion_id");



CREATE INDEX "idx_documentos_fed_requisito" ON "public"."documentos_federativos" USING "btree" ("requisito_id", "aportado_at" DESC);



CREATE INDEX "idx_historial_req_fed_requisito" ON "public"."historial_requisitos_federativos" USING "btree" ("requisito_id", "created_at" DESC);



CREATE INDEX "idx_requisitos_fed_inscripcion" ON "public"."requisitos_federativos_inscripcion" USING "btree" ("inscripcion_id");



CREATE INDEX "inscripciones_categoria_idx" ON "public"."inscripciones" USING "btree" ("categoria_id");



CREATE INDEX "inscripciones_temporada_estado_idx" ON "public"."inscripciones" USING "btree" ("temporada_id", "estado");



CREATE INDEX "notificaciones_salida_estado_idx" ON "public"."notificaciones_salida" USING "btree" ("estado", "created_at");



CREATE INDEX "notificaciones_salida_pendientes_idx" ON "public"."notificaciones_salida" USING "btree" ("estado", "disponible_desde", "created_at");



CREATE INDEX "pagos_inscripcion_inscripcion_idx" ON "public"."pagos_inscripcion" USING "btree" ("inscripcion_id", "fecha_pago" DESC);



CREATE UNIQUE INDEX "persona_roles_activo_uq" ON "public"."persona_roles" USING "btree" ("persona_id", "rol_id") WHERE (("activo" = true) AND ("fecha_hasta" IS NULL));



CREATE INDEX "personas_auth_user_idx" ON "public"."personas" USING "btree" ("auth_user_id");



CREATE INDEX "personas_nombre_fecha_idx" ON "public"."personas" USING "btree" ("lower"("nombre"), "lower"("primer_apellido"), "fecha_nacimiento");



CREATE INDEX "reconocimientos_jugador_idx" ON "public"."reconocimientos_medicos" USING "btree" ("jugador_id", "fecha_valido_hasta" DESC);



CREATE INDEX "reconocimientos_medicos_persona_idx" ON "public"."reconocimientos_medicos" USING "btree" ("persona_id", "fecha_reconocimiento" DESC);



CREATE UNIQUE INDEX "representacion_activa_jugador_uq" ON "public"."representaciones_jugador" USING "btree" ("jugador_id") WHERE ("fecha_hasta" IS NULL);



CREATE INDEX "telemetria_sesion_cliente_device_created_idx" ON "public"."telemetria_sesion_cliente" USING "btree" ("device_id", "created_at" DESC);



CREATE INDEX "telemetria_sesion_cliente_user_created_idx" ON "public"."telemetria_sesion_cliente" USING "btree" ("auth_user_id", "created_at" DESC) WHERE ("auth_user_id" IS NOT NULL);



CREATE UNIQUE INDEX "temporadas_unica_activa_uq" ON "public"."temporadas" USING "btree" ("estado") WHERE ("estado" = 'activa'::"text");



CREATE UNIQUE INDEX "vinculos_clubber_deportista_uq" ON "public"."vinculos_clubber" USING "btree" ("jugador_id") WHERE (("tipo" = 'deportista'::"text") AND ("activo" = true));



CREATE UNIQUE INDEX "vinculos_clubber_id_uq" ON "public"."vinculos_clubber" USING "btree" ("tipo", "clubber_id") WHERE ("activo" = true);



CREATE UNIQUE INDEX "vinculos_clubber_tutor_uq" ON "public"."vinculos_clubber" USING "btree" ("persona_id") WHERE (("tipo" = 'tutor'::"text") AND ("activo" = true));



CREATE OR REPLACE TRIGGER "categorias_updated_at" BEFORE UPDATE ON "public"."categorias" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "configuracion_economica_equipo_updated_at" BEFORE UPDATE ON "public"."configuracion_economica_equipo" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "documentos_identidad_updated_at" BEFORE UPDATE ON "public"."documentos_identidad" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "documentos_identidad_validar_dni_nie" BEFORE INSERT OR UPDATE OF "tipo", "numero" ON "public"."documentos_identidad" FOR EACH ROW EXECUTE FUNCTION "private"."validar_documento_identidad_espanol_trigger"();



CREATE OR REPLACE TRIGGER "documentos_updated_at" BEFORE UPDATE ON "public"."documentos" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "entrenador_equipo_updated_at" BEFORE UPDATE ON "public"."asignaciones_entrenador_equipo" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "entrenador_formaciones_audit_v92" AFTER DELETE OR UPDATE ON "public"."entrenador_formaciones" FOR EACH ROW EXECUTE FUNCTION "public"."auditar_cambios_entrenador_v92"();



CREATE OR REPLACE TRIGGER "entrenador_licencias_audit_v92" AFTER DELETE OR UPDATE ON "public"."entrenador_licencias_rffm" FOR EACH ROW EXECUTE FUNCTION "public"."auditar_cambios_entrenador_v92"();



CREATE OR REPLACE TRIGGER "entrenadores_updated_at" BEFORE UPDATE ON "public"."entrenadores" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "equipos_updated_at" BEFORE UPDATE ON "public"."equipos" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "inscripcion_init_requisitos_federativos" AFTER INSERT ON "public"."inscripciones" FOR EACH ROW EXECUTE FUNCTION "public"."trg_inicializar_requisitos_federativos"();



CREATE OR REPLACE TRIGGER "inscripciones_updated_at" BEFORE UPDATE ON "public"."inscripciones" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "jugador_equipo_updated_at" BEFORE UPDATE ON "public"."asignaciones_jugador_equipo" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "jugadores_updated_at" BEFORE UPDATE ON "public"."jugadores" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "pagos_inscripcion_updated_at" BEFORE UPDATE ON "public"."pagos_inscripcion" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "persona_roles_updated_at" BEFORE UPDATE ON "public"."persona_roles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "personas_updated_at" BEFORE UPDATE ON "public"."personas" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "reconocimientos_medicos_audit_v92" AFTER DELETE OR UPDATE ON "public"."reconocimientos_medicos" FOR EACH ROW EXECUTE FUNCTION "public"."auditar_cambios_entrenador_v92"();



CREATE OR REPLACE TRIGGER "reconocimientos_updated_at" BEFORE UPDATE ON "public"."reconocimientos_medicos" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "reglas_categoria_updated_at" BEFORE UPDATE ON "public"."reglas_categoria_temporada" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "representacion_ajustar_requisitos_mayoria" AFTER UPDATE OF "fecha_hasta", "motivo_fin" ON "public"."representaciones_jugador" FOR EACH ROW EXECUTE FUNCTION "private"."ajustar_requisitos_por_mayoria_edad"();



CREATE OR REPLACE TRIGGER "representaciones_updated_at" BEFORE UPDATE ON "public"."representaciones_jugador" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "situacion_economica_inscripcion_updated_at" BEFORE UPDATE ON "public"."situacion_economica_inscripcion" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "temporadas_updated_at" BEFORE UPDATE ON "public"."temporadas" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_asignacion_recalcular_economia" AFTER INSERT OR DELETE OR UPDATE ON "public"."asignaciones_jugador_equipo" FOR EACH ROW EXECUTE FUNCTION "private"."trg_recalcular_economia_asignacion"();



CREATE OR REPLACE TRIGGER "trg_calcular_categoria_inscripcion" BEFORE INSERT OR UPDATE OF "jugador_id", "temporada_id" ON "public"."inscripciones" FOR EACH ROW EXECUTE FUNCTION "public"."calcular_categoria_inscripcion"();



CREATE OR REPLACE TRIGGER "trg_entrenador_legacy_v84" AFTER INSERT OR UPDATE OF "curso_delegado", "licencia_tipo", "licencia_numero" ON "public"."entrenadores" FOR EACH ROW EXECUTE FUNCTION "private"."trg_entrenador_legacy_v84"();



CREATE OR REPLACE TRIGGER "trg_pago_recalcular_economia" AFTER INSERT OR DELETE OR UPDATE ON "public"."pagos_inscripcion" FOR EACH ROW EXECUTE FUNCTION "private"."trg_recalcular_economia_pago"();



CREATE OR REPLACE TRIGGER "trg_v83_recalc_econ" AFTER INSERT OR DELETE OR UPDATE ON "public"."situacion_economica_inscripcion" FOR EACH ROW EXECUTE FUNCTION "private"."trg_recalcular_estado_economia"();



CREATE OR REPLACE TRIGGER "trg_v83_recalc_ins_state" AFTER UPDATE OF "estado" ON "public"."inscripciones" FOR EACH ROW EXECUTE FUNCTION "private"."trg_recalcular_estado_inscripcion_estado"();



CREATE OR REPLACE TRIGGER "trg_v83_recalc_req" AFTER INSERT OR DELETE OR UPDATE ON "public"."requisitos_federativos_inscripcion" FOR EACH ROW EXECUTE FUNCTION "private"."trg_recalcular_estado_requisito"();



CREATE OR REPLACE TRIGGER "trg_v83_recalc_team" AFTER INSERT OR DELETE OR UPDATE ON "public"."asignaciones_jugador_equipo" FOR EACH ROW EXECUTE FUNCTION "private"."trg_recalcular_estado_equipo"();



CREATE OR REPLACE TRIGGER "trg_v83_rrmm_after" AFTER INSERT OR UPDATE ON "public"."reconocimientos_medicos" FOR EACH ROW EXECUTE FUNCTION "private"."trg_rrmm_v83"();



CREATE OR REPLACE TRIGGER "trg_v84_rrmm_persona_before" BEFORE INSERT OR UPDATE ON "public"."reconocimientos_medicos" FOR EACH ROW EXECUTE FUNCTION "private"."trg_rrmm_persona_v84"();



CREATE OR REPLACE TRIGGER "trg_v85_principal_unico" BEFORE INSERT OR UPDATE OF "equipo_id", "funcion", "fecha_desde", "fecha_hasta", "cancelada_at" ON "public"."asignaciones_entrenador_equipo" FOR EACH ROW EXECUTE FUNCTION "private"."validar_principal_unico_equipo"();



CREATE OR REPLACE TRIGGER "trg_validar_tutor_menor" BEFORE INSERT OR UPDATE OF "jugador_id", "fecha_solicitud" ON "public"."inscripciones" FOR EACH ROW EXECUTE FUNCTION "public"."validar_tutor_menor_inscripcion"();



CREATE OR REPLACE TRIGGER "vinculos_clubber_updated_at" BEFORE UPDATE ON "public"."vinculos_clubber" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



ALTER TABLE ONLY "public"."asignaciones_entrenador_equipo"
    ADD CONSTRAINT "asignaciones_entrenador_equipo_asignado_por_fkey" FOREIGN KEY ("asignado_por") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."asignaciones_entrenador_equipo"
    ADD CONSTRAINT "asignaciones_entrenador_equipo_entrenador_id_fkey" FOREIGN KEY ("entrenador_id") REFERENCES "public"."entrenadores"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."asignaciones_entrenador_equipo"
    ADD CONSTRAINT "asignaciones_entrenador_equipo_equipo_id_fkey" FOREIGN KEY ("equipo_id") REFERENCES "public"."equipos"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."asignaciones_jugador_equipo"
    ADD CONSTRAINT "asignaciones_jugador_equipo_asignado_por_fkey" FOREIGN KEY ("asignado_por") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."asignaciones_jugador_equipo"
    ADD CONSTRAINT "asignaciones_jugador_equipo_equipo_id_fkey" FOREIGN KEY ("equipo_id") REFERENCES "public"."equipos"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."asignaciones_jugador_equipo"
    ADD CONSTRAINT "asignaciones_jugador_equipo_inscripcion_id_fkey" FOREIGN KEY ("inscripcion_id") REFERENCES "public"."inscripciones"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."auditoria"
    ADD CONSTRAINT "auditoria_actor_auth_user_id_fkey" FOREIGN KEY ("actor_auth_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."autorizaciones_menor"
    ADD CONSTRAINT "autorizaciones_menor_actualizado_por_fkey" FOREIGN KEY ("actualizado_por") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."autorizaciones_menor"
    ADD CONSTRAINT "autorizaciones_menor_creado_por_fkey" FOREIGN KEY ("creado_por") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."autorizaciones_menor"
    ADD CONSTRAINT "autorizaciones_menor_persona_menor_id_fkey" FOREIGN KEY ("persona_menor_id") REFERENCES "public"."personas"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."autorizaciones_menor"
    ADD CONSTRAINT "autorizaciones_menor_tutor_persona_id_fkey" FOREIGN KEY ("tutor_persona_id") REFERENCES "public"."personas"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."citas_reconocimiento_medico"
    ADD CONSTRAINT "citas_reconocimiento_medico_creado_por_fkey" FOREIGN KEY ("creado_por") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."citas_reconocimiento_medico"
    ADD CONSTRAINT "citas_reconocimiento_medico_jugador_id_fkey" FOREIGN KEY ("jugador_id") REFERENCES "public"."jugadores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."citas_reconocimiento_medico"
    ADD CONSTRAINT "citas_reconocimiento_medico_persona_id_fkey" FOREIGN KEY ("persona_id") REFERENCES "public"."personas"("id");



ALTER TABLE ONLY "public"."citas_reconocimiento_medico"
    ADD CONSTRAINT "citas_reconocimiento_medico_reconocimiento_medico_id_fkey" FOREIGN KEY ("reconocimiento_medico_id") REFERENCES "public"."reconocimientos_medicos"("id");



ALTER TABLE ONLY "public"."configuracion_economica_equipo"
    ADD CONSTRAINT "configuracion_economica_equipo_actualizado_por_fkey" FOREIGN KEY ("actualizado_por") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."configuracion_economica_equipo"
    ADD CONSTRAINT "configuracion_economica_equipo_creado_por_fkey" FOREIGN KEY ("creado_por") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."configuracion_economica_equipo"
    ADD CONSTRAINT "configuracion_economica_equipo_equipo_id_fkey" FOREIGN KEY ("equipo_id") REFERENCES "public"."equipos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."configuracion_economica_equipo"
    ADD CONSTRAINT "configuracion_economica_equipo_temporada_id_fkey" FOREIGN KEY ("temporada_id") REFERENCES "public"."temporadas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."documentos_federativos"
    ADD CONSTRAINT "documentos_federativos_aportado_por_fkey" FOREIGN KEY ("aportado_por") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."documentos_federativos"
    ADD CONSTRAINT "documentos_federativos_inscripcion_id_fkey" FOREIGN KEY ("inscripcion_id") REFERENCES "public"."inscripciones"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."documentos_federativos"
    ADD CONSTRAINT "documentos_federativos_jugador_id_fkey" FOREIGN KEY ("jugador_id") REFERENCES "public"."jugadores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."documentos_federativos"
    ADD CONSTRAINT "documentos_federativos_requisito_id_fkey" FOREIGN KEY ("requisito_id") REFERENCES "public"."requisitos_federativos_inscripcion"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."documentos_federativos"
    ADD CONSTRAINT "documentos_federativos_revisado_por_fkey" FOREIGN KEY ("revisado_por") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."documentos_identidad"
    ADD CONSTRAINT "documentos_identidad_persona_id_fkey" FOREIGN KEY ("persona_id") REFERENCES "public"."personas"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."documentos"
    ADD CONSTRAINT "documentos_inscripcion_id_fkey" FOREIGN KEY ("inscripcion_id") REFERENCES "public"."inscripciones"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."documentos"
    ADD CONSTRAINT "documentos_jugador_id_fkey" FOREIGN KEY ("jugador_id") REFERENCES "public"."jugadores"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."documentos"
    ADD CONSTRAINT "documentos_persona_id_fkey" FOREIGN KEY ("persona_id") REFERENCES "public"."personas"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."documentos"
    ADD CONSTRAINT "documentos_reconocimiento_medico_id_fkey" FOREIGN KEY ("reconocimiento_medico_id") REFERENCES "public"."reconocimientos_medicos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."documentos"
    ADD CONSTRAINT "documentos_revisado_por_fkey" FOREIGN KEY ("revisado_por") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."entrenador_disponibilidad"
    ADD CONSTRAINT "entrenador_disponibilidad_entrenador_id_fkey" FOREIGN KEY ("entrenador_id") REFERENCES "public"."entrenadores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."entrenador_disponibilidad"
    ADD CONSTRAINT "entrenador_disponibilidad_temporada_id_fkey" FOREIGN KEY ("temporada_id") REFERENCES "public"."temporadas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."entrenador_formaciones"
    ADD CONSTRAINT "entrenador_formaciones_creado_por_fkey" FOREIGN KEY ("creado_por") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."entrenador_formaciones"
    ADD CONSTRAINT "entrenador_formaciones_entrenador_id_fkey" FOREIGN KEY ("entrenador_id") REFERENCES "public"."entrenadores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."entrenador_formaciones"
    ADD CONSTRAINT "entrenador_formaciones_verificado_por_fkey" FOREIGN KEY ("verificado_por") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."entrenador_licencia_equipos"
    ADD CONSTRAINT "entrenador_licencia_equipos_equipo_id_fkey" FOREIGN KEY ("equipo_id") REFERENCES "public"."equipos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."entrenador_licencia_equipos"
    ADD CONSTRAINT "entrenador_licencia_equipos_licencia_id_fkey" FOREIGN KEY ("licencia_id") REFERENCES "public"."entrenador_licencias_rffm"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."entrenador_licencias_rffm"
    ADD CONSTRAINT "entrenador_licencias_rffm_creado_por_fkey" FOREIGN KEY ("creado_por") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."entrenador_licencias_rffm"
    ADD CONSTRAINT "entrenador_licencias_rffm_entrenador_id_fkey" FOREIGN KEY ("entrenador_id") REFERENCES "public"."entrenadores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."entrenador_licencias_rffm"
    ADD CONSTRAINT "entrenador_licencias_rffm_temporada_id_fkey" FOREIGN KEY ("temporada_id") REFERENCES "public"."temporadas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."entrenador_licencias_rffm"
    ADD CONSTRAINT "entrenador_licencias_rffm_verificado_por_fkey" FOREIGN KEY ("verificado_por") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."entrenador_privacidad"
    ADD CONSTRAINT "entrenador_privacidad_decidido_por_fkey" FOREIGN KEY ("decidido_por") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."entrenador_privacidad"
    ADD CONSTRAINT "entrenador_privacidad_entrenador_id_fkey" FOREIGN KEY ("entrenador_id") REFERENCES "public"."entrenadores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."entrenador_temporadas"
    ADD CONSTRAINT "entrenador_temporadas_entrenador_id_fkey" FOREIGN KEY ("entrenador_id") REFERENCES "public"."entrenadores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."entrenador_temporadas"
    ADD CONSTRAINT "entrenador_temporadas_temporada_id_fkey" FOREIGN KEY ("temporada_id") REFERENCES "public"."temporadas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."entrenadores"
    ADD CONSTRAINT "entrenadores_persona_id_fkey" FOREIGN KEY ("persona_id") REFERENCES "public"."personas"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."equipos"
    ADD CONSTRAINT "equipos_categoria_id_fkey" FOREIGN KEY ("categoria_id") REFERENCES "public"."categorias"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."equipos"
    ADD CONSTRAINT "equipos_temporada_id_fkey" FOREIGN KEY ("temporada_id") REFERENCES "public"."temporadas"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."historial_requisitos_federativos"
    ADD CONSTRAINT "historial_requisitos_federativos_actor_auth_user_id_fkey" FOREIGN KEY ("actor_auth_user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."historial_requisitos_federativos"
    ADD CONSTRAINT "historial_requisitos_federativos_inscripcion_id_fkey" FOREIGN KEY ("inscripcion_id") REFERENCES "public"."inscripciones"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."historial_requisitos_federativos"
    ADD CONSTRAINT "historial_requisitos_federativos_requisito_id_fkey" FOREIGN KEY ("requisito_id") REFERENCES "public"."requisitos_federativos_inscripcion"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."historico_citas_rrmm"
    ADD CONSTRAINT "historico_citas_rrmm_actor_auth_user_id_fkey" FOREIGN KEY ("actor_auth_user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."historico_citas_rrmm"
    ADD CONSTRAINT "historico_citas_rrmm_cita_id_fkey" FOREIGN KEY ("cita_id") REFERENCES "public"."citas_reconocimiento_medico"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."historico_estados_inscripcion"
    ADD CONSTRAINT "historico_estados_inscripcion_cambiado_por_fkey" FOREIGN KEY ("cambiado_por") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."historico_estados_inscripcion"
    ADD CONSTRAINT "historico_estados_inscripcion_inscripcion_id_fkey" FOREIGN KEY ("inscripcion_id") REFERENCES "public"."inscripciones"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."horarios_equipo"
    ADD CONSTRAINT "horarios_equipo_equipo_id_fkey" FOREIGN KEY ("equipo_id") REFERENCES "public"."equipos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inscripciones"
    ADD CONSTRAINT "inscripciones_categoria_id_fkey" FOREIGN KEY ("categoria_id") REFERENCES "public"."categorias"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."inscripciones"
    ADD CONSTRAINT "inscripciones_documento_identidad_usado_id_fkey" FOREIGN KEY ("documento_identidad_usado_id") REFERENCES "public"."documentos_identidad"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."inscripciones"
    ADD CONSTRAINT "inscripciones_jugador_id_fkey" FOREIGN KEY ("jugador_id") REFERENCES "public"."jugadores"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."inscripciones"
    ADD CONSTRAINT "inscripciones_representacion_usada_id_fkey" FOREIGN KEY ("representacion_usada_id") REFERENCES "public"."representaciones_jugador"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."inscripciones"
    ADD CONSTRAINT "inscripciones_temporada_id_fkey" FOREIGN KEY ("temporada_id") REFERENCES "public"."temporadas"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."inscripciones"
    ADD CONSTRAINT "inscripciones_validada_por_fkey" FOREIGN KEY ("validada_por") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."jugadores"
    ADD CONSTRAINT "jugadores_persona_id_fkey" FOREIGN KEY ("persona_id") REFERENCES "public"."personas"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."notificaciones_salida"
    ADD CONSTRAINT "notificaciones_salida_cita_id_fkey" FOREIGN KEY ("cita_id") REFERENCES "public"."citas_reconocimiento_medico"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notificaciones_salida"
    ADD CONSTRAINT "notificaciones_salida_destinatario_persona_id_fkey" FOREIGN KEY ("destinatario_persona_id") REFERENCES "public"."personas"("id");



ALTER TABLE ONLY "public"."notificaciones_salida"
    ADD CONSTRAINT "notificaciones_salida_jugador_id_fkey" FOREIGN KEY ("jugador_id") REFERENCES "public"."jugadores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pagos_inscripcion"
    ADD CONSTRAINT "pagos_inscripcion_inscripcion_id_fkey" FOREIGN KEY ("inscripcion_id") REFERENCES "public"."inscripciones"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pagos_inscripcion"
    ADD CONSTRAINT "pagos_inscripcion_registrado_por_fkey" FOREIGN KEY ("registrado_por") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."persona_roles"
    ADD CONSTRAINT "persona_roles_otorgado_por_fkey" FOREIGN KEY ("otorgado_por") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."persona_roles"
    ADD CONSTRAINT "persona_roles_persona_id_fkey" FOREIGN KEY ("persona_id") REFERENCES "public"."personas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."persona_roles"
    ADD CONSTRAINT "persona_roles_rol_id_fkey" FOREIGN KEY ("rol_id") REFERENCES "public"."roles"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."personas"
    ADD CONSTRAINT "personas_auth_user_id_fkey" FOREIGN KEY ("auth_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."reconocimientos_medicos"
    ADD CONSTRAINT "reconocimientos_medicos_jugador_id_fkey" FOREIGN KEY ("jugador_id") REFERENCES "public"."jugadores"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."reconocimientos_medicos"
    ADD CONSTRAINT "reconocimientos_medicos_persona_id_fkey" FOREIGN KEY ("persona_id") REFERENCES "public"."personas"("id");



ALTER TABLE ONLY "public"."reconocimientos_medicos"
    ADD CONSTRAINT "reconocimientos_medicos_registrado_por_fkey" FOREIGN KEY ("registrado_por") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."reglas_categoria_temporada"
    ADD CONSTRAINT "reglas_categoria_temporada_categoria_id_fkey" FOREIGN KEY ("categoria_id") REFERENCES "public"."categorias"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."reglas_categoria_temporada"
    ADD CONSTRAINT "reglas_categoria_temporada_temporada_id_fkey" FOREIGN KEY ("temporada_id") REFERENCES "public"."temporadas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."representaciones_jugador"
    ADD CONSTRAINT "representaciones_jugador_creado_por_fkey" FOREIGN KEY ("creado_por") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."representaciones_jugador"
    ADD CONSTRAINT "representaciones_jugador_finalizado_por_fkey" FOREIGN KEY ("finalizado_por") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."representaciones_jugador"
    ADD CONSTRAINT "representaciones_jugador_jugador_id_fkey" FOREIGN KEY ("jugador_id") REFERENCES "public"."jugadores"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."representaciones_jugador"
    ADD CONSTRAINT "representaciones_jugador_representante_persona_id_fkey" FOREIGN KEY ("representante_persona_id") REFERENCES "public"."personas"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."requisitos_federativos_inscripcion"
    ADD CONSTRAINT "requisitos_federativos_current_documento_fk" FOREIGN KEY ("current_documento_id") REFERENCES "public"."documentos_federativos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."requisitos_federativos_inscripcion"
    ADD CONSTRAINT "requisitos_federativos_inscri_nueva_version_solicitada_por_fkey" FOREIGN KEY ("nueva_version_solicitada_por") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."requisitos_federativos_inscripcion"
    ADD CONSTRAINT "requisitos_federativos_inscripcion_declarado_realizado_por_fkey" FOREIGN KEY ("declarado_realizado_por") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."requisitos_federativos_inscripcion"
    ADD CONSTRAINT "requisitos_federativos_inscripcion_inscripcion_id_fkey" FOREIGN KEY ("inscripcion_id") REFERENCES "public"."inscripciones"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."requisitos_federativos_inscripcion"
    ADD CONSTRAINT "requisitos_federativos_inscripcion_revisado_por_fkey" FOREIGN KEY ("revisado_por") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."situacion_economica_inscripcion"
    ADD CONSTRAINT "situacion_economica_inscripci_validado_fraccionamiento_por_fkey" FOREIGN KEY ("validado_fraccionamiento_por") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."situacion_economica_inscripcion"
    ADD CONSTRAINT "situacion_economica_inscripcion_configuracion_id_fkey" FOREIGN KEY ("configuracion_id") REFERENCES "public"."configuracion_economica_equipo"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."situacion_economica_inscripcion"
    ADD CONSTRAINT "situacion_economica_inscripcion_equipo_id_fkey" FOREIGN KEY ("equipo_id") REFERENCES "public"."equipos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."situacion_economica_inscripcion"
    ADD CONSTRAINT "situacion_economica_inscripcion_inscripcion_id_fkey" FOREIGN KEY ("inscripcion_id") REFERENCES "public"."inscripciones"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vinculos_clubber"
    ADD CONSTRAINT "vinculos_clubber_actualizado_por_fkey" FOREIGN KEY ("actualizado_por") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."vinculos_clubber"
    ADD CONSTRAINT "vinculos_clubber_creado_por_fkey" FOREIGN KEY ("creado_por") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."vinculos_clubber"
    ADD CONSTRAINT "vinculos_clubber_jugador_id_fkey" FOREIGN KEY ("jugador_id") REFERENCES "public"."jugadores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vinculos_clubber"
    ADD CONSTRAINT "vinculos_clubber_persona_id_fkey" FOREIGN KEY ("persona_id") REFERENCES "public"."personas"("id") ON DELETE CASCADE;



CREATE POLICY "asignaciones_entrenador_club_admin_write" ON "public"."asignaciones_entrenador_equipo" TO "authenticated" USING (( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role")) WITH CHECK (( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role"));



ALTER TABLE "public"."asignaciones_entrenador_equipo" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "asignaciones_entrenador_read_authorized" ON "public"."asignaciones_entrenador_equipo" FOR SELECT TO "authenticated" USING ((( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role") OR (EXISTS ( SELECT 1
   FROM "public"."entrenadores" "e"
  WHERE (("e"."id" = "asignaciones_entrenador_equipo"."entrenador_id") AND ("e"."persona_id" = ( SELECT "private"."current_person_id"() AS "current_person_id")))))));



CREATE POLICY "asignaciones_jugador_club_admin_write" ON "public"."asignaciones_jugador_equipo" TO "authenticated" USING (( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role")) WITH CHECK (( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role"));



ALTER TABLE "public"."asignaciones_jugador_equipo" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "asignaciones_jugador_read_authorized" ON "public"."asignaciones_jugador_equipo" FOR SELECT TO "authenticated" USING (( SELECT "private"."can_access_inscription"("asignaciones_jugador_equipo"."inscripcion_id") AS "can_access_inscription"));



ALTER TABLE "public"."auditoria" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "auditoria_admin_read" ON "public"."auditoria" FOR SELECT TO "authenticated" USING (( SELECT "private"."has_role"('administrador'::"text") AS "has_role"));



ALTER TABLE "public"."autorizaciones_menor" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "autorizaciones_menor_read_authorized" ON "public"."autorizaciones_menor" FOR SELECT TO "authenticated" USING (("private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) OR ("tutor_persona_id" = "private"."current_person_id"()) OR ("persona_menor_id" = "private"."current_person_id"())));



ALTER TABLE "public"."categorias" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "categorias_authenticated_read" ON "public"."categorias" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."citas_reconocimiento_medico" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "citas_rrmm_club_admin_write" ON "public"."citas_reconocimiento_medico" TO "authenticated" USING (( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role")) WITH CHECK (( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role"));



CREATE POLICY "citas_rrmm_read_authorized" ON "public"."citas_reconocimiento_medico" FOR SELECT TO "authenticated" USING (("private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) OR ("persona_id" = "private"."current_person_id"()) OR (("jugador_id" IS NOT NULL) AND "private"."can_access_player"("jugador_id"))));



CREATE POLICY "configuracion_economica_authenticated_read" ON "public"."configuracion_economica_equipo" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."configuracion_economica_equipo" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."configuracion_visual_club" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "configuracion_visual_public_read" ON "public"."configuracion_visual_club" FOR SELECT TO "authenticated", "anon" USING (true);



ALTER TABLE "public"."documentos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "documentos_club_admin_write" ON "public"."documentos" TO "authenticated" USING (( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role")) WITH CHECK (( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role"));



CREATE POLICY "documentos_fed_read" ON "public"."documentos_federativos" FOR SELECT TO "authenticated" USING (("private"."can_access_inscription_personal"("inscripcion_id") OR "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"])));



ALTER TABLE "public"."documentos_federativos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."documentos_identidad" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "documentos_identidad_admin_write" ON "public"."documentos_identidad" TO "authenticated" USING (( SELECT "private"."has_role"('administrador'::"text") AS "has_role")) WITH CHECK (( SELECT "private"."has_role"('administrador'::"text") AS "has_role"));



CREATE POLICY "documentos_identidad_read_related" ON "public"."documentos_identidad" FOR SELECT TO "authenticated" USING (( SELECT "private"."can_read_person"("documentos_identidad"."persona_id") AS "can_read_person"));



CREATE POLICY "documentos_read_authorized" ON "public"."documentos" FOR SELECT TO "authenticated" USING (( SELECT "private"."can_read_document"("documentos"."id") AS "can_read_document"));



ALTER TABLE "public"."entrenador_disponibilidad" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "entrenador_disponibilidad_read_v90_1" ON "public"."entrenador_disponibilidad" FOR SELECT TO "authenticated" USING (("private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) OR (EXISTS ( SELECT 1
   FROM ("public"."entrenadores" "e"
     JOIN "public"."personas" "p" ON (("p"."id" = "e"."persona_id")))
  WHERE (("e"."id" = "entrenador_disponibilidad"."entrenador_id") AND ("p"."auth_user_id" = "auth"."uid"()))))));



CREATE POLICY "entrenador_disponibilidad_self_read" ON "public"."entrenador_disponibilidad" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."entrenadores" "e"
     JOIN "public"."personas" "p" ON (("p"."id" = "e"."persona_id")))
  WHERE (("e"."id" = "entrenador_disponibilidad"."entrenador_id") AND ("p"."auth_user_id" = "auth"."uid"())))));



ALTER TABLE "public"."entrenador_formaciones" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "entrenador_formaciones_read" ON "public"."entrenador_formaciones" FOR SELECT TO "authenticated" USING (("private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) OR (EXISTS ( SELECT 1
   FROM ("public"."entrenadores" "e"
     JOIN "public"."personas" "p" ON (("p"."id" = "e"."persona_id")))
  WHERE (("e"."id" = "entrenador_formaciones"."entrenador_id") AND ("p"."auth_user_id" = "auth"."uid"()))))));



CREATE POLICY "entrenador_formaciones_write" ON "public"."entrenador_formaciones" TO "authenticated" USING ("private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"])) WITH CHECK ("private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]));



ALTER TABLE "public"."entrenador_licencia_equipos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "entrenador_licencia_equipos_club" ON "public"."entrenador_licencia_equipos" TO "authenticated" USING ("private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"])) WITH CHECK ("private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]));



CREATE POLICY "entrenador_licencias_read" ON "public"."entrenador_licencias_rffm" FOR SELECT TO "authenticated" USING (("private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) OR (EXISTS ( SELECT 1
   FROM ("public"."entrenadores" "e"
     JOIN "public"."personas" "p" ON (("p"."id" = "e"."persona_id")))
  WHERE (("e"."id" = "entrenador_licencias_rffm"."entrenador_id") AND ("p"."auth_user_id" = "auth"."uid"()))))));



ALTER TABLE "public"."entrenador_licencias_rffm" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "entrenador_licencias_write" ON "public"."entrenador_licencias_rffm" TO "authenticated" USING ("private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"])) WITH CHECK ("private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]));



ALTER TABLE "public"."entrenador_privacidad" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "entrenador_privacidad_club" ON "public"."entrenador_privacidad" TO "authenticated" USING ("private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"])) WITH CHECK ("private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]));



ALTER TABLE "public"."entrenador_temporadas" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "entrenador_temporadas_club" ON "public"."entrenador_temporadas" TO "authenticated" USING ("private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"])) WITH CHECK ("private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]));



CREATE POLICY "entrenador_temporadas_self_read" ON "public"."entrenador_temporadas" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."entrenadores" "e"
     JOIN "public"."personas" "p" ON (("p"."id" = "e"."persona_id")))
  WHERE (("e"."id" = "entrenador_temporadas"."entrenador_id") AND ("p"."auth_user_id" = "auth"."uid"())))));



ALTER TABLE "public"."entrenadores" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "entrenadores_club_admin_write" ON "public"."entrenadores" TO "authenticated" USING (( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role")) WITH CHECK (( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role"));



CREATE POLICY "entrenadores_read_authorized" ON "public"."entrenadores" FOR SELECT TO "authenticated" USING ((( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role") OR ("persona_id" = ( SELECT "private"."current_person_id"() AS "current_person_id"))));



ALTER TABLE "public"."equipos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "equipos_authenticated_read" ON "public"."equipos" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "equipos_club_admin_write" ON "public"."equipos" TO "authenticated" USING (( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role")) WITH CHECK (( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role"));



CREATE POLICY "historial_req_fed_read" ON "public"."historial_requisitos_federativos" FOR SELECT TO "authenticated" USING (("private"."can_access_inscription_personal"("inscripcion_id") OR "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"])));



ALTER TABLE "public"."historial_requisitos_federativos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."historico_citas_rrmm" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "historico_citas_rrmm_club_admin_read" ON "public"."historico_citas_rrmm" FOR SELECT TO "authenticated" USING (( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role"));



CREATE POLICY "historico_estados_club_insert" ON "public"."historico_estados_inscripcion" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role"));



CREATE POLICY "historico_estados_club_read" ON "public"."historico_estados_inscripcion" FOR SELECT TO "authenticated" USING (( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role"));



ALTER TABLE "public"."historico_estados_inscripcion" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."horarios_equipo" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "horarios_equipo_club" ON "public"."horarios_equipo" TO "authenticated" USING ("private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"])) WITH CHECK ("private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]));



CREATE POLICY "horarios_equipo_coach_read" ON "public"."horarios_equipo" FOR SELECT TO "authenticated" USING (("private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) OR (EXISTS ( SELECT 1
   FROM (("public"."asignaciones_entrenador_equipo" "a"
     JOIN "public"."entrenadores" "e" ON (("e"."id" = "a"."entrenador_id")))
     JOIN "public"."personas" "p" ON (("p"."id" = "e"."persona_id")))
  WHERE (("a"."equipo_id" = "horarios_equipo"."equipo_id") AND ("p"."auth_user_id" = "auth"."uid"()) AND ("a"."cancelada_at" IS NULL) AND ("a"."fecha_desde" <= CURRENT_DATE) AND (("a"."fecha_hasta" IS NULL) OR ("a"."fecha_hasta" >= CURRENT_DATE)))))));



ALTER TABLE "public"."inscripciones" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "inscripciones_club_admin_write" ON "public"."inscripciones" TO "authenticated" USING (( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role")) WITH CHECK (( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role"));



CREATE POLICY "inscripciones_read_authorized" ON "public"."inscripciones" FOR SELECT TO "authenticated" USING (( SELECT "private"."can_access_player"("inscripciones"."jugador_id") AS "can_access_player"));



ALTER TABLE "public"."jugadores" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "jugadores_club_admin_write" ON "public"."jugadores" TO "authenticated" USING (( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role")) WITH CHECK (( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role"));



CREATE POLICY "jugadores_read_authorized" ON "public"."jugadores" FOR SELECT TO "authenticated" USING (( SELECT "private"."can_access_player"("jugadores"."id") AS "can_access_player"));



ALTER TABLE "public"."notificaciones_salida" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notificaciones_salida_club_admin_read" ON "public"."notificaciones_salida" FOR SELECT TO "authenticated" USING (( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role"));



ALTER TABLE "public"."pagos_inscripcion" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "pagos_inscripcion_read_authorized" ON "public"."pagos_inscripcion" FOR SELECT TO "authenticated" USING (("private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) OR "private"."can_access_inscription_personal"("inscripcion_id")));



ALTER TABLE "public"."persona_roles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "persona_roles_admin_write" ON "public"."persona_roles" TO "authenticated" USING (( SELECT "private"."has_role"('administrador'::"text") AS "has_role")) WITH CHECK (( SELECT "private"."has_role"('administrador'::"text") AS "has_role"));



CREATE POLICY "persona_roles_self_read" ON "public"."persona_roles" FOR SELECT TO "authenticated" USING ((("persona_id" = ( SELECT "private"."current_person_id"() AS "current_person_id")) OR ( SELECT "private"."has_role"('administrador'::"text") AS "has_role")));



ALTER TABLE "public"."personas" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "personas_admin_write" ON "public"."personas" TO "authenticated" USING (( SELECT "private"."has_role"('administrador'::"text") AS "has_role")) WITH CHECK (( SELECT "private"."has_role"('administrador'::"text") AS "has_role"));



CREATE POLICY "personas_read_related" ON "public"."personas" FOR SELECT TO "authenticated" USING (( SELECT "private"."can_read_person"("personas"."id") AS "can_read_person"));



CREATE POLICY "reconocimientos_club_admin_write" ON "public"."reconocimientos_medicos" TO "authenticated" USING (( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role")) WITH CHECK (( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role"));



ALTER TABLE "public"."reconocimientos_medicos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "reconocimientos_read_personal" ON "public"."reconocimientos_medicos" FOR SELECT TO "authenticated" USING (( SELECT "private"."can_access_player_personal"("reconocimientos_medicos"."jugador_id") AS "can_access_player_personal"));



CREATE POLICY "reglas_categoria_authenticated_read" ON "public"."reglas_categoria_temporada" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."reglas_categoria_temporada" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "representaciones_admin_write" ON "public"."representaciones_jugador" TO "authenticated" USING (( SELECT "private"."has_role"('administrador'::"text") AS "has_role")) WITH CHECK (( SELECT "private"."has_role"('administrador'::"text") AS "has_role"));



ALTER TABLE "public"."representaciones_jugador" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "representaciones_read_authorized" ON "public"."representaciones_jugador" FOR SELECT TO "authenticated" USING ((( SELECT "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) AS "has_any_role") OR ("representante_persona_id" = ( SELECT "private"."current_person_id"() AS "current_person_id")) OR (EXISTS ( SELECT 1
   FROM "public"."jugadores" "j"
  WHERE (("j"."id" = "representaciones_jugador"."jugador_id") AND ("j"."persona_id" = ( SELECT "private"."current_person_id"() AS "current_person_id")))))));



CREATE POLICY "requisitos_fed_read" ON "public"."requisitos_federativos_inscripcion" FOR SELECT TO "authenticated" USING (("private"."can_access_inscription_personal"("inscripcion_id") OR "private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"])));



ALTER TABLE "public"."requisitos_federativos_inscripcion" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."roles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "roles_authenticated_read" ON "public"."roles" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."situacion_economica_inscripcion" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "situacion_economica_read_authorized" ON "public"."situacion_economica_inscripcion" FOR SELECT TO "authenticated" USING (("private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) OR "private"."can_access_inscription_personal"("inscripcion_id")));



ALTER TABLE "public"."telemetria_sesion_cliente" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."temporadas" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "temporadas_authenticated_read" ON "public"."temporadas" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."vinculos_clubber" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "vinculos_clubber_club_read" ON "public"."vinculos_clubber" FOR SELECT TO "authenticated" USING (("private"."has_any_role"(ARRAY['administrador'::"text", 'club'::"text"]) OR (("tipo" = 'tutor'::"text") AND ("persona_id" = "private"."current_person_id"())) OR (("tipo" = 'deportista'::"text") AND (EXISTS ( SELECT 1
   FROM "public"."jugadores" "j"
  WHERE (("j"."id" = "vinculos_clubber"."jugador_id") AND "private"."can_access_player_personal"("j"."id")))))));



GRANT USAGE ON SCHEMA "private" TO "authenticated";
GRANT USAGE ON SCHEMA "private" TO "service_role";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



REVOKE ALL ON FUNCTION "private"."can_access_inscription"("target_inscription_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "private"."can_access_inscription"("target_inscription_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "private"."can_access_inscription"("target_inscription_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "private"."can_access_inscription_personal"("target_inscription_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "private"."can_access_inscription_personal"("target_inscription_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "private"."can_access_inscription_personal"("target_inscription_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "private"."can_access_player"("target_player_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "private"."can_access_player"("target_player_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "private"."can_access_player"("target_player_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "private"."can_access_player_personal"("target_player_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "private"."can_access_player_personal"("target_player_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "private"."can_access_player_personal"("target_player_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "private"."can_read_document"("target_document_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "private"."can_read_document"("target_document_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "private"."can_read_document"("target_document_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "private"."can_read_person"("target_person_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "private"."can_read_person"("target_person_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "private"."can_read_person"("target_person_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "private"."current_person_id"() FROM PUBLIC;
GRANT ALL ON FUNCTION "private"."current_person_id"() TO "authenticated";
GRANT ALL ON FUNCTION "private"."current_person_id"() TO "service_role";



REVOKE ALL ON FUNCTION "private"."encolar_notificaciones_cita"("p_cita_id" "uuid", "p_evento" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "private"."encolar_notificaciones_cita"("p_cita_id" "uuid", "p_evento" "text") TO "authenticated";
GRANT ALL ON FUNCTION "private"."encolar_notificaciones_cita"("p_cita_id" "uuid", "p_evento" "text") TO "service_role";



REVOKE ALL ON FUNCTION "private"."has_any_role"("role_codes" "text"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "private"."has_any_role"("role_codes" "text"[]) TO "authenticated";
GRANT ALL ON FUNCTION "private"."has_any_role"("role_codes" "text"[]) TO "service_role";



REVOKE ALL ON FUNCTION "private"."has_role"("role_code" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "private"."has_role"("role_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "private"."has_role"("role_code" "text") TO "service_role";



REVOKE ALL ON FUNCTION "private"."is_trainer_of_player"("target_player_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "private"."is_trainer_of_player"("target_player_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "private"."is_trainer_of_player"("target_player_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "private"."normalizar_documento"("p_numero" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "private"."normalizar_documento"("p_numero" "text") TO "authenticated";
GRANT ALL ON FUNCTION "private"."normalizar_documento"("p_numero" "text") TO "service_role";



REVOKE ALL ON FUNCTION "private"."recalcular_situacion_economica"("p_inscripcion_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "private"."recalcular_situacion_economica"("p_inscripcion_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "private"."validar_principal_unico_equipo"() FROM PUBLIC;



REVOKE ALL ON FUNCTION "public"."actualizar_jugador_autorrepresentado"("p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_telefono" "text", "p_tipo_documento" "text", "p_numero_documento" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."actualizar_jugador_autorrepresentado"("p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_telefono" "text", "p_tipo_documento" "text", "p_numero_documento" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."actualizar_menor_representado"("p_jugador_id" "uuid", "p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_tipo_documento" "text", "p_numero_documento" "text", "p_email_jugador" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."actualizar_menor_representado"("p_jugador_id" "uuid", "p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_tipo_documento" "text", "p_numero_documento" "text", "p_email_jugador" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."actualizar_perfiles_persona_admin"("p_persona_id" "uuid", "p_administrador" boolean, "p_club" boolean, "p_entrenador" boolean, "p_jugador" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."actualizar_perfiles_persona_admin"("p_persona_id" "uuid", "p_administrador" boolean, "p_club" boolean, "p_entrenador" boolean, "p_jugador" boolean) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."actualizar_vinculos_clubber"("p_jugador_id" "uuid", "p_clubber_deportista_id" "text", "p_tutor_persona_id" "uuid", "p_clubber_tutor_id" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."actualizar_vinculos_clubber"("p_jugador_id" "uuid", "p_clubber_deportista_id" "text", "p_tutor_persona_id" "uuid", "p_clubber_tutor_id" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."anular_pago_inscripcion"("p_pago_id" "uuid", "p_motivo" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."anular_pago_inscripcion"("p_pago_id" "uuid", "p_motivo" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."asignar_rol_entrenador"("p_persona_id" "uuid", "p_licencia_tipo" "text", "p_licencia_numero" "text", "p_curso_delegado" boolean, "p_activo" boolean, "p_observaciones" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."asignar_rol_entrenador"("p_persona_id" "uuid", "p_licencia_tipo" "text", "p_licencia_numero" "text", "p_curso_delegado" boolean, "p_activo" boolean, "p_observaciones" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."cancelar_cita_rrmm"("p_cita_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."cancelar_cita_rrmm"("p_cita_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."configurar_economia_equipo"("p_equipo_id" "uuid", "p_importe_inscripcion" numeric, "p_admite_fraccionamiento" boolean, "p_requiere_pago_ficha" boolean, "p_observaciones" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."configurar_economia_equipo"("p_equipo_id" "uuid", "p_importe_inscripcion" numeric, "p_admite_fraccionamiento" boolean, "p_requiere_pago_ficha" boolean, "p_observaciones" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."crear_inscripcion_jugador_adulto"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."crear_inscripcion_jugador_adulto"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."declarar_requisito_rffm_realizado"("p_requisito_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."declarar_requisito_rffm_realizado"("p_requisito_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."guardar_asignaciones_entrenador"("p_entrenador_id" "uuid", "p_asignaciones" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."guardar_asignaciones_entrenador"("p_entrenador_id" "uuid", "p_asignaciones" "jsonb") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."guardar_disponibilidad_entrenador"("p_entrenador_id" "uuid", "p_temporada_id" "uuid", "p_disponibilidad" "jsonb", "p_confirmar" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."guardar_disponibilidad_entrenador"("p_entrenador_id" "uuid", "p_temporada_id" "uuid", "p_disponibilidad" "jsonb", "p_confirmar" boolean) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."guardar_entrenador"("p_entrenador_id" "uuid", "p_persona_id" "uuid", "p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_email" "text", "p_telefono" "text", "p_licencia_tipo" "text", "p_licencia_numero" "text", "p_curso_delegado" boolean, "p_activo" boolean, "p_observaciones" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."guardar_entrenador"("p_entrenador_id" "uuid", "p_persona_id" "uuid", "p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_email" "text", "p_telefono" "text", "p_licencia_tipo" "text", "p_licencia_numero" "text", "p_curso_delegado" boolean, "p_activo" boolean, "p_observaciones" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."guardar_persona_admin"("p_persona_id" "uuid", "p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_email" "text", "p_telefono" "text", "p_fecha_nacimiento" "date", "p_activo" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."guardar_persona_admin"("p_persona_id" "uuid", "p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_email" "text", "p_telefono" "text", "p_fecha_nacimiento" "date", "p_activo" boolean) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."inicializar_requisitos_federativos"("p_inscripcion_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."inicializar_requisitos_federativos"("p_inscripcion_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inicializar_requisitos_federativos"("p_inscripcion_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."marcar_no_asiste_cita_rrmm"("p_cita_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."marcar_no_asiste_cita_rrmm"("p_cita_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."modificar_cita_rrmm"("p_cita_id" "uuid", "p_fecha_hora" timestamp with time zone, "p_lugar" "text", "p_direccion" "text", "p_indicaciones" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."modificar_cita_rrmm"("p_cita_id" "uuid", "p_fecha_hora" timestamp with time zone, "p_lugar" "text", "p_direccion" "text", "p_indicaciones" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."obtener_historico_entrenador"("p_entrenador_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."obtener_historico_entrenador"("p_entrenador_id" "uuid") TO "authenticated";



GRANT ALL ON FUNCTION "public"."procesar_mayorias_edad"() TO "authenticated";



GRANT ALL ON FUNCTION "public"."procesar_preparacion_mayoria_edad"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."programar_cita_rrmm"("p_jugador_id" "uuid", "p_fecha_hora" timestamp with time zone, "p_lugar" "text", "p_direccion" "text", "p_indicaciones" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."programar_cita_rrmm"("p_jugador_id" "uuid", "p_fecha_hora" timestamp with time zone, "p_lugar" "text", "p_direccion" "text", "p_indicaciones" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."programar_cita_rrmm_persona"("p_persona_id" "uuid", "p_fecha_hora" timestamp with time zone, "p_lugar" "text", "p_direccion" "text", "p_indicaciones" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."programar_cita_rrmm_persona"("p_persona_id" "uuid", "p_fecha_hora" timestamp with time zone, "p_lugar" "text", "p_direccion" "text", "p_indicaciones" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."registrar_documento_federativo"("p_requisito_id" "uuid", "p_storage_path" "text", "p_nombre_original" "text", "p_mime_type" "text", "p_subtipo" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."registrar_documento_federativo"("p_requisito_id" "uuid", "p_storage_path" "text", "p_nombre_original" "text", "p_mime_type" "text", "p_subtipo" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."registrar_menor"("p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_tipo_documento" "text", "p_numero_documento" "text", "p_email_jugador" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."registrar_menor"("p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_tipo_documento" "text", "p_numero_documento" "text", "p_email_jugador" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."registrar_mi_perfil"("p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_telefono" "text", "p_tipo_alta" "text", "p_tipo_documento" "text", "p_numero_documento" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."registrar_mi_perfil"("p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_telefono" "text", "p_tipo_alta" "text", "p_tipo_documento" "text", "p_numero_documento" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."registrar_pago_inscripcion"("p_inscripcion_id" "uuid", "p_importe" numeric, "p_metodo" "text", "p_fecha_pago" "date", "p_referencia_externa" "text", "p_clubber_pago_id" "text", "p_observaciones" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."registrar_pago_inscripcion"("p_inscripcion_id" "uuid", "p_importe" numeric, "p_metodo" "text", "p_fecha_pago" "date", "p_referencia_externa" "text", "p_clubber_pago_id" "text", "p_observaciones" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."registrar_telemetria_sesion"("p_device_id" "uuid", "p_event" "text", "p_app_version" "text", "p_auth_token_present" boolean, "p_visibility" "text", "p_online" boolean, "p_metadata" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."registrar_telemetria_sesion"("p_device_id" "uuid", "p_event" "text", "p_app_version" "text", "p_auth_token_present" boolean, "p_visibility" "text", "p_online" boolean, "p_metadata" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."registrar_telemetria_sesion"("p_device_id" "uuid", "p_event" "text", "p_app_version" "text", "p_auth_token_present" boolean, "p_visibility" "text", "p_online" boolean, "p_metadata" "jsonb") TO "authenticated";



GRANT ALL ON FUNCTION "public"."responder_autorizacion_entrenador_menor"("p_autorizacion_id" "uuid", "p_aceptar" boolean) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."responder_correcciones_jugador"("p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_telefono" "text", "p_tipo_documento" "text", "p_numero_documento" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."responder_correcciones_jugador"("p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_telefono" "text", "p_tipo_documento" "text", "p_numero_documento" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."responder_correcciones_menor"("p_jugador_id" "uuid", "p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_tipo_documento" "text", "p_numero_documento" "text", "p_email_jugador" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."responder_correcciones_menor"("p_jugador_id" "uuid", "p_nombre" "text", "p_primer_apellido" "text", "p_segundo_apellido" "text", "p_fecha_nacimiento" "date", "p_tipo_documento" "text", "p_numero_documento" "text", "p_email_jugador" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."revisar_requisito_federativo"("p_requisito_id" "uuid", "p_estado" "text", "p_motivo" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."revisar_requisito_federativo"("p_requisito_id" "uuid", "p_estado" "text", "p_motivo" "text") TO "authenticated";



GRANT ALL ON FUNCTION "public"."revocar_autorizacion_entrenador_menor"("p_autorizacion_id" "uuid") TO "authenticated";



GRANT ALL ON FUNCTION "public"."solicitar_autorizacion_entrenador_menor"("p_persona_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."solicitar_correcciones_inscripcion"("p_inscripcion_id" "uuid", "p_mensaje" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."solicitar_correcciones_inscripcion"("p_inscripcion_id" "uuid", "p_mensaje" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."solicitar_nueva_version_requisito"("p_requisito_id" "uuid", "p_motivo" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."solicitar_nueva_version_requisito"("p_requisito_id" "uuid", "p_motivo" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."validar_fraccionamiento_clubber"("p_inscripcion_id" "uuid", "p_validado" boolean, "p_observaciones" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."validar_fraccionamiento_clubber"("p_inscripcion_id" "uuid", "p_validado" boolean, "p_observaciones" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."vincular_auth_persona_por_email_admin"("p_persona_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."vincular_auth_persona_por_email_admin"("p_persona_id" "uuid") TO "authenticated";



GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."asignaciones_entrenador_equipo" TO "authenticated";
GRANT ALL ON TABLE "public"."asignaciones_entrenador_equipo" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."asignaciones_jugador_equipo" TO "authenticated";
GRANT ALL ON TABLE "public"."asignaciones_jugador_equipo" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."auditoria" TO "authenticated";
GRANT ALL ON TABLE "public"."auditoria" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."autorizaciones_menor" TO "authenticated";
GRANT ALL ON TABLE "public"."autorizaciones_menor" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."categorias" TO "authenticated";
GRANT ALL ON TABLE "public"."categorias" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."citas_reconocimiento_medico" TO "authenticated";
GRANT ALL ON TABLE "public"."citas_reconocimiento_medico" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."configuracion_economica_equipo" TO "authenticated";
GRANT ALL ON TABLE "public"."configuracion_economica_equipo" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."configuracion_visual_club" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."configuracion_visual_club" TO "authenticated";
GRANT ALL ON TABLE "public"."configuracion_visual_club" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."documentos" TO "authenticated";
GRANT ALL ON TABLE "public"."documentos" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."documentos_federativos" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."documentos_federativos" TO "authenticated";
GRANT ALL ON TABLE "public"."documentos_federativos" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."documentos_identidad" TO "authenticated";
GRANT ALL ON TABLE "public"."documentos_identidad" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."entrenador_disponibilidad" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."entrenador_disponibilidad" TO "authenticated";
GRANT ALL ON TABLE "public"."entrenador_disponibilidad" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."entrenador_formaciones" TO "anon";
GRANT ALL ON TABLE "public"."entrenador_formaciones" TO "authenticated";
GRANT ALL ON TABLE "public"."entrenador_formaciones" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."entrenador_licencia_equipos" TO "anon";
GRANT ALL ON TABLE "public"."entrenador_licencia_equipos" TO "authenticated";
GRANT ALL ON TABLE "public"."entrenador_licencia_equipos" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."entrenador_licencias_rffm" TO "anon";
GRANT ALL ON TABLE "public"."entrenador_licencias_rffm" TO "authenticated";
GRANT ALL ON TABLE "public"."entrenador_licencias_rffm" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."entrenador_privacidad" TO "anon";
GRANT ALL ON TABLE "public"."entrenador_privacidad" TO "authenticated";
GRANT ALL ON TABLE "public"."entrenador_privacidad" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."entrenador_temporadas" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."entrenador_temporadas" TO "authenticated";
GRANT ALL ON TABLE "public"."entrenador_temporadas" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."entrenadores" TO "authenticated";
GRANT ALL ON TABLE "public"."entrenadores" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."equipos" TO "authenticated";
GRANT ALL ON TABLE "public"."equipos" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."historial_requisitos_federativos" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."historial_requisitos_federativos" TO "authenticated";
GRANT ALL ON TABLE "public"."historial_requisitos_federativos" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."historico_citas_rrmm" TO "authenticated";
GRANT ALL ON TABLE "public"."historico_citas_rrmm" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."historico_estados_inscripcion" TO "authenticated";
GRANT ALL ON TABLE "public"."historico_estados_inscripcion" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."horarios_equipo" TO "anon";
GRANT ALL ON TABLE "public"."horarios_equipo" TO "authenticated";
GRANT ALL ON TABLE "public"."horarios_equipo" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."inscripciones" TO "authenticated";
GRANT ALL ON TABLE "public"."inscripciones" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."jugadores" TO "authenticated";
GRANT ALL ON TABLE "public"."jugadores" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."notificaciones_salida" TO "authenticated";
GRANT ALL ON TABLE "public"."notificaciones_salida" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."pagos_inscripcion" TO "authenticated";
GRANT ALL ON TABLE "public"."pagos_inscripcion" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."persona_roles" TO "authenticated";
GRANT ALL ON TABLE "public"."persona_roles" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."personas" TO "authenticated";
GRANT ALL ON TABLE "public"."personas" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."reconocimientos_medicos" TO "authenticated";
GRANT ALL ON TABLE "public"."reconocimientos_medicos" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."reglas_categoria_temporada" TO "authenticated";
GRANT ALL ON TABLE "public"."reglas_categoria_temporada" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."representaciones_jugador" TO "authenticated";
GRANT ALL ON TABLE "public"."representaciones_jugador" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."requisitos_federativos_inscripcion" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."requisitos_federativos_inscripcion" TO "authenticated";
GRANT ALL ON TABLE "public"."requisitos_federativos_inscripcion" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."roles" TO "authenticated";
GRANT ALL ON TABLE "public"."roles" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."situacion_economica_inscripcion" TO "authenticated";
GRANT ALL ON TABLE "public"."situacion_economica_inscripcion" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."telemetria_sesion_cliente" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."temporadas" TO "authenticated";
GRANT ALL ON TABLE "public"."temporadas" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."vinculos_clubber" TO "authenticated";
GRANT ALL ON TABLE "public"."vinculos_clubber" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "service_role";







