begin; do $$ begin if to_regclass('public.equipacion_reparto_resumen') is null then raise exception '058 missing'; end if; end $$; rollback;
