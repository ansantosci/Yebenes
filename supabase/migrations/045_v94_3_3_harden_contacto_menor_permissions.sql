-- V94.3.3 / ARCH-01 - hardening de permisos del RPC de contacto de menor.
-- 044 ya fue aplicada y es inmutable. Esta migracion corrige exclusivamente ACL.

begin;

revoke all on function public.actualizar_contacto_menor_representado(uuid,text) from public;
revoke all on function public.actualizar_contacto_menor_representado(uuid,text) from anon;
grant execute on function public.actualizar_contacto_menor_representado(uuid,text) to authenticated;

-- Verificacion local de seguridad. Los contract tests post-migracion repiten
-- estas comprobaciones como puerta de promocion del entorno.
do $$
declare
  fn oid;
  auth_oid oid;
  anon_oid oid;
begin
  fn := to_regprocedure('public.actualizar_contacto_menor_representado(uuid,text)');
  if fn is null then
    raise exception '045: RPC actualizar_contacto_menor_representado(uuid,text) no existe';
  end if;

  select oid into auth_oid from pg_roles where rolname='authenticated';
  select oid into anon_oid from pg_roles where rolname='anon';

  if exists (
    select 1
    from pg_proc p,
         lateral aclexplode(coalesce(p.proacl, acldefault('f',p.proowner))) a
    where p.oid=fn
      and a.grantee=0
      and a.privilege_type='EXECUTE'
  ) then
    raise exception '045: PUBLIC conserva EXECUTE sobre actualizar_contacto_menor_representado';
  end if;

  if auth_oid is null or not has_function_privilege(auth_oid,fn,'EXECUTE') then
    raise exception '045: authenticated debe tener EXECUTE sobre actualizar_contacto_menor_representado';
  end if;

  if anon_oid is not null and has_function_privilege(anon_oid,fn,'EXECUTE') then
    raise exception '045: anon no debe tener EXECUTE sobre actualizar_contacto_menor_representado';
  end if;
end
$$;

commit;

select '045_contacto_menor_permissions' as migration, 'PASS' as result;
