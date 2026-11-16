-- 089_security_invoker_operational_views.sql
-- Supabase Advisor hardening: make operational/economic views execute
-- with the privileges and RLS context of the querying user.
-- PRE-089 verified authenticated SELECT on all dependencies and no RLS gaps.

begin;

alter view public.equipacion_compra_sugerida set (security_invoker = true);
alter view public.equipacion_demanda_logistica set (security_invoker = true);
alter view public.equipacion_stock_lotes_disponibles set (security_invoker = true);
alter view public.equipacion_stock_resumen set (security_invoker = true);
alter view public.equipacion_estado_operativo set (security_invoker = true);
alter view public.equipacion_material_persona set (security_invoker = true);
alter view public.equipacion_reparto_resumen set (security_invoker = true);
alter view public.economia_estado_cargos set (security_invoker = true);
alter view public.economia_cuenta_persona_temporada set (security_invoker = true);

commit;
