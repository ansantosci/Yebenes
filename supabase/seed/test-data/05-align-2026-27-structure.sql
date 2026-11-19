-- TEST-S 2026/27 structural alignment.
-- Correct the canonical synthetic team that was historically named Infantil Femenino B.
-- The UUID is intentionally preserved so structural references remain stable.
-- This script is idempotent and scoped exclusively to Yebenes season 2026/2027.

begin;

do $$
declare
  v_season_id constant uuid := 'f6b07c5c-9f57-44f4-a20d-189ab8608eac';
  v_team_id constant uuid := '56b6183d-a492-493c-b764-51e67846493b';
  v_senior_category_id constant uuid := '46675387-012d-47b7-ad79-2a34175a618f';
  v_name text;
  v_code text;
begin
  if not exists (
    select 1
    from public.temporadas
    where id=v_season_id
      and nombre='2026/2027'
      and anio_inicio=2026
      and anio_fin=2027
  ) then
    raise exception 'TEST-S structure 2026/27 guard: canonical season does not match 2026/2027';
  end if;

  select nombre,codigo into v_name,v_code
  from public.equipos
  where id=v_team_id and temporada_id=v_season_id;

  if not found then
    raise exception 'TEST-S structure 2026/27 guard: target team % does not exist in canonical season',v_team_id;
  end if;

  if not ((v_name='Infantil Femenino B' and v_code='INF-FB')
          or (v_name='Veteranos Masculino' and v_code='VET-M')) then
    raise exception 'TEST-S structure 2026/27 guard: unexpected target identity name=% code=%',v_name,v_code;
  end if;

  if exists (
    select 1 from public.equipos
    where temporada_id=v_season_id and codigo='VET-M' and id<>v_team_id
  ) then
    raise exception 'TEST-S structure 2026/27 guard: another VET-M team already exists';
  end if;

  update public.equipos
  set nombre='Veteranos Masculino',
      codigo='VET-M',
      categoria_id=v_senior_category_id,
      genero='masculino',
      modalidad='F11',
      activo=true
  where id=v_team_id;

  if not exists (
    select 1 from public.equipos
    where id=v_team_id and temporada_id=v_season_id
      and nombre='Veteranos Masculino' and codigo='VET-M'
      and categoria_id=v_senior_category_id
      and genero='masculino' and modalidad='F11' and activo
  ) then
    raise exception 'TEST-S structure 2026/27 validation: Veteranos Masculino alignment failed';
  end if;
end $$;

commit;
