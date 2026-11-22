-- 107 contract - Sponsors authorization derives from sponsors.manage.
do $$
declare
  v_qual text;
  v_check text;
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='patrocinadores_club'
      and policyname='patrocinadores_anon_active_read'
      and roles @> array['anon']::name[]
      and coalesce(qual,'') like '%activo%true%'
  ) then
    raise exception '107: anonymous active-only sponsor read policy missing';
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='patrocinadores_club'
      and policyname='patrocinadores_authenticated_read'
      and roles @> array['authenticated']::name[]
  ) then
    raise exception '107: authenticated sponsor read policy missing';
  end if;

  select coalesce(qual,''),coalesce(with_check,'') into v_qual,v_check
  from pg_policies
  where schemaname='public' and tablename='patrocinadores_club'
    and policyname='patrocinadores_capability_write';
  if v_qual not like '%has_capability%sponsors.manage%'
     or v_check not like '%has_capability%sponsors.manage%' then
    raise exception '107: sponsor table write policy not capability-based';
  end if;

  if exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='patrocinadores_club'
      and (
        coalesce(qual,'') like '%has_any_role%administrador%club%'
        or coalesce(with_check,'') like '%has_any_role%administrador%club%'
      )
  ) then
    raise exception '107: legacy sponsor table role policy remains';
  end if;

  if (
    select count(*)
    from pg_policies
    where schemaname='storage' and tablename='objects'
      and policyname in (
        'patrocinadores_storage_insert',
        'patrocinadores_storage_update',
        'patrocinadores_storage_delete'
      )
      and (
        coalesce(qual,'') like '%has_capability%sponsors.manage%'
        or coalesce(with_check,'') like '%has_capability%sponsors.manage%'
      )
      and (
        coalesce(qual,'') like '%patrocinadores%'
        or coalesce(with_check,'') like '%patrocinadores%'
      )
  ) <> 3 then
    raise exception '107: sponsor storage policies not fully capability-based';
  end if;

  if exists (
    select 1 from pg_policies
    where schemaname='storage' and tablename='objects'
      and policyname like 'patrocinadores_storage_%'
      and (
        coalesce(qual,'') like '%has_any_role%administrador%club%'
        or coalesce(with_check,'') like '%has_any_role%administrador%club%'
      )
  ) then
    raise exception '107: legacy sponsor storage role policy remains';
  end if;

  if exists (
    select 1 from private.rol_capacidades rc
    join public.roles r on r.id=rc.rol_id
    where r.codigo in ('entrenador','jugador','familia')
      and rc.capacidad_codigo='sponsors.manage'
  ) then
    raise exception '107: non-club profile received sponsors.manage';
  end if;
end $$;

select '107_sponsors_capability_enforcement_contract' contract,'PASS' result;
