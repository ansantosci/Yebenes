-- 079 - Direct delivery with soft preparations.
begin;

create table if not exists public.equipacion_preparaciones_desplazadas (
 id uuid primary key default gen_random_uuid(),
 asignacion_afectada_id uuid not null references public.equipacion_asignaciones(id) on delete restrict,
 asignacion_beneficiaria_id uuid not null references public.equipacion_asignaciones(id) on delete restrict,
 lote_id uuid not null references public.equipacion_stock_lotes(id) on delete restrict,
 cantidad integer not null check(cantidad>0),
 desplazada_por uuid not null references auth.users(id) on delete restrict,
 desplazada_at timestamptz not null default now()
);

-- Direct delivery. If p_permitir_desplazar=false only free stock may be used.
-- If true, Club/Admin may consume physical stock committed to other preparations;
-- newest preparations are displaced first and every displacement is audited.
create or replace function private.equipacion_entregar_directo(
 p_asignacion uuid,p_permitir_desplazar boolean default false
) returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); a public.equipacion_asignaciones%rowtype;
 n public.equipacion_necesidades%rowtype; reservada integer; falta integer;
 libre integer; fisico integer; tomar integer; l record; x record; liberar integer;
begin
 if actor is null or not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
 select * into a from public.equipacion_asignaciones where id=p_asignacion for update;
 if a.id is null then raise exception 'Assignment not found'; end if;
 if a.estado='entregada' then return private.equipacion_confirmar_entrega(a.id,actor); end if;
 if a.estado='cancelada' then raise exception 'Cancelled assignment cannot be delivered'; end if;
 select * into n from public.equipacion_necesidades where id=a.necesidad_id;

 select coalesce(sum(al.cantidad),0)::integer into reservada
 from public.equipacion_asignacion_lotes al
 where al.asignacion_id=a.id and al.estado='reservada';
 if reservada>a.cantidad then raise exception 'Existing reservations exceed assignment quantity'; end if;
 falta:=a.cantidad-reservada;

 if falta>0 then
  select coalesce(sum(sl.cantidad_fisica-sl.cantidad_reservada),0)::integer,
         coalesce(sum(sl.cantidad_fisica),0)::integer
  into libre,fisico
  from public.equipacion_stock_lotes sl
  join public.equipacion_stock_lote_vigencia v on v.lote_id=sl.id
  where v.temporada_id=n.temporada_id and v.estado='valido'
    and sl.articulo_id=a.articulo_id and sl.talla=a.talla;

  if libre<falta and not p_permitir_desplazar then
    raise exception 'Insufficient free stock: available %, required %. Physical stock may be committed to other preparations',libre,falta;
  end if;
  if fisico<falta+reservada then
    raise exception 'Insufficient physical stock: available %, required %',fisico,a.cantidad;
  end if;

  if libre<falta then
   -- Release only as much soft preparation as is necessary. Newest preparation loses priority first.
   for x in
    select al.id al_id,al.asignacion_id,al.lote_id,al.cantidad,al.reservado_at
    from public.equipacion_asignacion_lotes al
    join public.equipacion_asignaciones ax on ax.id=al.asignacion_id
    join public.equipacion_necesidades nx on nx.id=ax.necesidad_id
    where al.estado='reservada' and al.asignacion_id<>a.id
      and ax.articulo_id=a.articulo_id and ax.talla=a.talla and nx.temporada_id=n.temporada_id
    order by al.reservado_at desc,al.id desc
    for update of al
   loop
    exit when libre>=falta;
    liberar:=least(x.cantidad,falta-libre);
    update public.equipacion_stock_lotes
      set cantidad_reservada=cantidad_reservada-liberar,updated_at=now()
      where id=x.lote_id and cantidad_reservada>=liberar;
    if not found then raise exception 'Prepared stock is inconsistent'; end if;

    if liberar=x.cantidad then
      update public.equipacion_asignacion_lotes set estado='liberada',liberado_at=now(),updated_at=now() where id=x.al_id;
    else
      update public.equipacion_asignacion_lotes set cantidad=cantidad-liberar,updated_at=now() where id=x.al_id;
    end if;
    insert into public.equipacion_preparaciones_desplazadas(
      asignacion_afectada_id,asignacion_beneficiaria_id,lote_id,cantidad,desplazada_por)
    values(x.asignacion_id,a.id,x.lote_id,liberar,actor);

    update public.equipacion_asignaciones ax
    set estado=case when coalesce((select sum(z.cantidad) from public.equipacion_asignacion_lotes z
                                  where z.asignacion_id=ax.id and z.estado='reservada'),0)>=ax.cantidad
                    then 'reservada' else 'propuesta' end,
        reservado_at=case when coalesce((select sum(z.cantidad) from public.equipacion_asignacion_lotes z
                                  where z.asignacion_id=ax.id and z.estado='reservada'),0)>=ax.cantidad
                          then ax.reservado_at else null end,
        updated_at=now()
    where ax.id=x.asignacion_id;
    libre:=libre+liberar;
   end loop;
  end if;

  -- Prepare the beneficiary from now-free stock using the established FIFO primitive.
  perform private.equipacion_preparar_asignacion_fifo(a.id);
 end if;

 return private.equipacion_confirmar_entrega(a.id,actor);
end $$;

alter table public.equipacion_preparaciones_desplazadas enable row level security;
create policy equipacion_preparaciones_desplazadas_club on public.equipacion_preparaciones_desplazadas
 for select to authenticated using(private.has_any_role(array['administrador','club']));
grant select on public.equipacion_preparaciones_desplazadas to authenticated,service_role;
grant all on public.equipacion_preparaciones_desplazadas to service_role;
revoke all on public.equipacion_preparaciones_desplazadas from anon;
revoke all on function private.equipacion_entregar_directo(uuid,boolean) from public,anon;
grant execute on function private.equipacion_entregar_directo(uuid,boolean) to authenticated,service_role;

commit;
