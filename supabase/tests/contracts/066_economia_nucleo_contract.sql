-- Contract 066: general economy is person/season scoped and independent from legacy federation economics.
do $$
begin
  if to_regclass('public.economia_cargos') is null
     or to_regclass('public.economia_pagos') is null
     or to_regclass('public.economia_ajustes') is null
     or to_regclass('public.economia_modalidades_equipacion') is null
     or to_regclass('public.economia_estado_cargos') is null then
    raise exception '066 contract failed: economy objects missing';
  end if;
  if has_function_privilege('anon','private.economia_registrar_pago(uuid,numeric,text,date,text,text)','EXECUTE')
     or has_function_privilege('anon','private.economia_aplicar_ajuste(uuid,text,numeric,text,text,text)','EXECUTE')
     or has_function_privilege('anon','private.economia_anular_cargo(uuid,text)','EXECUTE') then
    raise exception '066 contract failed: economy mutation RPC exposed to anon';
  end if;
end $$;

begin;
do $$
declare
 tid uuid:='06600000-0000-4000-8000-000000000001';
 pid uuid:='06600000-0000-4000-8000-000000000002';
 cid uuid:='06600000-0000-4000-8000-000000000003';
 concept uuid;
 r record;
begin
 insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado)
 values(tid,'2095/2096 CONTRACT 066',2095,2096,date '2095-07-01',date '2096-06-30','planificacion');
 insert into public.personas(id,nombre,primer_apellido,fecha_nacimiento,activo)
 values(pid,'Economia','Contract 066',date '1990-01-01',true);
 select id into concept from public.economia_conceptos where codigo='CUOTA_TEMPORADA';

 insert into public.economia_cargos(id,persona_id,temporada_id,concepto_id,importe_base,descripcion,origen,clave_origen)
 values(cid,pid,tid,concept,250,'Cuota contract 066','asignacion_equipo','CUOTA_TEMPORADA');

 -- Same person/season cannot receive a second season fee.
 begin
   insert into public.economia_cargos(persona_id,temporada_id,concepto_id,importe_base,origen,clave_origen)
   values(pid,tid,concept,250,'asignacion_equipo','CUOTA_TEMPORADA');
   raise exception '066 contract failed: duplicate season fee accepted';
 exception when unique_violation then null; end;

 -- Ledger arithmetic: original 250, sibling discount -50 => 200 due.
 insert into public.economia_ajustes(cargo_id,tipo,importe,nombre,motivo,origen)
 values(cid,'descuento',-50,'Segundo hermano','Contract 066','automatico');

 insert into public.economia_pagos(cargo_id,importe,metodo,fecha_pago,registrado_por)
 select cid,100,'efectivo',current_date,p.auth_user_id
 from public.personas p join public.persona_roles pr on pr.persona_id=p.id and pr.activo
 join public.roles ro on ro.id=pr.rol_id and ro.codigo in ('administrador','club')
 where p.auth_user_id is not null limit 1;

 select * into r from public.economia_estado_cargos where cargo_id=cid;
 if r.importe_exigible<>200 or r.importe_pagado<>100 or r.saldo_pendiente<>100 or r.estado_pago<>'parcialmente_pagado' then
   raise exception '066 contract failed: ledger arithmetic incorrect: exigible %, paid %, pending %, state %',
     r.importe_exigible,r.importe_pagado,r.saldo_pendiente,r.estado_pago;
 end if;

 -- A team change is represented by a regularisation on the same charge, never another fee.
 insert into public.economia_ajustes(cargo_id,tipo,importe,nombre,motivo,origen)
 values(cid,'regularizacion',25,'Cambio de equipo','Nueva regla economica','automatico');
 select * into r from public.economia_estado_cargos where cargo_id=cid;
 if r.importe_exigible<>225 or r.saldo_pendiente<>125 then
   raise exception '066 contract failed: team-change regularisation incorrect';
 end if;
end $$;
rollback;

select '066_economia_nucleo_contract' contract,'PASS' result;
