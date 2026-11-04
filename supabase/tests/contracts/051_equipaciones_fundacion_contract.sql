-- Contract for Equipaciones phase 1 foundation.
do $$
declare
  missing integer;
begin
  select count(*) into missing
  from (values
    ('equipacion_articulos'),('equipacion_config_temporada'),('equipacion_packs'),('equipacion_pack_articulos'),
    ('equipacion_tallas_persona'),('equipacion_tallas_excepcion'),('equipacion_necesidades'),('equipacion_dorsales')
  ) v(name)
  where to_regclass('public.'||v.name) is null;
  if missing <> 0 then raise exception 'Equipaciones contract failed: % tables missing', missing; end if;

  if to_regprocedure('private.can_manage_equipacion_tallas(uuid)') is null then
    raise exception 'Equipaciones contract failed: can_manage_equipacion_tallas missing';
  end if;
  if to_regprocedure('private.can_read_equipo_dorsales(uuid)') is null then
    raise exception 'Equipaciones contract failed: can_read_equipo_dorsales missing';
  end if;

  if not exists (select 1 from pg_indexes where schemaname='public' and tablename='equipacion_dorsales' and indexdef ilike '%temporada_id, equipo_id, dorsal%') then
    raise exception 'Equipaciones contract failed: unique team/season dorsal constraint missing';
  end if;

  if exists (
    select 1 from information_schema.role_table_grants
    where table_schema='public' and table_name like 'equipacion_%' and grantee='anon'
  ) then
    raise exception 'Equipaciones contract failed: anon must not have table grants';
  end if;

  if (select count(*) from pg_tables where schemaname='public' and tablename like 'equipacion_%' and rowsecurity) < 8 then
    raise exception 'Equipaciones contract failed: RLS not enabled on all phase-1 tables';
  end if;
end $$;

select '051_equipaciones_fundacion_contract' as contract, 'PASS' as result;
