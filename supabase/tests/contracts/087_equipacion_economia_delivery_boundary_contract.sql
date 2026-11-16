-- Contract 087-style hardening (no schema migration):
-- Equipaciones physical operations must not mutate Economia, and displacement
-- must remain item-scoped. This is a structural regression contract over the
-- effective delivery functions; functional evidence is also captured in the Master.
do $$
declare
  f079 text;
  f082 text;
  f083 text;
  f086 text;
begin
  if to_regprocedure('private.equipacion_entregar_directo(uuid,boolean)') is null then
    raise exception 'equipment/economy: 079 direct-delivery function missing';
  end if;
  if to_regprocedure('private.equipacion_entregar_pack(uuid)') is null then
    raise exception 'equipment/economy: 082 pack-delivery function missing';
  end if;
  if to_regprocedure('private.equipacion_entregar_multiple(uuid[])') is null then
    raise exception 'equipment/economy: 083 multiple-delivery function missing';
  end if;
  if to_regprocedure('private.equipacion_entregar_demanda(jsonb,boolean)') is null then
    raise exception 'equipment/economy: 086 demand-delivery function missing';
  end if;

  select lower(pg_get_functiondef('private.equipacion_entregar_directo(uuid,boolean)'::regprocedure)) into f079;
  select lower(pg_get_functiondef('private.equipacion_entregar_pack(uuid)'::regprocedure)) into f082;
  select lower(pg_get_functiondef('private.equipacion_entregar_multiple(uuid[])'::regprocedure)) into f083;
  select lower(pg_get_functiondef('private.equipacion_entregar_demanda(jsonb,boolean)'::regprocedure)) into f086;

  -- Physical delivery must not write into economic ledgers.
  if f079 ~ 'insert[[:space:]]+into[[:space:]]+public\.economia_' or
     f079 ~ 'update[[:space:]]+public\.economia_' or
     f079 ~ 'delete[[:space:]]+from[[:space:]]+public\.economia_' then
    raise exception 'equipment/economy: 079 mutates Economia';
  end if;
  if f082 ~ 'insert[[:space:]]+into[[:space:]]+public\.economia_' or
     f082 ~ 'update[[:space:]]+public\.economia_' or
     f082 ~ 'delete[[:space:]]+from[[:space:]]+public\.economia_' then
    raise exception 'equipment/economy: 082 mutates Economia';
  end if;
  if f083 ~ 'insert[[:space:]]+into[[:space:]]+public\.economia_' or
     f083 ~ 'update[[:space:]]+public\.economia_' or
     f083 ~ 'delete[[:space:]]+from[[:space:]]+public\.economia_' then
    raise exception 'equipment/economy: 083 mutates Economia';
  end if;
  if f086 ~ 'insert[[:space:]]+into[[:space:]]+public\.economia_' or
     f086 ~ 'update[[:space:]]+public\.economia_' or
     f086 ~ 'delete[[:space:]]+from[[:space:]]+public\.economia_' then
    raise exception 'equipment/economy: 086 mutates Economia';
  end if;

  -- 086 must delegate displacement semantics to 079 rather than reimplement them.
  if position('equipacion_entregar_directo' in f086)=0 then
    raise exception 'equipment/economy: 086 no longer delegates direct delivery to 079';
  end if;

  -- 079 must retain explicit opt-in displacement.
  if position('p_permitir_desplazar' in f079)=0 then
    raise exception 'equipment/economy: 079 displacement is no longer explicit';
  end if;
end $$;

select 'equipacion_economia_delivery_boundary_contract' contract,'PASS' result;
