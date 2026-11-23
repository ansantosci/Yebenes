-- Contract 108: targeted RBAC convergence must remain capability-based.
begin;

DO $$
DECLARE
  fn text;
BEGIN
  SELECT pg_get_functiondef('private.can_read_equipo_dorsales(uuid)'::regprocedure) INTO fn;

  IF position('private.has_capability(''equipment.manage'')' in fn) = 0 THEN
    RAISE EXCEPTION '108 contract: can_read_equipo_dorsales must require equipment.manage for administrative access';
  END IF;

  IF position('asignaciones_entrenador_equipo' in fn) = 0
     OR position('a.equipo_id=target_equipo_id' in replace(fn, ' ', '')) = 0 THEN
    RAISE EXCEPTION '108 contract: assigned-coach team scope must be preserved';
  END IF;

  IF position('has_any_role' in fn) > 0
     OR position('administrador' in lower(fn)) > 0
     OR position('club' in lower(fn)) > 0 THEN
    RAISE EXCEPTION '108 contract: role-name authorization reintroduced in can_read_equipo_dorsales';
  END IF;
END $$;

-- Canonical capabilities consumed by the converged Edge Functions must exist.
DO $$
DECLARE
  missing text[];
BEGIN
  SELECT array_agg(req.code ORDER BY req.code)
  INTO missing
  FROM (VALUES ('people.manage'),('coaches.manage'),('medical.manage'),('players.manage'),('equipment.manage')) AS req(code)
  LEFT JOIN private.capacidades c ON c.codigo=req.code
  WHERE c.codigo IS NULL;

  IF missing IS NOT NULL THEN
    RAISE EXCEPTION '108 contract: missing canonical capabilities: %', missing;
  END IF;
END $$;

rollback;
