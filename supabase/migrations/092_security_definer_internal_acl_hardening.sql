-- 092_security_definer_internal_acl_hardening.sql
-- ACL-only hardening. No function bodies, triggers or business logic changed.
begin;
revoke execute on function public.procesar_mayorias_edad() from public, anon, authenticated;
revoke execute on function public.procesar_preparacion_mayoria_edad() from public, anon, authenticated;
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
revoke execute on function public.auditar_cambios_entrenador_v92() from public, anon, authenticated;
revoke execute on function public.trg_inicializar_requisitos_federativos() from public, anon, authenticated;
commit;
