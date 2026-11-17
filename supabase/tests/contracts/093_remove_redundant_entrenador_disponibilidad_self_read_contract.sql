-- 093 contract
do $$
declare q text; roles_ name[]; cmd_ text; perm_ text; n integer; stripped text;
begin
 if not exists(select 1 from pg_class c join pg_namespace s on s.oid=c.relnamespace
   where s.nspname='public' and c.relname='entrenador_disponibilidad' and c.relrowsecurity)
 then raise exception '093: RLS disabled'; end if;

 if exists(select 1 from pg_policies where schemaname='public'
   and tablename='entrenador_disponibilidad' and policyname='entrenador_disponibilidad_self_read')
 then raise exception '093: redundant policy still exists'; end if;

 select qual,roles,cmd,permissive into q,roles_,cmd_,perm_
 from pg_policies where schemaname='public' and tablename='entrenador_disponibilidad'
 and policyname='entrenador_disponibilidad_read_v90_1';

 if q is null then raise exception '093: surviving read policy missing'; end if;
 if cmd_<>'SELECT' or perm_<>'PERMISSIVE' or roles_<>array['authenticated']::name[]
 then raise exception '093: surviving policy shape changed'; end if;

 if lower(q)!~'private\.has_any_role' or lower(q)!~'administrador' or lower(q)!~'club'
 then raise exception '093: Club/Admin authorization lost: %',q; end if;

 if lower(q)!~'entrenadores' or lower(q)!~'personas' or lower(q)!~'auth\.uid\s*\(\s*\)'
 then raise exception '093: self authorization lost: %',q; end if;

 if lower(q)!~'\(\s*select\s+auth\.uid\s*\(\s*\)(\s+as\s+uid)?\s*\)'
 then raise exception '093: InitPlan wrapper lost: %',q; end if;

 stripped:=regexp_replace(lower(q),
   '\(\s*select\s+auth\.uid\s*\(\s*\)(\s+as\s+uid)?\s*\)','','g');
 if stripped~'auth\.uid\s*\(\s*\)' then raise exception '093: direct auth.uid remains: %',q; end if;

 select count(*) into n from pg_policies where schemaname='public'
 and tablename='entrenador_disponibilidad' and permissive='PERMISSIVE'
 and cmd='SELECT' and 'authenticated'=any(roles);
 if n<>1 then raise exception '093: expected one authenticated SELECT policy, found %',n; end if;
end $$;
select 'remove_redundant_entrenador_disponibilidad_self_read_contract' contract,'PASS' result;
