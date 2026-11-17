-- 093_remove_redundant_entrenador_disponibilidad_self_read.sql
-- (admin/club OR self) OR self == (admin/club OR self)
begin;
drop policy if exists entrenador_disponibilidad_self_read on public.entrenador_disponibilidad;
commit;
