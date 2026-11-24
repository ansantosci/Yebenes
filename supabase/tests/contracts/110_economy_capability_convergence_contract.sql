-- 110 contract - Economy authorization derives from dedicated capabilities without widening own access.
do $$
declare
  v_count int;
  v_def text;
  v_qual text;
  v_check text;
  r record;
begin
  select count(*) into v_count from private.capacidades where codigo in (
    'economy.read_all','economy.read_own','economy.config.manage','economy.payments.manage','economy.adjustments.manage'
  );
  if v_count<>5 then raise exception '110 contract: missing economy capabilities'; end if;

  -- Club/Admin get the four effective administrative capabilities.
  select count(*) into v_count
  from public.roles ro join private.rol_capacidades rc on rc.rol_id=ro.id
  where ro.codigo in ('administrador','club')
    and rc.capacidad_codigo in ('economy.read_all','economy.config.manage','economy.payments.manage','economy.adjustments.manage');
  if v_count<>8 then raise exception '110 contract: Club/Admin economy matrix incomplete'; end if;

  -- read_own is reserved but deliberately unassigned until own/represented scope is explicitly contracted.
  if exists(select 1 from private.rol_capacidades where capacidad_codigo='economy.read_own') then
    raise exception '110 contract: economy.read_own must remain unassigned';
  end if;
  if exists(
    select 1 from public.roles ro join private.rol_capacidades rc on rc.rol_id=ro.id
    where ro.codigo in ('entrenador','tutor','jugador') and rc.capacidad_codigo like 'economy.%'
  ) then raise exception '110 contract: non administrative roles received economy capability'; end if;

  -- User-invokable economic entry points must use the dedicated capability and not role names.
  for r in select * from (values
    ('private.economia_registrar_pago(uuid,numeric,text,date,text,text)'::regprocedure,'economy.payments.manage'),
    ('private.economia_aplicar_ajuste(uuid,text,numeric,text,text,text)'::regprocedure,'economy.adjustments.manage'),
    ('private.economia_anular_cargo(uuid,text)'::regprocedure,'economy.adjustments.manage'),
    ('private.economia_decidir_regularizacion_hermano(uuid,boolean,text)'::regprocedure,'economy.adjustments.manage'),
    ('private.economia_vincular_hermanos_manual(uuid,uuid,uuid,text)'::regprocedure,'economy.adjustments.manage'),
    ('public.configurar_economia_equipo(uuid,numeric,boolean,boolean,text)'::regprocedure,'economy.config.manage'),
    ('public.registrar_pago_inscripcion(uuid,numeric,text,date,text,text,text)'::regprocedure,'economy.payments.manage'),
    ('public.anular_pago_inscripcion(uuid,text)'::regprocedure,'economy.adjustments.manage'),
    ('public.actualizar_vinculos_clubber(uuid,text,uuid,text)'::regprocedure,'economy.payments.manage'),
    ('public.validar_fraccionamiento_clubber(uuid,boolean,text)'::regprocedure,'economy.payments.manage')
  ) x(proc,cap)
  loop
    select pg_get_functiondef(r.proc) into v_def;
    if position('has_capability('''||r.cap||''')' in v_def)=0 then raise exception '110 contract: % missing %',r.proc,r.cap; end if;
    if position('has_any_role' in v_def)>0 then raise exception '110 contract: % still authorizes by role',r.proc; end if;
  end loop;

  -- Anonymous execution remains forbidden for all mutation entry points.
  if has_function_privilege('anon','private.economia_registrar_pago(uuid,numeric,text,date,text,text)','EXECUTE')
     or has_function_privilege('anon','private.economia_aplicar_ajuste(uuid,text,numeric,text,text,text)','EXECUTE')
     or has_function_privilege('anon','private.economia_anular_cargo(uuid,text)','EXECUTE')
     or has_function_privilege('anon','public.configurar_economia_equipo(uuid,numeric,boolean,boolean,text)','EXECUTE')
     or has_function_privilege('anon','public.registrar_pago_inscripcion(uuid,numeric,text,date,text,text,text)','EXECUTE')
     or has_function_privilege('anon','public.anular_pago_inscripcion(uuid,text)','EXECUTE') then
    raise exception '110 contract: anon can execute economy mutation';
  end if;

  -- Legacy operational reads preserve own/represented access while admin branch converges to read_all.
  select qual into v_qual from pg_policies where schemaname='public' and tablename='pagos_inscripcion' and policyname='pagos_inscripcion_read_authorized';
  if v_qual not like '%economy.read_all%' or v_qual not like '%can_access_inscription_personal%' or v_qual like '%has_any_role%' then raise exception '110 contract: pagos_inscripcion read policy invalid'; end if;
  select qual into v_qual from pg_policies where schemaname='public' and tablename='situacion_economica_inscripcion' and policyname='situacion_economica_read_authorized';
  if v_qual not like '%economy.read_all%' or v_qual not like '%can_access_inscription_personal%' or v_qual like '%has_any_role%' then raise exception '110 contract: situacion_economica read policy invalid'; end if;

  -- 066/067 economy policies must not authorize by role names anymore.
  if exists(
    select 1 from pg_policies
    where schemaname='public' and tablename like 'economia_%'
      and (coalesce(qual,'') like '%has_any_role%' or coalesce(with_check,'') like '%has_any_role%')
  ) then raise exception '110 contract: economy table policy still authorizes by role'; end if;
end $$;
