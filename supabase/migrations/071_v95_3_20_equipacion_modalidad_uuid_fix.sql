-- 071 - Fix UUID modality resolution introduced in 070.
-- PostgreSQL has no min(uuid); count first, then select the single matching UUID.
begin;

create or replace function private.equipacion_resolver_modalidad_economica(p_necesidad uuid)
returns uuid
language plpgsql stable security definer set search_path='' as $$
declare n public.equipacion_necesidades%rowtype; mid uuid; cnt integer;
begin
 select * into n from public.equipacion_necesidades where id=p_necesidad;
 if n.id is null or n.faceta<>'jugador' or n.confirmada_at is null then return null; end if;

 select count(*) into cnt
 from public.economia_modalidades_equipacion m
 where m.temporada_id=n.temporada_id and m.activo
   and m.requiere_partido=true
   and m.requiere_entrenamiento=(not n.reutiliza_entrenamiento);

 if cnt=0 then
   raise exception 'No economic equipment modality configured for confirmed need';
 elsif cnt>1 then
   raise exception 'Ambiguous economic equipment modality for confirmed need';
 end if;

 select m.id into mid
 from public.economia_modalidades_equipacion m
 where m.temporada_id=n.temporada_id and m.activo
   and m.requiere_partido=true
   and m.requiere_entrenamiento=(not n.reutiliza_entrenamiento)
 limit 1;

 return mid;
end $$;

commit;
