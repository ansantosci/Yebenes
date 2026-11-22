-- Contract 103: assigned player identity is minimal and capability-scoped.
begin;

do $$
declare def text;
begin
  if to_regprocedure('public.identidad_jugadores_asignados(uuid[])') is null then
    raise exception '103 contract: identidad_jugadores_asignados(uuid[]) missing';
  end if;
  def := pg_get_functiondef('public.identidad_jugadores_asignados(uuid[])'::regprocedure);
  if def not like '%players.read_assigned%' then
    raise exception '103 contract: RPC is not capability-scoped';
  end if;
  if def not like '%asignaciones_entrenador_equipo%' then
    raise exception '103 contract: RPC is not assignment-scoped';
  end if;
  if def like '%email_contacto%' or def like '%telefono%' or def like '%fecha_nacimiento%' then
    raise exception '103 contract: RPC exposes non-minimal personal data';
  end if;
end $$;

rollback;
