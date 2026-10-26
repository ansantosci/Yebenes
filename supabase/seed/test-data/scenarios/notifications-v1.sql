-- Scenario NOTIFICATIONS v1: exactly one known pending notification.
begin;
delete from public.notificaciones_salida where id=private.test_uuid('scenario:notification:1');
insert into public.notificaciones_salida(id,tipo,destinatario_tipo,destinatario_persona_id,destinatario_email,asunto,cuerpo,estado,intentos,disponible_desde)
values(private.test_uuid('scenario:notification:1'),'test_smtp','tutor',private.test_uuid('tutor:ALE-A'),'tutor01@test.invalid','Prueba SMTP TEST-S','Mensaje sintetico para validar cola -> SMTP -> SendPit.','pendiente',0,now());
insert into private.test_dataset_entities values('TEST-S','notificaciones_salida',private.test_uuid('scenario:notification:1'),now()) on conflict do nothing;
update private.test_datasets set scenario='NOTIFICATIONS',loaded_at=now() where id='TEST-S';
commit;
