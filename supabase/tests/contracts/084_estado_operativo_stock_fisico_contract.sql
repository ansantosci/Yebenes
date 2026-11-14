-- Contract 084: operational projection exposes physical stock without changing 078 semantics.
do $$
declare cols text[];
begin
 if to_regclass('public.equipacion_estado_operativo') is null then
   raise exception '084: operational view missing';
 end if;
 if has_table_privilege('anon','public.equipacion_estado_operativo','SELECT') then
   raise exception '084: operational view exposed to anon';
 end if;

 select array_agg(a.attname order by a.attnum)
 into cols
 from pg_attribute a
 where a.attrelid='public.equipacion_estado_operativo'::regclass
   and a.attnum>0 and not a.attisdropped;

 if not ('stock_fisico'=any(cols)) then raise exception '084: stock_fisico missing'; end if;
 if not ('stock_disponible'=any(cols)) then raise exception '084: stock_disponible regression'; end if;
 if not ('cantidad_reservada'=any(cols)) then raise exception '084: cantidad_reservada regression'; end if;
 if not ('estado_operativo'=any(cols)) then raise exception '084: estado_operativo regression'; end if;
end $$;

begin;
do $$
declare
 tid uuid:='08400000-0000-4000-8000-000000000001';
 pid uuid:='08400000-0000-4000-8000-000000000002';
 jid uuid:='08400000-0000-4000-8000-000000000003';
 pt uuid:='08400000-0000-4000-8000-000000000004';
 art uuid:='08400000-0000-4000-8000-000000000005';
 need uuid:='08400000-0000-4000-8000-000000000006';
 ass uuid:='08400000-0000-4000-8000-000000000007';
 r record;
begin
 insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado)
 values(tid,'2085/2086 CONTRACT 084',2085,2086,date '2085-07-01',date '2086-06-30','planificacion');
 insert into public.personas(id,nombre,primer_apellido,fecha_nacimiento,activo)
 values(pid,'Jugador','Contract084',date '2000-01-01',true);
 insert into public.jugadores(id,persona_id,activo,fecha_alta) values(jid,pid,true,current_date);
 insert into public.equipacion_personas_temporada(id,persona_id,temporada_id,faceta,jugador_id,estado,validada_at)
 values(pt,pid,tid,'jugador',jid,'validada',now());
 insert into public.equipacion_articulos(id,codigo,nombre,tipo_prenda,usa_talla,activo)
 values(art,'ART-084','Articulo 084','pantalon',true,true);
 insert into public.equipacion_tallas_persona(persona_id,temporada_id,talla_general,confirmada_at)
 values(pid,tid,'2XS',now());
 insert into public.equipacion_necesidades(id,persona_id,temporada_id,faceta,jugador_id,persona_temporada_id,
   articulo_id_adicional,cantidad_adicional,sin_cargo,precio_unitario_snapshot,estado,origen,confirmada_at,comunicada_at)
 values(need,pid,tid,'jugador',jid,pt,art,1,true,0,'comunicada','manual',now(),now());
 insert into public.equipacion_asignaciones(id,necesidad_id,articulo_id,talla,cantidad,estado,origen)
 values(ass,need,art,'2XS',1,'propuesta','manual');

 -- One physical unit exists but it is fully committed elsewhere. The assignment
 -- remains pendiente_compra under 078 semantics, while 084 must expose the
 -- physical unit so the client can request explicit displacement authorization.
 insert into public.equipacion_stock(temporada_id,articulo_id,talla,cantidad_fisica,cantidad_reservada)
 values(tid,art,'2XS',1,1);

 select * into r from public.equipacion_estado_operativo where asignacion_id=ass;
 if r.estado_operativo<>'pendiente_compra' then
   raise exception '084: committed-only stock must preserve pendiente_compra state';
 end if;
 if r.stock_fisico<>1 or r.stock_disponible<>0 then
   raise exception '084: physical/free stock projection incorrect';
 end if;
 if r.stock_fisico <> r.stock_disponible + 1 then
   raise exception '084: committed physical stock is not observable';
 end if;
end $$;
rollback;

select '084_estado_operativo_stock_fisico_contract' contract,'PASS' result;
