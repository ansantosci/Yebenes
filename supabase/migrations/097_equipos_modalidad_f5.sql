-- 097: F5 is a first-class team modality (Debutantes/Chupetines).
begin;

alter table public.equipos
  drop constraint if exists equipos_modalidad_check;

alter table public.equipos
  add constraint equipos_modalidad_check
  check (modalidad is null or modalidad in ('F5','F7','F11'));

comment on column public.equipos.modalidad is
  'Playing format for the team: F5, F7 or F11. NULL is retained only for legacy/unclassified rows.';

commit;
