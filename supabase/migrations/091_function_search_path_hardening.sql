-- 091_function_search_path_hardening.sql
-- Supabase Advisor hardening for the 16 currently mutable functions.
-- No function bodies or business semantics are changed.
begin;

alter function private.demo_access_persona_id(p_key text) set search_path = pg_catalog, public, private;
alter function private.demo_uuid(p_key text) set search_path = pg_catalog, public, private;
alter function private.test_s_coach_id(p_n bigint) set search_path = pg_catalog, public, private;
alter function private.test_s_coach_id(p_n integer) set search_path = pg_catalog, public, private;
alter function private.test_s_coach_person_id(p_n bigint) set search_path = pg_catalog, public, private;
alter function private.test_s_coach_person_id(p_n integer) set search_path = pg_catalog, public, private;
alter function private.test_s_player_id(p_team_code text, p_slot bigint) set search_path = pg_catalog, public, private;
alter function private.test_s_player_id(p_team_code text, p_slot integer) set search_path = pg_catalog, public, private;
alter function private.test_s_player_person_id(p_team_code text, p_slot bigint) set search_path = pg_catalog, public, private;
alter function private.test_s_player_person_id(p_team_code text, p_slot integer) set search_path = pg_catalog, public, private;
alter function private.test_s_tutor_person_id(p_team_code text) set search_path = pg_catalog, public, private;
alter function private.test_uuid(p_key text) set search_path = pg_catalog, public, private;
alter function private.equipacion_recepcion_linea_inmutable() set search_path = pg_catalog, public, private;
alter function public.calcular_categoria_inscripcion() set search_path = pg_catalog, public, private;
alter function public.set_updated_at() set search_path = pg_catalog, public, private;
alter function public.validar_tutor_menor_inscripcion() set search_path = pg_catalog, public, private;

-- Trigger functions are internal execution surfaces, not client RPCs.
-- Remove direct client execution grants; trigger invocation remains installed.
revoke execute on function private.equipacion_recepcion_linea_inmutable() from public, anon, authenticated;
revoke execute on function public.calcular_categoria_inscripcion() from public, anon, authenticated;
revoke execute on function public.set_updated_at() from public, anon, authenticated;
revoke execute on function public.validar_tutor_menor_inscripcion() from public, anon, authenticated;

commit;
