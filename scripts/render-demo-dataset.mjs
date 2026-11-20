import fs from 'node:fs';
import path from 'node:path';

const args = Object.fromEntries(process.argv.slice(2).map((arg, i, all) => {
  if (!arg.startsWith('--')) return [arg, true];
  return [arg.slice(2), all[i + 1] && !all[i + 1].startsWith('--') ? all[i + 1] : true];
}));
const input = args.input;
const output = args.output;
const kind = args.kind || 'scenario';
if (!input || !output) throw new Error('Usage: node scripts/render-demo-dataset.mjs --kind reset|scenario --input FILE --output FILE');

let sql = fs.readFileSync(input, 'utf8');
const source = sql;

if (kind === 'parity') {
  const marker = '-- V1.3 canonical future-season multifacet participation coverage (060).';
  const start = sql.indexOf(marker);
  const end = sql.lastIndexOf('commit;');
  if (start < 0 || end < start) throw new Error('Baseline parity renderer: future-season fixture markers not found');
  const futureFixture = sql.slice(start, end)
    .replaceAll('private.test_dataset_entities', 'private.demo_dataset_entities')
    .replaceAll('private.test_datasets', 'private.demo_datasets')
    .replaceAll('private.test_uuid', 'private.demo_uuid')
    .replaceAll("'TEST-S'", "'DEMO-S'")
    .replaceAll('@test.invalid', '@demo.invalid');
  sql = `-- DEMO-S parity overlay generated from the canonical TEST baseline.
begin;

-- Team schedules: same functional coverage as TEST, over the richer DEMO population.
insert into public.horarios_equipo(id,equipo_id,dia_semana,hora_inicio,hora_fin,activo)
select private.demo_uuid('schedule:'||e.codigo), e.id, 2 + (row_number() over(order by e.codigo)::int % 3),
       time '18:00' + ((row_number() over(order by e.codigo)::int % 3) * interval '30 minutes'),
       time '19:30' + ((row_number() over(order by e.codigo)::int % 3) * interval '30 minutes'), true
from public.equipos e join public.temporadas t on t.id=e.temporada_id where t.estado='activa'
on conflict(id) do update set dia_semana=excluded.dia_semana,hora_inicio=excluded.hora_inicio,hora_fin=excluded.hora_fin,activo=true;
insert into private.demo_dataset_entities
select 'DEMO-S','horarios_equipo',private.demo_uuid('schedule:'||e.codigo),now() from public.equipos e join public.temporadas t on t.id=e.temporada_id where t.estado='activa' on conflict do nothing;

-- Economic team configuration equivalent to TEST baseline; canonical rows are upserted, not dataset-owned.
insert into public.configuracion_economica_equipo(id,temporada_id,equipo_id,importe_inscripcion,admite_fraccionamiento,requiere_pago_ficha,observaciones)
select private.demo_uuid('econ-config:'||e.codigo),e.temporada_id,e.id,120 + (row_number() over(order by e.codigo)%4)*30,true,true,'DEMO-S parity'
from public.equipos e join public.temporadas t on t.id=e.temporada_id where t.estado='activa'
on conflict(temporada_id,equipo_id) do update set importe_inscripcion=excluded.importe_inscripcion,admite_fraccionamiento=true,requiere_pago_ficha=true,observaciones='DEMO-S parity';

-- Canonical active-season participation for every DEMO-S player and coach.
insert into public.persona_participaciones_temporada(id,persona_id,temporada_id,faceta,origen,estado,categoria_prevista_id,aceptada_at)
select private.demo_uuid('parity:participation:player:'||p.id::text),p.id,i.temporada_id,'jugador','administrativa','aceptada',i.categoria_id,now()
from private.demo_dataset_entities de join public.jugadores j on de.dataset_id='DEMO-S' and de.table_name='jugadores' and de.entity_id=j.id
join public.personas p on p.id=j.persona_id
join public.inscripciones i on i.jugador_id=j.id
join public.temporadas t on t.id=i.temporada_id and t.estado='activa'
on conflict(persona_id,temporada_id,faceta) do update set estado='aceptada',categoria_prevista_id=excluded.categoria_prevista_id,aceptada_at=coalesce(public.persona_participaciones_temporada.aceptada_at,now()),baja_at=null,motivo_baja=null;
insert into private.demo_dataset_entities(dataset_id,table_name,entity_id)
select 'DEMO-S','persona_participaciones_temporada',ppt.id from public.persona_participaciones_temporada ppt
join private.demo_dataset_entities de on de.dataset_id='DEMO-S' and de.table_name='jugadores'
join public.jugadores j on j.id=de.entity_id and j.persona_id=ppt.persona_id
join public.temporadas t on t.id=ppt.temporada_id and t.estado='activa' where ppt.faceta='jugador' on conflict do nothing;

insert into public.persona_participaciones_temporada(id,persona_id,temporada_id,faceta,origen,estado,aceptada_at)
select private.demo_uuid('parity:participation:coach:'||p.id::text),p.id,t.id,'entrenador','administrativa','aceptada',now()
from private.demo_dataset_entities de join public.entrenadores c on de.dataset_id='DEMO-S' and de.table_name='entrenadores' and de.entity_id=c.id
join public.personas p on p.id=c.persona_id cross join lateral (select id from public.temporadas where estado='activa' order by fecha_inicio desc limit 1) t
on conflict(persona_id,temporada_id,faceta) do update set estado='aceptada',aceptada_at=coalesce(public.persona_participaciones_temporada.aceptada_at,now()),baja_at=null,motivo_baja=null;
insert into private.demo_dataset_entities(dataset_id,table_name,entity_id)
select 'DEMO-S','persona_participaciones_temporada',ppt.id from public.persona_participaciones_temporada ppt
join private.demo_dataset_entities de on de.dataset_id='DEMO-S' and de.table_name='entrenadores'
join public.entrenadores c on c.id=de.entity_id and c.persona_id=ppt.persona_id
join public.temporadas t on t.id=ppt.temporada_id and t.estado='activa' where ppt.faceta='entrenador' on conflict do nothing;

${futureFixture}

commit;
`;
} else {
  sql = sql
    .replaceAll('private.test_dataset_entities', 'private.demo_dataset_entities')
    .replaceAll('private.test_datasets', 'private.demo_datasets')
    .replaceAll('private.test_uuid', 'private.demo_uuid')
    .replaceAll("'TEST-S'", "'DEMO-S'");
}

if (kind === 'reset') {
  sql = sql
    .replace('select private.test_set_reception_delete_guard(false);', 'alter table public.equipacion_recepcion_lineas disable trigger equipacion_recepcion_lineas_no_delete;')
    .replace('select private.test_set_reception_delete_guard(true);', 'alter table public.equipacion_recepcion_lineas enable trigger equipacion_recepcion_lineas_no_delete;')
    .replace('select private.test_set_economia_reset_mode(true);', "select set_config('yebenes.test_s_reset_mode','on',true);")
    .replace('select private.test_set_economia_reset_mode(false);', "select set_config('yebenes.test_s_reset_mode','off',true);");
} else if (kind === 'scenario') {
  // NOTIFICATIONS has one historical deterministic TEST tutor id. DEMO baseline uses family:* ids.
  sql = sql
    .replace("private.demo_uuid('tutor:ALE-A')", "(select e.entity_id from private.demo_dataset_entities e join public.personas p on p.id=e.entity_id where e.dataset_id='DEMO-S' and e.table_name='personas' and p.nombre='Familia DEMO' order by p.id limit 1)")
    .replaceAll('tutor01@test.invalid', 'tutor01@demo.invalid');

  if (input.endsWith('completo-v1.sql')) {
    // Cross-module bridge must select a pack compatible with player needs; never rely on creation order.
    if (!sql.includes("p.destinatario in ('jugador','ambos')")) {
      throw new Error('COMPLETO renderer: cross-module pack selection is not recipient-safe');
    }

    // DEMO Matrix must be built from the canonical DEMO-S roster/economy population only.
    // Rehearsal also owns one temporary operational minor fixture; keep it resettable but outside Matrix.
    const matrixNeedle = `create temporary table test_matrix_players on commit drop as
select j.id jugador_id,j.persona_id,i.temporada_id,e.id equipo_id,e.codigo equipo_codigo,
       row_number() over(order by e.codigo,j.id) rn
from public.jugadores j
join public.inscripciones i on i.jugador_id=j.id
join public.temporadas t on t.id=i.temporada_id and t.estado='activa'
join public.asignaciones_jugador_equipo aje on aje.inscripcion_id=i.id
 and aje.fecha_desde<=current_date and (aje.fecha_hasta is null or aje.fecha_hasta>=current_date)
join public.equipos e on e.id=aje.equipo_id and e.temporada_id=i.temporada_id
where j.activo;`;
    const matrixReplacement = `create temporary table test_matrix_players on commit drop as
select j.id jugador_id,j.persona_id,i.temporada_id,e.id equipo_id,e.codigo equipo_codigo,
       row_number() over(order by e.codigo,j.id) rn
from public.jugadores j
join private.demo_dataset_entities matrix_owner
  on matrix_owner.dataset_id='DEMO-S' and matrix_owner.table_name='jugadores' and matrix_owner.entity_id=j.id
join public.inscripciones i on i.jugador_id=j.id
join public.temporadas t on t.id=i.temporada_id and t.estado='activa'
join public.asignaciones_jugador_equipo aje on aje.inscripcion_id=i.id
 and aje.fecha_desde<=current_date and (aje.fecha_hasta is null or aje.fecha_hasta>=current_date)
join public.equipos e on e.id=aje.equipo_id and e.temporada_id=i.temporada_id
where j.activo
  and j.id<>private.demo_uuid('access-player:minor_player');`;
    if (!sql.includes(matrixNeedle)) throw new Error('COMPLETO renderer: canonical Matrix table anchor not found');
    sql = sql.replace(matrixNeedle, matrixReplacement);
    if (!sql.includes("matrix_owner.dataset_id='DEMO-S'") || !sql.includes("j.id<>private.demo_uuid('access-player:minor_player')")) {
      throw new Error('COMPLETO renderer: canonical DEMO Matrix population guard was not rendered');
    }

    const integrityNeedle = `where j.activo\n      and not exists(`;
    const integrityReplacement = `where j.activo\n      and exists (select 1 from private.demo_dataset_entities owner where owner.dataset_id='DEMO-S' and owner.table_name='jugadores' and owner.entity_id=j.id)\n      and not exists(`;
    if (!sql.includes(integrityNeedle)) throw new Error('COMPLETO renderer: integrity anchor not found');
    sql = sql.replace(integrityNeedle, integrityReplacement);

    const negativeNeedle = `where ec.saldo_pendiente<0`;
    const negativeReplacement = `where ec.saldo_pendiente<0\n      and exists (select 1 from private.demo_dataset_entities owner where owner.dataset_id='DEMO-S' and owner.table_name='economia_cargos' and owner.entity_id=c.id)`;
    if (!sql.includes(negativeNeedle)) throw new Error('COMPLETO renderer: economy balance anchor not found');
    sql = sql.replace(negativeNeedle, negativeReplacement);

    const totalNeedle = `if total<>(select coalesce(sum(case modalidad when 'F11' then 20 when 'F7' then 12 when 'F5' then 8 else 0 end),0)+2
                    from public.equipos e join public.temporadas t on t.id=e.temporada_id where t.estado='activa' and e.activo)
 then raise exception 'MATRIX v3: active player population does not match modality-sized rosters + 2 economy cases: got %',total; end if;`;
    const totalReplacement = `if total<>(select coalesce(sum(case modalidad when 'F11' then 20 when 'F7' then 12 when 'F5' then 8 else 0 end),0)+2
                    from public.equipos e join public.temporadas t on t.id=e.temporada_id where t.estado='activa' and e.activo)
 then raise exception 'MATRIX v3 DEMO: dataset-owned active population does not match modality-sized rosters + 2 economy cases: got %',total; end if;`;
    if (!sql.includes(totalNeedle)) throw new Error('COMPLETO renderer: total assertion anchor not found');
    sql = sql.replace(totalNeedle, totalReplacement);

    // Lifecycle diversity counts must measure the matrix population, not unrelated permanent people.
    sql = sql
      .replace("select count(distinct persona_id) into pending from public.equipacion_estado_operativo where estado_operativo='pendiente_compra';",
               "select count(distinct eo.persona_id) into pending from public.equipacion_estado_operativo eo join test_matrix_players m on m.persona_id=eo.persona_id where eo.estado_operativo='pendiente_compra';")
      .replace("select count(distinct persona_id) into prepared from public.equipacion_estado_operativo where estado_operativo='preparada';",
               "select count(distinct eo.persona_id) into prepared from public.equipacion_estado_operativo eo join test_matrix_players m on m.persona_id=eo.persona_id where eo.estado_operativo='preparada';")
      .replace("select count(distinct persona_id) into delivered from public.equipacion_estado_operativo where estado_operativo='entregada';",
               "select count(distinct eo.persona_id) into delivered from public.equipacion_estado_operativo eo join test_matrix_players m on m.persona_id=eo.persona_id where eo.estado_operativo='entregada';");
  }
}

const forbidden = ["private.test_dataset_entities", "private.test_datasets", "private.test_uuid", "'TEST-S'"];
for (const token of forbidden) {
  if (sql.includes(token)) throw new Error(`Rendered DEMO SQL still contains forbidden TEST token: ${token}`);
}
if (kind === 'reset' && /private\.test_set_(reception_delete_guard|economia_reset_mode)/.test(sql)) {
  throw new Error('Rendered DEMO reset still depends on TEST-named reset helpers');
}
if (sql === source) throw new Error('Renderer made no changes; wrong input?');
fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, sql);
