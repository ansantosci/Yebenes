-- 106 - Finish Equipment RLS convergence after granular capability split.
-- Preserve personal/family size access; replace only administrative role branches.
begin;

drop policy if exists equipacion_personas_temporada_club_manage on public.equipacion_personas_temporada;
drop policy if exists equipacion_personas_temporada_equipment_manage on public.equipacion_personas_temporada;
create policy equipacion_personas_temporada_equipment_manage
on public.equipacion_personas_temporada
to authenticated
using (private.has_capability('equipment.manage'))
with check (private.has_capability('equipment.manage'));

drop policy if exists equipacion_tallas_write on public.equipacion_tallas_persona;
create policy equipacion_tallas_write
on public.equipacion_tallas_persona
for all to authenticated
using (
  private.has_capability('equipment.manage')
  or (confirmada_at is null and private.can_manage_equipacion_tallas(persona_id))
)
with check (
  private.has_capability('equipment.manage')
  or (confirmada_at is null and private.can_manage_equipacion_tallas(persona_id))
);

drop policy if exists equipacion_tallas_excepcion_write on public.equipacion_tallas_excepcion;
create policy equipacion_tallas_excepcion_write
on public.equipacion_tallas_excepcion
for all to authenticated
using (
  exists (
    select 1 from public.equipacion_tallas_persona t
    where t.id=talla_persona_id
      and (
        private.has_capability('equipment.manage')
        or (t.confirmada_at is null and private.can_manage_equipacion_tallas(t.persona_id))
      )
  )
)
with check (
  exists (
    select 1 from public.equipacion_tallas_persona t
    where t.id=talla_persona_id
      and (
        private.has_capability('equipment.manage')
        or (t.confirmada_at is null and private.can_manage_equipacion_tallas(t.persona_id))
      )
  )
);

commit;
