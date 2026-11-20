-- 099: Persist summaries of club-wide RFFM refresh executions.
begin;

create table public.rffm_actualizaciones_generales (
  id uuid primary key default gen_random_uuid(),
  temporada_id uuid not null references public.temporadas(id) on delete cascade,
  finalizado_at timestamptz not null default now(),
  equipos_total integer not null check (equipos_total >= 0),
  equipos_ok integer not null check (equipos_ok >= 0),
  equipos_error integer not null check (equipos_error >= 0),
  estado text not null check (estado in ('completa','parcial','error')),
  created_at timestamptz not null default now(),
  constraint rffm_actualizaciones_generales_totales_chk check (equipos_ok + equipos_error = equipos_total),
  constraint rffm_actualizaciones_generales_estado_chk check (
    (estado='completa' and equipos_error=0 and equipos_ok=equipos_total) or
    (estado='parcial' and equipos_ok>0 and equipos_error>0) or
    (estado='error' and equipos_ok=0 and equipos_error=equipos_total)
  )
);

create index rffm_actualizaciones_generales_temporada_idx
  on public.rffm_actualizaciones_generales(temporada_id,finalizado_at desc);

comment on table public.rffm_actualizaciones_generales is
  'Resumen persistente de cada ejecución manual de Actualizar todos en Resultados RFFM. No contiene resultados deportivos.';

alter table public.rffm_actualizaciones_generales enable row level security;

create policy rffm_actualizaciones_generales_club_read
on public.rffm_actualizaciones_generales for select to authenticated
using ((select private.has_any_role(array['administrador','club'])));

create policy rffm_actualizaciones_generales_club_insert
on public.rffm_actualizaciones_generales for insert to authenticated
with check ((select private.has_any_role(array['administrador','club'])));

revoke all on table public.rffm_actualizaciones_generales from public,anon,authenticated;
grant select,insert on table public.rffm_actualizaciones_generales to authenticated;
grant all on table public.rffm_actualizaciones_generales to service_role;

commit;
