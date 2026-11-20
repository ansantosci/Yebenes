-- 098: Persistent RFFM result snapshots without coupling the relational model to federation payload shape.
begin;

create table public.rffm_resultados_snapshots (
  id uuid primary key default gen_random_uuid(),
  integracion_id uuid not null references public.equipo_integraciones_federacion(id) on delete cascade,
  payload jsonb not null,
  payload_hash text not null,
  obtenido_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint rffm_resultados_snapshots_payload_object_chk check (jsonb_typeof(payload)='object'),
  constraint rffm_resultados_snapshots_hash_chk check (payload_hash ~ '^[0-9a-f]{64}$'),
  constraint rffm_resultados_snapshots_integracion_hash_uq unique(integracion_id,payload_hash)
);

create index rffm_resultados_snapshots_integracion_obtenido_idx
  on public.rffm_resultados_snapshots(integracion_id,obtenido_at desc);

create table public.rffm_resultados_estado (
  integracion_id uuid primary key references public.equipo_integraciones_federacion(id) on delete cascade,
  ultimo_snapshot_id uuid null references public.rffm_resultados_snapshots(id) on delete set null,
  ultimo_intento_at timestamptz null,
  ultimo_exito_at timestamptz null,
  ultimo_error text null,
  updated_at timestamptz not null default now()
);

create trigger rffm_resultados_estado_updated_at
before update on public.rffm_resultados_estado
for each row execute function public.set_updated_at();

comment on table public.rffm_resultados_snapshots is
  'Snapshots JSON normalizados devueltos por rffm-resultados. Se conserva histórico solo cuando cambia el payload.';
comment on column public.rffm_resultados_snapshots.payload is
  'Contrato normalizado de la Edge Function; no replica el HTML bruto de RFFM ni fija su estructura en columnas.';
comment on table public.rffm_resultados_estado is
  'Estado operativo de la última consulta RFFM por integración: último intento, último éxito, error y snapshot vigente.';

alter table public.rffm_resultados_snapshots enable row level security;
alter table public.rffm_resultados_estado enable row level security;

create policy rffm_resultados_snapshots_club_read
on public.rffm_resultados_snapshots for select to authenticated
using ((select private.has_any_role(array['administrador','club'])));

create policy rffm_resultados_estado_club_read
on public.rffm_resultados_estado for select to authenticated
using ((select private.has_any_role(array['administrador','club'])));

revoke all on table public.rffm_resultados_snapshots from public,anon,authenticated;
revoke all on table public.rffm_resultados_estado from public,anon,authenticated;
grant select on table public.rffm_resultados_snapshots to authenticated;
grant select on table public.rffm_resultados_estado to authenticated;
grant all on table public.rffm_resultados_snapshots to service_role;
grant all on table public.rffm_resultados_estado to service_role;

commit;
