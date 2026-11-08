-- 059 - Security hardening for Equipaciones objects introduced by 056-058.
-- 056-058 were already applied before the historical 051 contract detected implicit anon grants.
begin;

-- New state tables follow the same club-managed security model as 052 logistics.
alter table public.equipacion_personas_temporada enable row level security;
alter table public.equipacion_stock_lotes enable row level security;
alter table public.equipacion_stock_lote_vigencia enable row level security;

drop policy if exists equipacion_personas_temporada_club_manage on public.equipacion_personas_temporada;
create policy equipacion_personas_temporada_club_manage
on public.equipacion_personas_temporada
to authenticated
using (private.has_any_role(array['administrador','club']))
with check (private.has_any_role(array['administrador','club']));

drop policy if exists equipacion_stock_lotes_club_manage on public.equipacion_stock_lotes;
create policy equipacion_stock_lotes_club_manage
on public.equipacion_stock_lotes
to authenticated
using (private.has_any_role(array['administrador','club']))
with check (private.has_any_role(array['administrador','club']));

drop policy if exists equipacion_stock_lote_vigencia_club_manage on public.equipacion_stock_lote_vigencia;
create policy equipacion_stock_lote_vigencia_club_manage
on public.equipacion_stock_lote_vigencia
to authenticated
using (private.has_any_role(array['administrador','club']))
with check (private.has_any_role(array['administrador','club']));

grant select,insert,update,delete
on public.equipacion_personas_temporada,
   public.equipacion_stock_lotes,
   public.equipacion_stock_lote_vigencia
to authenticated;

grant all
on public.equipacion_personas_temporada,
   public.equipacion_stock_lotes,
   public.equipacion_stock_lote_vigencia
to service_role;

revoke all
on public.equipacion_personas_temporada,
   public.equipacion_stock_lotes,
   public.equipacion_stock_lote_vigencia
from anon;

-- Views are read-only application projections. Their underlying tables remain RLS protected.
grant select
on public.equipacion_stock_lotes_disponibles,
   public.equipacion_reparto_resumen
to authenticated,service_role;

revoke all
on public.equipacion_stock_lotes_disponibles,
   public.equipacion_reparto_resumen
from anon;

-- The validation trigger helper is not an application API.
revoke all on function private.equipacion_validar_necesidad_confirmada() from public,anon,authenticated;
grant execute on function private.equipacion_validar_necesidad_confirmada() to service_role;

commit;
