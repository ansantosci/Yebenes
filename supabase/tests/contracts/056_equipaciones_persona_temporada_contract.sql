begin; do $$ begin if to_regclass('public.equipacion_personas_temporada') is null then raise exception '056 missing'; end if; end $$; rollback;
