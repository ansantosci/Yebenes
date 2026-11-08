-- V95.3.7 backend - pack/person delivery aggregation over per-garment assignments.
begin;
create or replace view public.equipacion_reparto_resumen as
select n.id necesidad_id,n.persona_id,n.temporada_id,n.faceta,n.jugador_id,n.entrenador_id,n.pack_id,
count(a.id)::integer prendas_asignadas,count(a.id) filter(where a.estado='entregada')::integer prendas_entregadas,
case when count(a.id)=0 then 'pendiente' when count(a.id) filter(where a.estado='entregada')=0 then 'pendiente'
when count(a.id) filter(where a.estado='entregada')<count(a.id) then 'parcial' else 'entregado' end estado_reparto
from public.equipacion_necesidades n left join public.equipacion_asignaciones a on a.necesidad_id=n.id and a.estado<>'cancelada'
group by n.id,n.persona_id,n.temporada_id,n.faceta,n.jugador_id,n.entrenador_id,n.pack_id;
commit;
