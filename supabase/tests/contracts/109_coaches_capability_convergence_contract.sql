-- 109_coaches_capability_convergence_contract.sql
-- Regression contract for coach-domain capability convergence.
do $$
declare
  v_assign text;
  v_save text;
begin
  select pg_get_functiondef('public.asignar_rol_entrenador(uuid,text,text,boolean,boolean,text)'::regprocedure) into v_assign;
  select pg_get_functiondef('public.guardar_asignaciones_entrenador(uuid,jsonb)'::regprocedure) into v_save;

  if position('has_capability(''coaches.manage'')' in v_assign) = 0 then
    raise exception '109 contract: asignar_rol_entrenador must require coaches.manage';
  end if;
  if position('has_any_role' in v_assign) > 0 or position('administrador' in lower(v_assign)) > 0 or position('club' in lower(v_assign)) > 0 then
    raise exception '109 contract: asignar_rol_entrenador must not authorize by role name';
  end if;
  if position('has_capability(''coaches.manage'')' in v_save) = 0 then
    raise exception '109 contract: guardar_asignaciones_entrenador must require coaches.manage';
  end if;
  if position('has_any_role' in v_save) > 0 or position('administrador' in lower(v_save)) > 0 or position('club' in lower(v_save)) > 0 then
    raise exception '109 contract: guardar_asignaciones_entrenador must not authorize by role name';
  end if;
end $$;
