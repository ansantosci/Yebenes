-- RFFM 2026/27: carga idempotente de configuracion federativa por equipo canonico TEST-BASE.
-- Fuente funcional: catalogo verificado de yebenes_rffm_web_v27.
-- IMPORTANTE: esta carga SOLO es valida para la temporada Yebenes 2026/2027 / RFFM season 22.
-- No copiar estos competition_id/group_id a temporadas posteriores.

begin;

do $$
declare
  v_season_id constant uuid := 'f6b07c5c-9f57-44f4-a20d-189ab8608eac';
  v_count integer;
begin
  if not exists (
    select 1 from public.temporadas
    where id=v_season_id and nombre='2026/2027' and anio_inicio=2026 and anio_fin=2027
  ) then
    raise exception 'RFFM 2026/27 guard: canonical season is missing or does not match 2026/2027';
  end if;

  -- Validar las 23 correspondencias explicitas de v27, no la cardinalidad global de equipos.
  -- TEST-S puede contener equipos auxiliares de otros escenarios (p. ej. ECONOMIA).
  select count(*) into v_count
  from public.equipos
  where temporada_id=v_season_id
    and activo
    and id = any(array[
      'f951e14a-dc0e-43fd-8f58-36cb68aa378b'::uuid,
      '93e08be0-cab1-4003-81b2-52d1cb4116f5'::uuid,
      'ef3577eb-dd74-455a-9202-2aa813ec0800'::uuid,
      '7776e2ac-9bb7-4008-8401-40ea8d471d2c'::uuid,
      '7492314d-9a6f-4c8c-ad50-c5ac830ec23d'::uuid,
      '03f79079-4523-4803-8af9-b8c3cb4513aa'::uuid,
      '7a48e397-b059-4eab-aab0-1d4395c9093d'::uuid,
      '9c42c5ca-b331-4a68-a175-eec82e723a30'::uuid,
      'b70a6dee-7b26-40f4-a924-92c6df39e472'::uuid,
      '9b6ee4c4-0dec-4a7c-b647-a6f97667f896'::uuid,
      '566f2474-9d3e-44d3-9a23-40079e8e3f04'::uuid,
      '3317e7ac-ae6c-4bf1-8605-cacae92fa8ca'::uuid,
      '4cf8a784-fead-4208-b4a3-2b7c5db5477c'::uuid,
      '56b6183d-a492-493c-b764-51e67846493b'::uuid,
      'e21f6c94-fadd-4412-8058-2970bc5a480e'::uuid,
      'd0b8b571-5891-4cfe-9c16-8722144c8f08'::uuid,
      'de597922-5e76-415f-8824-9bef995c4fb1'::uuid,
      '95bd3687-2606-4573-b1a2-3fb62f0447fd'::uuid,
      '56546387-63e6-4cf1-87a5-9c2ff1af17e1'::uuid,
      '6a93f6ba-eda4-49a1-87c1-e12df4fad3cb'::uuid,
      'ecc0f268-c155-46f2-a04c-bb3d5d910b55'::uuid,
      'ce5c092d-f058-4ea8-b061-b01019b181f7'::uuid,
      '4e419c93-e881-4e83-908e-4597563950ff'::uuid
    ]::uuid[]);
  if v_count <> 23 then
    raise exception 'RFFM 2026/27 guard: expected the 23 explicit v27 teams to exist and be active, found %', v_count;
  end if;

  if not exists (
    select 1 from public.equipos
    where id='56b6183d-a492-493c-b764-51e67846493b'::uuid
      and temporada_id=v_season_id and nombre='Veteranos Masculino' and codigo='VET-M'
      and categoria_id='46675387-012d-47b7-ad79-2a34175a618f'::uuid
      and genero='masculino' and modalidad='F11'
  ) then
    raise exception 'RFFM 2026/27 guard: Veteranos Masculino canonical correction has not been applied';
  end if;
end $$;

with mappings(equipo_id, competition_id, group_id, game_type, external_team_id, label) as (
  values
    ('f951e14a-dc0e-43fd-8f58-36cb68aa378b'::uuid,'26737701','26737705','1',null::text,'PREFERENTE AFICIONADO'),
    ('93e08be0-cab1-4003-81b2-52d1cb4116f5'::uuid,'26738300','26738322','1',null,'SEGUNDA AFICIONADO'),
    ('ef3577eb-dd74-455a-9202-2aa813ec0800'::uuid,'26737715','26834942','1',null,'PRIMERA DIVISION AUTONOMICA JUVENIL'),
    ('7776e2ac-9bb7-4008-8401-40ea8d471d2c'::uuid,'26737724','27173681','1',null,'PRIMERA JUVENIL'),
    ('7492314d-9a6f-4c8c-ad50-c5ac830ec23d'::uuid,'26737742','26737749','1',null,'PREFERENTE CADETE'),
    ('03f79079-4523-4803-8af9-b8c3cb4513aa'::uuid,'26737768','26737807','1',null,'SEGUNDA CADETE'),
    ('7a48e397-b059-4eab-aab0-1d4395c9093d'::uuid,'26737819','26737825','1',null,'PREFERENTE INFANTIL'),
    ('9c42c5ca-b331-4a68-a175-eec82e723a30'::uuid,'26737874','26737877','1',null,'PRIMERA FUTBOL FEMENINO'),
    ('b70a6dee-7b26-40f4-a924-92c6df39e472'::uuid,'26737890','26737894','1',null,'PRIMERA FEMENINO CADETE'),
    ('9b6ee4c4-0dec-4a7c-b647-a6f97667f896'::uuid,'26737926','26800642','2',null,'PREFERENTE BENJAMIN F-7'),
    ('566f2474-9d3e-44d3-9a23-40079e8e3f04'::uuid,'26737926','26800642','2',null,'PREFERENTE BENJAMIN F-7'),
    ('3317e7ac-ae6c-4bf1-8605-cacae92fa8ca'::uuid,'26738323','27133798','1',null,'SEGUNDA JUVENIL'),
    ('4cf8a784-fead-4208-b4a3-2b7c5db5477c'::uuid,'26738324','26738355','1',null,'SEGUNDA INFANTIL'),
    ('56b6183d-a492-493c-b764-51e67846493b'::uuid,'26738269','26738270','1',null,'VETERANOS MASCULINO F11 - MOVEMBER'),
    ('e21f6c94-fadd-4412-8058-2970bc5a480e'::uuid,'26738132','26738140','2','307756','PREFERENTE ALEVIN F-7'),
    ('d0b8b571-5891-4cfe-9c16-8722144c8f08'::uuid,'26738071','26738094','2','13564961','SEGUNDA ALEVIN F-7'),
    ('de597922-5e76-415f-8824-9bef995c4fb1'::uuid,'26738167','26738176','2',null,'PREBENJAMIN F-7 DESARROLLO'),
    ('95bd3687-2606-4573-b1a2-3fb62f0447fd'::uuid,'26737899','26750939','2',null,'PREFERENTE FEMENINO INFANTIL F-7'),
    ('56546387-63e6-4cf1-87a5-9c2ff1af17e1'::uuid,'26738029','28766865','4',null,'DEBUTANTE'),
    ('6a93f6ba-eda4-49a1-87c1-e12df4fad3cb'::uuid,'26737768','27325526','1',null,'SEGUNDA CADETE'),
    ('ecc0f268-c155-46f2-a04c-bb3d5d910b55'::uuid,'26737859','27325583','1',null,'PRIMERA ALEVIN'),
    ('ce5c092d-f058-4ea8-b061-b01019b181f7'::uuid,'26737943','27597735','2',null,'PRIMERA BENJAMIN F-7'),
    ('4e419c93-e881-4e83-908e-4597563950ff'::uuid,'26797573','28157850','2',null,'PREBENJAMIN F7 INICIACION')
), checked as (
  select m.*
  from mappings m
  join public.equipos e on e.id=m.equipo_id
  where e.temporada_id='f6b07c5c-9f57-44f4-a20d-189ab8608eac'::uuid and e.activo
), upserted as (
  insert into public.equipo_integraciones_federacion
    (equipo_id,proveedor,competition_id,group_id,game_type,external_team_id,config,activo)
  select equipo_id,'RFFM',competition_id,group_id,game_type,external_team_id,
         jsonb_build_object('season_id','22','source','yebenes_rffm_web_v27','season_scope','2026/2027','competition_label',label),true
  from checked
  on conflict (equipo_id,proveedor) do update set
    competition_id=excluded.competition_id,
    group_id=excluded.group_id,
    game_type=excluded.game_type,
    external_team_id=excluded.external_team_id,
    config=excluded.config,
    activo=true,
    ultima_validacion_at=case
      when public.equipo_integraciones_federacion.competition_id=excluded.competition_id
       and public.equipo_integraciones_federacion.group_id=excluded.group_id
       and public.equipo_integraciones_federacion.game_type=excluded.game_type
       and coalesce(public.equipo_integraciones_federacion.external_team_id,'')=coalesce(excluded.external_team_id,'')
      then public.equipo_integraciones_federacion.ultima_validacion_at else null end,
    ultima_validacion_ok=case
      when public.equipo_integraciones_federacion.competition_id=excluded.competition_id
       and public.equipo_integraciones_federacion.group_id=excluded.group_id
       and public.equipo_integraciones_federacion.game_type=excluded.game_type
       and coalesce(public.equipo_integraciones_federacion.external_team_id,'')=coalesce(excluded.external_team_id,'')
      then public.equipo_integraciones_federacion.ultima_validacion_ok else null end,
    ultima_validacion_mensaje=case
      when public.equipo_integraciones_federacion.competition_id=excluded.competition_id
       and public.equipo_integraciones_federacion.group_id=excluded.group_id
       and public.equipo_integraciones_federacion.game_type=excluded.game_type
       and coalesce(public.equipo_integraciones_federacion.external_team_id,'')=coalesce(excluded.external_team_id,'')
      then public.equipo_integraciones_federacion.ultima_validacion_mensaje else null end
  returning equipo_id
)
select count(*) as mappings_upserted from upserted;

do $$
declare v_count integer;
begin
  select count(*) into v_count
  from public.equipo_integraciones_federacion i
  join public.equipos e on e.id=i.equipo_id
  where e.temporada_id='f6b07c5c-9f57-44f4-a20d-189ab8608eac'::uuid
    and i.proveedor='RFFM'
    and i.activo
    and i.config->>'season_id'='22'
    and i.equipo_id = any(array[
      'f951e14a-dc0e-43fd-8f58-36cb68aa378b'::uuid,
      '93e08be0-cab1-4003-81b2-52d1cb4116f5'::uuid,
      'ef3577eb-dd74-455a-9202-2aa813ec0800'::uuid,
      '7776e2ac-9bb7-4008-8401-40ea8d471d2c'::uuid,
      '7492314d-9a6f-4c8c-ad50-c5ac830ec23d'::uuid,
      '03f79079-4523-4803-8af9-b8c3cb4513aa'::uuid,
      '7a48e397-b059-4eab-aab0-1d4395c9093d'::uuid,
      '9c42c5ca-b331-4a68-a175-eec82e723a30'::uuid,
      'b70a6dee-7b26-40f4-a924-92c6df39e472'::uuid,
      '9b6ee4c4-0dec-4a7c-b647-a6f97667f896'::uuid,
      '566f2474-9d3e-44d3-9a23-40079e8e3f04'::uuid,
      '3317e7ac-ae6c-4bf1-8605-cacae92fa8ca'::uuid,
      '4cf8a784-fead-4208-b4a3-2b7c5db5477c'::uuid,
      '56b6183d-a492-493c-b764-51e67846493b'::uuid,
      'e21f6c94-fadd-4412-8058-2970bc5a480e'::uuid,
      'd0b8b571-5891-4cfe-9c16-8722144c8f08'::uuid,
      'de597922-5e76-415f-8824-9bef995c4fb1'::uuid,
      '95bd3687-2606-4573-b1a2-3fb62f0447fd'::uuid,
      '56546387-63e6-4cf1-87a5-9c2ff1af17e1'::uuid,
      '6a93f6ba-eda4-49a1-87c1-e12df4fad3cb'::uuid,
      'ecc0f268-c155-46f2-a04c-bb3d5d910b55'::uuid,
      'ce5c092d-f058-4ea8-b061-b01019b181f7'::uuid,
      '4e419c93-e881-4e83-908e-4597563950ff'::uuid
    ]::uuid[]);
  if v_count <> 23 then
    raise exception 'RFFM 2026/27 validation: expected 23 explicit v27 mappings, found %',v_count;
  end if;
end $$;

commit;
