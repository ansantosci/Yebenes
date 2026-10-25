-- Contract for migration 044: represented minor contact update RPC.
do $$
declare
  fn oid;
  auth_oid oid;
  anon_oid oid;
  is_secdef boolean;
  public_execute boolean;
  auth_execute boolean;
  anon_execute boolean;
begin
  fn := to_regprocedure('public.actualizar_contacto_menor_representado(uuid,text)');
  if fn is null then
    raise exception 'CONTRACT FAIL: expected RPC public.actualizar_contacto_menor_representado(uuid,text) does not exist';
  end if;

  select p.prosecdef into is_secdef from pg_proc p where p.oid=fn;
  if is_secdef is distinct from true then
    raise exception 'CONTRACT FAIL: actualizar_contacto_menor_representado must be SECURITY DEFINER';
  end if;

  select oid into auth_oid from pg_roles where rolname='authenticated';
  select oid into anon_oid from pg_roles where rolname='anon';
  if auth_oid is null or anon_oid is null then
    raise exception 'CONTRACT FAIL: expected Supabase roles authenticated/anon are missing';
  end if;

  select exists (
    select 1
    from aclexplode(coalesce(p.proacl, acldefault('f',p.proowner))) a
    where a.grantee=0 and a.privilege_type='EXECUTE'
  ) into public_execute
  from pg_proc p where p.oid=fn;

  select has_function_privilege(auth_oid, fn, 'EXECUTE') into auth_execute;
  select has_function_privilege(anon_oid, fn, 'EXECUTE') into anon_execute;

  if public_execute then
    raise exception 'CONTRACT FAIL: PUBLIC must not have EXECUTE on actualizar_contacto_menor_representado';
  end if;
  if auth_execute is distinct from true then
    raise exception 'CONTRACT FAIL: authenticated must have EXECUTE on actualizar_contacto_menor_representado';
  end if;
  if anon_execute then
    raise exception 'CONTRACT FAIL: anon must not have EXECUTE on actualizar_contacto_menor_representado';
  end if;
end
$$;

select '044_contacto_menor_contract' as contract, 'PASS' as result;
