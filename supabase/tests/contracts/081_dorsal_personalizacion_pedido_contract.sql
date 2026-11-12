do $$
declare s text;
begin
 if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='equipacion_articulos' and column_name='personalizable_dorsal') then raise exception '081 article personalization flag missing'; end if;
 if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='equipacion_pedido_lineas' and column_name='dorsal') then raise exception '081 order-line dorsal missing'; end if;
 if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='equipacion_stock_lotes' and column_name='dorsal') then raise exception '081 stock-lot dorsal missing'; end if;
 select pg_get_functiondef('private.equipacion_cambiar_dorsal_propuesto(uuid,uuid,uuid,integer)'::regprocedure) into s;
 if position('after personalized order is placed' in lower(s))=0 then raise exception '081 order lock missing'; end if;
 if has_function_privilege('anon','private.equipacion_proponer_dorsal(uuid,uuid,uuid,boolean)','EXECUTE') then raise exception '081 proposal exposed to anon'; end if;
end $$;
select '081_dorsal_personalizacion_pedido_contract' contract,'PASS' result;
