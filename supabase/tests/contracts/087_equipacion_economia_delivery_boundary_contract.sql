-- Contract 087: Equipaciones physical delivery/displacement must not mutate Economia.
-- Structural regression contract over the effective functions as of 079/082/083/086.
do $$
declare
  f079 text;
  f083 text;
  f082 text;
  f086 text;
begin
  if to_regprocedure('private.equipacion_entregar_directo(uuid,boolean)') is null then
    raise exception 'equipment/economy: 079 direct-delivery function missing';
  end if;
  if to_regprocedure('private.equipacion_entregar_multiple(uuid[],uuid[])') is null then
    raise exception 'equipment/economy: 083 private multiple-delivery function missing';
  end if;
  if to_regprocedure('public.equipacion_entregar_multiple(uuid[],uuid[])') is null then
    raise exception 'equipment/economy: 082 public multiple-delivery wrapper missing';
  end if;
  if to_regprocedure('private.equipacion_entregar_demanda(jsonb,boolean)') is null then
    raise exception 'equipment/economy: 086 demand-delivery function missing';
  end if;

  select lower(pg_get_functiondef('private.equipacion_entregar_directo(uuid,boolean)'::regprocedure)) into f079;
  select lower(pg_get_functiondef('private.equipacion_entregar_multiple(uuid[],uuid[])'::regprocedure)) into f083;
  select lower(pg_get_functiondef('public.equipacion_entregar_multiple(uuid[],uuid[])'::regprocedure)) into f082;
  select lower(pg_get_functiondef('private.equipacion_entregar_demanda(jsonb,boolean)'::regprocedure)) into f086;

  -- Physical operations must not write into economic ledgers.
  if f079 ~ '(insert[[:space:]]+into|update|delete[[:space:]]+from)[[:space:]]+public\.economia_' then
    raise exception 'equipment/economy: 079 mutates Economia';
  end if;
  if f083 ~ '(insert[[:space:]]+into|update|delete[[:space:]]+from)[[:space:]]+public\.economia_' then
    raise exception 'equipment/economy: 083 mutates Economia';
  end if;
  if f082 ~ '(insert[[:space:]]+into|update|delete[[:space:]]+from)[[:space:]]+public\.economia_' then
    raise exception 'equipment/economy: 082 mutates Economia';
  end if;
  if f086 ~ '(insert[[:space:]]+into|update|delete[[:space:]]+from)[[:space:]]+public\.economia_' then
    raise exception 'equipment/economy: 086 mutates Economia';
  end if;

  -- 082 remains a thin public wrapper over the corrected private operation.
  if position('private.equipacion_entregar_multiple' in f082)=0 then
    raise exception 'equipment/economy: 082 no longer delegates to private multiple delivery';
  end if;

  -- 083 must keep explicit per-assignment displacement authorization and compose 079.
  if position('p_desplazamiento_autorizado' in f083)=0
     or position('equipacion_entregar_directo' in f083)=0 then
    raise exception 'equipment/economy: 083 displacement contract incomplete';
  end if;

  -- 086 demand delivery must delegate displacement semantics to 079.
  if position('equipacion_entregar_directo' in f086)=0
     or position('p_permitir_desplazar' in f086)=0 then
    raise exception 'equipment/economy: 086 displacement delegation incomplete';
  end if;
end $$;

select 'equipacion_economia_delivery_boundary_contract' contract,'PASS' result;
