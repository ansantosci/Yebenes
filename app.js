const APP_VERSION='29';
const DATA_VERSION='13';
const SUPABASE_URL='https://ypyzochuqtetddffohpv.supabase.co';
const SUPABASE_PUBLISHABLE_KEY='sb_publishable_AZkaUtTojw0Xrxu3dwgkhg_2QFNU1q3';
const sb=window.supabase?.createClient(SUPABASE_URL,SUPABASE_PUBLISHABLE_KEY,{
  auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}
});
const DB_ROLE_TO_APP={administrador:'admin',club:'club',entrenador:'coach',tutor:'family',jugador:'player'};
const K={
  users:`yebenes-users-v${DATA_VERSION}`,session:`yebenes-session-v${DATA_VERSION}`,players:`yebenes-players-v${DATA_VERSION}`,
  seasons:`yebenes-seasons-v${DATA_VERSION}`,categories:`yebenes-categories-v${DATA_VERSION}`,teams:`yebenes-teams-v${DATA_VERSION}`,
  inscriptions:`yebenes-inscriptions-v${DATA_VERSION}`,reps:`yebenes-representations-v${DATA_VERSION}`,playerTeams:`yebenes-player-teams-v${DATA_VERSION}`,
  medicals:`yebenes-medicals-v${DATA_VERSION}`,coaches:`yebenes-coaches-v${DATA_VERSION}`,statusHistory:`yebenes-status-history-v${DATA_VERSION}`,
  audit:`yebenes-audit-v${DATA_VERSION}`,currentSeason:`yebenes-current-season-v${DATA_VERSION}`,sessionRole:`yebenes-session-role-v${DATA_VERSION}`,persons:'yebenes-persons-v1'
};
const LEGACY={users:'yebenes-users-v6',players:'yebenes-players-v6',coaches:'yebenes-coaches-v8',teams:'yebenes-teams-v8'};
const V12={users:'yebenes-users-v12',players:'yebenes-players-v12',seasons:'yebenes-seasons-v12',categories:'yebenes-categories-v12',teams:'yebenes-teams-v12',inscriptions:'yebenes-inscriptions-v12',reps:'yebenes-representations-v12',playerTeams:'yebenes-player-teams-v12',medicals:'yebenes-medicals-v12',coaches:'yebenes-coaches-v12',statusHistory:'yebenes-status-history-v12',audit:'yebenes-audit-v12',currentSeason:'yebenes-current-season-v12'};
const V11={users:'yebenes-users-v11',players:'yebenes-players-v11',seasons:'yebenes-seasons-v11',categories:'yebenes-categories-v11',teams:'yebenes-teams-v11',inscriptions:'yebenes-inscriptions-v11',reps:'yebenes-representations-v11',playerTeams:'yebenes-player-teams-v11',medicals:'yebenes-medicals-v11',coaches:'yebenes-coaches-v11',statusHistory:'yebenes-status-history-v11',audit:'yebenes-audit-v11',currentSeason:'yebenes-current-season-v11'};
const WORKFLOW=[
  {key:'review',label:'Pendiente de revisión inicial',federation:'Pendiente de revisión'},
  {key:'initial_ok',label:'Inscripción inicial validada',federation:'Inscripción validada'},
  {key:'medical',label:'Pendiente de reconocimiento médico',federation:'Pendiente de RRMM'},
  {key:'ready',label:'Listo para federar',federation:'Listo para federar'},
  {key:'federated',label:'Ficha tramitada',federation:'Ficha tramitada'}
];
const $=s=>document.querySelector(s), $$=s=>[...document.querySelectorAll(s)];
const esc=(s='')=>String(s).replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
const readJSON=(k,f)=>{try{return JSON.parse(localStorage.getItem(k))??f}catch{return f}};
const writeJSON=(k,v)=>localStorage.setItem(k,JSON.stringify(v));
const isoToday=()=>new Date().toISOString().slice(0,10);
const parseDate=v=>{if(!v)return null;const [y,m,d]=v.split('-').map(Number);return new Date(y,m-1,d)};
const fmt=v=>{const d=parseDate(v);return d?new Intl.DateTimeFormat('es-ES').format(d):'—'};
const addYears=(v,n)=>{const d=parseDate(v);if(!d)return '';d.setFullYear(d.getFullYear()+n);return d.toISOString().slice(0,10)};
const dayDiff=(a,b)=>Math.ceil((parseDate(b)-parseDate(a))/86400000);
const ROLE_LABELS={admin:'Administrador',club:'Usuario del club',coach:'Entrenador',family:'Tutor / Familia',player:'Jugador'};
const roleLabel=r=>ROLE_LABELS[r]||r;
const normalizeUser=u=>{if(!u)return u;u.roles=Array.isArray(u.roles)&&u.roles.length?[...new Set(u.roles)]:[u.role||'family'];return u};
const normText=v=>String(v||'').trim().toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/\s+/g,' ');
const normDni=v=>String(v||'').toUpperCase().replace(/[^A-Z0-9]/g,'');
const personForUser=id=>persons.find(p=>p.id===users.find(u=>u.id===id)?.personId);
const personForPlayer=id=>persons.find(p=>p.id===players.find(x=>x.id===id)?.personId);
function ensurePersons(){
  persons=readJSON(K.persons,[]);
  const byId=new Map(persons.map(p=>[p.id,p]));
  const make=(name,email='',dni='')=>{const x={id:uid('person'),name:name||'Persona',email:String(email||'').toLowerCase(),dni:normDni(dni),createdAt:isoToday(),mergedFrom:[]};persons.push(x);byId.set(x.id,x);return x};
  users.forEach(u=>{if(u.personId&&byId.has(u.personId))return;let x=null;if(u.playerId){const pl=players.find(p=>p.id===u.playerId);if(pl?.personId&&byId.has(pl.personId))x=byId.get(pl.personId)}if(!x&&u.email)x=persons.find(p=>p.email&&p.email===String(u.email).toLowerCase());if(!x)x=make(u.name,u.email,u.dni||'');if(!x.dni&&u.dni)x.dni=normDni(u.dni);u.personId=x.id});
  players.forEach(pl=>{if(pl.personId&&byId.has(pl.personId))return;let x=null;const linked=users.find(u=>u.playerId===pl.id);if(linked?.personId)x=byId.get(linked.personId);if(!x&&pl.dni)x=persons.find(p=>p.dni&&p.dni===normDni(pl.dni));if(!x)x=make(pl.name,'',pl.dni);pl.personId=x.id});
  persons.forEach(p=>{const us=users.filter(u=>u.personId===p.id),ps=players.filter(x=>x.personId===p.id);p.name=us[0]?.name||ps[0]?.name||p.name;p.email=us[0]?.email||p.email||'';p.dni=normDni(ps.find(x=>x.dni)?.dni||p.dni||'')});
  saveUsers();savePlayers();writeJSON(K.persons,persons);
}
function personSignals(p){const us=users.filter(u=>u.personId===p.id),ps=players.filter(x=>x.personId===p.id);return{emails:[...new Set(us.flatMap(u=>[u.email,...(u.emailAliases||[])]).filter(Boolean).map(x=>String(x).toLowerCase()))],dnis:[...new Set([normDni(p.dni),...ps.map(x=>normDni(x.dni))].filter(Boolean))],nameBirth:[...new Set(ps.filter(x=>x.birth).map(x=>`${normText(x.name)}|${x.birth}`))]}}
function duplicatePairs(){const out=[];for(let i=0;i<persons.length;i++)for(let j=i+1;j<persons.length;j++){const a=personSignals(persons[i]),b=personSignals(persons[j]);const reasons=[];if(a.emails.some(x=>b.emails.includes(x)))reasons.push('mismo correo');if(a.dnis.some(x=>b.dnis.includes(x)))reasons.push('mismo DNI/NIE');if(a.nameBirth.some(x=>b.nameBirth.includes(x)))reasons.push('mismo nombre y fecha de nacimiento');if(reasons.length)out.push({a:persons[i],b:persons[j],reasons})}return out}
function mergePersons(primaryId,secondaryId){if(primaryId===secondaryId)return;const A=persons.find(p=>p.id===primaryId),B=persons.find(p=>p.id===secondaryId);if(!A||!B)return;const aPlayers=players.filter(p=>p.personId===A.id),bPlayers=players.filter(p=>p.personId===B.id);let keepPlayer=aPlayers[0]||null;for(const bp of bPlayers){if(!keepPlayer){bp.personId=A.id;keepPlayer=bp;continue}const clash=inscriptions.some(i=>i.playerId===keepPlayer.id&&inscriptions.some(j=>j.playerId===bp.id&&j.seasonId===i.seasonId));if(clash){alert('No se pueden fusionar automáticamente estas personas porque tienen dos inscripciones en la misma temporada. Requiere revisión manual.');return}inscriptions.forEach(x=>{if(x.playerId===bp.id)x.playerId=keepPlayer.id});representations.forEach(x=>{if(x.playerId===bp.id)x.playerId=keepPlayer.id});playerTeams.forEach(x=>{if(x.playerId===bp.id)x.playerId=keepPlayer.id});medicals.forEach(x=>{if(x.playerId===bp.id)x.playerId=keepPlayer.id});statusHistory.forEach(x=>{if(x.playerId===bp.id)x.playerId=keepPlayer.id});users.forEach(u=>{if(u.playerId===bp.id)u.playerId=keepPlayer.id});if(!keepPlayer.dni&&bp.dni)keepPlayer.dni=bp.dni;if(!keepPlayer.birth&&bp.birth)keepPlayer.birth=bp.birth;players=players.filter(x=>x.id!==bp.id)}
  const aUsers=users.filter(u=>u.personId===A.id),bUsers=users.filter(u=>u.personId===B.id);let keepUser=aUsers[0]||null;for(const bu of bUsers){if(!keepUser){bu.personId=A.id;keepUser=bu;continue}keepUser.roles=[...new Set([...(keepUser.roles||[]),...(bu.roles||[])])];keepUser.emailAliases=[...new Set([...(keepUser.emailAliases||[]),bu.email,...(bu.emailAliases||[])].filter(x=>x&&x!==keepUser.email))];representations.forEach(r=>{if(r.userId===bu.id)r.userId=keepUser.id});const bc=coaches.find(c=>c.userId===bu.id),ac=coaches.find(c=>c.userId===keepUser.id);if(bc){if(ac){ac.assignments=[...(ac.assignments||[]),...(bc.assignments||[])];ac.hasLicense=ac.hasLicense||bc.hasLicense;ac.delegateCourse=ac.delegateCourse||bc.delegateCourse;coaches=coaches.filter(c=>c.id!==bc.id)}else bc.userId=keepUser.id}users=users.filter(x=>x.id!==bu.id)}
  users.forEach(u=>{if(u.personId===B.id)u.personId=A.id});players.forEach(p=>{if(p.personId===B.id)p.personId=A.id});A.name=A.name||B.name;A.email=A.email||B.email;A.dni=A.dni||B.dni;A.mergedFrom=[...(A.mergedFrom||[]),B.id,...(B.mergedFrom||[])];persons=persons.filter(p=>p.id!==B.id);saveAll();writeJSON(K.persons,persons);recordAudit('Fusión de personas','',`${B.name} → ${A.name}`);renderPersons();renderClubUsers();renderClub();}
function duplicatePlayerMatch(name,birth,dni,excludeId=''){const nd=normDni(dni),nn=normText(name);return players.find(p=>p.id!==excludeId&&((nd&&normDni(p.dni)===nd)||(birth&&p.birth===birth&&normText(p.name)===nn)))}
function personWithOwnDni(dni,excludePersonId=''){const nd=normDni(dni);return nd?persons.find(p=>p.id!==excludePersonId&&normDni(p.dni)===nd):null}
const hasRole=(u,r)=>!!u&&normalizeUser(u).roles.includes(r);
const internalRoles=u=>normalizeUser(u).roles.filter(r=>['admin','club','coach'].includes(r));
const roleAvailable=(u,r,when=isoToday())=>hasRole(u,r)&&!(r==='player'&&u.pendingActivationDate&&when<u.pendingActivationDate);
const availableRoles=u=>normalizeUser(u).roles.filter(r=>roleAvailable(u,r));
const workflowLabel=k=>WORKFLOW.find(x=>x.key===k)?.label||'Pendiente de revisión';
const coachRoleLabel=v=>v==='first'?'Primer entrenador':'Segundo entrenador';
const uid=p=>`${p}-${Date.now()}-${Math.random().toString(36).slice(2,7)}`;

const seedSeasons=[{id:'s-2026',name:'2026/2027',startDate:'2026-07-01',endDate:'2027-06-30',active:true},{id:'s-2027',name:'2027/2028',startDate:'2027-07-01',endDate:'2028-06-30',active:false}];
const seedCategories=[
  {id:'cat-chu',name:'Chupetín',active:true},{id:'cat-pb',name:'Prebenjamín',active:true},{id:'cat-ben',name:'Benjamín',active:true},
  {id:'cat-ale',name:'Alevín',active:true},{id:'cat-inf',name:'Infantil',active:true},{id:'cat-cad',name:'Cadete',active:true},
  {id:'cat-juv',name:'Juvenil',active:true},{id:'cat-sen',name:'Senior',active:true}
];
const seedUsers=[
  {id:'u-admin',name:'Administrador del Club',email:'admin@yebenes.demo',phone:'',password:'demo123',roles:['admin'],active:true},
  {id:'u-club',name:'Usuario del Club',email:'club@yebenes.demo',phone:'',password:'demo123',roles:['club'],active:true},
  {id:'u-coach',name:'Carlos Martín López',email:'entrenador@yebenes.demo',phone:'',password:'demo123',roles:['coach'],active:true},
  {id:'u-family',name:'Familia Santos',email:'familia@yebenes.demo',phone:'600000000',dni:'12345678Z',password:'demo123',roles:['family'],active:true},
  {id:'u-player',name:'Jorge Adulto Demo',email:'jugador@yebenes.demo',phone:'',password:'demo123',roles:['player'],active:true,playerId:'p-jorge'},
  {id:'u-multi',name:'Persona Multirol Demo',email:'multi@yebenes.demo',phone:'600111222',password:'demo123',roles:['family','player','coach','club'],active:true,playerId:'p-multi'}
]
const seedPlayers=[
  {id:'p-daniel',name:'Daniel Santos García',birth:'2019-05-12',dni:'',data:true,active:true},
  {id:'p-alvaro',name:'Álvaro Santos García',birth:'2017-11-03',dni:'',data:true,active:true},
  {id:'p-hugo',name:'Hugo Pérez Martín',birth:'2015-02-21',dni:'',data:true,active:true},
  {id:'p-lucia',name:'Lucía Moreno Díaz',birth:'2013-09-14',dni:'',data:true,active:true},
  {id:'p-jorge',name:'Jorge Adulto Demo',birth:'2008-03-01',dni:'',data:true,active:true},
  {id:'p-multi',name:'Persona Multirol Demo',birth:'1990-04-10',dni:'',data:true,active:true}
];
const seedTeams=[
  {id:'t-pb-a',seasonId:'s-2026',name:'Prebenjamín A',categoryId:'cat-pb',active:true},
  {id:'t-pb-b',seasonId:'s-2026',name:'Prebenjamín B',categoryId:'cat-pb',active:true},
  {id:'t-ben-a',seasonId:'s-2026',name:'Benjamín A',categoryId:'cat-ben',active:true},
  {id:'t-ale-a',seasonId:'s-2026',name:'Alevín A',categoryId:'cat-ale',active:true},
  {id:'t-inf-a',seasonId:'s-2026',name:'Infantil A',categoryId:'cat-inf',active:true},
  {id:'t-sen-a',seasonId:'s-2026',name:'Senior A',categoryId:'cat-sen',active:true}
];
const seedInscriptions=[
  {id:'i-daniel-26',playerId:'p-daniel',seasonId:'s-2026',categoryId:'cat-pb',docs:'Completa',workflow:'ready',federation:'Listo para federar',status:'complete',familyActionRequired:false,returnMessage:'',createdAt:'2026-06-10'},
  {id:'i-alvaro-26',playerId:'p-alvaro',seasonId:'s-2026',categoryId:'cat-ben',docs:'Falta fotografía',workflow:'review',federation:'Pendiente de revisión',status:'pending',familyActionRequired:false,returnMessage:'',createdAt:'2026-06-11'},
  {id:'i-hugo-26',playerId:'p-hugo',seasonId:'s-2026',categoryId:'cat-ale',docs:'Falta DNI/NIE',workflow:'review',federation:'Pendiente',status:'pending',familyActionRequired:false,returnMessage:'',createdAt:'2026-06-12'},
  {id:'i-lucia-26',playerId:'p-lucia',seasonId:'s-2026',categoryId:'cat-inf',docs:'Completa',workflow:'federated',federation:'Ficha tramitada',status:'complete',familyActionRequired:false,returnMessage:'',createdAt:'2026-06-01'},
  {id:'i-jorge-26',playerId:'p-jorge',seasonId:'s-2026',categoryId:'cat-sen',docs:'Completa',workflow:'initial_ok',federation:'Inscripción validada',status:'pending',familyActionRequired:false,returnMessage:'',createdAt:'2026-07-15'},
  {id:'i-multi-26',playerId:'p-multi',seasonId:'s-2026',categoryId:'cat-sen',docs:'Completa',workflow:'federated',federation:'Ficha tramitada',status:'complete',familyActionRequired:false,returnMessage:'',createdAt:'2026-07-01'}
];
const seedReps=[
  {id:'r-daniel',playerId:'p-daniel',userId:'u-family',type:'guardian',startDate:'2026-06-10',endDate:'',reason:'Inscripción inicial',legalException:false},
  {id:'r-alvaro',playerId:'p-alvaro',userId:'u-family',type:'guardian',startDate:'2026-06-11',endDate:'',reason:'Inscripción inicial',legalException:false},
  {id:'r-jorge',playerId:'p-jorge',userId:'u-player',type:'self',startDate:'2026-03-01',endDate:'',reason:'Mayoría de edad',legalException:false},
  {id:'r-multi',playerId:'p-multi',userId:'u-multi',type:'self',startDate:'2026-07-01',endDate:'',reason:'Autorregistro adulto',legalException:false}
];
const seedPlayerTeams=[
  {id:'pt-daniel',playerId:'p-daniel',seasonId:'s-2026',teamId:'t-pb-a',startDate:'2026-09-01',endDate:'2027-06-30',reason:'Asignación inicial'},
  {id:'pt-lucia',playerId:'p-lucia',seasonId:'s-2026',teamId:'t-inf-a',startDate:'2026-09-01',endDate:'2027-06-30',reason:'Asignación inicial'},
  {id:'pt-jorge',playerId:'p-jorge',seasonId:'s-2026',teamId:'t-sen-a',startDate:'2026-09-01',endDate:'2027-06-30',reason:'Asignación inicial'},
  {id:'pt-multi',playerId:'p-multi',seasonId:'s-2026',teamId:'t-sen-a',startDate:'2026-09-01',endDate:'2027-06-30',reason:'Asignación inicial'}
];
const seedMedicals=[
  {id:'m-daniel',playerId:'p-daniel',date:'2026-06-15',expiry:'2027-06-15',validatedAt:'2026-06-16'},
  {id:'m-alvaro',playerId:'p-alvaro',date:'2025-12-10',expiry:'2026-11-20',validatedAt:'2025-12-11'},
  {id:'m-lucia',playerId:'p-lucia',date:'2025-09-01',expiry:'2026-09-01',validatedAt:'2025-09-02'}
];
const seedCoaches=[
  {id:'c1',userId:'u-coach',name:'Carlos Martín López',assignments:[{teamId:'t-pb-a',coachRole:'first',startDate:'2026-09-01',endDate:'2027-06-30'}],hasLicense:true,licenseType:'UEFA C',delegateCourse:true,active:true},
  {id:'c2',userId:null,name:'Javier Ruiz Gómez',assignments:[{teamId:'t-pb-b',coachRole:'second',startDate:'2026-09-01',endDate:'2027-06-30'}],hasLicense:false,licenseType:'',delegateCourse:true,active:true},
  {id:'c3',userId:null,name:'Marta Sánchez Gil',assignments:[{teamId:'t-ale-a',coachRole:'first',startDate:'2026-09-01',endDate:'2027-06-30'}],hasLicense:true,licenseType:'UEFA B',delegateCourse:false,active:true},
  {id:'c4',userId:null,name:'Luis Moreno Pérez',assignments:[{teamId:'t-inf-a',coachRole:'second',startDate:'2026-09-01',endDate:'2027-06-30'}],hasLicense:true,licenseType:'UEFA C',delegateCourse:true,active:true},
  {id:'c5',userId:'u-multi',name:'Persona Multirol Demo',assignments:[{teamId:'t-pb-b',coachRole:'first',startDate:'2026-09-01',endDate:'2027-06-30'}],hasLicense:true,licenseType:'UEFA C',delegateCourse:true,active:true}
];

let users=[],players=[],persons=[],seasons=[],categories=[],teams=[],inscriptions=[],representations=[],playerTeams=[],medicals=[],coaches=[],statusHistory=[],audit=[],currentUser=null,currentRole=null,currentSeasonId='s-2026';
let dbSeasons=[],dbCategories=[],dbTeams=[],dbCategoryRules=[],dbStructureLoaded=false;
let remoteClubPlayers=[],selectedRemotePlayerId=null;
let remoteFamilyPlayers=[];
let remoteMedicalRows=[];
const PENDING_SIGNUP_KEY='yebenes-pending-signup-v1';
const AUTH_REDIRECT_URL='https://ansantosci.github.io/Yebenes/';
let selectedPlayerId=null,editingPlayerId=null,selectedMedicalPlayerId=null,editingCoachId=null,editingTeamId=null,pendingCoachAssignments=[],pendingUserAssignments=[];

function categoryByName(name){return categories.find(c=>c.name===name)}
function categoryName(id){return categories.find(c=>c.id===id)?.name||'Sin categoría'}
function teamName(id){return teams.find(t=>t.id===id)?.name||'Sin equipo'}
function seasonName(id){return seasons.find(s=>s.id===id)?.name||'—'}
function currentSeason(){return seasons.find(s=>s.id===currentSeasonId)||seasons[0]}
function seasonStartYear(seasonId=currentSeasonId){const s=seasons.find(x=>x.id===seasonId);return s?.startDate?Number(s.startDate.slice(0,4)):Number(String(s?.name||'').slice(0,4))||new Date().getFullYear()}
function categoryForBirth(birth,seasonId=currentSeasonId){if(!birth)return null;const y=Number(String(birth).slice(0,4)),sy=seasonStartYear(seasonId);let name='';if(y===sy-4||y===sy-5)name='Chupetín';else if(y===sy-6||y===sy-7)name='Prebenjamín';else if(y===sy-8||y===sy-9)name='Benjamín';else if(y===sy-10||y===sy-11)name='Alevín';else if(y===sy-12||y===sy-13)name='Infantil';else if(y===sy-14||y===sy-15)name='Cadete';else if(y>=sy-18&&y<=sy-16)name='Juvenil';else if(y<=sy-19)name='Senior';return categoryByName(name)||null}
function syncInscriptionCategory(i){const p=players.find(x=>x.id===i.playerId),cat=categoryForBirth(p?.birth,i.seasonId);if(cat&&i.categoryId!==cat.id){i.categoryId=cat.id;return true}return false}
function recalculateSeasonCategories(seasonId=currentSeasonId){let changed=false;inscriptions.filter(i=>i.seasonId===seasonId).forEach(i=>{if(syncInscriptionCategory(i))changed=true});if(changed)saveInscriptions();return changed}
function isBetween(d,start,end){return (!start||d>=start)&&(!end||d<=end)}
function activeTeamAssignment(playerId,seasonId=currentSeasonId,when=isoToday()){return playerTeams.filter(a=>a.playerId===playerId&&a.seasonId===seasonId&&isBetween(when,a.startDate,a.endDate)).sort((a,b)=>(b.startDate||'').localeCompare(a.startDate||''))[0]||null}
function activeRepresentation(playerId,when=isoToday()){return representations.filter(r=>r.playerId===playerId&&isBetween(when,r.startDate,r.endDate)).sort((a,b)=>(b.startDate||'').localeCompare(a.startDate||''))[0]||null}
function inscriptionFor(playerId,seasonId=currentSeasonId){return inscriptions.find(i=>i.playerId===playerId&&i.seasonId===seasonId)||null}
function latestMedical(playerId){return medicals.filter(m=>m.playerId===playerId).sort((a,b)=>(b.expiry||b.date||'').localeCompare(a.expiry||a.date||''))[0]||null}
function ageOn(birth,date=isoToday()){const b=parseDate(birth),d=parseDate(date);if(!b||!d)return null;let a=d.getFullYear()-b.getFullYear();if(d.getMonth()<b.getMonth()||(d.getMonth()===b.getMonth()&&d.getDate()<b.getDate()))a--;return a}
function eighteenthBirthday(p){return addYears(p.birth,18)}
function daysTo18(p){const d=eighteenthBirthday(p);return d?dayDiff(isoToday(),d):null}
function repUserName(r){return users.find(u=>u.id===r?.userId)?.name||'Sin representante'}
function currentPlayerUser(p){return users.find(u=>hasRole(u,'player')&&u.playerId===p.id)||null}
function currentSeasonTeams(){return teams.filter(t=>t.seasonId===currentSeasonId)}
function recordAudit(action,playerId='',detail='',actorId=currentUser?.id||'system'){audit.unshift({id:uid('a'),date:new Date().toISOString(),actorId,action,playerId,detail});saveAudit()}
function addStatusHistory(inscriptionId,playerId,from,to,note=''){statusHistory.unshift({id:uid('h'),date:new Date().toISOString(),actorId:currentUser?.id||'system',inscriptionId,playerId,from,to,note});saveStatusHistory()}
function actorName(id){return users.find(u=>u.id===id)?.name||(id==='system'?'Sistema':'Usuario')}

function saveAll(){saveUsers();savePlayers();writeJSON(K.persons,persons);saveSeasons();saveCategories();saveTeams();saveInscriptions();saveReps();savePlayerTeams();saveMedicals();saveCoaches();saveStatusHistory();saveAudit()}
function saveUsers(){writeJSON(K.users,users)} function savePlayers(){writeJSON(K.players,players)} function saveSeasons(){writeJSON(K.seasons,seasons)}
function saveCategories(){writeJSON(K.categories,categories)} function saveTeams(){writeJSON(K.teams,teams)} function saveInscriptions(){writeJSON(K.inscriptions,inscriptions)}
function saveReps(){writeJSON(K.reps,representations)} function savePlayerTeams(){writeJSON(K.playerTeams,playerTeams)} function saveMedicals(){writeJSON(K.medicals,medicals)}
function saveCoaches(){writeJSON(K.coaches,coaches)} function saveStatusHistory(){writeJSON(K.statusHistory,statusHistory)} function saveAudit(){writeJSON(K.audit,audit)}

function migrateLegacy(){
  const lu=readJSON(LEGACY.users,null),lp=readJSON(LEGACY.players,null),lt=readJSON(LEGACY.teams,null),lc=readJSON(LEGACY.coaches,null);
  users=Array.isArray(lu)&&lu.length?lu.map(normalizeUser):seedUsers.map(x=>normalizeUser({...x}));
  if(!users.some(u=>u.id==='u-player'))users.push(normalizeUser({...seedUsers.find(u=>u.id==='u-player')}));
  if(!users.some(u=>u.id==='u-multi'))users.push(normalizeUser({...seedUsers.find(u=>u.id==='u-multi')}));
  seasons=seedSeasons.map(x=>({...x}));categories=seedCategories.map(x=>({...x}));
  teams=Array.isArray(lt)&&lt.length?lt.map(t=>({id:t.id,name:t.name,seasonId:'s-2026',categoryId:categoryByLegacyName(t.category),active:t.active!==false})):seedTeams.map(x=>({...x}));
  players=[];inscriptions=[];representations=[];playerTeams=[];medicals=[];
  if(Array.isArray(lp)&&lp.length){
    lp.forEach((p,idx)=>{
      const pid=p.id||uid('p');players.push({id:pid,name:p.name,birth:p.birth||'',dni:p.dni||'',data:p.data!==false});
      const cat=categoryByLegacyName(p.category);const iid=`i-mig-${idx}-${pid}`;inscriptions.push({id:iid,playerId:pid,seasonId:'s-2026',categoryId:cat,docs:p.docs||'Pendiente de documentos',workflow:p.workflow==='data_ok'||p.workflow==='docs_ok'?'initial_ok':(p.workflow||'review'),federation:p.federation||'Pendiente',status:p.status||'pending',familyActionRequired:!!p.familyActionRequired,returnMessage:p.returnMessage||'',createdAt:isoToday()});
      if(p.ownerUserId)representations.push({id:uid('r'),playerId:pid,userId:p.ownerUserId,type:'guardian',startDate:'2026-06-01',endDate:'',reason:'Migración V10',legalException:false});
      if(p.teamId)playerTeams.push({id:uid('pt'),playerId:pid,seasonId:'s-2026',teamId:p.teamId,startDate:'2026-09-01',endDate:'2027-06-30',reason:'Migración V10'});
      if(p.medicalDate||p.medicalExpiry)medicals.push({id:uid('m'),playerId:pid,date:p.medicalDate||'',expiry:p.medicalExpiry||'',validatedAt:''});
    });
  }else{players=seedPlayers.map(x=>({...x}));inscriptions=seedInscriptions.map(x=>({...x}));representations=seedReps.map(x=>({...x}));playerTeams=seedPlayerTeams.map(x=>({...x}));medicals=seedMedicals.map(x=>({...x}))}
  if(!players.some(p=>p.id==='p-jorge')){players.push({...seedPlayers.find(p=>p.id==='p-jorge')});inscriptions.push({...seedInscriptions.find(i=>i.playerId==='p-jorge')});representations.push({...seedReps.find(r=>r.playerId==='p-jorge')});playerTeams.push({...seedPlayerTeams.find(a=>a.playerId==='p-jorge')})}
  if(!players.some(p=>p.id==='p-multi')){players.push({...seedPlayers.find(p=>p.id==='p-multi')});inscriptions.push({...seedInscriptions.find(i=>i.playerId==='p-multi')});representations.push({...seedReps.find(r=>r.playerId==='p-multi')});playerTeams.push({...seedPlayerTeams.find(a=>a.playerId==='p-multi')})}
  coaches=Array.isArray(lc)&&lc.length?lc.map(c=>({...c,assignments:Array.isArray(c.assignments)?c.assignments:[]})):seedCoaches.map(x=>({...x,assignments:x.assignments.map(a=>({...a}))}));
  statusHistory=[];audit=[];currentSeasonId='s-2026';saveAll();writeJSON(K.currentSeason,currentSeasonId);
}

function migrateV12(){
  users=readJSON(V12.users,seedUsers).map(normalizeUser);players=readJSON(V12.players,seedPlayers).map(normalizePlayer);seasons=readJSON(V12.seasons,seedSeasons);categories=readJSON(V12.categories,seedCategories);teams=readJSON(V12.teams,seedTeams);
  inscriptions=readJSON(V12.inscriptions,seedInscriptions);representations=readJSON(V12.reps,seedReps);playerTeams=readJSON(V12.playerTeams,seedPlayerTeams);medicals=readJSON(V12.medicals,seedMedicals);coaches=readJSON(V12.coaches,seedCoaches);statusHistory=readJSON(V12.statusHistory,[]);audit=readJSON(V12.audit,[]);currentSeasonId=readJSON(V12.currentSeason,'s-2026');
  recalculateSeasonCategories(currentSeasonId);saveAll();writeJSON(K.currentSeason,currentSeasonId);
}
function migrateV11(){
  users=readJSON(V11.users,seedUsers).map(normalizeUser);players=readJSON(V11.players,seedPlayers).map(normalizePlayer);seasons=readJSON(V11.seasons,seedSeasons);categories=readJSON(V11.categories,seedCategories);teams=readJSON(V11.teams,seedTeams);
  inscriptions=readJSON(V11.inscriptions,seedInscriptions);representations=readJSON(V11.reps,seedReps);playerTeams=readJSON(V11.playerTeams,seedPlayerTeams);medicals=readJSON(V11.medicals,seedMedicals);coaches=readJSON(V11.coaches,seedCoaches);statusHistory=readJSON(V11.statusHistory,[]);audit=readJSON(V11.audit,[]);currentSeasonId=readJSON(V11.currentSeason,'s-2026');
  saveAll();writeJSON(K.currentSeason,currentSeasonId);
}
function categoryByLegacyName(n){return seedCategories.find(c=>c.name===n)?.id||'cat-pb'}
function normalizePlayer(p){return {...p,active:p.active!==false}}
function initData(){
  if(!localStorage.getItem(K.users)){if(localStorage.getItem(V12.users))migrateV12();else if(localStorage.getItem(V11.users))migrateV11();else migrateLegacy()}else reloadCore();
  players=players.map(normalizePlayer);ensurePersons();recalculateSeasonCategories(currentSeasonId);savePlayers();applyAgeTransitions();
}
function reloadCore(){
  users=readJSON(K.users,seedUsers).map(normalizeUser);players=readJSON(K.players,seedPlayers).map(normalizePlayer);seasons=readJSON(K.seasons,seedSeasons);categories=readJSON(K.categories,seedCategories);teams=readJSON(K.teams,seedTeams);
  inscriptions=readJSON(K.inscriptions,seedInscriptions);representations=readJSON(K.reps,seedReps);playerTeams=readJSON(K.playerTeams,seedPlayerTeams);medicals=readJSON(K.medicals,seedMedicals);
  coaches=readJSON(K.coaches,seedCoaches);persons=readJSON(K.persons,[]);statusHistory=readJSON(K.statusHistory,[]);audit=readJSON(K.audit,[]);currentSeasonId=readJSON(K.currentSeason,'s-2026');
}
function reload(){reloadCore();const savedRole=localStorage.getItem(K.sessionRole),roles=currentUser?availableRoles(currentUser):[];currentRole=currentUser&&roles.includes(savedRole)?savedRole:(roles[0]||null)}
function applyAgeTransitions(){
  const today=isoToday();let changed=false;
  players.forEach(p=>{
    const birthday=eighteenthBirthday(p);if(!birthday||today<birthday)return;
    const r=activeRepresentation(p.id,today);if(r?.type==='guardian'&&!r.legalException){r.endDate=birthday;changed=true;recordAudit('Representación de tutor finalizada automáticamente',p.id,`Mayoría de edad: ${fmt(birthday)}`,'system')}
    const pu=currentPlayerUser(p);if(pu&&pu.pendingActivationDate&&today>=pu.pendingActivationDate&&!pu.active){pu.active=true;pu.pendingActivationDate='';changed=true;representations.push({id:uid('r'),playerId:p.id,userId:pu.id,type:'self',startDate:birthday,endDate:'',reason:'Mayoría de edad',legalException:false});recordAudit('Autorrepresentación activada automáticamente',p.id,'Cuenta de jugador activada','system')}
  });if(changed){saveUsers();saveReps();saveAudit()}
}

function familyAccessPlayers(){
  if(currentRole==='player')return players.filter(p=>p.id===currentUser.playerId);
  if(currentRole!=='family')return [];
  const ids=representations.filter(r=>r.userId===currentUser.id&&r.type==='guardian'&&isBetween(isoToday(),r.startDate,r.endDate)).map(r=>r.playerId);
  return players.filter(p=>ids.includes(p.id));
}
function activeCoachAssignments(userId){const c=coaches.find(x=>x.userId===userId);return c&&c.active!==false?(c.assignments||[]).filter(a=>isBetween(isoToday(),a.startDate,a.endDate)):[]}
function visiblePlayers(){
  if(currentRole!=='coach')return players.filter(p=>inscriptionFor(p.id));
  const teamIds=activeCoachAssignments(currentUser.id).map(a=>a.teamId);return players.filter(p=>p.active!==false).filter(p=>{const a=activeTeamAssignment(p.id);return a&&teamIds.includes(a.teamId)})
}
function playerVM(p){const i=inscriptionFor(p.id);const ta=activeTeamAssignment(p.id);const rep=activeRepresentation(p.id);return {p,i,ta,rep,category:categoryName(i?.categoryId),team:teamName(ta?.teamId)}}


async function loadSupabaseStructure(){
  if(!sb||!currentUser)return;
  const [seasonRes,catRes,teamRes,ruleRes]=await Promise.all([
    sb.from('temporadas').select('id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado').order('anio_inicio',{ascending:false}),
    sb.from('categorias').select('id,codigo,nombre,orden,activo').order('orden',{ascending:true}),
    sb.from('equipos').select('id,temporada_id,categoria_id,nombre,codigo,genero,modalidad,activo').order('nombre',{ascending:true}),
    sb.from('reglas_categoria_temporada').select('temporada_id,categoria_id,anio_nacimiento_desde,anio_nacimiento_hasta,activo')
  ]);
  if(seasonRes.error)throw seasonRes.error;
  if(catRes.error)throw catRes.error;
  if(teamRes.error)throw teamRes.error;
  if(ruleRes.error)throw ruleRes.error;
  dbSeasons=(seasonRes.data||[]).map(x=>({id:x.id,name:x.nombre,startDate:x.fecha_inicio,endDate:x.fecha_fin,status:x.estado,active:x.estado!=='cerrada'}));
  dbCategories=(catRes.data||[]).map(x=>({id:x.id,code:x.codigo,name:x.nombre,order:x.orden,active:x.activo!==false}));
  dbTeams=(teamRes.data||[]).map(x=>({id:x.id,seasonId:x.temporada_id,categoryId:x.categoria_id,name:x.nombre,code:x.codigo,gender:x.genero,modality:x.modalidad,active:x.activo!==false}));
  dbCategoryRules=(ruleRes.data||[]).map(x=>({seasonId:x.temporada_id,categoryId:x.categoria_id,from:x.anio_nacimiento_desde,to:x.anio_nacimiento_hasta,active:x.activo!==false}));
  dbStructureLoaded=true;
}
function dbActiveSeason(){return dbSeasons.find(s=>s.status==='activa')||dbSeasons[0]||null}
function dbCategoryName(id){return dbCategories.find(c=>c.id===id)?.name||'—'}
function dbSeasonTeams(){const s=dbActiveSeason();return s?dbTeams.filter(t=>t.seasonId===s.id):[]}
function dbCategoryForBirth(birth){
  if(!birth)return null;
  const season=dbActiveSeason(),year=Number(String(birth).slice(0,4));
  if(!season||!year)return null;
  const rule=dbCategoryRules.find(r=>r.seasonId===season.id&&r.active&&(r.from==null||year>=r.from)&&(r.to==null||year<=r.to));
  return rule?dbCategories.find(c=>c.id===rule.categoryId)||null:null;
}

async function loadSupabaseIdentity(authUser){
  if(!sb||!authUser)return null;
  const {data:person,error:personError}=await sb
    .from('personas')
    .select('id,nombre,primer_apellido,segundo_apellido,fecha_nacimiento,email_contacto,telefono,activo')
    .eq('auth_user_id',authUser.id)
    .maybeSingle();
  if(personError)throw personError;
  if(!person)throw new Error('El usuario está autenticado, pero no tiene una Persona vinculada en la aplicación.');
  if(person.activo===false)throw new Error('La persona asociada a esta cuenta está inactiva.');

  const {data:assignments,error:assignError}=await sb
    .from('persona_roles')
    .select('rol_id,activo,fecha_desde,fecha_hasta')
    .eq('persona_id',person.id);
  if(assignError)throw assignError;

  const roleIds=[...new Set((assignments||[]).map(x=>x.rol_id).filter(Boolean))];
  let roleRows=[];
  if(roleIds.length){
    const {data,error}=await sb.from('roles').select('id,codigo,nombre').in('id',roleIds);
    if(error)throw error;
    roleRows=data||[];
  }
  const byId=new Map(roleRows.map(r=>[r.id,r]));
  const today=isoToday();
  const roles=(assignments||[])
    .filter(a=>a.activo!==false && (!a.fecha_desde||a.fecha_desde<=today) && (!a.fecha_hasta||a.fecha_hasta>=today))
    .map(a=>DB_ROLE_TO_APP[byId.get(a.rol_id)?.codigo])
    .filter(Boolean);

  const {data:identityDoc,error:docError}=await sb
    .from('documentos_identidad')
    .select('tipo,numero,es_principal,activo')
    .eq('persona_id',person.id)
    .eq('activo',true)
    .order('es_principal',{ascending:false})
    .limit(1)
    .maybeSingle();
  if(docError)throw docError;
  const fullName=[person.nombre,person.primer_apellido,person.segundo_apellido].filter(Boolean).join(' ');
  return normalizeUser({
    id:authUser.id,
    authUserId:authUser.id,
    personId:person.id,
    name:fullName||authUser.email||'Usuario',
    email:authUser.email||person.email_contacto||'',
    phone:person.telefono||'',
    birth:person.fecha_nacimiento||'',
    documentType:identityDoc?.tipo||'',
    documentNumber:identityDoc?.numero||'',
    roles:[...new Set(roles)],
    active:true,
    source:'supabase'
  });
}

function pendingSignupFor(email){
  const p=readJSON(PENDING_SIGNUP_KEY,null);
  return p&&String(p.email||'').toLowerCase()===String(email||'').toLowerCase()?p:null;
}
async function registerProfileFromPayload(payload){
  const args={
    p_nombre:payload.firstName,
    p_primer_apellido:payload.surname1,
    p_segundo_apellido:payload.surname2||null,
    p_fecha_nacimiento:payload.birth,
    p_telefono:payload.phone||null,
    p_tipo_alta:payload.mode==='guardian'?'tutor':'jugador',
    p_tipo_documento:payload.documentNumber?payload.documentType:null,
    p_numero_documento:payload.documentNumber||null
  };
  const {error}=await sb.rpc('registrar_mi_perfil',args);
  if(error)throw error;
  if(payload.mode==='self'){
    const {error:selfError}=await sb.rpc('crear_inscripcion_jugador_adulto');
    if(selfError)throw selfError;
  }
  localStorage.removeItem(PENDING_SIGNUP_KEY);
}
async function loadIdentityWithPending(authUser){
  try{return await loadSupabaseIdentity(authUser)}catch(err){
    const pending=pendingSignupFor(authUser?.email);
    if(!pending||!String(err?.message||'').includes('Persona vinculada'))throw err;
    await registerProfileFromPayload(pending);
    return await loadSupabaseIdentity(authUser);
  }
}
async function loadRemoteFamilyData(){
  remoteFamilyPlayers=[];
  if(!sb||!currentUser||!['family','player'].includes(currentRole))return remoteFamilyPlayers;
  let playerIds=[];
  if(currentRole==='family'){
    const {data,error}=await sb.from('representaciones_jugador').select('id,jugador_id,fecha_desde,fecha_hasta').eq('representante_persona_id',currentUser.personId);
    if(error)throw error;
    const today=isoToday();
    playerIds=(data||[]).filter(r=>(!r.fecha_desde||r.fecha_desde<=today)&&(!r.fecha_hasta||r.fecha_hasta>=today)).map(r=>r.jugador_id);
  }else{
    const {data,error}=await sb.from('jugadores').select('id').eq('persona_id',currentUser.personId);
    if(error)throw error;
    playerIds=(data||[]).map(x=>x.id);
  }
  playerIds=[...new Set(playerIds)];
  if(!playerIds.length)return remoteFamilyPlayers;
  const {data:playerRows,error:pErr}=await sb.from('jugadores').select('id,persona_id,activo,fecha_alta,fecha_baja').in('id',playerIds);
  if(pErr)throw pErr;
  const personIds=[...new Set((playerRows||[]).map(x=>x.persona_id))];
  const {data:personRows,error:personErr}=personIds.length?await sb.from('personas').select('id,nombre,primer_apellido,segundo_apellido,fecha_nacimiento').in('id',personIds):{data:[],error:null};
  if(personErr)throw personErr;
  const season=dbActiveSeason();
  let insRows=[];
  if(season){const res=await sb.from('inscripciones').select('id,jugador_id,temporada_id,categoria_id,fecha_solicitud,estado,observaciones').in('jugador_id',playerIds).eq('temporada_id',season.id);if(res.error)throw res.error;insRows=res.data||[];}
  const insIds=insRows.map(x=>x.id);
  let assignRows=[];
  if(insIds.length){const res=await sb.from('asignaciones_jugador_equipo').select('inscripcion_id,equipo_id,fecha_desde,fecha_hasta').in('inscripcion_id',insIds);if(res.error)throw res.error;assignRows=res.data||[];}
  const personsById=new Map((personRows||[]).map(x=>[x.id,x]));
  const insByPlayer=new Map(insRows.map(x=>[x.jugador_id,x]));
  const today=isoToday();
  remoteFamilyPlayers=(playerRows||[]).map(p=>{
    const person=personsById.get(p.persona_id)||{};const ins=insByPlayer.get(p.id)||null;
    const assignment=ins?assignRows.filter(a=>a.inscripcion_id===ins.id&&(!a.fecha_desde||a.fecha_desde<=today)&&(!a.fecha_hasta||a.fecha_hasta>=today)).sort((a,b)=>String(b.fecha_desde||'').localeCompare(String(a.fecha_desde||'')))[0]:null;
    const team=assignment?dbTeams.find(t=>t.id===assignment.equipo_id):null;
    return {id:p.id,personId:p.persona_id,name:[person.nombre,person.primer_apellido,person.segundo_apellido].filter(Boolean).join(' '),birth:person.fecha_nacimiento||'',active:p.activo!==false,inscription:ins,categoryName:ins?dbCategoryName(ins.categoria_id):'—',teamName:team?.name||'Sin equipo'};
  });
  return remoteFamilyPlayers;
}
function remoteStateMeta(state){
  const m={
    pendiente_revision_inicial:['pending','⚠ Pendiente','Pendiente de revisión'],
    devuelta_familia:['returned','↩ Revisar','Devuelto a familia'],
    datos_validados:['pending','En revisión','Datos validados'],
    documentacion_validada:['pending','En revisión','Documentación validada'],
    lista_para_federar:['complete','✓ Completa','Listo para federar'],
    ficha_tramitada:['complete','✓ Completa','Ficha tramitada'],
    cancelada:['returned','Cancelada','Cancelada']
  };
  return m[state]||['pending','⚠ Pendiente',state||'Pendiente'];
}
function remoteStateLabel(state){return remoteStateMeta(state)[2]}
function remoteStateIsComplete(state){return ['lista_para_federar','ficha_tramitada'].includes(state)}
function remoteStateProgress(state){return ({pendiente_revision_inicial:25,devuelta_familia:25,datos_validados:50,documentacion_validada:70,lista_para_federar:90,ficha_tramitada:100,cancelada:0})[state]??0}
function setFamilyProgress(value){const ring=document.querySelector('.progress-ring');const pct=Math.max(0,Math.min(100,Math.round(Number(value)||0)));if(ring){ring.style.setProperty('--p',pct);const span=ring.querySelector('span');if(span)span.textContent=`${pct}%`}}
async function renderRemoteFamily(){
  $('#playersList').innerHTML='<div class="empty-card">Cargando jugadores…</div>';
  try{
    await loadRemoteFamilyData();
    $('#playersList').innerHTML=remoteFamilyPlayers.length?remoteFamilyPlayers.map(p=>{
      const i=p.inscription;
      if(!i)return `<article class="player-card"><div class="row"><div><h3>${esc(p.name)}</h3><div class="meta">Sin inscripción en la temporada activa</div></div><span class="status pending">Pendiente</span></div></article>`;
      const [cls,badge,fed]=remoteStateMeta(i.estado);
      const returned=i.estado==='devuelta_familia';
      return `<article class="player-card ${returned?'needs-action':''}"><div class="row"><div><h3>${esc(p.name)}</h3><div class="meta">${esc(p.categoryName)} · ${esc(dbActiveSeason()?.name||'')}</div></div><span class="status ${cls}">${esc(badge)}</span></div><div class="meta representation-line">${currentRole==='player'?'Autorrepresentación':'Tutor activo: '+esc(currentUser.name)}</div>${returned?`<div class="family-alert"><strong>El club solicita cambios</strong><p>${esc(i.observaciones||'Revisa la información de la ficha.')}</p><button class="primary small edit-remote-family" data-id="${esc(p.id)}">Revisar y modificar</button></div>`:''}<div class="checklist"><div class="check"><span>Datos personales</span><strong>✓</strong></div><div class="check"><span>Documentación</span><strong>${p.docsLabel?esc(p.docsLabel):'Pendiente'}</strong></div><div class="check"><span>Equipo</span><strong>${esc(p.teamName)}</strong></div><div class="check"><span>Federación</span><strong>${esc(fed)}</strong></div></div></article>`
    }).join(''):'<div class="empty-card">No hay jugadores asociados a tu cuenta.</div>';
    $$('.edit-remote-family').forEach(b=>b.onclick=()=>openRemoteFamilyEdit(b.dataset.id));
    $('#familyPlayerCount').textContent=currentRole==='player'?(remoteFamilyPlayers.length?'1 jugador · autorrepresentación':'Sin inscripción activa'):`${remoteFamilyPlayers.length} ${remoteFamilyPlayers.length===1?'jugador representado':'jugadores representados'}`;
    const progress=remoteFamilyPlayers.length?remoteFamilyPlayers.reduce((a,p)=>a+remoteStateProgress(p.inscription?.estado),0)/remoteFamilyPlayers.length:0;
    setFamilyProgress(progress);
  }catch(err){console.error('Carga familia Supabase',err);$('#playersList').innerHTML=`<div class="empty-card">No se pudieron cargar los jugadores: ${esc(err.message||err)}</div>`;setFamilyProgress(0)}
}

async function loadRemoteClubData(){
  remoteClubPlayers=[];
  if(!sb||!currentUser||!['admin','club','coach'].includes(currentRole))return remoteClubPlayers;
  const season=dbActiveSeason();if(!season)return remoteClubPlayers;
  const {data:insRows,error:insErr}=await sb.from('inscripciones').select('id,jugador_id,temporada_id,categoria_id,fecha_solicitud,estado,observaciones,documento_identidad_usado_id,representacion_usada_id').eq('temporada_id',season.id);
  if(insErr)throw insErr;
  const playerIds=[...new Set((insRows||[]).map(x=>x.jugador_id))];if(!playerIds.length)return remoteClubPlayers;
  const {data:playerRows,error:pErr}=await sb.from('jugadores').select('id,persona_id,activo,fecha_alta,fecha_baja,motivo_baja').in('id',playerIds);if(pErr)throw pErr;
  const personIds=[...new Set((playerRows||[]).map(x=>x.persona_id))];
  const {data:personRows,error:personErr}=personIds.length?await sb.from('personas').select('id,nombre,primer_apellido,segundo_apellido,fecha_nacimiento').in('id',personIds):{data:[],error:null};if(personErr)throw personErr;
  const {data:repRows,error:repErr}=await sb.from('representaciones_jugador').select('id,jugador_id,representante_persona_id,fecha_desde,fecha_hasta,motivo_alta,motivo_fin,excepcion_representacion_adulto').in('jugador_id',playerIds);if(repErr)throw repErr;
  const repPersonIds=[...new Set((repRows||[]).map(x=>x.representante_persona_id).filter(Boolean))];
  const {data:repPersons,error:repPersonErr}=repPersonIds.length?await sb.from('personas').select('id,nombre,primer_apellido,segundo_apellido').in('id',repPersonIds):{data:[],error:null};if(repPersonErr)throw repPersonErr;
  const insIds=(insRows||[]).map(x=>x.id);
  const {data:assignRows,error:aErr}=insIds.length?await sb.from('asignaciones_jugador_equipo').select('id,inscripcion_id,equipo_id,fecha_desde,fecha_hasta,motivo_cambio').in('inscripcion_id',insIds):{data:[],error:null};if(aErr)throw aErr;
  const {data:docRows,error:dErr}=await sb.from('documentos').select('id,jugador_id,inscripcion_id,estado,tipo').or(`jugador_id.in.(${playerIds.join(',')}),inscripcion_id.in.(${insIds.join(',')})`);if(dErr&&dErr.code!=='PGRST100')throw dErr;
  const {data:medicalRows,error:mErr}=await sb.from('reconocimientos_medicos').select('id,jugador_id,fecha_reconocimiento,fecha_valido_hasta,fecha_validacion_rffm,centro_medico,observaciones,created_at').in('jugador_id',playerIds).order('fecha_reconocimiento',{ascending:false});if(mErr)throw mErr;
  remoteMedicalRows=medicalRows||[];
  const personsById=new Map((personRows||[]).map(x=>[x.id,x])),repPersonsById=new Map((repPersons||[]).map(x=>[x.id,x])),insByPlayer=new Map((insRows||[]).map(x=>[x.jugador_id,x]));
  const today=isoToday();
  remoteClubPlayers=(playerRows||[]).map(p=>{
    const person=personsById.get(p.persona_id)||{},ins=insByPlayer.get(p.id)||null;
    const rep=(repRows||[]).filter(r=>r.jugador_id===p.id&&(!r.fecha_desde||r.fecha_desde<=today)&&(!r.fecha_hasta||r.fecha_hasta>=today)).sort((a,b)=>String(b.fecha_desde||'').localeCompare(String(a.fecha_desde||'')))[0]||null;
    const repPerson=rep?repPersonsById.get(rep.representante_persona_id):null;
    const assignment=ins?(assignRows||[]).filter(a=>a.inscripcion_id===ins.id&&(!a.fecha_desde||a.fecha_desde<=today)&&(!a.fecha_hasta||a.fecha_hasta>=today)).sort((a,b)=>String(b.fecha_desde||'').localeCompare(String(a.fecha_desde||'')))[0]:null;
    const team=assignment?dbTeams.find(t=>t.id===assignment.equipo_id):null;
    const docs=(docRows||[]).filter(d=>d.jugador_id===p.id||d.inscripcion_id===ins?.id);const docsComplete=docs.length>0&&docs.every(d=>d.estado==='aceptado');
    const medicalsForPlayer=(medicalRows||[]).filter(m=>m.jugador_id===p.id).sort((a,b)=>String(b.fecha_reconocimiento||'').localeCompare(String(a.fecha_reconocimiento||'')));
    const latestRemoteMedical=medicalsForPlayer[0]||null;
    return {id:p.id,personId:p.persona_id,name:[person.nombre,person.primer_apellido,person.segundo_apellido].filter(Boolean).join(' '),birth:person.fecha_nacimiento||'',active:p.activo!==false,inscription:ins,categoryName:ins?dbCategoryName(ins.categoria_id):'—',representation:rep,tutorName:repPerson?[repPerson.nombre,repPerson.primer_apellido,repPerson.segundo_apellido].filter(Boolean).join(' '):'Sin representante',assignment,teamName:team?.name||'Sin equipo',docs,docsLabel:docsComplete?'Completa':docs.length?'Pendiente':'Pendiente',medicals:medicalsForPlayer,medical:latestRemoteMedical};
  });
  return remoteClubPlayers;
}

async function renderRemoteClub(){
  $('#adminTable').innerHTML='<tr><td colspan="8">Cargando fichas desde Supabase…</td></tr>';
  try{
    await loadRemoteClubData();
    const catSel=$('#clubCategoryFilter');if(catSel){const prev=catSel.value||'all';catSel.innerHTML='<option value="all">Todas las categorías</option>'+dbCategories.filter(c=>c.active).map(c=>`<option value="${c.id}">${esc(c.name)}</option>`).join('');if([...catSel.options].some(o=>o.value===prev))catSel.value=prev}
    const q=$('#searchInput').value.trim().toLowerCase(),f=$('#statusFilter').value,cf=$('#clubCategoryFilter')?.value||'all',af=$('#clubActiveFilter')?.value||'active';
    const rows=remoteClubPlayers.filter(v=>{const statusGroup=remoteStateIsComplete(v.inscription?.estado)?'complete':'pending';return(f==='all'||statusGroup===f)&&(cf==='all'||v.inscription?.categoria_id===cf)&&(af==='all'||(af==='active')===v.active)&&v.name.toLowerCase().includes(q)});
    $('#adminTable').innerHTML=rows.length?rows.map(v=>`<tr class="admin-row ${!v.active?'inactive-row':''}" data-id="${esc(v.id)}" tabindex="0"><td><strong>${esc(v.name)}</strong>${!v.active?'<div class="meta inactive-note">Jugador inactivo</div>':''}${v.inscription?.estado==='devuelta_familia'?'<div class="meta return-note">Devuelto a familia</div>':''}</td><td>${esc(v.tutorName)}</td><td>${esc(v.categoryName)}</td><td><strong>${esc(v.teamName)}</strong></td><td><span class="status ${v.active?'complete':'returned'}">${v.active?'Activo':'Inactivo'}</span></td><td><span class="dot ok">✓ Completo</span></td><td>${esc(v.docsLabel)}</td><td><span class="workflow-pill ${esc(v.inscription?.estado||'')}">${esc(remoteStateLabel(v.inscription?.estado))}</span></td></tr>`).join(''):'<tr><td colspan="8">No hay jugadores que coincidan con los filtros.</td></tr>';
    $$('.admin-row').forEach(r=>{r.onclick=()=>openRemoteAdminPlayer(r.dataset.id);r.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();openRemoteAdminPlayer(r.dataset.id)}}});
    const operational=remoteClubPlayers.filter(v=>v.active);$('#statPlayers').textContent=operational.length;$('#statComplete').textContent=operational.filter(v=>remoteStateIsComplete(v.inscription?.estado)).length;$('#statDocs').textContent=operational.filter(v=>v.docsLabel!=='Completa').length;$('#statReview').textContent=operational.filter(v=>['pendiente_revision_inicial','devuelta_familia'].includes(v.inscription?.estado)).length;$('#statMedical90').textContent=operational.filter(v=>medicalState(v.medical?{date:v.medical.fecha_reconocimiento,expiry:v.medical.fecha_valido_hasta}:null).key==='soon').length;$('#statAdult30').textContent=operational.filter(v=>{const d=v.birth?dayDiff(isoToday(),addYears(v.birth,18)):null;return d!==null&&d>=0&&d<=30}).length;
  }catch(err){console.error('Carga fichas Supabase',err);$('#adminTable').innerHTML=`<tr><td colspan="8">No se pudieron cargar las fichas: ${esc(err.message||err)}</td></tr>`}
}

async function recordRemoteHistory(inscriptionId,oldState,newState,comment){
  const {error}=await sb.from('historico_estados_inscripcion').insert({inscripcion_id:inscriptionId,estado_anterior:oldState||null,estado_nuevo:newState,comentario:comment||null,cambiado_por:currentUser.authUserId||currentUser.id});if(error)throw error;
}
async function updateRemoteInscriptionState(player,newState,comment,observaciones=null){
  const ins=player?.inscription;if(!ins)throw new Error('No existe inscripción activa.');const old=ins.estado;
  const patch={estado:newState};if(observaciones!==null)patch.observaciones=observaciones;
  const {error}=await sb.from('inscripciones').update(patch).eq('id',ins.id);if(error)throw error;
  await recordRemoteHistory(ins.id,old,newState,comment);ins.estado=newState;if(observaciones!==null)ins.observaciones=observaciones;
}
async function loadRemoteHistory(inscriptionId){const {data,error}=await sb.from('historico_estados_inscripcion').select('estado_anterior,estado_nuevo,comentario,fecha').eq('inscripcion_id',inscriptionId).order('fecha',{ascending:false});if(error)throw error;return data||[]}
async function openRemoteAdminPlayer(id){
  const v=remoteClubPlayers.find(x=>x.id===id);if(!v)return;selectedRemotePlayerId=id;selectedPlayerId=id;
  $('#adminPlayerName').textContent=v.name;$('#adminPlayerCategory').textContent=`${v.categoryName} · ${dbActiveSeason()?.name||''}`;$('#adminPlayerSource').textContent='Datos reales de Supabase';$('#adminPlayerData').textContent='Completo';$('#adminPlayerDocs').textContent=v.docsLabel;$('#adminPlayerFed').textContent=remoteStateLabel(v.inscription?.estado);$('#playerOperationalStatus').textContent=v.active?'Activo':'Inactivo';$('#togglePlayerActive').textContent=v.active?'Marcar como inactivo':'Reactivar jugador';
  $('#representationSummary').innerHTML=v.representation?`<div><strong>${esc(v.tutorName)}</strong><div class="meta">Representación activa desde ${fmt(v.representation.fecha_desde)}${v.representation.excepcion_representacion_adulto?' · excepción jurídica':''}</div></div><span class="status complete">Activa</span>`:'<div><strong>Sin representante activo</strong></div>';
  $('#changeTutorButton').style.display='none';$('#selfRepresentationButton').style.display='none';
  const state=v.inscription?.estado||'pendiente_revision_inicial';const categoryId=v.inscription?.categoria_id;const teamOptions=dbSeasonTeams().filter(t=>t.active&&(!categoryId||t.categoryId===categoryId));$('#adminTeam').innerHTML='<option value="">Sin equipo asignado</option>'+teamOptions.map(t=>`<option value="${t.id}">${esc(t.name)}${t.modality?' · '+esc(t.modality):''}</option>`).join('');$('#adminTeam').value=v.assignment?.equipo_id||'';
  const canAssign=!['pendiente_revision_inicial','devuelta_familia','cancelada'].includes(state);$('#adminTeam').disabled=!canAssign||currentRole==='coach';$('#saveTeamAssignment').disabled=!canAssign||currentRole==='coach';$('#teamAssignHint').textContent=canAssign?'El equipo queda asociado a esta inscripción y conserva histórico de cambios.':'Valida primero la inscripción inicial antes de asignar un equipo.';
  $('#teamAssignmentHistory').innerHTML=v.assignment?`<div class="history-item"><strong>${esc(v.teamName)}</strong><span>Desde ${fmt(v.assignment.fecha_desde)}</span></div>`:'<div class="meta">Sin asignación deportiva.</div>';
  const states=[['pendiente_revision_inicial','Pendiente de revisión inicial'],['devuelta_familia','Devuelta a la familia'],['datos_validados','Datos validados'],['documentacion_validada','Documentación validada'],['lista_para_federar','Listo para federar'],['ficha_tramitada','Ficha tramitada']];$('#adminWorkflow').innerHTML=states.map(([k,l])=>`<option value="${k}">${l}</option>`).join('');$('#adminWorkflow').value=state;$('#adminWorkflow').disabled=currentRole==='coach';$('#saveWorkflow').disabled=currentRole==='coach';$('#advanceStatus').disabled=currentRole==='coach'||['ficha_tramitada','cancelada'].includes(state);
  $('#returnMessage').value=state==='devuelta_familia'?(v.inscription?.observaciones||''):'';$('#returnToFamily').disabled=currentRole==='coach';$('#returnHint').textContent=v.representation?'La familia verá este mensaje en su ficha.':'No hay un tutor activo al que devolver la inscripción.';
  try{const hist=await loadRemoteHistory(v.inscription.id);$('#playerHistory').innerHTML=hist.length?hist.map(h=>`<div class="history-item"><strong>${esc(remoteStateLabel(h.estado_nuevo))}</strong><span>${fmt(String(h.fecha||'').slice(0,10))}${h.comentario?' · '+esc(h.comentario):''}</span></div>`).join(''):'<div class="meta">Sin movimientos registrados.</div>'}catch(err){$('#playerHistory').innerHTML='<div class="meta">No se pudo cargar el histórico.</div>'}
  $('#adminPlayerModal').showModal();
}
function openAdminPlayer(id){if(currentUser?.source==='supabase')return openRemoteAdminPlayer(id);alert('Esta ficha pertenece al prototipo local.');}
async function saveRemoteTeamAssignment(){const v=remoteClubPlayers.find(x=>x.id===selectedRemotePlayerId);if(!v||currentRole==='coach')return;const teamId=$('#adminTeam').value||null;if(['pendiente_revision_inicial','devuelta_familia','cancelada'].includes(v.inscription?.estado)){alert('Valida primero la inscripción inicial.');return}try{const old=v.assignment;if(old?.equipo_id===teamId)return;if(old){const {error}=await sb.from('asignaciones_jugador_equipo').update({fecha_hasta:isoToday(),motivo_cambio:teamId?'Cambio de equipo':'Equipo retirado'}).eq('id',old.id);if(error)throw error}if(teamId){const {error}=await sb.from('asignaciones_jugador_equipo').insert({inscripcion_id:v.inscription.id,equipo_id:teamId,fecha_desde:isoToday(),asignado_por:currentUser.authUserId||currentUser.id,motivo_cambio:old?'Cambio de equipo':'Asignación inicial'});if(error)throw error}await renderRemoteClub();await openRemoteAdminPlayer(v.id)}catch(err){alert(`No se ha podido guardar el equipo: ${err.message||err}`)}}
async function advanceRemoteSelected(){const v=remoteClubPlayers.find(x=>x.id===selectedRemotePlayerId);if(!v||currentRole==='coach')return;const order=['pendiente_revision_inicial','datos_validados','documentacion_validada','lista_para_federar','ficha_tramitada'];let ix=order.indexOf(v.inscription.estado);if(v.inscription.estado==='devuelta_familia')ix=0;const next=order[Math.min(Math.max(ix,0)+1,order.length-1)];const gate=validateRemoteFederationGate(v,next);if(gate){alert(gate);return}try{await updateRemoteInscriptionState(v,next,`Estado avanzado por ${currentUser.name}`,next==='datos_validados'?'':v.inscription.observaciones);await renderRemoteClub();await openRemoteAdminPlayer(v.id)}catch(err){alert(`No se ha podido avanzar el estado: ${err.message||err}`)}}
async function setRemoteWorkflowSelected(){const v=remoteClubPlayers.find(x=>x.id===selectedRemotePlayerId);if(!v||currentRole==='coach')return;const next=$('#adminWorkflow').value;if(!next)return;const gate=validateRemoteFederationGate(v,next);if(gate){alert(gate);$('#adminWorkflow').value=v.inscription.estado;return}try{await updateRemoteInscriptionState(v,next,`Estado cambiado manualmente por ${currentUser.name}`,next==='devuelta_familia'?v.inscription.observaciones||'Revisión solicitada por el club':'');await renderRemoteClub();await openRemoteAdminPlayer(v.id)}catch(err){alert(`No se ha podido guardar el estado: ${err.message||err}`)}}
async function returnRemoteSelected(){const v=remoteClubPlayers.find(x=>x.id===selectedRemotePlayerId);if(!v||currentRole==='coach')return;const msg=$('#returnMessage').value.trim();if(!msg){alert('Indica qué debe revisar la familia.');return}if(!v.representation){alert('El jugador no tiene un tutor activo.');return}try{await updateRemoteInscriptionState(v,'devuelta_familia',`Devuelto a la familia: ${msg}`,msg);$('#adminPlayerModal').close();await renderRemoteClub()}catch(err){alert(`No se ha podido devolver a la familia: ${err.message||err}`)}}
async function toggleRemotePlayerActive(){const v=remoteClubPlayers.find(x=>x.id===selectedRemotePlayerId);if(!v||!['admin','club'].includes(currentRole))return;try{const next=!v.active;const patch={activo:next};if(!next){patch.fecha_baja=isoToday();patch.motivo_baja='Baja operativa desde panel del club'}else{patch.fecha_baja=null;patch.motivo_baja=null}const {error}=await sb.from('jugadores').update(patch).eq('id',v.id);if(error)throw error;await renderRemoteClub();await openRemoteAdminPlayer(v.id)}catch(err){alert(`No se ha podido cambiar el estado del jugador: ${err.message||err}`)}}
async function openRemoteFamilyEdit(id){const p=remoteFamilyPlayers.find(x=>x.id===id);if(!p||currentRole!=='family')return;editingPlayerId=id;const parts=p.name.split(' '),f=$('#playerForm');f.reset();f.elements.name.value=parts[0]||'';f.elements.surname1.value=parts[1]||'';f.elements.surname2.value=parts.slice(2).join(' ');f.elements.birth.value=p.birth||'';f.elements.email.value=currentUser.email||'';f.elements.phone.value=currentUser.phone||'';syncGuardianDocumentField();$('#playerModalTitle').textContent='Revisar datos del jugador';$('#savePlayer').textContent='Guardar cambios';refreshCalculatedCategory(f);$('#playerModal').showModal()}

async function restoreSupabaseSession(){
  if(!sb){showAuth('login');alert('No se ha podido cargar el cliente de Supabase. Comprueba la conexión a Internet.');return;}
  try{
    const {data,error}=await sb.auth.getSession();
    if(error)throw error;
    const authUser=data.session?.user||null;
    if(!authUser){currentUser=null;currentRole=null;localStorage.removeItem(K.sessionRole);showAuth('login');return;}
    currentUser=await loadIdentityWithPending(authUser);
    await loadSupabaseStructure();
    const savedRole=localStorage.getItem(K.sessionRole);
    const roles=availableRoles(currentUser);
    currentRole=roles.includes(savedRole)?savedRole:(roles[0]||null);
    if(!roles.length){await sb.auth.signOut();currentUser=null;currentRole=null;showAuth('login');alert('Tu cuenta no tiene ningún perfil activo en el club.');return;}
    if(roles.length>1&&!savedRole){showRoleChooser();}else showApp();
  }catch(err){
    console.error('Supabase session error',err);
    currentUser=null;currentRole=null;showAuth('login');
    alert(`No se ha podido cargar tu perfil: ${err.message||err}`);
  }
}

function showAuth(mode='login'){ $('#authScreen').classList.remove('hidden');$('#appShell').classList.add('hidden');const login=mode==='login';$('#loginForm').classList.toggle('hidden',!login);$('#familySignupForm').classList.toggle('hidden',login);$('#showLogin').classList.toggle('active',login);$('#showFamilySignup').classList.toggle('active',!login);$('#authSeasonLabel').textContent=currentSeason()?.name||'2026/2027' }
function setView(id){['clubView','medicalView','coachesView','structureView','usersView','personsView'].forEach(v=>$('#'+v)?.classList.toggle('active',v===id));$$('.club-nav .nav-item').forEach(x=>x.classList.toggle('active',x.dataset.clubView===id))}
function showRoleChooser(force=false){
  if(!currentUser)return;const roles=availableRoles(currentUser);if(!roles.length){alert('Tu cuenta todavía no tiene ningún perfil activo.');return}if(roles.length<=1&&!force){currentRole=roles[0]||'family';localStorage.setItem(K.sessionRole,currentRole);showApp();return}
  $('#roleChooserList').innerHTML=roles.map(r=>`<button type="button" class="role-choice" data-role="${esc(r)}"><strong>${esc(roleLabel(r))}</strong><span>${r==='family'?'Gestionar menores a tu cargo':r==='player'?'Gestionar tu propia ficha':r==='coach'?'Acceder a los jugadores de tus equipos':r==='club'?'Gestión deportiva del club':'Administración completa del sistema'}</span></button>`).join('');
  $$('.role-choice').forEach(b=>b.onclick=()=>{currentRole=b.dataset.role;localStorage.setItem(K.sessionRole,currentRole);$('#roleChooserModal').close();recordAudit('Cambio de perfil','',roleLabel(currentRole));showApp()});$('#roleChooserModal').showModal()
}
function showApp(){
  if(!currentRole||!roleAvailable(currentUser,currentRole)){currentRole=availableRoles(currentUser)[0]||null}if(!currentRole)return;
  $('#authScreen').classList.add('hidden');$('#appShell').classList.remove('hidden');$('#currentRoleLabel').textContent=roleLabel(currentRole);$('#currentSeasonLabel').textContent=currentSeason()?.name||'';$('#roleSwitchButton').classList.toggle('hidden',availableRoles(currentUser).length<2);
  const familyLike=['family','player'].includes(currentRole);
  $('#familyNav').classList.toggle('hidden',!familyLike);$('#clubNav').classList.toggle('hidden',familyLike);$('#familyView').classList.toggle('active',familyLike);
  if(familyLike){['clubView','medicalView','coachesView','structureView','usersView','personsView'].forEach(v=>$('#'+v)?.classList.remove('active'));$('#addPlayerButton').classList.toggle('hidden',currentRole==='player');$('#familyHeroEyebrow').textContent=currentRole==='player'?'Área del jugador':'Área de familias';$('#familyHeroTitle').textContent=currentRole==='player'?'Gestiona tu ficha desde el móvil':'Gestiona la ficha de los menores a tu cargo';$('#familyHeroText').textContent=currentRole==='player'?'Consulta tu inscripción, documentación y estado federativo.':'Completa datos, adjunta documentación y consulta el estado de cada inscripción.';$('#familyTitle').textContent=currentRole==='player'?'Mi ficha':currentUser.name;(currentUser.source==='supabase'?renderRemoteFamily():renderFamily());return}
  $('#familyView').classList.remove('active');setView('clubView');const isCoach=currentRole==='coach';
  $('#medicalNavButton').style.display=isCoach?'none':'flex';$('#coachesNavButton').style.display=isCoach?'none':'flex';$('#structureNavButton').style.display=isCoach?'none':'flex';$('#usersNavButton').style.display=currentRole==='admin'?'flex':'none';$('#personsNavButton').style.display=currentRole==='admin'?'flex':'none';$('#openCoachModal').style.display=currentRole==='admin'?'inline-flex':'none';
  $('#clubNav').style.gridTemplateColumns=isCoach?'repeat(2,1fr)':currentRole==='admin'?'repeat(7,1fr)':'repeat(5,1fr)';$('#clubHeroTitle').textContent=isCoach?'Jugadores de mis equipos':'Control de fichas federativas';$('#clubHeroText').textContent=isCoach?'Consulta los jugadores asignados a tus equipos con una asignación vigente.':'Revisa inscripciones, representación, equipos, reconocimientos y preparación federativa.';
  renderClub();if(!isCoach){renderMedical();renderCoaches();renderStructure()}if(currentRole==='admin'){renderClubUsers();renderPersons();}
}

function renderFamily(){
  const mine=familyAccessPlayers();
  $('#playersList').innerHTML=mine.length?mine.map(p=>{const v=playerVM(p),i=v.i;if(!i)return '';const rep=v.rep;const repLine=currentRole==='player'?'Autorrepresentación activa':`Tutor activo: ${esc(repUserName(rep))}`;return `<article class="player-card ${i.familyActionRequired?'needs-action':''}"><div class="row"><div><h3>${esc(p.name)}</h3><div class="meta">${esc(v.category)} · ${esc(seasonName(i.seasonId))}</div></div><span class="status ${i.familyActionRequired?'returned':i.status}">${i.familyActionRequired?'↩ Revisar':i.status==='complete'?'✓ Completa':'⚠ Pendiente'}</span></div><div class="meta representation-line">${repLine}</div>${i.familyActionRequired?`<div class="family-alert"><strong>El club solicita cambios</strong><p>${esc(i.returnMessage||'Revisa la información de la ficha.')}</p><button class="primary small edit-family" data-id="${esc(p.id)}">Revisar y modificar</button></div>`:''}<div class="checklist"><div class="check"><span>Datos personales</span><strong>${p.data?'✓':'!'}</strong></div><div class="check"><span>Documentación</span><strong>${esc(i.docs)}</strong></div><div class="check"><span>Equipo</span><strong>${esc(v.team)}</strong></div><div class="check"><span>Federación</span><strong>${esc(i.federation)}</strong></div></div></article>`}).join(''):'<div class="empty-card">No hay jugadores asociados a tu cuenta.</div>';
  $$('.edit-family').forEach(b=>b.onclick=()=>openPlayerForEdit(b.dataset.id));$('#familyPlayerCount').textContent=currentRole==='player'?'1 jugador · autorrepresentación':`${mine.length} ${mine.length===1?'jugador representado':'jugadores representados'}`;
}
function renderClub(){if(currentUser?.source==='supabase')return renderRemoteClub();return renderLocalClub();}
function renderLocalClub(){
  const source=visiblePlayers().map(playerVM).filter(v=>v.i);
  const q=$('#searchInput').value.trim().toLowerCase(),f=$('#statusFilter').value,cf=$('#clubCategoryFilter')?.value||'all',af=$('#clubActiveFilter')?.value||'active';
  const catSel=$('#clubCategoryFilter');if(catSel){const prev=catSel.value||'all';catSel.innerHTML='<option value="all">Todas las categorías</option>'+categories.filter(c=>c.active).map(c=>`<option value="${c.id}">${esc(c.name)}</option>`).join('');if([...catSel.options].some(o=>o.value===prev))catSel.value=prev}
  const rows=source.filter(v=>(f==='all'||v.i.status===f)&&(cf==='all'||v.i.categoryId===cf)&&(af==='all'||(af==='active')===(v.p.active!==false))&&v.p.name.toLowerCase().includes(q));
  $('#adminTable').innerHTML=rows.length?rows.map(v=>`<tr class="admin-row ${v.p.active===false?'inactive-row':''}" data-id="${esc(v.p.id)}" tabindex="0"><td><strong>${esc(v.p.name)}</strong>${v.p.active===false?'<div class="meta inactive-note">Jugador inactivo</div>':''}${v.i.familyActionRequired?'<div class="meta return-note">Devuelto a familia</div>':''}${adultAlertHtml(v.p)}</td><td>${esc(repUserName(v.rep))}</td><td>${esc(v.category)}</td><td><strong>${esc(v.team)}</strong></td><td><span class="status ${v.p.active!==false?'complete':'returned'}">${v.p.active!==false?'Activo':'Inactivo'}</span></td><td><span class="dot ${v.p.data?'ok':'warn'}">${v.p.data?'✓ Completo':'⚠ Revisar'}</span></td><td>${esc(v.i.docs)}</td><td><span class="workflow-pill ${esc(v.i.workflow)}">${esc(workflowLabel(v.i.workflow))}</span></td></tr>`).join(''):'<tr><td colspan="8">No hay jugadores que coincidan con los filtros.</td></tr>';
  $$('.admin-row').forEach(r=>{r.onclick=()=>openAdminPlayer(r.dataset.id);r.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();openAdminPlayer(r.dataset.id)}}});
  const operational=source.filter(v=>v.p.active!==false);$('#statPlayers').textContent=operational.length;$('#statComplete').textContent=operational.filter(v=>v.i.status==='complete').length;$('#statDocs').textContent=operational.filter(v=>v.i.docs!=='Completa').length;$('#statReview').textContent=operational.filter(v=>v.i.workflow==='review'||v.i.familyActionRequired).length;$('#statMedical90').textContent=operational.filter(v=>medicalState(latestMedical(v.p.id)).key==='soon').length;$('#statAdult30').textContent=operational.filter(v=>{const d=daysTo18(v.p);return d!==null&&d>=0&&d<=30&&!currentPlayerUser(v.p)}).length;
}
function adultAlertHtml(p){const d=daysTo18(p),a=ageOn(p.birth);if(a!==null&&a>=18&&!currentPlayerUser(p)&&!activeRepresentation(p.id)?.legalException)return '<div class="meta adult-alert">⚠ Pendiente autorrepresentación</div>';if(d!==null&&d>=0&&d<=30&&!currentPlayerUser(p))return `<div class="meta adult-alert">Cumple 18 en ${d} días</div>`;return ''}

function medicalState(m){if(!m?.expiry)return {key:'missing',label:'Sin fecha',days:null};const days=dayDiff(isoToday(),m.expiry);if(days<0)return {key:'expired',label:'Vencido',days};if(days<=90)return {key:'soon',label:`Vence en ${days} días`,days};return {key:'ok',label:'En vigor',days}}
async function renderRemoteMedical(){
  if(!$('#medicalTable'))return;
  try{
    await loadRemoteClubData();
    const q=($('#medicalSearch')?.value||'').trim().toLowerCase(),f=$('#medicalFilter')?.value||'all';
    const source=remoteClubPlayers.filter(v=>v.active).map(v=>{const m=v.medical?{date:v.medical.fecha_reconocimiento,expiry:v.medical.fecha_valido_hasta}:null;return {...v,m,state:medicalState(m)}});
    const rows=source.filter(x=>(!q||x.name.toLowerCase().includes(q))&&(f==='all'||x.state.key===f));
    $('#medicalTable').innerHTML=rows.length?rows.map(x=>`<tr class="medical-row" data-id="${esc(x.id)}" tabindex="0"><td><strong>${esc(x.name)}</strong></td><td>${esc(x.categoryName)}</td><td>${fmt(x.m?.date)}</td><td>${fmt(x.m?.expiry)}</td><td><span class="medical-badge ${x.state.key}">${esc(x.state.label)}</span></td></tr>`).join(''):'<tr><td colspan="5">No hay jugadores que coincidan con el filtro.</td></tr>';
    $$('.medical-row').forEach(r=>{r.onclick=()=>openRemoteMedical(r.dataset.id);r.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();openRemoteMedical(r.dataset.id)}}});
    $('#medicalTotal').textContent=source.length;$('#medicalOk').textContent=source.filter(x=>x.state.key==='ok').length;$('#medicalSoon').textContent=source.filter(x=>x.state.key==='soon').length;$('#medicalExpired').textContent=source.filter(x=>['expired','missing'].includes(x.state.key)).length;
  }catch(err){console.error('Carga RRMM Supabase',err);$('#medicalTable').innerHTML=`<tr><td colspan="5">No se pudieron cargar los reconocimientos: ${esc(err.message||err)}</td></tr>`}
}
async function openRemoteMedical(id){
  const v=remoteClubPlayers.find(x=>x.id===id);if(!v)return;selectedMedicalPlayerId=id;
  $('#medicalPlayerName').textContent=v.name;$('#medicalPlayerMeta').textContent=v.categoryName;
  const f=$('#medicalForm'),m=v.medical;f.elements.medicalDate.value=m?.fecha_reconocimiento||'';f.elements.medicalExpiry.value=m?.fecha_valido_hasta||'';
  const hist=(v.medicals||[]).slice().sort((a,b)=>String(b.fecha_reconocimiento||'').localeCompare(String(a.fecha_reconocimiento||'')));
  $('#medicalHistory').innerHTML=hist.length?hist.map(x=>`<div class="history-item"><strong>${fmt(x.fecha_reconocimiento)} → ${fmt(x.fecha_valido_hasta)}</strong><span>${x.fecha_validacion_rffm?'Validado '+fmt(x.fecha_validacion_rffm):'Registrado por el club'}${x.centro_medico?' · '+esc(x.centro_medico):''}</span></div>`).join(''):'<div class="meta">Sin reconocimientos anteriores.</div>';
  $('#medicalModal').showModal();
}
async function saveRemoteMedical(form){
  if(!['admin','club'].includes(currentRole))return;const fd=new FormData(form),date=String(fd.get('medicalDate')||''),expiry=String(fd.get('medicalExpiry')||'');if(!date){alert('Indica la fecha del reconocimiento.');return}const calculated=expiry||addYears(date,2);
  try{
    const payload={jugador_id:selectedMedicalPlayerId,fecha_reconocimiento:date,fecha_valido_hasta:calculated,fecha_validacion_rffm:isoToday(),registrado_por:currentUser.authUserId||currentUser.id};
    const {error}=await sb.from('reconocimientos_medicos').insert(payload);if(error)throw error;
    $('#medicalModal').close();await renderRemoteMedical();await renderRemoteClub();
  }catch(err){alert(`No se ha podido registrar el reconocimiento: ${err.message||err}`)}
}
function remoteMedicalIsValid(v){const state=medicalState(v?.medical?{date:v.medical.fecha_reconocimiento,expiry:v.medical.fecha_valido_hasta}:null);return ['ok','soon'].includes(state.key)}
function validateRemoteFederationGate(v,targetState){
  if(!['lista_para_federar','ficha_tramitada'].includes(targetState))return null;
  if(!v.assignment)return 'Asigna primero un equipo al jugador.';
  if(!remoteMedicalIsValid(v))return 'El jugador necesita un reconocimiento médico en vigor antes de quedar listo para federar.';
  return null;
}
function renderMedical(){if(currentUser?.source==='supabase')return renderRemoteMedical();if(!$('#medicalTable'))return;const q=($('#medicalSearch')?.value||'').trim().toLowerCase(),f=$('#medicalFilter')?.value||'all';const source=players.filter(p=>p.active!==false&&inscriptionFor(p.id)).map(p=>({p,i:inscriptionFor(p.id),m:latestMedical(p.id)})).map(x=>({...x,state:medicalState(x.m)}));const rows=source.filter(x=>(!q||x.p.name.toLowerCase().includes(q))&&(f==='all'||x.state.key===f));$('#medicalTable').innerHTML=rows.length?rows.map(x=>`<tr class="medical-row" data-id="${esc(x.p.id)}" tabindex="0"><td><strong>${esc(x.p.name)}</strong></td><td>${esc(categoryName(x.i.categoryId))}</td><td>${fmt(x.m?.date)}</td><td>${fmt(x.m?.expiry)}</td><td><span class="medical-badge ${x.state.key}">${esc(x.state.label)}</span></td></tr>`).join(''):'<tr><td colspan="5">No hay jugadores que coincidan con el filtro.</td></tr>';$$('.medical-row').forEach(r=>r.onclick=()=>openMedical(r.dataset.id));$('#medicalTotal').textContent=source.length;$('#medicalOk').textContent=source.filter(x=>x.state.key==='ok').length;$('#medicalSoon').textContent=source.filter(x=>x.state.key==='soon').length;$('#medicalExpired').textContent=source.filter(x=>['expired','missing'].includes(x.state.key)).length}
function openMedical(id){if(currentUser?.source==='supabase')return openRemoteMedical(id);selectedMedicalPlayerId=id;const p=players.find(x=>x.id===id),m=latestMedical(id);if(!p)return;$('#medicalPlayerName').textContent=p.name;$('#medicalPlayerMeta').textContent=categoryName(inscriptionFor(id)?.categoryId);const f=$('#medicalForm');f.elements.medicalDate.value=m?.date||'';f.elements.medicalExpiry.value=m?.expiry||'';$('#medicalHistory').innerHTML=medicals.filter(x=>x.playerId===id).sort((a,b)=>(b.date||'').localeCompare(a.date||'')).map(x=>`<div class="history-item"><strong>${fmt(x.date)} → ${fmt(x.expiry)}</strong><span>Validez registrada${x.validatedAt?' · validado '+fmt(x.validatedAt):''}</span></div>`).join('')||'<div class="meta">Sin reconocimientos anteriores.</div>';$('#medicalModal').showModal()}

function assignmentState(a,when=isoToday()){if(a.startDate&&when<a.startDate)return'upcoming';if(a.endDate&&when>a.endDate)return'finished';return'active'}
function assignmentStateLabel(s){return s==='upcoming'?'Próxima':s==='finished'?'Finalizada':'Activa'}
function assignmentStateClass(s){return s==='active'?'complete':s==='upcoming'?'pending':'returned'}
function renderAssignmentList(target,arr,cls){const e=$(target);if(!e)return;e.innerHTML=arr.length?arr.map((a,i)=>`<div class="assignment-card"><div><strong>${esc(teamName(a.teamId))}</strong><div class="meta">${esc(coachRoleLabel(a.coachRole))} · ${fmt(a.startDate)} → ${fmt(a.endDate)}</div></div><span class="status ${assignmentStateClass(assignmentState(a))}">${assignmentStateLabel(assignmentState(a))}</span><button type="button" class="secondary tiny ${cls}" data-index="${i}">Quitar</button></div>`).join(''):'<div class="meta">Todavía no hay equipos asignados.</div>'}
function fillAssignmentTeamSelect(id){const s=$(id);if(s)s.innerHTML='<option value="">Seleccionar equipo</option>'+currentSeasonTeams().filter(t=>t.active).map(t=>`<option value="${esc(t.id)}">${esc(t.name)} · ${esc(categoryName(t.categoryId))}</option>`).join('')}
function addAssignmentFrom(prefix,target,render){const team=$(`#${prefix}Team`).value,role=$(`#${prefix}Role`).value,startDate=$(`#${prefix}Start`).value,endDate=$(`#${prefix}End`).value;if(!team||!startDate||!endDate){alert('Selecciona equipo y completa las fechas.');return}if(endDate<startDate){alert('La fecha de fin no puede ser anterior al inicio.');return}if(target.some(a=>a.teamId===team&&!(endDate<a.startDate||startDate>a.endDate))){alert('Ya existe una asignación solapada para ese equipo.');return}target.push({teamId:team,coachRole:role,startDate,endDate});render()}
function renderCoaches(){if(!$('#coachesTable'))return;const teamSel=$('#coachTeamFilter'),catSel=$('#coachCategoryFilter');teamSel.innerHTML='<option value="all">Todos los equipos</option>'+currentSeasonTeams().filter(t=>t.active).map(t=>`<option value="${t.id}">${esc(t.name)}</option>`).join('');const cv=catSel.value;catSel.innerHTML='<option value="all">Todas las categorías</option>'+categories.filter(c=>c.active).map(c=>`<option value="${c.id}">${esc(c.name)}</option>`).join('');if([...catSel.options].some(o=>o.value===cv))catSel.value=cv;const cf=catSel.value,tf=teamSel.value,rf=$('#coachRoleFilter').value,lf=$('#coachLicenseFilter').value,df=$('#coachDelegateFilter').value;const rows=coaches.filter(c=>{const aa=c.assignments||[];return(cf==='all'||aa.some(a=>teams.find(t=>t.id===a.teamId)?.categoryId===cf))&&(tf==='all'||aa.some(a=>a.teamId===tf))&&(rf==='all'||aa.some(a=>a.coachRole===rf))&&(lf==='all'||(lf==='yes')===!!c.hasLicense)&&(df==='all'||(df==='yes')===!!c.delegateCourse)});$('#coachesTable').innerHTML=rows.length?rows.map(c=>{const ah=(c.assignments||[]).map(a=>`<div class="assignment-inline"><div><strong>${esc(teamName(a.teamId))}</strong><div class="meta">${coachRoleLabel(a.coachRole)} · ${fmt(a.startDate)} → ${fmt(a.endDate)}</div></div><span class="status ${assignmentStateClass(assignmentState(a))}">${assignmentStateLabel(assignmentState(a))}</span></div>`).join('')||'—';const any=(c.assignments||[]).some(a=>assignmentState(a)==='active');return`<tr><td><strong>${esc(c.name)}</strong>${c.userId?'<div class="meta">Usuario de entrenador</div>':''}</td><td>${ah}</td><td><span class="dot ${c.hasLicense?'ok':'warn'}">${c.hasLicense?'✓ '+esc(c.licenseType||'Sí'):'⚠ No'}</span></td><td><span class="dot ${c.delegateCourse?'ok':'warn'}">${c.delegateCourse?'✓ Hecho':'⚠ Pendiente'}</span></td><td><span class="status ${c.active&&any?'complete':'returned'}">${!c.active?'Inactivo':any?'Con asignación activa':'Sin asignación activa'}</span></td><td>${currentRole==='admin'?`<button class="secondary tiny edit-coach" data-id="${c.id}">Editar</button>`:''}</td></tr>`}).join(''):'<tr><td colspan="6">No hay entrenadores que coincidan con los filtros.</td></tr>';$$('.edit-coach').forEach(b=>b.onclick=()=>openCoachForEdit(b.dataset.id));renderTeamsSummary()}
function renderCoachAssignments(){renderAssignmentList('#coachAssignmentsList',pendingCoachAssignments,'remove-coach-assignment');$$('.remove-coach-assignment').forEach(b=>b.onclick=()=>{pendingCoachAssignments.splice(+b.dataset.index,1);renderCoachAssignments()})}
function openCoachForNew(){editingCoachId=null;pendingCoachAssignments=[];$('#coachForm').reset();fillAssignmentTeamSelect('#coachAssignmentTeam');renderCoachAssignments();$('#coachModalTitle').textContent='Nuevo entrenador';$('#coachModal').showModal()}
function openCoachForEdit(id){const c=coaches.find(x=>x.id===id);if(!c)return;editingCoachId=id;pendingCoachAssignments=(c.assignments||[]).map(a=>({...a}));const f=$('#coachForm');f.elements.name.value=c.name;f.elements.hasLicense.value=c.hasLicense?'yes':'no';f.elements.licenseType.value=c.licenseType||'';f.elements.delegateCourse.value=c.delegateCourse?'yes':'no';f.elements.active.value=c.active?'yes':'no';fillAssignmentTeamSelect('#coachAssignmentTeam');renderCoachAssignments();$('#coachModalTitle').textContent='Editar entrenador';$('#coachModal').showModal()}
function renderTeamsSummary(){if(!$('#teamsTable'))return;const source=dbStructureLoaded?dbSeasonTeams():currentSeasonTeams();const catName=id=>dbStructureLoaded?dbCategoryName(id):categoryName(id);$('#teamsTable').innerHTML=source.map(t=>`<tr><td><strong>${esc(t.name)}</strong></td><td>${esc(catName(t.categoryId))}</td><td>${dbStructureLoaded?'—':playerTeams.filter(a=>a.teamId===t.id&&a.seasonId===currentSeasonId&&assignmentState(a)==='active').length}</td><td>${dbStructureLoaded?'—':coaches.filter(c=>c.active&&(c.assignments||[]).some(a=>a.teamId===t.id&&assignmentState(a)==='active')).length}</td><td><span class="status ${t.active?'complete':'returned'}">${t.active?'Activo':'Inactivo'}</span></td></tr>`).join('')}

function renderClubUsers(){if(!$('#clubUsersTable'))return;const rows=users.filter(u=>internalRoles(u).length);$('#clubUsersTable').innerHTML=rows.map(u=>{const c=coaches.find(x=>x.userId===u.id),ts=c?(c.assignments||[]).filter(a=>assignmentState(a)==='active').map(a=>teamName(a.teamId)).join(', '):'—';const badges=(u.roles||[]).map(r=>`<span class="role-badge">${esc(roleLabel(r))}</span>`).join('');return`<tr><td><strong>${esc(u.name)}</strong></td><td>${esc(u.email)}</td><td><div class="role-badges">${badges}</div></td><td>${esc(ts||'—')}</td><td><span class="status ${u.active?'complete':'returned'}">${u.active?'Activo':'Inactivo'}</span></td><td><button class="secondary tiny toggle-user" data-id="${u.id}">${u.active?'Desactivar':'Activar'}</button></td></tr>`}).join('');$$('.toggle-user').forEach(b=>b.onclick=()=>{users=users.map(u=>u.id===b.dataset.id?{...u,active:!u.active}:u);saveUsers();renderClubUsers()})}

function renderPersons(){if(!$('#personsTable'))return;const pairs=duplicatePairs();$('#duplicateCount').textContent=String(pairs.length);$('#duplicateList').innerHTML=pairs.length?pairs.map(d=>`<div class="duplicate-card"><div><strong>${esc(d.a.name)} ↔ ${esc(d.b.name)}</strong><span>${esc(d.reasons.join(', '))}</span></div><button class="secondary tiny merge-persons" data-a="${d.a.id}" data-b="${d.b.id}">Fusionar</button></div>`).join(''):'<div class="empty-note">No se han detectado posibles duplicados.</div>';$('#personsTable').innerHTML=persons.map(p=>{const us=users.filter(u=>u.personId===p.id),ps=players.filter(x=>x.personId===p.id),roles=[...new Set(us.flatMap(u=>u.roles||[]))];const emails=[...new Set(us.flatMap(u=>[u.email,...(u.emailAliases||[])]).filter(Boolean))];const dnis=[...new Set([p.dni,...ps.map(x=>x.dni)].filter(Boolean))];return`<tr><td><strong>${esc(p.name)}</strong></td><td>${esc(emails.join(', ')||'—')}</td><td>${esc(dnis.join(', ')||'—')}</td><td><div class="role-badges">${roles.map(r=>`<span class="role-badge">${esc(roleLabel(r))}</span>`).join('')||'—'}</div></td><td>${ps.length}</td><td>${us.length}</td></tr>`}).join('');$$('.merge-persons').forEach(b=>b.onclick=()=>{const A=persons.find(p=>p.id===b.dataset.a),B=persons.find(p=>p.id===b.dataset.b);if(confirm(`Fusionar "${B?.name}" dentro de "${A?.name}"? Se conservarán perfiles e históricos.`))mergePersons(b.dataset.a,b.dataset.b)})}

function renderStructure(){
  if(!$('#seasonsTable'))return;
  const can=currentRole==='admin';
  if(dbStructureLoaded){
    const active=dbActiveSeason();
    $('#openSeasonModal').style.display='none';
    $('#openTeamModal').style.display='none';
    $('#seasonsTable').innerHTML=dbSeasons.map(s=>`<tr><td><strong>${esc(s.name)}</strong></td><td>${fmt(s.startDate)}</td><td>${fmt(s.endDate)}</td><td>${s.id===active?.id?'<span class="status complete">Actual</span>':'—'}</td><td>${s.status==='cerrada'?'Cerrada':s.status==='activa'?'Activa':'Planificación'}</td><td>—</td></tr>`).join('');
    $('#structureTeamsTable').innerHTML=dbSeasonTeams().map(t=>`<tr><td><strong>${esc(t.name)}</strong></td><td>${esc(dbCategoryName(t.categoryId))}</td><td>${t.modality?esc(t.modality):'—'}</td><td>${remoteClubPlayers.filter(p=>p.assignment?.equipo_id===t.id&&p.active).length||'—'}</td><td>—</td><td><span class="status ${t.active?'complete':'returned'}">${t.active?'Activo':'Inactivo'}</span></td><td><span class="meta">Supabase</span></td></tr>`).join('');
    return;
  }
  $('#openSeasonModal').style.display=can?'inline-flex':'none';$('#openTeamModal').style.display=can?'inline-flex':'none';$('#seasonsTable').innerHTML=seasons.map(s=>`<tr><td><strong>${esc(s.name)}</strong></td><td>${fmt(s.startDate)}</td><td>${fmt(s.endDate)}</td><td>${s.id===currentSeasonId?'<span class="status complete">Actual</span>':'—'}</td><td>${s.active?'Activa':'Cerrada'}</td><td>${can&&s.id!==currentSeasonId?`<button class="secondary tiny activate-season" data-id="${s.id}">Usar</button>`:''}</td></tr>`).join('');$$('.activate-season').forEach(b=>b.onclick=()=>{currentSeasonId=b.dataset.id;writeJSON(K.currentSeason,currentSeasonId);recalculateSeasonCategories(currentSeasonId);recordAudit('Cambio de temporada activa','',seasonName(currentSeasonId));$('#currentSeasonLabel').textContent=seasonName(currentSeasonId);renderStructure();renderClub();renderMedical();renderCoaches()});$('#structureTeamsTable').innerHTML=currentSeasonTeams().map(t=>`<tr><td><strong>${esc(t.name)}</strong></td><td>${esc(categoryName(t.categoryId))}</td><td>${t.modality?esc(t.modality):'—'}</td><td>${playerTeams.filter(a=>a.teamId===t.id&&a.seasonId===currentSeasonId&&assignmentState(a)==='active').length}</td><td>${coaches.filter(c=>c.active&&(c.assignments||[]).some(a=>a.teamId===t.id&&assignmentState(a)==='active')).length}</td><td><span class="status ${t.active?'complete':'returned'}">${t.active?'Activo':'Inactivo'}</span></td><td>${can?`<button class="secondary tiny edit-team" data-id="${t.id}">Editar</button>`:''}</td></tr>`).join('');$$('.edit-team').forEach(b=>b.onclick=()=>openTeamEdit(b.dataset.id))
}
function saveTeamAssignment(){if(currentRole==='coach')return;const p=players.find(x=>x.id===selectedPlayerId),i=inscriptionFor(selectedPlayerId);if(!p||!i||i.workflow==='review')return;const teamId=$('#adminTeam').value,old=activeTeamAssignment(p.id);if(old?.teamId===teamId)return;if(old){old.endDate=isoToday();old.reason='Cambio de equipo';}if(teamId){playerTeams.push({id:uid('pt'),playerId:p.id,seasonId:currentSeasonId,teamId,startDate:isoToday(),endDate:currentSeason().endDate,reason:old?'Cambio de equipo':'Asignación inicial'})}savePlayerTeams();recordAudit('Asignación de equipo',p.id,teamId?`Asignado a ${teamName(teamId)}`:'Equipo retirado');openAdminPlayer(p.id);renderClub();renderCoaches();renderStructure()}
function advanceSelected(){const i=inscriptionFor(selectedPlayerId);if(currentRole==='coach'||!i)return;const ix=Math.max(0,WORKFLOW.findIndex(x=>x.key===i.workflow)),n=WORKFLOW[Math.min(ix+1,WORKFLOW.length-1)];updateInscription(selectedPlayerId,x=>({...x,workflow:n.key,federation:n.federation,status:['ready','federated'].includes(n.key)?'complete':'pending',familyActionRequired:false,returnMessage:''}),'Avance de estado');openAdminPlayer(selectedPlayerId)}
function setWorkflowSelected(){if(currentRole==='coach')return;const wf=WORKFLOW.find(x=>x.key===$('#adminWorkflow').value);if(!wf)return;updateInscription(selectedPlayerId,x=>({...x,workflow:wf.key,federation:wf.federation,status:['ready','federated'].includes(wf.key)?'complete':'pending',familyActionRequired:false,returnMessage:''}),'Cambio manual de estado');openAdminPlayer(selectedPlayerId)}
function returnSelected(){const v=playerVM(players.find(x=>x.id===selectedPlayerId));if(currentRole==='coach'||v.rep?.type!=='guardian')return;const m=$('#returnMessage').value.trim();if(!m){alert('Indica qué debe revisar la familia.');return}updateInscription(selectedPlayerId,x=>({...x,workflow:'review',federation:'Devuelto a familia',status:'pending',familyActionRequired:true,returnMessage:m}),'Devuelto a familia: '+m);$('#adminPlayerModal').close()}

function syncGuardianDocumentField(){const f=$('#playerForm'),wrap=$('#guardianDniField'),input=f?.elements?.guardianDni,hint=$('#guardianDniHint');if(!f||!wrap||!input)return;const familyMode=currentRole==='family';wrap.classList.toggle('hidden',!familyMode);input.disabled=!familyMode;input.required=familyMode;if(!familyMode){input.value='';return}const dni=currentUser?.source==='supabase'?normDni(currentUser.documentNumber||''):normDni(personForUser(currentUser?.id)?.dni||'');input.value=dni;input.readOnly=!!dni;if(hint)hint.textContent=dni?'Documento propio del tutor, recuperado automáticamente de su cuenta.':'No hay DNI/NIE de tutor registrado. Completa la identidad antes de inscribir un menor.'}
function openPlayerForNew(){editingPlayerId=null;const f=$('#playerForm');f.reset();f.elements.email.value=currentUser?.email||'';f.elements.phone.value=currentUser?.phone||'';syncGuardianDocumentField();$('#playerModalTitle').textContent='Datos del jugador';$('#savePlayer').textContent='Guardar jugador';refreshCalculatedCategory(f);$('#playerModal').showModal()}
function openPlayerForEdit(id){const p=familyAccessPlayers().find(x=>x.id===id);if(!p)return;editingPlayerId=id;const f=$('#playerForm'),parts=p.name.split(' '),i=inscriptionFor(id);f.elements.name.value=parts[0]||'';f.elements.surname1.value=parts[1]||'';f.elements.surname2.value=parts.slice(2).join(' ');f.elements.birth.value=p.birth||'';f.elements.dni.value=p.dni||'';f.elements.email.value=currentUser.email||'';f.elements.phone.value=currentUser.phone||'';syncGuardianDocumentField();$('#playerModalTitle').textContent='Revisar datos del jugador';$('#savePlayer').textContent='Guardar cambios';refreshCalculatedCategory(f);$('#playerModal').showModal()}

function openChangeTutor(){if(currentRole!=='admin')return;const p=players.find(x=>x.id===selectedPlayerId);if(!p)return;const eligible=users.filter(u=>hasRole(u,'family')&&u.active);$('#tutorUserSelect').innerHTML='<option value="">Seleccionar tutor registrado</option>'+eligible.map(u=>`<option value="${u.id}">${esc(u.name)} · ${esc(u.email)}</option>`).join('');$('#changeTutorForm').reset();$('#changeTutorModal').showModal()}
function openSelfRepresentation(){if(currentRole!=='admin')return;const p=players.find(x=>x.id===selectedPlayerId);if(!p)return;const pu=currentPlayerUser(p),d=daysTo18(p),a=ageOn(p.birth);const f=$('#selfRepresentationForm');f.reset();if(pu)f.elements.email.value=pu.email;$('#selfRepresentationHint').textContent=a>=18?'El jugador ya es mayor de edad: la cuenta se activará ahora y la representación ordinaria del tutor finalizará.':`La cuenta quedará preparada y se activará al cumplir 18 años${d!==null?` (en ${d} días)`:''}.`;$('#selfRepresentationModal').showModal()}

function openTeamEdit(id){editingTeamId=id;const t=teams.find(x=>x.id===id);if(!t)return;fillTeamCategorySelect();const f=$('#teamForm');f.elements.name.value=t.name;f.elements.categoryId.value=t.categoryId;f.elements.active.value=t.active?'yes':'no';$('#teamModalTitle').textContent='Editar equipo';$('#teamModal').showModal()}
function fillTeamCategorySelect(){const s=$('#teamCategorySelect');s.innerHTML=categories.filter(c=>c.active).map(c=>`<option value="${c.id}">${esc(c.name)}</option>`).join('')}

function renderUserAssignments(){renderAssignmentList('#clubUserAssignmentsList',pendingUserAssignments,'remove-user-assignment');$$('.remove-user-assignment').forEach(b=>b.onclick=()=>{pendingUserAssignments.splice(+b.dataset.index,1);renderUserAssignments()})}
function syncCoachUserFields(){const x=$('#clubUserRole').value==='coach';$('#coachUserFields').classList.toggle('hidden',!x);if(x){fillAssignmentTeamSelect('#clubUserAssignmentTeam');renderUserAssignments()}}

$('#showLogin').onclick=()=>showAuth('login');$('#showFamilySignup').onclick=()=>showAuth('signup');
function syncSignupMode(){const self=document.querySelector('input[name="signupMode"]:checked')?.value==='self';$('#selfSignupFields').classList.toggle('hidden',!self);$('#guardianSignupFields').classList.toggle('hidden',self);const f=$('#familySignupForm'),tutorDni=f?.elements?.tutorDni,tutorType=f?.elements?.tutorDocumentType,selfDni=f?.elements?.selfDni,selfType=f?.elements?.selfDocumentType;if(tutorDni){tutorDni.required=!self;tutorDni.disabled=self}if(tutorType)tutorType.disabled=self;if(selfDni)selfDni.disabled=!self;if(selfType)selfType.disabled=!self;refreshCalculatedCategory(f)}
$$('input[name="signupMode"]').forEach(r=>r.onchange=syncSignupMode);syncSignupMode();
$('#loginForm').onsubmit=async e=>{e.preventDefault();const form=e.currentTarget;if(!sb){alert('No se ha podido cargar Supabase. Comprueba tu conexión.');return}const fd=new FormData(form),email=String(fd.get('email')||'').trim(),password=String(fd.get('password')||'');const submit=form.querySelector('button[type="submit"]');if(submit){submit.disabled=true;submit.textContent='Entrando…'}try{const {data,error}=await sb.auth.signInWithPassword({email,password});if(error)throw error;currentUser=await loadIdentityWithPending(data.user);await loadSupabaseStructure();const avail=availableRoles(currentUser);if(!avail.length){await sb.auth.signOut();currentUser=null;throw new Error('Tu cuenta no tiene ningún perfil activo en el club.')}currentRole=avail.length===1?avail[0]:null;form.reset();if(currentRole){localStorage.setItem(K.sessionRole,currentRole);showApp()}else{localStorage.removeItem(K.sessionRole);showRoleChooser()}}catch(err){console.error('Login Supabase',err);alert(err?.message==='Invalid login credentials'?'Correo o contraseña incorrectos.':`No se ha podido iniciar sesión: ${err.message||err}`)}finally{if(submit){submit.disabled=false;submit.textContent='Entrar'}}};
$('#familySignupForm').onsubmit=async e=>{
  e.preventDefault();const form=e.currentTarget;if(!sb){alert('No se ha podido cargar Supabase.');return}
  const fd=new FormData(form),mode=String(fd.get('signupMode')||'guardian'),password=String(fd.get('password')||''),password2=String(fd.get('password2')||''),email=String(fd.get('email')||'').trim().toLowerCase(),birth=String(fd.get('birth')||'');
  if(password!==password2){alert('Las contraseñas no coinciden.');return}
  const age=ageOn(birth);if(age===null||age<18){alert('El registro de cuenta solo está disponible para mayores de 18 años. Si el jugador es menor, debe registrarlo su tutor.');return}
  const documentNumber=normDni(mode==='guardian'?fd.get('tutorDni'):fd.get('selfDni'));
  const documentType=String(mode==='guardian'?fd.get('tutorDocumentType'):fd.get('selfDocumentType')||'dni');
  if(mode==='guardian'&&!documentNumber){alert('El DNI/NIE del tutor es obligatorio.');return}
  const payload={mode,firstName:String(fd.get('firstName')||'').trim(),surname1:String(fd.get('surname1')||'').trim(),surname2:String(fd.get('surname2')||'').trim(),birth,phone:String(fd.get('phone')||'').trim(),email,documentType,documentNumber};
  const submit=form.querySelector('button[type="submit"]');if(submit){submit.disabled=true;submit.textContent='Creando cuenta…'}
  try{
    localStorage.setItem(PENDING_SIGNUP_KEY,JSON.stringify(payload));
    const {data,error}=await sb.auth.signUp({email,password,options:{emailRedirectTo:AUTH_REDIRECT_URL}});if(error)throw error;
    if(data.session){
      await registerProfileFromPayload(payload);currentUser=await loadSupabaseIdentity(data.user);await loadSupabaseStructure();currentRole=mode==='guardian'?'family':'player';localStorage.setItem(K.sessionRole,currentRole);form.reset();showApp();
    }else{
      form.reset();showAuth('login');const loginEmail=$('#loginForm')?.elements?.email;if(loginEmail)loginEmail.value=email;alert('Cuenta creada. Revisa tu correo y confirma la dirección. Si no recibes el mensaje, usa “Reenviar correo de confirmación”. Después inicia sesión: la aplicación completará automáticamente tu perfil.');
    }
  }catch(err){console.error('Alta Supabase',err);alert(`No se ha podido crear la cuenta: ${err.message||err}`)}finally{if(submit){submit.disabled=false;submit.textContent='Crear cuenta'}}
};
$('#resendConfirmationButton').onclick=async()=>{
  if(!sb){alert('No se ha podido cargar Supabase. Comprueba tu conexión.');return}
  const button=$('#resendConfirmationButton');
  const loginEmail=$('#loginForm')?.elements?.email;
  const pending=readJSON(PENDING_SIGNUP_KEY,null);
  const email=String(loginEmail?.value||pending?.email||'').trim().toLowerCase();
  if(!email){alert('Introduce primero el correo electrónico de la cuenta que quieres confirmar.');loginEmail?.focus();return}
  if(loginEmail&&!loginEmail.value)loginEmail.value=email;
  const originalText=button?.textContent||'Reenviar correo de confirmación';
  if(button){button.disabled=true;button.textContent='Enviando…'}
  try{
    const {error}=await sb.auth.resend({type:'signup',email,options:{emailRedirectTo:AUTH_REDIRECT_URL}});
    if(error)throw error;
    alert(`Correo de confirmación reenviado a ${email}. Usa únicamente el enlace del mensaje más reciente.`);
  }catch(err){
    console.error('Reenvío confirmación Supabase',err);
    const msg=String(err?.message||err||'');
    if(/rate limit|security purposes|seconds/i.test(msg)){
      alert('Supabase limita temporalmente los reenvíos por seguridad. Espera unos segundos y vuelve a intentarlo.');
    }else{
      alert(`No se ha podido reenviar el correo de confirmación: ${msg}`);
    }
  }finally{
    if(button){button.disabled=false;button.textContent=originalText}
  }
};

function showAuthRedirectError(){
  const url=new URL(window.location.href);
  const params=new URLSearchParams(url.search);
  const hashParams=new URLSearchParams((url.hash||'').replace(/^#/,''));
  const code=params.get('error_code')||hashParams.get('error_code');
  const description=params.get('error_description')||hashParams.get('error_description');
  if(!code&&!description)return;
  const expired=code==='otp_expired'||/expired|invalid/i.test(description||'');
  setTimeout(()=>alert(expired?'El enlace de confirmación no es válido o ha caducado. Introduce tu correo y pulsa “Reenviar correo de confirmación” para generar uno nuevo.':`No se ha podido completar la confirmación: ${description||code}`),0);
  ['error','error_code','error_description'].forEach(k=>url.searchParams.delete(k));
  if(url.hash)url.hash='';
  history.replaceState({},document.title,url.toString());
}
showAuthRedirectError();

$('#logoutButton').onclick=async()=>{localStorage.removeItem(K.sessionRole);currentUser=null;currentRole=null;if(sb)await sb.auth.signOut();showAuth('login')};$('#roleSwitchButton').onclick=()=>showRoleChooser(true);$('#closeRoleChooser').onclick=()=>$('#roleChooserModal').close();

function refreshCalculatedCategory(form){const birth=form?.elements?.birth?.value||'',cat=(currentUser?.source==='supabase'&&dbStructureLoaded)?dbCategoryForBirth(birth):categoryForBirth(birth,currentSeasonId),out=form?.querySelector?.('[data-category-calculated]');if(out)out.value=cat?cat.name:'Fuera de categorías configuradas'}
$('#familySignupForm')?.elements?.birth?.addEventListener('change',()=>refreshCalculatedCategory($('#familySignupForm')));
$('#playerForm')?.elements?.birth?.addEventListener('change',()=>refreshCalculatedCategory($('#playerForm')));
$('#addPlayerButton').onclick=openPlayerForNew;$('#playerForm').onsubmit=async e=>{e.preventDefault();const form=e.currentTarget;if(currentUser?.source==='supabase'&&currentRole==='family'&&editingPlayerId){const fd=new FormData(form),birth=String(fd.get('birth')||''),docNumber=normDni(fd.get('dni')||'');const submit=$('#savePlayer');if(submit){submit.disabled=true;submit.textContent='Guardando…'}try{const {error}=await sb.rpc('actualizar_menor_representado',{p_jugador_id:editingPlayerId,p_nombre:String(fd.get('name')||'').trim(),p_primer_apellido:String(fd.get('surname1')||'').trim(),p_segundo_apellido:String(fd.get('surname2')||'').trim()||null,p_fecha_nacimiento:birth,p_tipo_documento:docNumber?String(fd.get('childDocumentType')||'dni'):null,p_numero_documento:docNumber||null});if(error)throw error;editingPlayerId=null;form.reset();$('#playerModal').close();await renderRemoteFamily();alert('Datos actualizados. La ficha vuelve a quedar pendiente de revisión por el club.')}catch(err){console.error('Edición menor Supabase',err);alert(`No se han podido guardar los cambios: ${err.message||err}`)}finally{if(submit){submit.disabled=false;submit.textContent='Guardar jugador'}}return;}if(currentUser?.source==='supabase'&&currentRole==='family'&&!editingPlayerId){const fd=new FormData(form),birth=String(fd.get('birth')||''),age=ageOn(birth);if(age===null||age>=18){alert('Este formulario es para menores de 18 años. Un adulto debe crear su propia cuenta de Jugador.');return}if(!currentUser.documentNumber){alert('Tu perfil de Tutor no tiene DNI/NIE registrado. Contacta con el club antes de continuar.');return}const submit=$('#savePlayer');if(submit){submit.disabled=true;submit.textContent='Guardando…'}try{const docNumber=normDni(fd.get('dni')||'');const {error}=await sb.rpc('registrar_menor',{p_nombre:String(fd.get('name')||'').trim(),p_primer_apellido:String(fd.get('surname1')||'').trim(),p_segundo_apellido:String(fd.get('surname2')||'').trim()||null,p_fecha_nacimiento:birth,p_tipo_documento:docNumber?String(fd.get('childDocumentType')||'dni'):null,p_numero_documento:docNumber||null});if(error)throw error;form.reset();$('#playerModal').close();await renderRemoteFamily();alert('Jugador registrado correctamente. La inscripción ha quedado pendiente de revisión por el club.')}catch(err){console.error('Alta menor Supabase',err);alert(`No se ha podido registrar al jugador: ${err.message||err}`)}finally{if(submit){submit.disabled=false;submit.textContent='Guardar jugador'}}return;}if(currentRole==='player'&&!editingPlayerId)return;const fd=new FormData(e.currentTarget),full=[fd.get('name'),fd.get('surname1'),fd.get('surname2')].filter(Boolean).join(' '),birth=fd.get('birth'),cat=categoryForBirth(birth,currentSeasonId),childDni=normDni(fd.get('dni')||'');if(!cat){alert('La fecha de nacimiento no corresponde a una categoría configurada para la temporada activa.');return}let guardianPerson=null,guardianDni='';if(currentRole==='family'){guardianPerson=personForUser(currentUser.id);guardianDni=normDni(fd.get('guardianDni')||guardianPerson?.dni||'');if(!guardianDni){alert('El DNI/NIE del tutor es obligatorio.');return}const owner=personWithOwnDni(guardianDni,guardianPerson?.id||'');if(owner){alert(`El DNI/NIE ${guardianDni} ya pertenece a otra persona registrada. El club debe revisar la identidad antes de continuar.`);return}if(guardianPerson&&!guardianPerson.dni){guardianPerson.dni=guardianDni;writeJSON(K.persons,persons)}}const dupPlayer=duplicatePlayerMatch(full,birth,childDni,editingPlayerId||'');if(dupPlayer){alert(`Posible duplicado: ya existe ${dupPlayer.name} con el mismo DNI/NIE propio o con el mismo nombre y fecha de nacimiento. El DNI del tutor no se usa para deduplicar jugadores.`);return}if(editingPlayerId){const p=players.find(x=>x.id===editingPlayerId);if(!p)return;p.name=full;p.birth=birth||'';p.dni=childDni;p.data=true;const pp=personForPlayer(p.id);if(pp)pp.dni=childDni;const i=inscriptionFor(p.id);if(i){const old=i.workflow;i.categoryId=cat?.id||i.categoryId;i.workflow='review';i.federation='Modificado por usuario · pendiente de revisión';i.status='pending';i.familyActionRequired=false;i.returnMessage='';if(childDni){i.identityDocumentSource='player';i.identityDocumentPersonId=p.personId;i.identityDocumentSnapshot=childDni}else if(currentRole==='family'&&guardianPerson){i.identityDocumentSource='guardian';i.identityDocumentPersonId=guardianPerson.id;i.identityDocumentSnapshot=guardianDni}addStatusHistory(i.id,p.id,old,'review','Datos modificados por usuario')}recordAudit('Datos del jugador modificados',p.id,childDni?'Documento propio informado':'Sin DNI propio · utiliza documento del tutor');savePlayers();saveInscriptions();writeJSON(K.persons,persons)}else{const person={id:uid('person'),name:full,email:'',dni:childDni,createdAt:isoToday(),mergedFrom:[]};persons.push(person);const pid=uid('p'),iid=uid('i');players.push({id:pid,personId:person.id,name:full,birth:birth||'',dni:childDni,data:true,active:true});inscriptions.push({id:iid,playerId:pid,seasonId:currentSeasonId,categoryId:cat?.id||'cat-pb',docs:'Pendiente de documentos',workflow:'review',federation:'Pendiente de revisión',status:'pending',familyActionRequired:false,returnMessage:'',createdAt:isoToday(),identityDocumentSource:childDni?'player':'guardian',identityDocumentPersonId:childDni?person.id:guardianPerson?.id||'',identityDocumentSnapshot:childDni||guardianDni});representations.push({id:uid('r'),playerId:pid,userId:currentUser.id,type:'guardian',startDate:isoToday(),endDate:'',reason:'Inscripción inicial',legalException:false});addStatusHistory(iid,pid,'','review','Inscripción creada por familia');recordAudit('Alta de jugador',pid,childDni?'Con DNI/NIE propio':'Sin DNI propio · documento del tutor reutilizado');savePlayers();saveInscriptions();saveReps();writeJSON(K.persons,persons)}renderFamily();e.currentTarget.reset();editingPlayerId=null;$('#playerModal').close()};$$('#playerForm [value="cancel"]').forEach(b=>b.onclick=()=>{$('#playerForm').reset();editingPlayerId=null;$('#playerModal').close()});

$('#searchInput').oninput=renderClub;['statusFilter','clubCategoryFilter','clubActiveFilter'].forEach(id=>$('#'+id).onchange=renderClub);$('#saveTeamAssignment').onclick=()=>currentUser?.source==='supabase'?saveRemoteTeamAssignment():saveTeamAssignment();$('#advanceStatus').onclick=()=>currentUser?.source==='supabase'?advanceRemoteSelected():advanceSelected();$('#saveWorkflow').onclick=()=>currentUser?.source==='supabase'?setRemoteWorkflowSelected():setWorkflowSelected();$('#returnToFamily').onclick=()=>currentUser?.source==='supabase'?returnRemoteSelected():returnSelected();$('#closeAdminModal').onclick=()=>$('#adminPlayerModal').close();$('#changeTutorButton').onclick=openChangeTutor;$('#selfRepresentationButton').onclick=openSelfRepresentation;
$$('[data-club-view]').forEach(b=>b.onclick=()=>{if(currentRole==='coach'&&b.dataset.clubView!=='clubView')return;if(['usersView','personsView'].includes(b.dataset.clubView)&&currentRole!=='admin')return;setView(b.dataset.clubView);if(b.dataset.clubView==='clubView')renderClub();if(b.dataset.clubView==='medicalView')renderMedical();if(b.dataset.clubView==='coachesView')renderCoaches();if(b.dataset.clubView==='structureView')renderStructure();if(b.dataset.clubView==='usersView')renderClubUsers();if(b.dataset.clubView==='personsView')renderPersons()});
$$('[data-family-tab]').forEach(b=>b.onclick=()=>{$$('[data-family-tab]').forEach(x=>x.classList.remove('active'));b.classList.add('active');if(b.dataset.familyTab==='players')$('.section').scrollIntoView({behavior:'smooth'})});

$('#togglePlayerActive').onclick=()=>{if(currentUser?.source==='supabase')return toggleRemotePlayerActive();if(currentRole!=='admin'&&currentRole!=='club')return;const p=players.find(x=>x.id===selectedPlayerId);if(!p)return;const next=p.active===false;p.active=next;savePlayers();recordAudit(next?'Jugador reactivado':'Jugador marcado inactivo',p.id,next?'Vuelve a operación diaria':'Salida o baja operativa');openAdminPlayer(p.id);renderClub();renderMedical()};
$('#changeTutorForm').onsubmit=e=>{e.preventDefault();if(currentRole!=='admin')return;const fd=new FormData(e.currentTarget),p=players.find(x=>x.id===selectedPlayerId),newUser=users.find(u=>u.id===fd.get('tutorUserId'));if(!p||!newUser)return;const newTutorPerson=personForUser(newUser.id);if(!normDni(newTutorPerson?.dni||'')){alert('El tutor seleccionado no tiene DNI/NIE propio registrado. Completa su identidad antes de asignarlo como representante.');return}const legal=fd.get('legalException')==='on',a=ageOn(p.birth);if(a>=18&&!legal){alert('El jugador ya es mayor de edad. Solo puede mantenerse un tutor si se registra una excepción jurídica.');return}const old=activeRepresentation(p.id);if(old)old.endDate=isoToday();representations.push({id:uid('r'),playerId:p.id,userId:newUser.id,type:'guardian',startDate:isoToday(),endDate:'',reason:fd.get('reason'),legalException:legal});saveReps();recordAudit('Cambio de tutor',p.id,`${repUserName(old)} → ${newUser.name}. Motivo: ${fd.get('reason')}`);$('#changeTutorModal').close();openAdminPlayer(p.id);renderClub()};
$('#closeChangeTutorModal').onclick=$('#cancelChangeTutor').onclick=()=>$('#changeTutorModal').close();
$('#selfRepresentationForm').onsubmit=e=>{e.preventDefault();if(currentRole!=='admin')return;const fd=new FormData(e.currentTarget),p=players.find(x=>x.id===selectedPlayerId);if(!p)return;const email=String(fd.get('email')).toLowerCase();let pu=currentPlayerUser(p),byEmail=users.find(u=>u.email.toLowerCase()===email);const birthday=eighteenthBirthday(p),adult=ageOn(p.birth)>=18;if(!pu&&byEmail){byEmail=normalizeUser(byEmail);if(!hasRole(byEmail,'player'))byEmail.roles.push('player');byEmail.playerId=p.id;byEmail.pendingActivationDate=adult?'':birthday;pu=byEmail}else if(pu){pu=normalizeUser(pu);if(!hasRole(pu,'player'))pu.roles.push('player');pu.email=email;pu.playerId=p.id;pu.pendingActivationDate=adult?'':birthday}else{pu={id:uid('u-person'),personId:p.personId,name:p.name,email,phone:'',password:fd.get('password'),roles:['player'],active:true,playerId:p.id,pendingActivationDate:adult?'':birthday};users.push(pu)}if(fd.get('password'))pu.password=fd.get('password');if(adult){pu.active=true;pu.pendingActivationDate='';const old=activeRepresentation(p.id);if(old?.type==='guardian'&&!old.legalException)old.endDate=isoToday();if(!activeRepresentation(p.id)||activeRepresentation(p.id)?.type!=='self')representations.push({id:uid('r'),playerId:p.id,userId:pu.id,type:'self',startDate:isoToday(),endDate:'',reason:'Mayoría de edad',legalException:false})}saveUsers();saveReps();recordAudit(adult?'Autorrepresentación activada':'Cuenta de jugador preparada',p.id,pu.email);$('#selfRepresentationModal').close();openAdminPlayer(p.id);renderClub()};
$('#closeSelfRepresentationModal').onclick=$('#cancelSelfRepresentation').onclick=()=>$('#selfRepresentationModal').close();

$('#medicalSearch').oninput=renderMedical;$('#medicalFilter').onchange=renderMedical;$('#medicalForm [name="medicalDate"]').onchange=e=>{const f=$('#medicalForm');if(currentUser?.source==='supabase'&&e.target.value&&!f.elements.medicalExpiry.value)f.elements.medicalExpiry.value=addYears(e.target.value,2)};$('#closeMedicalModal').onclick=$('#cancelMedical').onclick=()=>$('#medicalModal').close();$('#medicalForm').onsubmit=e=>{e.preventDefault();const form=e.currentTarget;if(currentUser?.source==='supabase')return saveRemoteMedical(form);const fd=new FormData(form);medicals.push({id:uid('m'),playerId:selectedMedicalPlayerId,date:fd.get('medicalDate')||'',expiry:fd.get('medicalExpiry')||'',validatedAt:isoToday()});saveMedicals();recordAudit('Reconocimiento médico registrado',selectedMedicalPlayerId,`${fmt(fd.get('medicalDate'))} → ${fmt(fd.get('medicalExpiry'))}`);$('#medicalModal').close();renderMedical();renderClub()};

$('#openCoachModal').onclick=openCoachForNew;$('#closeCoachModal').onclick=$('#cancelCoach').onclick=()=>$('#coachModal').close();['coachCategoryFilter','coachTeamFilter','coachRoleFilter','coachLicenseFilter','coachDelegateFilter'].forEach(id=>$('#'+id).onchange=renderCoaches);$('#coachForm').onsubmit=e=>{e.preventDefault();if(currentRole!=='admin')return;if(!pendingCoachAssignments.length){alert('Añade al menos una asignación.');return}const fd=new FormData(e.currentTarget),old=coaches.find(c=>c.id===editingCoachId),item={id:editingCoachId||uid('c'),userId:old?.userId||null,name:fd.get('name'),assignments:pendingCoachAssignments.map(a=>({...a})),hasLicense:fd.get('hasLicense')==='yes',licenseType:fd.get('licenseType')||'',delegateCourse:fd.get('delegateCourse')==='yes',active:fd.get('active')==='yes'};if(editingCoachId)coaches=coaches.map(c=>c.id===editingCoachId?item:c);else coaches.push(item);if(item.userId){const u=users.find(x=>x.id===item.userId);if(u)u.name=item.name;saveUsers()}saveCoaches();recordAudit('Entrenador actualizado','',item.name);editingCoachId=null;pendingCoachAssignments=[];e.currentTarget.reset();$('#coachModal').close();renderCoaches();renderStructure();if(currentRole==='admin')renderClubUsers()};
$('#addCoachAssignment').onclick=()=>addAssignmentFrom('coachAssignment',pendingCoachAssignments,renderCoachAssignments);

$('#openClubUserModal').onclick=()=>{pendingUserAssignments=[];$('#clubUserForm').reset();syncCoachUserFields();$('#clubUserModal').showModal()};$('#closeClubUserModal').onclick=$('#cancelClubUser').onclick=()=>$('#clubUserModal').close();$('#clubUserRole').onchange=syncCoachUserFields;$('#addClubUserAssignment').onclick=()=>addAssignmentFrom('clubUserAssignment',pendingUserAssignments,renderUserAssignments);$('#clubUserForm').onsubmit=e=>{e.preventDefault();if(currentRole!=='admin')return;const fd=new FormData(e.currentTarget),email=String(fd.get('email')).toLowerCase(),role=fd.get('role');let u=users.find(x=>x.email.toLowerCase()===email);if(role==='coach'&&!pendingUserAssignments.length){alert('Añade al menos una asignación de equipo.');return}if(u){u=normalizeUser(u);if(hasRole(u,role)){alert('Esa persona ya tiene ese perfil.');return}u.roles.push(role);u.name=fd.get('name')||u.name;u.active=true;if(role==='coach'){let c=coaches.find(x=>x.userId===u.id);const data={name:u.name,assignments:pendingUserAssignments.map(a=>({...a})),hasLicense:fd.get('hasLicense')==='yes',licenseType:fd.get('licenseType')||'',delegateCourse:fd.get('delegateCourse')==='yes',active:true};if(c)Object.assign(c,data);else coaches.push({id:uid('c'),userId:u.id,...data})}recordAudit('Perfil añadido a persona','',`${u.name} · ${roleLabel(role)}`)}else{const password=fd.get('password');if(!password||String(password).length<6){alert('Para una cuenta nueva indica una contraseña inicial de al menos 6 caracteres.');return}const person={id:uid('person'),name:fd.get('name'),email,dni:'',createdAt:isoToday(),mergedFrom:[]};persons.push(person);u={id:uid('u-person'),personId:person.id,name:fd.get('name'),email,phone:'',password,roles:[role],active:true};users.push(u);if(role==='coach')coaches.push({id:uid('c'),userId:u.id,name:u.name,assignments:pendingUserAssignments.map(a=>({...a})),hasLicense:fd.get('hasLicense')==='yes',licenseType:fd.get('licenseType')||'',delegateCourse:fd.get('delegateCourse')==='yes',active:true});recordAudit('Persona interna creada','',`${u.name} · ${roleLabel(role)}`)}saveUsers();saveCoaches();writeJSON(K.persons,persons);pendingUserAssignments=[];$('#clubUserModal').close();renderClubUsers();renderCoaches()};

$('#openTeamModal').onclick=()=>{if(currentRole!=='admin')return;editingTeamId=null;$('#teamForm').reset();fillTeamCategorySelect();$('#teamModalTitle').textContent='Nuevo equipo';$('#teamModal').showModal()};$('#closeTeamModal').onclick=$('#cancelTeam').onclick=()=>$('#teamModal').close();$('#teamForm').onsubmit=e=>{e.preventDefault();if(currentRole!=='admin')return;const fd=new FormData(e.currentTarget);if(editingTeamId){const t=teams.find(x=>x.id===editingTeamId);Object.assign(t,{name:fd.get('name'),categoryId:fd.get('categoryId'),active:fd.get('active')==='yes'})}else teams.push({id:uid('t'),seasonId:currentSeasonId,name:fd.get('name'),categoryId:fd.get('categoryId'),active:fd.get('active')==='yes'});saveTeams();recordAudit('Equipo actualizado','',fd.get('name'));$('#teamModal').close();renderStructure();renderCoaches()};
$('#openSeasonModal').onclick=()=>{if(currentRole!=='admin')return;$('#seasonForm').reset();$('#seasonModal').showModal()};$('#closeSeasonModal').onclick=$('#cancelSeason').onclick=()=>$('#seasonModal').close();$('#seasonForm').onsubmit=e=>{e.preventDefault();if(currentRole!=='admin')return;const fd=new FormData(e.currentTarget);if(fd.get('endDate')<fd.get('startDate')){alert('La fecha fin no puede ser anterior.');return}seasons.push({id:uid('s'),name:fd.get('name'),startDate:fd.get('startDate'),endDate:fd.get('endDate'),active:true});saveSeasons();recordAudit('Temporada creada','',fd.get('name'));$('#seasonModal').close();renderStructure()};

window.addEventListener('storage',()=>{reload();applyAgeTransitions();if(currentUser)showApp()});
initData();reload();restoreSupabaseSession();

// V26 development update strategy: deliberately disable Service Workers.
// During rapid prototyping, always prefer the current GitHub Pages deployment.
// Existing localStorage application data is intentionally preserved.
async function disableLegacyServiceWorkers(){
  if (!('serviceWorker' in navigator)) return;
  try {
    const registrations = await navigator.serviceWorker.getRegistrations();
    await Promise.all(registrations.map(reg => reg.unregister()));
    if ('caches' in window) {
      const keys = await caches.keys();
      await Promise.all(keys.filter(k => k.startsWith('yebenes-')).map(k => caches.delete(k)));
    }
  } catch (e) {
    console.warn('No se pudo limpiar la caché PWA anterior', e);
  }
}

disableLegacyServiceWorkers();
