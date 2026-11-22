import { withSupabase } from 'npm:@supabase/server@^1'

const BASE='https://www.rffm.es'
const CLUB_KEY='LOS YEBENES-SAN BRUNO'
const HEADERS={'User-Agent':'Mozilla/5.0 (compatible; YebenesResultados/2.0)'}
const cache=new Map<string,{at:number,data:any}>()
const CACHE_MS=10*60*1000
async function payloadHash(data:any){const bytes=new TextEncoder().encode(JSON.stringify(data));const digest=await crypto.subtle.digest('SHA-256',bytes);return [...new Uint8Array(digest)].map(x=>x.toString(16).padStart(2,'0')).join('')}
async function persistSnapshot(sb:any,cfg:any,data:any){
  const now=new Date().toISOString(),hash=await payloadHash(data);
  const {data:existing,error:findError}=await sb.from('rffm_resultados_snapshots').select('id,obtenido_at').eq('integracion_id',cfg.id).eq('payload_hash',hash).maybeSingle();
  if(findError)throw findError;
  let snapshot=existing,changed=false;
  if(!snapshot){const {data:created,error}=await sb.from('rffm_resultados_snapshots').insert({integracion_id:cfg.id,payload:data,payload_hash:hash,obtenido_at:now}).select('id,obtenido_at').single();if(error)throw error;snapshot=created;changed=true}
  const {error:stateError}=await sb.from('rffm_resultados_estado').upsert({integracion_id:cfg.id,ultimo_snapshot_id:snapshot.id,ultimo_intento_at:now,ultimo_exito_at:now,ultimo_error:null},{onConflict:'integracion_id'});if(stateError)throw stateError;
  return {snapshotId:snapshot.id,obtenidoAt:snapshot.obtenido_at||now,changed};
}
async function persistAttemptError(sb:any,cfg:any,message:string){if(!cfg?.id)return;const now=new Date().toISOString();await sb.from('rffm_resultados_estado').upsert({integracion_id:cfg.id,ultimo_intento_at:now,ultimo_error:String(message||'Error RFFM').slice(0,2000)},{onConflict:'integracion_id'})}

function norm(s:any){return String(s||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/\s+/g,' ').trim().toUpperCase()}
function canonical(s:any){return norm(s).replace(/^(C\.D\.|CD|CDE|CDB)\s+/,'').trim()}
function teamDiscriminator(name:any){
  const s=norm(name);
  const quoted=s.match(/[\"']([A-Z])['\"]\s*$/);
  if(quoted)return quoted[1];
  const plain=s.match(/(?:^|\s)([A-Z])\s*$/);
  return plain?plain[1]:'';
}
function teamMatches(name:any, externalId:any, configuredId:any, expectedName:any=null){
  const idOk=Boolean(configuredId&&externalId!=null&&String(externalId)===String(configuredId));
  if(configuredId&&externalId!=null&&String(externalId).trim()!=='')return idOk;
  const got=canonical(name),wanted=canonical(CLUB_KEY);
  if(!got.includes(wanted))return false;
  const expectedDiscriminator=teamDiscriminator(expectedName);
  if(!expectedDiscriminator)return true;
  return teamDiscriminator(name)===expectedDiscriminator;
}
function walk(obj:any):any[]{const out:any[]=[];const rec=(x:any)=>{if(Array.isArray(x))x.forEach(rec);else if(x&&typeof x==='object'){out.push(x);Object.values(x).forEach(rec)}};rec(obj);return out}
function pick(d:any,...names:string[]){const low=new Map(Object.entries(d||{}).map(([k,v])=>[k.toLowerCase(),v]));for(const n of names){if(low.has(n.toLowerCase()))return low.get(n.toLowerCase())}return null}
function num(v:any){const n=Number(String(v??'').trim());return Number.isFinite(n)?n:null}
function dateValue(s:any){const m=String(s||'').match(/^(\d{2})[\/-](\d{2})[\/-](\d{4})/);return m?new Date(`${m[3]}-${m[2]}-${m[1]}T12:00:00Z`):null}
function logoUrl(path:any){const p=String(path||'').trim();return p.startsWith('/pnfg/pimg/Clubes/')?`https://appweb.rffm.es${p}`:null}
async function getPageProps(url:string){const r=await fetch(url,{headers:HEADERS});if(!r.ok)throw new Error(`RFFM HTTP ${r.status}`);const html=await r.text();const m=html.match(/<script[^>]+id=["']__NEXT_DATA__["'][^>]*>([\s\S]*?)<\/script>/i);if(!m)throw new Error('RFFM no devolvió datos de competición');const data=JSON.parse(m[1]);return data?.props?.pageProps||{}}
function cfgUrl(cfg:any,path:string,extra=''){const season=String(cfg?.config?.season_id||'22');return `${BASE}${path}?competicion=${encodeURIComponent(cfg.competition_id)}&grupo=${encodeURIComponent(cfg.group_id)}&temporada=${encodeURIComponent(season)}&tipojuego=${encodeURIComponent(cfg.game_type)}${extra}`}
async function parseRound(cfg:any,jornada:number){const url=cfgUrl(cfg,'/competicion/resultados-y-jornadas',`&jornada=${jornada}`), pp=await getPageProps(url), results=pp?.results||{}, out:any[]=[];for(const p of results?.partidos||[]){const home=p.Nombre_equipo_local||'',away=p.Nombre_equipo_visitante||'';const homeIs=teamMatches(home,p.CodEquipo_local,cfg.external_team_id,cfg.expected_team_name),awayIs=teamMatches(away,p.CodEquipo_visitante,cfg.external_team_id,cfg.expected_team_name);if(!homeIs&&!awayIs)continue;let score=null;if(p.Goles_casa!==null&&p.Goles_casa!==''&&p.Goles_visitante!==null&&p.Goles_visitante!=='')score=[String(p.Goles_casa),String(p.Goles_visitante)];out.push({jornada,date:p.fecha,time:p.hora,score,home,away,teamName:homeIs?home:away,opponent:homeIs?away:home,place:String(p.campojuego||'').trim(),teamId:homeIs?p.CodEquipo_local:p.CodEquipo_visitante,homeLogo:logoUrl(p.url_img_local),awayLogo:logoUrl(p.url_img_visitante),matchId:p.codacta})}return {matches:out,results}}
async function classification(cfg:any){
  const url=cfgUrl(cfg,'/competicion/clasificaciones');
  const page=await getPageProps(url);

  // Faithful TypeScript port of yebenes_rffm_web_v27/server.py::parse_classification.
  const intNum=(v:any)=>{const n=Number.parseInt(String(v??'').trim(),10);return Number.isFinite(n)?n:null};
  const teamName=(d:any)=>{
    const direct=pick(d,'nombre_equipo','Nombre_equipo','equipo','Equipo','nombre','Nombre','teamName');
    if(typeof direct==='string'&&direct.trim())return direct.trim();
    for(const [k,v] of Object.entries(d||{})){
      const kl=String(k).toLowerCase();
      if(typeof v==='string'&&kl.includes('equipo')&&(kl.includes('nombre')||kl==='equipo'))return v.trim();
    }
    return null;
  };
  const teamId=(d:any)=>{
    const direct=pick(d,'codigo_equipo','CodigoEquipo','CodEquipo','cod_equipo','id_equipo','equipo_id');
    if(direct!==null&&direct!==undefined)return String(direct);
    for(const [k,v] of Object.entries(d||{})){
      const kl=String(k).toLowerCase();
      if(kl.includes('equipo')&&(kl.includes('cod')||kl.startsWith('id'))&&v!==null&&v!==undefined)return String(v);
    }
    return '';
  };
  const logoPath=(d:any)=>{
    const direct=pick(d,'url_img','url_imagen','url_img_equipo','imagen','escudo','logo','url_logo');
    if(typeof direct==='string'&&direct.trim())return direct.trim();
    for(const [k,v] of Object.entries(d||{})){
      const kl=String(k).toLowerCase();
      if(typeof v==='string'&&(kl.includes('img')||kl.includes('imagen')||kl.includes('escudo')||kl.includes('logo'))&&(/\/pnfg\//i.test(v)||/\.(png|jpe?g|webp|jfif)$/i.test(v)))return v.trim();
    }
    return '';
  };
  const normLoose=(v:any)=>norm(v).replace(/[-_]/g,' ').replace(/[^A-Z0-9]+/g,' ').replace(/\s+/g,' ').trim();

  const rows:any[]=[];
  const seen=new Set<string>();
  for(const d of walk(page)){
    if(!d||typeof d!=='object'||Array.isArray(d))continue;
    const name=teamName(d);
    const pos=intNum(pick(d,'posicion','puesto','Posicion','orden','clasificacion'));
    const pts=intNum(pick(d,'puntos','Puntos','ptos','Pts','puntos_totales'));
    const played=intNum(pick(d,'jugados','Jugados','partidos_jugados','PJ','pj'));
    if(!name||pos===null||(pts===null&&played===null))continue;
    const tid=teamId(d);
    const key=`${pos}|${tid||normLoose(name)}`;
    if(seen.has(key))continue;
    seen.add(key);
    const lp=logoPath(d);
    rows.push({position:pos,team:name,teamId:tid||null,points:pts,played,logo:lp?logoUrl(lp):null});
  }
  rows.sort((a,b)=>a.position-b.position);

  const configuredId=String(cfg?.external_team_id||'');
  let currentIdx:number|null=null;

  // 1) Strong identity: use the external RFFM team id whenever the standings expose it.
  if(configuredId){
    const exactIdx=rows.findIndex(r=>String(r.teamId||'')===configuredId);
    if(exactIdx>=0)currentIdx=exactIdx;
  }

  // 2) Name fallback. Preserve A/B/C discrimination when RFFM exposes the suffix.
  if(currentIdx===null){
    const clubRows=rows
      .map((r,i)=>({r,i}))
      .filter(x=>canonical(x.r.team).includes(canonical(CLUB_KEY)));
    const expectedDiscriminator=teamDiscriminator(cfg.expected_team_name);
    if(expectedDiscriminator){
      const discriminated=clubRows.filter(x=>teamDiscriminator(x.r.team)===expectedDiscriminator);
      if(discriminated.length===1)currentIdx=discriminated[0].i;
      // Some standings payloads omit the A/B suffix and also omit CodEquipo.
      // Relax only when there is a single Los Yebenes candidate; never when A/B coexist.
      else if(discriminated.length===0&&clubRows.length===1)currentIdx=clubRows[0].i;
    }else if(clubRows.length===1){
      currentIdx=clubRows[0].i;
    }
  }

  const result:any={url};
  if(currentIdx!==null){
    const cur=rows[currentIdx];
    result.position=cur.position;result.points=cur.points;result.played=cur.played;result.teamName=cur.team;
    let start=Math.max(0,currentIdx-2);
    if(rows.length>=5)start=Math.min(start,rows.length-5);
    result.context=rows.slice(start,start+5);
    result.all=rows;
  }
  return result;
}
function competitionMeta(page:any){
  const direct=pick(page?.results||page,'nombre_competicion','NombreCompeticion','competicion_nombre','competicion');
  if(typeof direct==='string'&&direct.trim())return {competitionName:direct.trim()};
  const candidates:any[]=[];
  for(const d of walk(page)){
    if(!d||typeof d!=='object'||Array.isArray(d))continue;
    for(const [k,v] of Object.entries(d)){
      if(typeof v!=='string'||!v.trim())continue;
      const kl=String(k).toLowerCase();
      if(kl.includes('competicion')&&(kl.includes('nombre')||kl==='competicion'))candidates.push(v.trim());
    }
  }
  const name=candidates.find(x=>x.length>3&&x.length<120)||null;
  return {competitionName:name};
}
function scorerName(d:any){
  const direct=pick(d,'jugador','Jugador','nombre_jugador','NombreJugador','nombre','Nombre','deportista');
  if(typeof direct==='string'&&direct.trim())return direct.trim();
  for(const [k,v] of Object.entries(d||{})){const kl=String(k).toLowerCase();if(typeof v==='string'&&kl.includes('jugador')&&kl.includes('nombre'))return v.trim()}
  return null;
}
function scorerTeam(d:any){
  const direct=pick(d,'equipo','Equipo','nombre_equipo','Nombre_equipo','NombreEquipo','team');
  if(typeof direct==='string'&&direct.trim())return direct.trim();
  for(const [k,v] of Object.entries(d||{})){const kl=String(k).toLowerCase();if(typeof v==='string'&&kl.includes('equipo')&&(kl.includes('nombre')||kl==='equipo'))return v.trim()}
  return null;
}
function scorerGoals(d:any){
  const raw=pick(d,'goles','Goles','total_goles','goles_total','num_goles','NumGoles');
  if(raw!==null&&raw!==undefined){const m=String(raw).match(/\d+/);if(m)return Number(m[0])}
  for(const [k,v] of Object.entries(d||{})){if(String(k).toLowerCase().includes('gol')){const m=String(v??'').match(/\d+/);if(m)return Number(m[0])}}
  return null;
}
function scorerPenalties(d:any){
  const raw=pick(d,'penaltis','Penaltis','penalties','goles_penalti','GolesPenalti');
  if(raw!==null&&raw!==undefined){const m=String(raw).match(/\d+/);if(m)return Number(m[0])}
  const goalsRaw=pick(d,'goles','Goles','total_goles');
  const m=String(goalsRaw??'').match(/\((\d+)P\)/i);return m?Number(m[1]):0;
}
async function scorers(cfg:any,jornada:number|null=null){
  try{
    const url=cfgUrl(cfg,'/competicion/goleadores',jornada?`&jornada=${jornada}`:'');
    const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),3500);
    let page:any;
    try{
      const r=await fetch(url,{headers:HEADERS,signal:controller.signal});
      if(!r.ok)throw new Error(`RFFM HTTP ${r.status}`);
      const html=await r.text(),m=html.match(/<script[^>]+id=["']__NEXT_DATA__["'][^>]*>([\s\S]*?)<\/script>/i);
      if(!m)throw new Error('RFFM no devolvió datos de goleadores');
      page=JSON.parse(m[1])?.props?.pageProps||{};
    }finally{clearTimeout(timer)}
    const rows:any[]=[],seen=new Set<string>();
    for(const d of walk(page)){
      if(!d||typeof d!=='object'||Array.isArray(d))continue;
      const player=scorerName(d),team=scorerTeam(d),goals=scorerGoals(d);
      if(!player||!team||goals===null||!teamMatches(team,pick(d,'CodEquipo','codigo_equipo','equipo_id'),cfg.external_team_id,cfg.expected_team_name))continue;
      const key=`${norm(player)}|${norm(team)}`;if(seen.has(key))continue;seen.add(key);
      rows.push({player,team,goals,penalties:scorerPenalties(d)});
    }
    rows.sort((a,b)=>b.goals-a.goals||a.player.localeCompare(b.player,'es'));
    return {url,top:rows.slice(0,3)};
  }catch{return {url:cfgUrl(cfg,'/competicion/goleadores',jornada?`&jornada=${jornada}`:''),top:[]}}
}
async function teamData(cfg:any){
  const probe=await getPageProps(cfgUrl(cfg,'/competicion/resultados-y-jornadas')),results=probe?.results||{},meta=competitionMeta(probe);
  const jornadas:any[]=[];
  for(const block of results?.listado_jornadas||[])for(const j of block?.jornadas||[]){const n=Number(j.codjornada);if(Number.isFinite(n))jornadas.push({n,date:dateValue(String(j.fecha_jornada||'').replace(/-/g,'/'))})}
  const today=new Date(),past=jornadas.filter(x=>!x.date||x.date<=today).slice(-3),future=jornadas.filter(x=>x.date&&x.date>today).slice(0,3),targets=[...new Set([...past,...future].map(x=>x.n))];
  let matches:any[]=[];
  for(const j of targets){try{matches.push(...(await parseRound(cfg,j)).matches)}catch{}}
  if(!matches.length){for(const j of jornadas.slice(0,40)){try{matches.push(...(await parseRound(cfg,j.n)).matches)}catch{}if(matches.length>=2)break}}
  const unique:any[]=[],sig=new Set<string>();for(const m of matches){const k=`${m.jornada}|${m.matchId}|${m.home}|${m.away}`;if(!sig.has(k)){sig.add(k);unique.push(m)}}
  const completed=unique.filter(m=>m.score&&dateValue(m.date)&&dateValue(m.date)!<=today).sort((a,b)=>(dateValue(a.date)?.getTime()||0)-(dateValue(b.date)?.getTime()||0));
  const upcoming=unique.filter(m=>!m.score&&dateValue(m.date)&&dateValue(m.date)!>=new Date(today.toISOString().slice(0,10))).sort((a,b)=>(dateValue(a.date)?.getTime()||0)-(dateValue(b.date)?.getTime()||0));
  const latestScorerRound=past.length?past[past.length-1].n:(jornadas.length?jornadas[jornadas.length-1].n:null);
  const [cls,sc]=await Promise.all([classification(cfg),scorers(cfg,latestScorerRound)]);
  return {lastMatch:completed.at(-1)||null,nextMatch:upcoming[0]||null,classification:cls,teamName:(completed.at(-1)||upcoming[0])?.teamName||cls?.teamName||null,competitionName:meta.competitionName||null,scorers:sc.top};
}

function fail(status:number,code:string,phase:string,message:string,details:any=null){return Response.json({ok:false,error:message,message,code,phase,details},{status})}
export default {fetch:withSupabase({auth:'user'},async(req,ctx)=>{let phase='request',cfg:any=null;try{if(req.method!=='POST')return fail(405,'METHOD_NOT_ALLOWED',phase,'Método no permitido');const body=await req.json().catch(()=>({})),teamId=String(body?.team_id||''),action=String(body?.action||'team');if(!teamId)return fail(400,'TEAM_ID_REQUIRED',phase,'team_id obligatorio');phase='authorization';const {data:canRead,error:authError}=await ctx.supabase.rpc('puede_consultar_rffm_equipo',{p_equipo_id:teamId});if(authError)throw authError;if(canRead!==true)return fail(403,'RFFM_TEAM_FORBIDDEN',phase,'No tienes permiso para consultar RFFM de este equipo');if(action==='validate'){const {data:canManage,error:manageError}=await ctx.supabase.rpc('puede_gestionar_rffm');if(manageError)throw manageError;if(canManage!==true)return fail(403,'RFFM_CONFIG_FORBIDDEN',phase,'Solo Club o Administrador pueden validar la configuración RFFM');}phase='config';const {data:cfgRow,error}=await ctx.supabaseAdmin.from('equipo_integraciones_federacion').select('*').eq('equipo_id',teamId).eq('proveedor','RFFM').maybeSingle();if(error)throw error;cfg=cfgRow;if(!cfg||!cfg.activo)return fail(404,'RFFM_CONFIG_NOT_ACTIVE',phase,'El equipo no tiene integración RFFM activa');
phase='team-context';
const {data:teamRow,error:teamError}=await ctx.supabaseAdmin.from('equipos').select('nombre,codigo').eq('id',teamId).maybeSingle();
if(teamError)throw teamError;
cfg={...cfg,expected_team_name:teamRow?.nombre||teamRow?.codigo||null};
phase='fetch';const key=`${cfg.equipo_id}|${cfg.competition_id}|${cfg.group_id}|${cfg.game_type}|${cfg.external_team_id||''}`,hit=cache.get(key);let data=hit&&Date.now()-hit.at<CACHE_MS&&!body?.force?hit.data:null;if(!data){data=await teamData(cfg);cache.set(key,{at:Date.now(),data})}phase='snapshot-write';const snapshot=await persistSnapshot(ctx.supabaseAdmin,cfg,data);phase='validate';if(action==='validate'){const ok=Boolean(data.teamName||data.classification?.position);const msg=ok?`Equipo localizado${data.teamName?`: ${data.teamName}`:''}`:'No se ha localizado el equipo en resultados o clasificación';phase='validation-write';const {error:writeError}=await ctx.supabaseAdmin.from('equipo_integraciones_federacion').update({ultima_validacion_at:new Date().toISOString(),ultima_validacion_ok:ok,ultima_validacion_mensaje:msg}).eq('id',cfg.id);if(writeError)throw writeError;if(!ok)return fail(422,'TEAM_NOT_FOUND','validation',msg,{competition_id:cfg.competition_id,group_id:cfg.group_id,game_type:cfg.game_type,external_team_id:cfg.external_team_id});return Response.json({ok:true,...data,_cache:snapshot})}return Response.json({ok:true,...data,_cache:snapshot})}catch(e){const message=String((e as any)?.message||e);try{await persistAttemptError(ctx.supabaseAdmin,cfg,message)}catch{}return fail(500,'RFFM_INTERNAL_ERROR',phase,message)}})}
