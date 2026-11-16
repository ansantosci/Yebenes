-- 088_security_hardening_acl_views_indexes.sql
-- Conservative hardening derived from Supabase Advisor diagnostics.
-- No business data changes. No RLS policy rewrites. No security_invoker conversion yet.
begin;

-- 1) Remove anonymous/PUBLIC execution from SECURITY DEFINER objects that require a session
--    or are internal trigger/helper functions. Telemetry is deliberately excluded because
--    the client emits boot/login diagnostics before a session can exist.
revoke execute on function private.ajustar_requisitos_por_mayoria_edad() from public, anon;
revoke execute on function private.autorizacion_entrenador_menor_vigente(p_persona_id uuid) from public, anon;
revoke execute on function private.can_manage_equipacion_tallas(target_persona_id uuid) from public, anon;
revoke execute on function private.can_read_equipo_dorsales(target_equipo_id uuid) from public, anon;
revoke execute on function private.equipacion_ajustar_stock(p_temporada uuid, p_articulo uuid, p_talla text, p_delta integer) from public, anon;
revoke execute on function private.equipacion_aplicar_recepcion_linea_lote_personalizado() from public, anon;
revoke execute on function private.equipacion_recalcular_estado_pedido(p_pedido uuid) from public, anon;
revoke execute on function private.equipacion_reservar_asignacion(p_asignacion uuid) from public, anon;
revoke execute on function private.recalcular_estado_inscripcion(p_inscripcion_id uuid) from public, anon;
revoke execute on function private.trg_entrenador_legacy_v84() from public, anon;
revoke execute on function private.trg_recalcular_economia_asignacion() from public, anon;
revoke execute on function private.trg_recalcular_economia_pago() from public, anon;
revoke execute on function private.trg_recalcular_estado_economia() from public, anon;
revoke execute on function private.trg_recalcular_estado_equipo() from public, anon;
revoke execute on function private.trg_recalcular_estado_inscripcion_estado() from public, anon;
revoke execute on function private.trg_recalcular_estado_requisito() from public, anon;
revoke execute on function private.trg_rrmm_persona_v84() from public, anon;
revoke execute on function private.trg_rrmm_v83() from public, anon;
revoke execute on function public.actualizar_jugador_autorrepresentado(p_nombre text, p_primer_apellido text, p_segundo_apellido text, p_fecha_nacimiento date, p_telefono text, p_tipo_documento text, p_numero_documento text) from public, anon;
revoke execute on function public.actualizar_menor_representado(p_jugador_id uuid, p_nombre text, p_primer_apellido text, p_segundo_apellido text, p_fecha_nacimiento date, p_tipo_documento text, p_numero_documento text, p_email_jugador text) from public, anon;
revoke execute on function public.actualizar_perfiles_persona_admin(p_persona_id uuid, p_administrador boolean, p_club boolean, p_entrenador boolean, p_jugador boolean) from public, anon;
revoke execute on function public.actualizar_vinculos_clubber(p_jugador_id uuid, p_clubber_deportista_id text, p_tutor_persona_id uuid, p_clubber_tutor_id text) from public, anon;
revoke execute on function public.anular_pago_inscripcion(p_pago_id uuid, p_motivo text) from public, anon;
revoke execute on function public.asignar_rol_entrenador(p_persona_id uuid, p_licencia_tipo text, p_licencia_numero text, p_curso_delegado boolean, p_activo boolean, p_observaciones text) from public, anon;
revoke execute on function public.auditar_cambios_entrenador_v92() from public, anon;
revoke execute on function public.cancelar_cita_rrmm(p_cita_id uuid) from public, anon;
revoke execute on function public.configurar_economia_equipo(p_equipo_id uuid, p_importe_inscripcion numeric, p_admite_fraccionamiento boolean, p_requiere_pago_ficha boolean, p_observaciones text) from public, anon;
revoke execute on function public.crear_inscripcion_jugador_adulto() from public, anon;
revoke execute on function public.declarar_requisito_rffm_realizado(p_requisito_id uuid) from public, anon;
revoke execute on function public.guardar_asignaciones_entrenador(p_entrenador_id uuid, p_asignaciones jsonb) from public, anon;
revoke execute on function public.guardar_disponibilidad_entrenador(p_entrenador_id uuid, p_temporada_id uuid, p_disponibilidad jsonb, p_confirmar boolean) from public, anon;
revoke execute on function public.guardar_entrenador(p_entrenador_id uuid, p_persona_id uuid, p_nombre text, p_primer_apellido text, p_segundo_apellido text, p_email text, p_telefono text, p_licencia_tipo text, p_licencia_numero text, p_curso_delegado boolean, p_activo boolean, p_observaciones text) from public, anon;
revoke execute on function public.guardar_persona_admin(p_persona_id uuid, p_nombre text, p_primer_apellido text, p_segundo_apellido text, p_email text, p_telefono text, p_fecha_nacimiento date, p_activo boolean) from public, anon;
revoke execute on function public.inicializar_requisitos_federativos(p_inscripcion_id uuid) from public, anon;
revoke execute on function public.marcar_no_asiste_cita_rrmm(p_cita_id uuid) from public, anon;
revoke execute on function public.modificar_cita_rrmm(p_cita_id uuid, p_fecha_hora timestamp with time zone, p_lugar text, p_direccion text, p_indicaciones text) from public, anon;
revoke execute on function public.obtener_historico_entrenador(p_entrenador_id uuid) from public, anon;
revoke execute on function public.procesar_mayorias_edad() from public, anon;
revoke execute on function public.procesar_preparacion_mayoria_edad() from public, anon;
revoke execute on function public.programar_cita_rrmm(p_jugador_id uuid, p_fecha_hora timestamp with time zone, p_lugar text, p_direccion text, p_indicaciones text) from public, anon;
revoke execute on function public.programar_cita_rrmm_persona(p_persona_id uuid, p_fecha_hora timestamp with time zone, p_lugar text, p_direccion text, p_indicaciones text) from public, anon;
revoke execute on function public.registrar_documento_federativo(p_requisito_id uuid, p_storage_path text, p_nombre_original text, p_mime_type text, p_subtipo text) from public, anon;
revoke execute on function public.registrar_menor(p_nombre text, p_primer_apellido text, p_segundo_apellido text, p_fecha_nacimiento date, p_tipo_documento text, p_numero_documento text, p_email_jugador text) from public, anon;
revoke execute on function public.registrar_mi_perfil(p_nombre text, p_primer_apellido text, p_segundo_apellido text, p_fecha_nacimiento date, p_telefono text, p_tipo_alta text, p_tipo_documento text, p_numero_documento text) from public, anon;
revoke execute on function public.registrar_pago_inscripcion(p_inscripcion_id uuid, p_importe numeric, p_metodo text, p_fecha_pago date, p_referencia_externa text, p_clubber_pago_id text, p_observaciones text) from public, anon;
revoke execute on function public.responder_autorizacion_entrenador_menor(p_autorizacion_id uuid, p_aceptar boolean) from public, anon;
revoke execute on function public.responder_correcciones_jugador(p_nombre text, p_primer_apellido text, p_segundo_apellido text, p_fecha_nacimiento date, p_telefono text, p_tipo_documento text, p_numero_documento text) from public, anon;
revoke execute on function public.responder_correcciones_menor(p_jugador_id uuid, p_nombre text, p_primer_apellido text, p_segundo_apellido text, p_fecha_nacimiento date, p_tipo_documento text, p_numero_documento text, p_email_jugador text) from public, anon;
revoke execute on function public.revisar_requisito_federativo(p_requisito_id uuid, p_estado text, p_motivo text) from public, anon;
revoke execute on function public.revocar_autorizacion_entrenador_menor(p_autorizacion_id uuid) from public, anon;
revoke execute on function public.rls_auto_enable() from public, anon;
revoke execute on function public.solicitar_autorizacion_entrenador_menor(p_persona_id uuid) from public, anon;
revoke execute on function public.solicitar_correcciones_inscripcion(p_inscripcion_id uuid, p_mensaje text) from public, anon;
revoke execute on function public.solicitar_nueva_version_requisito(p_requisito_id uuid, p_motivo text) from public, anon;
revoke execute on function public.trg_inicializar_requisitos_federativos() from public, anon;
revoke execute on function public.validar_fraccionamiento_clubber(p_inscripcion_id uuid, p_validado boolean, p_observaciones text) from public, anon;
revoke execute on function public.vincular_auth_persona_por_email_admin(p_persona_id uuid) from public, anon;

-- 2) Restore only the intended callable surface.
-- Public RPCs remain available to signed-in users; their existing in-function role/ownership
-- checks remain authoritative. service_role is retained for operational/backend use.
grant execute on function public.actualizar_jugador_autorrepresentado(p_nombre text, p_primer_apellido text, p_segundo_apellido text, p_fecha_nacimiento date, p_telefono text, p_tipo_documento text, p_numero_documento text) to authenticated, service_role;
grant execute on function public.actualizar_menor_representado(p_jugador_id uuid, p_nombre text, p_primer_apellido text, p_segundo_apellido text, p_fecha_nacimiento date, p_tipo_documento text, p_numero_documento text, p_email_jugador text) to authenticated, service_role;
grant execute on function public.actualizar_perfiles_persona_admin(p_persona_id uuid, p_administrador boolean, p_club boolean, p_entrenador boolean, p_jugador boolean) to authenticated, service_role;
grant execute on function public.actualizar_vinculos_clubber(p_jugador_id uuid, p_clubber_deportista_id text, p_tutor_persona_id uuid, p_clubber_tutor_id text) to authenticated, service_role;
grant execute on function public.anular_pago_inscripcion(p_pago_id uuid, p_motivo text) to authenticated, service_role;
grant execute on function public.asignar_rol_entrenador(p_persona_id uuid, p_licencia_tipo text, p_licencia_numero text, p_curso_delegado boolean, p_activo boolean, p_observaciones text) to authenticated, service_role;
grant execute on function public.cancelar_cita_rrmm(p_cita_id uuid) to authenticated, service_role;
grant execute on function public.configurar_economia_equipo(p_equipo_id uuid, p_importe_inscripcion numeric, p_admite_fraccionamiento boolean, p_requiere_pago_ficha boolean, p_observaciones text) to authenticated, service_role;
grant execute on function public.crear_inscripcion_jugador_adulto() to authenticated, service_role;
grant execute on function public.declarar_requisito_rffm_realizado(p_requisito_id uuid) to authenticated, service_role;
grant execute on function public.guardar_asignaciones_entrenador(p_entrenador_id uuid, p_asignaciones jsonb) to authenticated, service_role;
grant execute on function public.guardar_disponibilidad_entrenador(p_entrenador_id uuid, p_temporada_id uuid, p_disponibilidad jsonb, p_confirmar boolean) to authenticated, service_role;
grant execute on function public.guardar_entrenador(p_entrenador_id uuid, p_persona_id uuid, p_nombre text, p_primer_apellido text, p_segundo_apellido text, p_email text, p_telefono text, p_licencia_tipo text, p_licencia_numero text, p_curso_delegado boolean, p_activo boolean, p_observaciones text) to authenticated, service_role;
grant execute on function public.guardar_persona_admin(p_persona_id uuid, p_nombre text, p_primer_apellido text, p_segundo_apellido text, p_email text, p_telefono text, p_fecha_nacimiento date, p_activo boolean) to authenticated, service_role;
grant execute on function public.inicializar_requisitos_federativos(p_inscripcion_id uuid) to authenticated, service_role;
grant execute on function public.marcar_no_asiste_cita_rrmm(p_cita_id uuid) to authenticated, service_role;
grant execute on function public.modificar_cita_rrmm(p_cita_id uuid, p_fecha_hora timestamp with time zone, p_lugar text, p_direccion text, p_indicaciones text) to authenticated, service_role;
grant execute on function public.obtener_historico_entrenador(p_entrenador_id uuid) to authenticated, service_role;
grant execute on function public.procesar_mayorias_edad() to authenticated, service_role;
grant execute on function public.procesar_preparacion_mayoria_edad() to authenticated, service_role;
grant execute on function public.programar_cita_rrmm(p_jugador_id uuid, p_fecha_hora timestamp with time zone, p_lugar text, p_direccion text, p_indicaciones text) to authenticated, service_role;
grant execute on function public.programar_cita_rrmm_persona(p_persona_id uuid, p_fecha_hora timestamp with time zone, p_lugar text, p_direccion text, p_indicaciones text) to authenticated, service_role;
grant execute on function public.registrar_documento_federativo(p_requisito_id uuid, p_storage_path text, p_nombre_original text, p_mime_type text, p_subtipo text) to authenticated, service_role;
grant execute on function public.registrar_menor(p_nombre text, p_primer_apellido text, p_segundo_apellido text, p_fecha_nacimiento date, p_tipo_documento text, p_numero_documento text, p_email_jugador text) to authenticated, service_role;
grant execute on function public.registrar_mi_perfil(p_nombre text, p_primer_apellido text, p_segundo_apellido text, p_fecha_nacimiento date, p_telefono text, p_tipo_alta text, p_tipo_documento text, p_numero_documento text) to authenticated, service_role;
grant execute on function public.registrar_pago_inscripcion(p_inscripcion_id uuid, p_importe numeric, p_metodo text, p_fecha_pago date, p_referencia_externa text, p_clubber_pago_id text, p_observaciones text) to authenticated, service_role;
grant execute on function public.responder_autorizacion_entrenador_menor(p_autorizacion_id uuid, p_aceptar boolean) to authenticated, service_role;
grant execute on function public.responder_correcciones_jugador(p_nombre text, p_primer_apellido text, p_segundo_apellido text, p_fecha_nacimiento date, p_telefono text, p_tipo_documento text, p_numero_documento text) to authenticated, service_role;
grant execute on function public.responder_correcciones_menor(p_jugador_id uuid, p_nombre text, p_primer_apellido text, p_segundo_apellido text, p_fecha_nacimiento date, p_tipo_documento text, p_numero_documento text, p_email_jugador text) to authenticated, service_role;
grant execute on function public.revisar_requisito_federativo(p_requisito_id uuid, p_estado text, p_motivo text) to authenticated, service_role;
grant execute on function public.revocar_autorizacion_entrenador_menor(p_autorizacion_id uuid) to authenticated, service_role;
grant execute on function public.solicitar_autorizacion_entrenador_menor(p_persona_id uuid) to authenticated, service_role;
grant execute on function public.solicitar_correcciones_inscripcion(p_inscripcion_id uuid, p_mensaje text) to authenticated, service_role;
grant execute on function public.solicitar_nueva_version_requisito(p_requisito_id uuid, p_motivo text) to authenticated, service_role;
grant execute on function public.validar_fraccionamiento_clubber(p_inscripcion_id uuid, p_validado boolean, p_observaciones text) to authenticated, service_role;
grant execute on function public.vincular_auth_persona_por_email_admin(p_persona_id uuid) to authenticated, service_role;

-- RLS/access helpers that are intentionally evaluated for signed-in users.
grant execute on function private.autorizacion_entrenador_menor_vigente(p_persona_id uuid) to authenticated, service_role;
grant execute on function private.can_manage_equipacion_tallas(target_persona_id uuid) to authenticated, service_role;
grant execute on function private.can_read_equipo_dorsales(target_equipo_id uuid) to authenticated, service_role;

-- 3) Economic views must never be readable by an anonymous session.
revoke all on table public.economia_estado_cargos from anon;
revoke all on table public.economia_cuenta_persona_temporada from anon;
grant select on table public.economia_estado_cargos to authenticated, service_role;
grant select on table public.economia_cuenta_persona_temporada to authenticated, service_role;

-- 4) Remove the redundant unique index. The UNIQUE constraint-backed
--    entrenadores_persona_id_key remains the source of uniqueness.
drop index if exists public.entrenadores_persona_id_uniq;

commit;
