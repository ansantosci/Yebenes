-- Contract 097: equipos.modalidad accepts F5/F7/F11 and rejects unsupported values.
begin;

do $$
declare
  v_team public.equipos%rowtype;
begin
  select * into v_team from public.equipos limit 1;
  if v_team.id is null then
    raise exception '097 contract requires at least one team';
  end if;

  update public.equipos set modalidad='F5' where id=v_team.id;
  update public.equipos set modalidad='F7' where id=v_team.id;
  update public.equipos set modalidad='F11' where id=v_team.id;
  update public.equipos set modalidad=null where id=v_team.id;

  begin
    update public.equipos set modalidad='F9' where id=v_team.id;
    raise exception '097 contract: unsupported F9 modality was accepted';
  exception
    when check_violation then null;
  end;
end $$;

rollback;
