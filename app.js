const APP_VERSION='91.2';
const DATA_VERSION='13';
const SUPABASE_URL='https://ypyzochuqtetddffohpv.supabase.co';
const SUPABASE_PUBLISHABLE_KEY='sb_publishable_AZkaUtTojw0Xrxu3dwgkhg_2QFNU1q3';
const sb=window.supabase?.createClient(SUPABASE_URL,SUPABASE_PUBLISHABLE_KEY,{
  auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}
});
const DB_ROLE_TO_APP={administrador:'admin',club:'club',entrenador:'coach',tutor:'family',jugador:'player'};
const DEFAULT_VISUAL_THEME={
  nombre_club:'C.D. Los Yebenes San Bruno',
  logo_url:'https://losyebenessanbruno.es/wp-content/uploads/2023/03/cvncvn.png',
  color_primario:'#c51230',color_primario_oscuro:'#8f0c22',color_acento:'#f4c542',
  color_fondo:'#f5f6f8',color_tarjeta:'#ffffff',color_texto:'#20232a'
};
let visualTheme={...DEFAULT_VISUAL_THEME};
async function loadVisualTheme(){
  if(!sb)return visualTheme;
  try{
    const {data,error}=await sb.from('configuracion_visual_club').select('nombre_club,logo_url,color_primario,color_primario_oscuro,color_acento,color_fondo,color_tarjeta,color_texto').eq('id',1).maybeSingle();
    if(!error&&data)visualTheme={...visualTheme,...data};
  }catch(err){console.warn('Tema visual remoto no disponible',err)}
  const root=document.documentElement;
  root.style.setProperty('--red',visualTheme.color_primario||DEFAULT_VISUAL_THEME.color_primario);
  root.style.setProperty('--red-dark',visualTheme.color_primario_oscuro||DEFAULT_VISUAL_THEME.color_primario_oscuro);
  root.style.setProperty('--yellow',visualTheme.color_acento||DEFAULT_VISUAL_THEME.color_acento);
  root.style.setProperty('--bg',visualTheme.color_fondo||DEFAULT_VISUAL_THEME.color_fondo);
  root.style.setProperty('--card',visualTheme.color_tarjeta||DEFAULT_VISUAL_THEME.color_tarjeta);
  root.style.setProperty('--ink',visualTheme.color_texto||DEFAULT_VISUAL_THEME.color_texto);
  document.querySelectorAll('.auth-brand img,.brand-mark img').forEach(img=>{img.src=visualTheme.logo_url;img.alt=`Escudo ${visualTheme.nombre_club}`});
  document.querySelectorAll('.auth-brand strong,.club-name').forEach(el=>el.textContent=visualTheme.nombre_club);
  const themeMeta=document.querySelector('meta[name="theme-color"]');if(themeMeta)themeMeta.setAttribute('content',visualTheme.color_primario);
  document.title=`${visualTheme.nombre_club} · Gestión de inscripciones`;
  return visualTheme;
}

// Configuración operativa de medios de cobro manual.
// El modelo de datos no se modifica: se conservan capacidades técnicas para futuras formas de pago,
// pero en producción actual solo está habilitado el registro manual en efectivo.
const PAYMENT_FEATURES={
  manualMethods:[
    {value:'efectivo',label:'Efectivo',enabled:true},
    {value:'otro',label:'Otro medio',enabled:false}
  ],
  cluberImportEnabled:false,
  cardPaymentsEnabled:false
};

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
// V51: acceso documental robusto. Se registra al principio para que no dependa
// de la inicialización posterior de controles legacy o de rerenders de Familia.
document.addEventListener('click',e=>{
  const button=e.target.closest?.('.manage-docs, .manage-docs-summary');
  if(!button)return;
  e.preventDefault();
  e.stopPropagation();
  const playerId=button.dataset.id;
  if(playerId&&typeof openDocumentManager==='function') openDocumentManager(playerId);
},true);
const esc=(s='')=>String(s).replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
function normalizedEmailValue(v){return String(v||'').trim().toLowerCase()}
function validateRepeatedEmail(primary,confirm,{required=false}={}){const a=normalizedEmailValue(primary),b=normalizedEmailValue(confirm);if(required&&!a)return 'Indica un correo electrónico.';if(!a&&!b)return '';if(!b)return 'Repite el correo electrónico para verificarlo.';if(a!==b)return 'Los correos electrónicos no coinciden. Escríbelos de nuevo.';return ''}
function blockPasteOnEmailConfirm(root=document){root.querySelectorAll('[data-email-confirm]').forEach(input=>{if(input.dataset.noPasteBound==='1')return;input.dataset.noPasteBound='1';['paste','drop'].forEach(evt=>input.addEventListener(evt,e=>e.preventDefault()))})}

const readJSON=(k,f)=>{try{return JSON.parse(localStorage.getItem(k))??f}catch{return f}};
const writeJSON=(k,v)=>localStorage.setItem(k,JSON.stringify(v));
const isoToday=()=>new Date().toISOString().slice(0,10);
const parseDate=v=>{
  if(!v)return null;
  const raw=String(v).trim();
  let d=null;
  if(/^\d{4}-\d{2}-\d{2}$/.test(raw)){const [y,m,day]=raw.split('-').map(Number);d=new Date(y,m-1,day)}
  else d=new Date(raw);
  return Number.isNaN(d.getTime())?null:d;
};
const fmt=v=>{const d=parseDate(v);return d?new Intl.DateTimeFormat('es-ES').format(d):'—'};
const addYears=(v,n)=>{const d=parseDate(v);if(!d)return '';d.setFullYear(d.getFullYear()+n);return d.toISOString().slice(0,10)};
const addMonths=(v,n)=>{const m=String(v||'').match(/^(\d{4})-(\d{2})-(\d{2})$/);if(!m)return '';const y=Number(m[1]),mo=Number(m[2])-1,day=Number(m[3]);const base=new Date(y,mo+n,1,12,0,0);const last=new Date(base.getFullYear(),base.getMonth()+1,0,12,0,0).getDate();const d=Math.min(day,last);return `${base.getFullYear()}-${String(base.getMonth()+1).padStart(2,'0')}-${String(d).padStart(2,'0')}`};
const dayDiff=(a,b)=>Math.ceil((parseDate(b)-parseDate(a))/86400000);
const ROLE_LABELS={admin:'Administrador',club:'Usuario del club',coach:'Entrenador',family:'Tutor / Familia',player:'Jugador'};
const roleLabel=r=>ROLE_LABELS[r]||r;
const normalizeUser=u=>{if(!u)return u;u.roles=Array.isArray(u.roles)&&u.roles.length?[...new Set(u.roles)]:[u.role||'family'];return u};
const normText=v=>String(v||'').trim().toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/\s+/g,' ');
const normDni=v=>String(v||'').toUpperCase().replace(/[^A-Z0-9]/g,'');
const SPANISH_ID_LETTERS='TRWAGMYFPDXBNJZSQVHLCKE';
function validateSpanishIdentity(type,value,{required=false}={}){
  const t=String(type||'').toLowerCase(),v=normDni(value);
  if(!v)return required?'Indica el DNI/NIE.':'';
  if(!['dni','nie'].includes(t))return '';
  let numberText='',letter='';
  if(t==='dni'){
    if(!/^\d{8}[A-Z]$/.test(v))return 'DNI no válido. Debe tener 8 cifras y una letra.';
    numberText=v.slice(0,8);letter=v.slice(-1);
  }else{
    if(!/^[XYZ]\d{7}[A-Z]$/.test(v))return 'NIE no válido. Debe comenzar por X, Y o Z, seguido de 7 cifras y una letra.';
    const prefix={X:'0',Y:'1',Z:'2'}[v[0]];numberText=prefix+v.slice(1,8);letter=v.slice(-1);
  }
  const expected=SPANISH_ID_LETTERS[Number(numberText)%23];
  if(letter!==expected)return `${t==='dni'?'DNI':'NIE'} no válido: la letra no corresponde al número.`;
  return '';
}
function bindSpanishIdentityValidation(root=document){
  const pairs=[['tutorDocumentType','tutorDni'],['selfDocumentType','selfDni'],['childDocumentType','dni']];
  pairs.forEach(([typeName,numName])=>{
    const type=root.querySelector(`[name="${typeName}"]`),input=root.querySelector(`[name="${numName}"]`);if(!type||!input||input.dataset.spanishIdBound==='1')return;
    input.dataset.spanishIdBound='1';
    const check=()=>{const err=validateSpanishIdentity(type.value,input.value,{required:input.required});input.setCustomValidity(err)};
    input.addEventListener('input',()=>{input.value=normDni(input.value);check()});input.addEventListener('blur',check);type.addEventListener('change',check);
  });
}

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
const coachRoleLabel=v=>v==='first'?'Entrenador principal':v==='second'?'Segundo entrenador':v==='goalkeeper'?'Entrenador de porteros':v==='fitness'?'Preparador físico':String(v||'—');
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
let dbCoachesLoaded=false;
let clubQuickFilter='all',medicalQuickFilter='all';
let dbSeasons=[],dbCategories=[],dbTeams=[],dbCategoryRules=[],dbEconomicConfigs=[],dbPersons=[],dbPersonRoles=[],dbRoleCatalog=[],dbStructureLoaded=false;
let dbCoachFormations=[],dbCoachLicenses=[],dbCoachSeasonRows=[],dbCoachAvailability=[],dbCoachPrivacy=[],dbTeamSchedules=[];
let remoteClubPlayers=[],selectedRemotePlayerId=null;
let selectedEconomicTeamId=null,selectedEconomicPlayerId=null,economicReturnPlayerId=null;
let remoteFamilyPlayers=[];
let editingFromCorrection=false;
let remoteMedicalAppointments=[];
let remoteMedicalRows=[];
const PENDING_SIGNUP_KEY='yebenes-pending-signup-v1';
const AUTH_REDIRECT_URL='https://ansantosci.github.io/Yebenes/';
let selectedPlayerId=null,editingPlayerId=null,selectedMedicalPlayerId=null,editingCoachId=null,selectedCoachPersonId=null,editingTeamId=null,selectedPersonAdminId=null,pendingCoachAssignments=[],pendingUserAssignments=[],pendingMinorConsentAction=null;

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
  await loadSupabaseCoaches();
  if((currentUser.roles||[]).includes('admin')) await loadSupabasePersons();
}
async function loadSupabasePersons(){
  if(!sb||!currentUser||!(currentRole&&['admin','club'].includes(currentRole))&&!(currentUser.roles||[]).some(r=>['admin','club'].includes(r)))return [];
  const [personRes,roleRes,prRes]=await Promise.all([
    sb.from('personas').select('id,auth_user_id,nombre,primer_apellido,segundo_apellido,email_contacto,telefono,fecha_nacimiento,activo').order('primer_apellido',{ascending:true}),
    sb.from('roles').select('id,codigo,nombre'),
    sb.from('persona_roles').select('persona_id,rol_id,fecha_desde,fecha_hasta,activo')
  ]);
  if(personRes.error)throw personRes.error;if(roleRes.error)throw roleRes.error;if(prRes.error)throw prRes.error;
  dbPersons=personRes.data||[];dbRoleCatalog=roleRes.data||[];dbPersonRoles=prRes.data||[];return dbPersons;
}
function remotePersonName(p){return [p?.nombre,p?.primer_apellido,p?.segundo_apellido].filter(Boolean).join(' ')||'Persona'}
function remotePersonRoleCodes(personId){const today=isoToday(),ids=dbPersonRoles.filter(x=>x.persona_id===personId&&x.activo!==false&&(!x.fecha_desde||x.fecha_desde<=today)&&(!x.fecha_hasta||x.fecha_hasta>=today)).map(x=>x.rol_id);return dbRoleCatalog.filter(r=>ids.includes(r.id)).map(r=>r.codigo)}
async function loadSupabaseCoaches(){
  dbCoachesLoaded=false;
  if(!sb||!currentUser)return [];
  const internal=(currentUser.roles||[]).some(r=>['admin','club','coach'].includes(r));
  if(!internal){coaches=[];return []}
  const seasonId=dbActiveSeason()?.id||null;
  const [coachRes,assignmentRes,formationRes,licenseRes,seasonRes,availabilityRes,privacyRes,scheduleRes]=await Promise.all([
    sb.from('entrenadores').select('id,persona_id,activo,licencia_tipo,licencia_numero,curso_delegado,observaciones'),
    sb.from('asignaciones_entrenador_equipo').select('id,entrenador_id,equipo_id,fecha_desde,fecha_hasta,funcion,cancelada_at,motivo_fin'),
    sb.from('entrenador_formaciones').select('id,entrenador_id,tipo,nombre_otro,estado,fecha_inicio,fecha_obtencion,entidad_emisora,numero_acreditacion,fecha_caducidad,verificacion_estado'),
    seasonId?sb.from('entrenador_licencias_rffm').select('id,entrenador_id,temporada_id,tipo,nombre_otro,numero,fecha_expedicion,fecha_caducidad,estado_excepcional,verificacion_estado').eq('temporada_id',seasonId):Promise.resolve({data:[],error:null}),
    seasonId?sb.from('entrenador_temporadas').select('entrenador_id,temporada_id,estado,disponibilidad_confirmada_at').eq('temporada_id',seasonId):Promise.resolve({data:[],error:null}),
    seasonId?sb.from('entrenador_disponibilidad').select('entrenador_id,temporada_id,dia_semana,tipo,hora_desde,hora_hasta').eq('temporada_id',seasonId):Promise.resolve({data:[],error:null}),
    sb.from('entrenador_privacidad').select('entrenador_id,compartir_email,compartir_telefono,compartir_foto'),
    seasonId?sb.from('horarios_equipo').select('id,equipo_id,dia_semana,hora_inicio,hora_fin,activo').eq('activo',true):Promise.resolve({data:[],error:null})
  ]);
  for(const r of [coachRes,assignmentRes,formationRes,licenseRes,seasonRes,availabilityRes,privacyRes,scheduleRes])if(r?.error)throw r.error;
  dbCoachFormations=formationRes.data||[];dbCoachLicenses=licenseRes.data||[];dbCoachSeasonRows=seasonRes.data||[];dbCoachAvailability=availabilityRes.data||[];dbCoachPrivacy=privacyRes.data||[];dbTeamSchedules=scheduleRes.data||[];
  const personIds=[...new Set((coachRes.data||[]).map(x=>x.persona_id).filter(Boolean))];
  let personRows=[],consentRows=[],medicalRows=[],playerRows=[];
  if(personIds.length){
    const [pr,mr,jr]=await Promise.all([
      sb.from('personas').select('id,auth_user_id,nombre,primer_apellido,segundo_apellido,email_contacto,telefono,fecha_nacimiento,activo').in('id',personIds),
      sb.from('reconocimientos_medicos').select('id,persona_id,jugador_id,fecha_reconocimiento,fecha_valido_hasta,fecha_validacion_rffm').in('persona_id',personIds).order('fecha_reconocimiento',{ascending:false}),
      sb.from('jugadores').select('id,persona_id,activo').in('persona_id',personIds)
    ]);
    if(pr.error)throw pr.error;if(mr.error)throw mr.error;if(jr.error)throw jr.error;
    personRows=pr.data||[];medicalRows=mr.data||[];playerRows=jr.data||[];
  }
  if(personIds.length&&['admin','club'].includes(currentRole)){
    const {data,error}=await sb.from('autorizaciones_menor').select('persona_menor_id,estado,fecha_desde,fecha_hasta,version_texto').in('persona_menor_id',personIds).eq('tipo','entrenador_menor');
    if(error)console.warn('No se pudo cargar el estado de autorizaciones de entrenadores menores',error);else consentRows=data||[];
  }
  const pm=new Map(personRows.map(x=>[x.id,x]));
  const consentMap=new Map(),consentPriority={aceptada:4,pendiente:3,pendiente_email:2,revocada:1,rechazada:1,finalizada_mayoria_edad:1};
  for(const a of consentRows){const prev=consentMap.get(a.persona_menor_id);if(!prev||(consentPriority[a.estado]||0)>(consentPriority[prev.estado]||0))consentMap.set(a.persona_menor_id,a)}
  const today=isoToday();
  const validLicense=l=>l.verificacion_estado==='verificada'&&!l.estado_excepcional&&(!l.fecha_caducidad||l.fecha_caducidad>=today);
  coaches=(coachRes.data||[]).map(c=>{
    const person=pm.get(c.persona_id)||{};
    const assignments=(assignmentRes.data||[]).filter(a=>a.entrenador_id===c.id&&!a.cancelada_at).map(a=>({id:a.id,teamId:a.equipo_id,coachRole:a.funcion||'first',startDate:a.fecha_desde||'',endDate:a.fecha_hasta||'',cancelledAt:a.cancelada_at||null,endReason:a.motivo_fin||''}));
    const isMinor=!!person.fecha_nacimiento&&person.fecha_nacimiento>new Date(new Date().setFullYear(new Date().getFullYear()-18)).toISOString().slice(0,10);
    const consent=consentMap.get(c.persona_id)||null;
    const formations=dbCoachFormations.filter(x=>x.entrenador_id===c.id);
    const licenses=dbCoachLicenses.filter(x=>x.entrenador_id===c.id);
    const validLicenses=licenses.filter(validLicense);
    const delegate=formations.find(x=>x.tipo==='delegado'&&x.estado==='vigente'&&x.verificacion_estado==='verificada');
    const delegateInProgress=formations.some(x=>x.tipo==='delegado'&&x.estado==='en_curso');
    const technical=formations.filter(x=>['uefa_c','uefa_b','uefa_a','uefa_pro','tecnico_deportivo','tecnico_deportivo_superior'].includes(x.tipo)&&x.estado==='vigente');
    const inProgress=formations.filter(x=>x.estado==='en_curso');
    const latestMedical=medicalRows.find(x=>x.persona_id===c.persona_id)||null;
    const medState=medicalState(latestMedical?{date:latestMedical.fecha_reconocimiento,expiry:latestMedical.fecha_valido_hasta}:null);
    const seasonRow=dbCoachSeasonRows.find(x=>x.entrenador_id===c.id)||null;
    const hasCurrentAssignment=assignments.some(a=>assignmentState(a)==='active'&&(!seasonId||dbTeams.find(t=>t.id===a.teamId)?.seasonId===seasonId));
    const seasonState=!c.activo?'baja':hasCurrentAssignment?'activo':'sin_asignacion';
    const benchLicensed=validLicenses.length>0;
    const minorOk=!isMinor||consent?.estado==='aceptada';
    const benchState=benchLicensed&&minorOk?'acreditada':(validLicenses.length||delegate||delegateInProgress||technical.length||inProgress.length)?'pendiente':'sin_habilitacion';
    return {id:c.id,personId:c.persona_id,userId:person.auth_user_id||null,name:[person.nombre,person.primer_apellido,person.segundo_apellido].filter(Boolean).join(' ')||'Entrenador',firstName:person.nombre||'',lastName1:person.primer_apellido||'',lastName2:person.segundo_apellido||'',email:person.email_contacto||'',phone:person.telefono||'',birth:person.fecha_nacimiento||'',isMinor,minorConsentStatus:consent?.estado||null,minorConsentVersion:consent?.version_texto||null,assignments,hasLicense:validLicenses.length>0,licenseType:validLicenses.map(x=>x.tipo).join(', '),licenseNumber:validLicenses.map(x=>x.numero).filter(Boolean).join(', '),delegateCourse:!!delegate,delegateInProgress,formations,licenses,validLicenses,technicalFormations:technical,trainingInProgress:inProgress,medical:latestMedical,medicalState:medState,seasonState,availabilityConfirmed:!!seasonRow?.disponibilidad_confirmada_at,availabilityConfirmedAt:seasonRow?.disponibilidad_confirmada_at||null,availability:dbCoachAvailability.filter(x=>x.entrenador_id===c.id),benchState,isPlayer:playerRows.some(x=>x.persona_id===c.persona_id&&x.activo!==false),legacyLicenseType:c.licencia_tipo||'',legacyLicenseNumber:c.licencia_numero||'',legacyDelegateCourse:c.curso_delegado===true,legacyNotes:c.observaciones||'',active:c.activo!==false};
  });
  dbCoachesLoaded=true;
  return coaches;
}
function coachFormationLabel(f){const labels={delegado:'Curso de Delegado',uefa_c:'UEFA C',uefa_b:'UEFA B',uefa_a:'UEFA A',uefa_pro:'UEFA PRO',tecnico_deportivo:'Técnico Deportivo',tecnico_deportivo_superior:'Técnico Deportivo Superior',otra:f?.nombre_otro||'Otra'};return labels[f?.tipo]||f?.tipo||'—'}
function coachBenchLabel(c){return c?.benchState==='acreditada'?'Habilitación acreditada':c?.benchState==='pendiente'?'Pendiente de acreditar licencia RFFM':'Sin habilitación registrada'}
function coachBenchReason(c){if(c?.benchState==='acreditada')return c.validLicenses?.length?`Licencia RFFM vigente: ${c.validLicenses.map(x=>x.tipo).join(', ')}`:'Vía habilitante vigente';if(c?.benchState==='pendiente'){if(c.delegateCourse)return 'Curso de Delegado verificado · Sin licencia federativa vigente en la temporada activa';if(c.delegateInProgress)return 'Curso de Delegado en curso · Sin licencia federativa vigente';if(c.technicalFormations?.length)return 'Titulación técnica registrada · Sin licencia federativa vigente en la temporada activa';return 'Existe información formativa pendiente de completar con una licencia RFFM vigente'}return 'No consta una vía habilitante federativa vigente'}
function coachBenchClass(c){return c?.benchState==='acreditada'?'complete':c?.benchState==='pendiente'?'pending':'returned'}
function coachMinorConsentBadge(c){
  if(!c?.isMinor)return '';
  if(c.minorConsentStatus==='aceptada')return '<div class="meta"><span class="status complete">Autorización tutor: vigente</span></div>';
  if(c.minorConsentStatus==='pendiente')return '<div class="meta"><span class="status pending">Autorización tutor: pendiente</span></div>';
  return '<div class="meta"><span class="status returned">Autorización tutor: no vigente</span></div>';
}
function renderCoachMinorConsentPanel(){
  const el=$('#coachMinorConsentPanel');if(!el)return;
  const c=coaches.find(x=>x.id===editingCoachId);
  if(!c?.isMinor){el.hidden=true;el.innerHTML='';return}
  const status=c.minorConsentStatus||'sin_solicitud';
  let badge='<span class="status returned">No vigente</span>',detail='El tutor debe autorizar expresamente la actividad como entrenador antes de poder añadir asignaciones.',action='';
  if(status==='aceptada'){badge='<span class="status complete">Vigente</span>';detail='La autorización del tutor está vigente. Se pueden gestionar asignaciones deportivas.'}
  else if(status==='pendiente'){badge='<span class="status pending">Pendiente</span>';detail='La solicitud ya ha sido enviada al tutor. Hasta que la autorice no se pueden añadir asignaciones.'}
  else if(status==='pendiente_email'){badge='<span class="status pending">Pendiente de correo</span>';detail='Antes de solicitar el consentimiento, el tutor debe informar un correo propio del menor desde Familia > Datos.'}
  else if(['club','admin'].includes(currentRole)){action='<button type="button" class="secondary small" id="requestMinorCoachConsent">Solicitar nueva autorización</button>'}
  const label={pendiente_email:'Pendiente de correo propio',revocada:'Revocada',rechazada:'Rechazada',finalizada_mayoria_edad:'Finalizada por mayoría de edad',sin_solicitud:'No solicitada'}[status]||status;
  el.hidden=false;
  el.className='workflow-box compact-consent';
  el.innerHTML=`<span class="eyebrow dark">Autorización de entrenador menor</span><div class="checklist"><div class="check"><span>Estado</span><strong>${badge}</strong></div>${status!=='aceptada'&&status!=='pendiente'?`<div class="check"><span>Último estado</span><strong>${esc(label)}</strong></div>`:''}</div><p class="meta">${esc(detail)}</p>${action}`;
  const b=$('#requestMinorCoachConsent');if(b)b.onclick=requestMinorCoachConsent;
}
async function requestMinorCoachConsent(){
  const c=coaches.find(x=>x.id===editingCoachId);if(!c?.personId||!sb)return;
  const b=$('#requestMinorCoachConsent');if(b){b.disabled=true;b.textContent='Solicitando…'}
  try{
    const {error}=await sb.rpc('solicitar_autorizacion_entrenador_menor',{p_persona_id:c.personId});
    if(error)throw error;
    await loadSupabaseCoaches();
    renderCoaches();
    renderCoachMinorConsentPanel();
    const fresh=coaches.find(x=>x.id===editingCoachId);
    setCoachAssignmentGuard(fresh?.minorConsentStatus==='pendiente_email'?'El tutor debe informar primero un correo propio del menor. La solicitud de autorización quedará disponible automáticamente después.':'Solicitud enviada al tutor. Hasta que la autorice no se podrán añadir asignaciones.','info');
  }catch(err){setCoachAssignmentGuard(`No se ha podido solicitar la autorización del tutor: ${err.message||err}`)}
  finally{const x=$('#requestMinorCoachConsent');if(x){x.disabled=false;x.textContent='Solicitar nueva autorización'}}
}
async function ensureMinorCoachAssignmentAllowed(personId){
  if(!personId||!sb)return true;
  let p=dbPersons.find(x=>x.id===personId);
  if(!p){const {data,error}=await sb.from('personas').select('id,fecha_nacimiento').eq('id',personId).maybeSingle();if(error)throw error;p=data}
  const birth=p?.fecha_nacimiento||p?.birth||'';
  if(!birth)return true;
  const d=new Date();d.setFullYear(d.getFullYear()-18);const cutoff=d.toISOString().slice(0,10);
  if(birth<=cutoff)return true;
  const {data,error}=await sb.from('autorizaciones_menor').select('id,estado,fecha_desde,fecha_hasta').eq('persona_menor_id',personId).eq('tipo','entrenador_menor').eq('estado','aceptada').maybeSingle();
  if(error)throw error;
  const today=isoToday();return !!data&&(!data.fecha_desde||data.fecha_desde<=today)&&(!data.fecha_hasta||data.fecha_hasta>=today);
}
function coachTeamName(id){return dbStructureLoaded?(dbTeams.find(t=>t.id===id)?.name||'—'):teamName(id)}
function coachTeamCategoryId(id){return dbStructureLoaded?dbTeams.find(t=>t.id===id)?.categoryId:teams.find(t=>t.id===id)?.categoryId}
function dbActiveSeason(){return dbSeasons.find(s=>s.status==='activa')||dbSeasons[0]||null}
function dbCategoryName(id){return dbCategories.find(c=>c.id===id)?.name||'—'}
function categoryAgeOrder(categoryId,remote=dbStructureLoaded){
  if(remote){
    const c=dbCategories.find(x=>x.id===categoryId);
    return Number.isFinite(Number(c?.order))?Number(c.order):9999;
  }
  const ix=categories.findIndex(x=>x.id===categoryId);
  return ix>=0?ix:9999;
}
function sortTeamsByCategoryAge(list,remote=dbStructureLoaded){
  return [...list].sort((a,b)=>{
    const catDiff=categoryAgeOrder(a.categoryId,remote)-categoryAgeOrder(b.categoryId,remote);
    if(catDiff!==0)return catDiff;
    return String(a.name||'').localeCompare(String(b.name||''),'es',{numeric:true,sensitivity:'base'});
  });
}
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
  const pending=pendingSignupFor(authUser?.email);
  if(pending){
    await registerProfileFromPayload(pending);
  }
  return await loadSupabaseIdentity(authUser);
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
  const {data:personRows,error:personErr}=personIds.length?await sb.from('personas').select('id,nombre,primer_apellido,segundo_apellido,fecha_nacimiento,email_contacto,telefono').in('id',personIds):{data:[],error:null};
  if(personErr)throw personErr;
  let childIdentityRows=[];if(personIds.length){const dr=await sb.from('documentos_identidad').select('id,persona_id,tipo,numero,es_principal,activo,created_at').in('persona_id',personIds).eq('activo',true).order('created_at',{ascending:false});if(!dr.error)childIdentityRows=dr.data||[];}
  const season=dbActiveSeason();
  let insRows=[];
  if(season){const res=await sb.from('inscripciones').select('id,jugador_id,temporada_id,categoria_id,fecha_solicitud,estado,observaciones').in('jugador_id',playerIds).eq('temporada_id',season.id);if(res.error)throw res.error;insRows=res.data||[];}
  const insIds=insRows.map(x=>x.id);
  let assignRows=[];
  if(insIds.length){const res=await sb.from('asignaciones_jugador_equipo').select('inscripcion_id,equipo_id,fecha_desde,fecha_hasta').in('inscripcion_id',insIds);if(res.error)throw res.error;assignRows=res.data||[];}
  let reqRows=[],fedDocRows=[];
  if(insIds.length){
    const rr=await sb.from('requisitos_federativos_inscripcion').select('id,inscripcion_id,codigo,nombre,obligatorio,requiere_archivo,estado,current_documento_id,motivo_rechazo,revisado_at,nueva_version_solicitada_at,motivo_nueva_version,declarado_realizado_at,declarado_realizado_por').in('inscripcion_id',insIds).order('created_at',{ascending:true});if(rr.error)throw rr.error;reqRows=rr.data||[];
    const dr=await sb.from('documentos_federativos').select('id,requisito_id,inscripcion_id,storage_path,nombre_original,mime_type,subtipo,estado,motivo_rechazo,aportado_at,revisado_at').in('inscripcion_id',insIds).order('aportado_at',{ascending:false});if(dr.error)throw dr.error;fedDocRows=dr.data||[];
  }
  let medicalRows=[];{const res=await sb.from('reconocimientos_medicos').select('id,jugador_id,fecha_reconocimiento,fecha_valido_hasta,fecha_validacion_rffm,created_at').in('jugador_id',playerIds).order('fecha_reconocimiento',{ascending:false});if(!res.error)medicalRows=res.data||[];}
  let appointmentRows=[];{const res=await sb.from('citas_reconocimiento_medico').select('id,jugador_id,fecha_hora,lugar,direccion,indicaciones,estado,comunicada_at').in('jugador_id',playerIds).eq('estado','programada').order('fecha_hora',{ascending:true});if(!res.error)appointmentRows=res.data||[];}
  let economicRows=[],familyEconomicConfigs=[];if(insIds.length){const er=await sb.from('situacion_economica_inscripcion').select('inscripcion_id,configuracion_id,equipo_id,importe_total,importe_pagado,estado_economico,fraccionamiento_clubber_validado,fecha_validacion_fraccionamiento,apto_para_ficha').in('inscripcion_id',insIds);if(!er.error)economicRows=er.data||[];const cfgIds=[...new Set((economicRows||[]).map(x=>x.configuracion_id).filter(Boolean))];if(cfgIds.length){const cr=await sb.from('configuracion_economica_equipo').select('id,importe_inscripcion,admite_fraccionamiento,requiere_pago_ficha').in('id',cfgIds);if(!cr.error)familyEconomicConfigs=cr.data||[];}}
  const personsById=new Map((personRows||[]).map(x=>[x.id,x]));
  const identityByPerson=new Map();for(const d of childIdentityRows){if(!identityByPerson.has(d.persona_id)||d.es_principal)identityByPerson.set(d.persona_id,d)}
  const insByPlayer=new Map(insRows.map(x=>[x.jugador_id,x]));
  const today=isoToday();
  remoteFamilyPlayers=(playerRows||[]).map(p=>{
    const person=personsById.get(p.persona_id)||{};const ins=insByPlayer.get(p.id)||null;
    const assignment=ins?assignRows.filter(a=>a.inscripcion_id===ins.id&&(!a.fecha_desde||a.fecha_desde<=today)&&(!a.fecha_hasta||a.fecha_hasta>=today)).sort((a,b)=>String(b.fecha_desde||'').localeCompare(String(a.fecha_desde||'')))[0]:null;
    const team=assignment?dbTeams.find(t=>t.id===assignment.equipo_id):null;
    const isAdult=!!person.fecha_nacimiento&&ageOn(person.fecha_nacimiento)>=18;const requirements=ins?reqRows.filter(r=>r.inscripcion_id===ins.id&&!(isAdult&&r.codigo==='autorizacion_tutor')):[];
    const fedDocs=ins?fedDocRows.filter(d=>d.inscripcion_id===ins.id):[];
    const docsComplete=requirements.length>0&&requirements.filter(r=>r.obligatorio).every(r=>r.estado==='validado');
    const appointment=appointmentRows.find(a=>a.jugador_id===p.id&&new Date(a.fecha_hora)>=new Date())||null;const medical=(medicalRows||[]).filter(m=>m.jugador_id===p.id).sort((a,b)=>String(b.fecha_reconocimiento||'').localeCompare(String(a.fecha_reconocimiento||'')))[0]||null;const economic=ins?economicRows.find(e=>e.inscripcion_id===ins.id)||null:null;const economicConfig=economic?(familyEconomicConfigs.find(c=>c.id===economic.configuracion_id)||{importe_inscripcion:economic.importe_total,requiere_pago_ficha:true,admite_fraccionamiento:true}):null;const identity=identityByPerson.get(p.persona_id)||null;return {id:p.id,personId:p.persona_id,name:[person.nombre,person.primer_apellido,person.segundo_apellido].filter(Boolean).join(' '),birth:person.fecha_nacimiento||'',playerEmail:person.email_contacto||'',playerPhone:person.telefono||'',childDocumentType:identity?.tipo||'',childDocumentNumber:identity?.numero||'',active:p.activo!==false,inscription:ins,categoryName:ins?dbCategoryName(ins.categoria_id):'—',teamName:team?.name||'Sin equipo',assignment,appointment,medical,requirements,fedDocs,economic,economicConfig,docsLabel:docsComplete?'Completa':requirements.some(r=>r.estado==='rechazado'||r.estado==='nueva_version_solicitada')?'Revisar':requirements.some(r=>['aportado','declarado_realizado'].includes(r.estado))?'En revisión':'Pendiente'};
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
function remotePlayerIsAdult(v){return !!v?.birth&&ageOn(v.birth)>=18}
function remotePlayerStateLabel(v,state=v?.inscription?.estado){if(state==='devuelta_familia'&&remotePlayerIsAdult(v)&&!v?.representation)return 'Correcciones solicitadas';return remoteStateLabel(state)}
function workflowPrimaryMeta(v){
  const state=v?.inscription?.estado||'pendiente_revision_inicial';
  if(state==='pendiente_revision_inicial'||state==='devuelta_familia')return {label:'✓ Validar datos personales',text:'Revisa los datos personales. Si son correctos, valídalos para continuar con la preparación de la ficha.'};
  if(state==='datos_validados')return {label:'✓ Confirmar documentación',text:'Los datos personales ya están validados. Confirma la documentación cuando todos los requisitos aplicables estén revisados.'};
  if(state==='documentacion_validada')return {label:'✓ Marcar listo para federar',text:'Comprueba equipo, reconocimiento médico y situación económica antes de marcar la ficha como lista para federar.'};
  if(state==='lista_para_federar')return {label:'✓ Marcar ficha tramitada',text:'La ficha cumple los requisitos implantados. Confirma cuando la tramitación federativa haya finalizado.'};
  return {label:'Ficha tramitada',text:'La ficha ya está marcada como tramitada.'};
}
function remoteStateIsComplete(state){return ['lista_para_federar','ficha_tramitada'].includes(state)}
function remoteStateProgress(state){return ({pendiente_revision_inicial:25,devuelta_familia:25,datos_validados:50,documentacion_validada:70,lista_para_federar:90,ficha_tramitada:100,cancelada:0})[state]??0}
let familyMinorCoachConsents=[];
function familyCoachConsentsFor(personId){return familyMinorCoachConsents.filter(x=>x.persona_menor_id===personId)}
function familyCoachConsentHtml(p){
  const rows=familyCoachConsentsFor(p.personId);
  if(!rows.length)return '';
  const waitingEmail=rows.find(x=>x.estado==='pendiente_email');
  const pending=rows.find(x=>x.estado==='pendiente');
  const active=rows.find(x=>x.estado==='aceptada');
  const history=rows.filter(x=>!['pendiente_email','pendiente','aceptada'].includes(x.estado));
  const historyLabel={rechazada:'Rechazada',revocada:'Revocada',finalizada_mayoria_edad:'Finalizada por mayoría de edad'};
  if(waitingEmail)return `<section class="workflow-box compact-consent"><span class="eyebrow dark">Actividad como entrenador</span><div class="family-alert"><strong>Falta correo propio del jugador</strong><p>Para continuar con la autorización de ${esc(p.name)} como entrenador menor, informa primero un correo propio en esta ficha.</p><button type="button" class="primary small edit-remote-family" data-id="${esc(p.id)}">Informar correo</button></div>${history.length?`<details class="workflow-history"><summary>Histórico (${history.length})</summary>${history.map(a=>`<div class="check"><span>${fmt(a.respondida_at||a.fecha_hasta||a.solicitada_at)}</span><strong>${esc(historyLabel[a.estado]||a.estado)}</strong></div>`).join('')}</details>`:''}</section>`;
  if(pending)return `<section class="workflow-box compact-consent"><span class="eyebrow dark">Actividad como entrenador</span><div class="family-alert"><strong>Autorización pendiente</strong><p>El club solicita tu autorización para que ${esc(p.name)} pueda desempeñar funciones de entrenador mientras sea menor de edad.</p><div class="workflow-actions"><button type="button" class="primary small minor-coach-consent" data-id="${esc(pending.id)}" data-name="${esc(p.name)}" data-action="accept">Autorizar</button><button type="button" class="secondary small minor-coach-consent" data-id="${esc(pending.id)}" data-name="${esc(p.name)}" data-action="reject">Rechazar</button></div></div>${history.length?`<details class="workflow-history"><summary>Histórico (${history.length})</summary>${history.map(a=>`<div class="check"><span>${fmt(a.respondida_at||a.fecha_hasta||a.solicitada_at)}</span><strong>${esc(historyLabel[a.estado]||a.estado)}</strong></div>`).join('')}</details>`:''}</section>`;
  if(active)return `<section class="workflow-box compact-consent"><span class="eyebrow dark">Actividad como entrenador</span><div class="checklist"><div class="check"><span>Autorización del tutor</span><strong class="status complete">Vigente</strong></div><div class="check"><span>Desde</span><strong>${fmt(active.fecha_desde||active.respondida_at||'')}</strong></div></div><button type="button" class="secondary small minor-coach-consent" data-id="${esc(active.id)}" data-name="${esc(p.name)}" data-action="revoke">Revocar autorización</button>${history.length?`<details class="workflow-history"><summary>Histórico (${history.length})</summary>${history.map(a=>`<div class="check"><span>${fmt(a.respondida_at||a.fecha_hasta||a.solicitada_at)}</span><strong>${esc(historyLabel[a.estado]||a.estado)}</strong></div>`).join('')}</details>`:''}</section>`;
  return history.length?`<section class="workflow-box compact-consent"><span class="eyebrow dark">Actividad como entrenador</span><div class="meta">No hay una autorización vigente.</div><details class="workflow-history" open><summary>Histórico (${history.length})</summary>${history.map(a=>`<div class="check"><span>${fmt(a.respondida_at||a.fecha_hasta||a.solicitada_at)}</span><strong>${esc(historyLabel[a.estado]||a.estado)}</strong></div>`).join('')}</details></section>`:'';
}
async function loadFamilyMinorCoachConsents(){
  familyMinorCoachConsents=[];
  if(currentRole!=='family'||!currentUser?.personId)return;
  const {data,error}=await sb.from('autorizaciones_menor').select('id,persona_menor_id,tutor_persona_id,tipo,estado,solicitada_at,respondida_at,fecha_desde,fecha_hasta,version_texto,motivo').eq('tutor_persona_id',currentUser.personId).eq('tipo','entrenador_menor').order('solicitada_at',{ascending:false});
  if(error){console.warn('No se pudieron cargar autorizaciones de entrenador menor',error);return}
  familyMinorCoachConsents=data||[];
}
function bindMinorCoachConsentButtons(root=document){root.querySelectorAll('.minor-coach-consent').forEach(b=>b.onclick=()=>openMinorCoachConsentDialog(b.dataset.id,b.dataset.name,b.dataset.action))}
function setFamilyProgress(value){const ring=document.querySelector('.progress-ring');const pct=Math.max(0,Math.min(100,Math.round(Number(value)||0)));if(ring){ring.style.setProperty('--p',pct);const span=ring.querySelector('span');if(span)span.textContent=`${pct}%`}}
function familyAttentionFor(p){
  const rows=familyCoachConsentsFor(p.personId),age=ageOn(p.birth),d18=p.birth?dayDiff(isoToday(),addYears(p.birth,18)):null;
  const items=[];
  if(rows.some(x=>x.estado==='pendiente_email'))items.push({kind:'email',text:'Falta correo propio para continuar con su autorización como entrenador.'});
  if(rows.some(x=>x.estado==='pendiente'))items.push({kind:'consent',text:'Autorización de entrenador pendiente de revisar.'});
  if(rows.some(x=>x.estado==='aceptada')&&!p.playerEmail)items.push({kind:'email',text:'Este entrenador menor necesita un correo propio del jugador.'});
  if(age!==null&&age>=16&&age<18&&!p.playerEmail)items.push({kind:'email',text:'A partir de los 16 años es obligatorio informar un correo propio del jugador.'});
  if(age!==null&&age>=14&&age<18&&!p.childDocumentNumber)items.push({kind:'document',text:'A partir de los 14 años es obligatorio informar el DNI/NIE propio del jugador.'});
  if(d18!==null&&d18>=0&&d18<=90)items.push({kind:'adult',text:d18===0?'Cumple 18 años hoy. Revisa el correo propio y la transición a gestión autónoma.':`Cumple 18 años en ${d18} días. Revisa que el correo propio sea correcto.`});
  return items;
}
function renderFamilyActionBanner(){
  const box=$('#familyActionBanner');if(!box)return;
  if(currentRole!=='family'){box.classList.add('hidden');box.innerHTML='';return}
  const entries=remoteFamilyPlayers.flatMap(p=>{const seen=new Set();return familyAttentionFor(p).filter(x=>{const k=x.kind; if(seen.has(k))return false;seen.add(k);return true}).map(x=>({...x,player:p}))});
  if(!entries.length){box.classList.add('hidden');box.innerHTML='';return}
  box.classList.remove('hidden');
  box.innerHTML=`<div class="family-action-head"><div><strong>⚠ ${entries.length} ${entries.length===1?'acción pendiente':'acciones pendientes'}</strong><span>Hay información que requiere tu atención.</span></div></div><div class="family-action-list">${entries.map((e,i)=>`<button type="button" class="family-action-item" data-player="${esc(e.player.id)}"><span><strong>${esc(e.player.name)}</strong><small>${esc(e.text)}</small></span><b>Revisar →</b></button>`).join('')}</div>`;
  box.querySelectorAll('.family-action-item').forEach(b=>b.onclick=()=>focusFamilyPlayerData(b.dataset.player));
}
function focusFamilyPlayerData(playerId){
  const card=document.querySelector(`.player-card[data-family-player="${CSS.escape(playerId)}"]`);if(!card)return;
  const tab=card.querySelector('[data-family-card-tab="data"]');if(tab)tab.click();card.scrollIntoView({behavior:'smooth',block:'center'});
}
function familyPlayerTabbedCard(p){
  const i=p.inscription;if(!i)return `<article class="player-card"><div class="row"><div><h3>${esc(p.name)}</h3><div class="meta">Sin inscripción en la temporada activa</div></div><span class="status pending">Pendiente</span></div></article>`;
  const [cls,badge]=remoteStateMeta(i.estado),fed=remotePlayerStateLabel(p,i.estado),returned=i.estado==='devuelta_familia';
  const docs=federationDocsProgress(p),m=medicalState(p.medical?{date:p.medical.fecha_reconocimiento,expiry:p.medical.fecha_valido_hasta}:null),econ=economicState(p),attention=familyAttentionFor(p);
  const dataAlert=returned||attention.length>0;
  const docsAlert=(p.requirements||[]).some(r=>['pendiente','aportado','declarado_realizado','rechazado','nueva_version_solicitada'].includes(r.estado)),medicalBlock=!['ok','soon'].includes(m.key),medicalWarn=m.key==='soon',insBlock=returned||!econ.ok,insWarn=!returned&&econ.ok&&!!econ.warning;
  return `<article class="player-card ${returned?'needs-action':''}" data-family-player="${esc(p.id)}"><div class="row"><div><h3>${esc(p.name)}</h3><div class="meta">${esc(p.categoryName)} · ${esc(dbActiveSeason()?.name||'')}</div></div><span class="status ${cls}">${esc(badge)}</span></div><div class="meta representation-line">${currentRole==='player'?'Autorrepresentación':'Tutor activo: '+esc(currentUser.name)}</div>
  <nav class="family-card-tabs" aria-label="Secciones de ${esc(p.name)}"><button class="family-card-tab active" type="button" data-family-card-tab="summary">Resumen</button><button class="family-card-tab" type="button" data-family-card-tab="data">Datos${dataAlert?' <span class="family-tab-alert">!</span>':''}</button><button class="family-card-tab" type="button" data-family-card-tab="docs">Documentos${docsAlert?' <span class="family-tab-alert">!</span>':''}</button><button class="family-card-tab" type="button" data-family-card-tab="medical">RRMM${medicalBlock?' <span class="family-tab-alert">!</span>':medicalWarn?' <span class="family-tab-alert amber">!</span>':''}</button><button class="family-card-tab" type="button" data-family-card-tab="inscription">Inscripción${insBlock?' <span class="family-tab-alert">!</span>':insWarn?' <span class="family-tab-alert amber">!</span>':''}</button></nav>
  <div class="family-card-panel active" data-family-card-panel="summary">${returned?`<div class="family-alert"><strong>El club solicita cambios</strong><p>${esc(i.observaciones||'Revisa la información de la ficha.')}</p><button class="primary small ${currentRole==='player'?'edit-self-player':'edit-remote-family'}" data-id="${esc(p.id)}">Revisar y modificar</button></div>`:''}${attention.length?`<div class="family-attention-note"><strong>⚠ Requiere atención</strong><span>${esc(attention[0].text)}</span></div>`:''}<div class="checklist"><div class="check"><span>Datos personales</span><strong>✓</strong></div><div class="check"><span>Documentación</span><strong>${docs.pct}% · ${docs.valid}/${docs.total}</strong></div><div class="check"><span>RRMM</span><strong>${['ok','soon'].includes(m.key)?(m.key==='soon'?'⚠ '+m.label:'✓ Vigente'):(m.key==='expired'?'✕ Vencido':'✕ Pendiente')}</strong></div><div class="check"><span>Equipo</span><strong>${esc(p.teamName)}</strong></div><div class="check"><span>Pago inscripción</span><strong>${econ.ok?'✓ '+esc(econ.label):'✕ '+esc(econ.label)}</strong></div><div class="check"><span>Federación</span><strong>${esc(fed)}</strong></div></div></div>
  <div class="family-card-panel" data-family-card-panel="data"><div class="checklist"><div class="check"><span>Jugador</span><strong>${esc(p.name)}</strong></div><div class="check"><span>Fecha de nacimiento</span><strong>${fmt(p.birth)}</strong></div><div class="check"><span>Correo propio</span><strong>${p.playerEmail?esc(p.playerEmail):'<span class="status pending">No informado</span>'}</strong></div><div class="check"><span>Teléfono</span><strong>${p.playerPhone?esc(p.playerPhone):'—'}</strong></div><div class="check"><span>DNI/NIE</span><strong>${p.childDocumentNumber?esc(String(p.childDocumentType||'').toUpperCase()+' · '+p.childDocumentNumber):'—'}</strong></div><div class="check"><span>Categoría</span><strong>${esc(p.categoryName)}</strong></div><div class="check"><span>Representación</span><strong>${currentRole==='player'?'Autorrepresentación':esc(currentUser.name)}</strong></div></div>${familyCoachConsentHtml(p)}${currentRole==='player'?`<button class="secondary small edit-self-player" data-id="${esc(p.id)}">Modificar mis datos</button>`:''}${currentRole==='family'?`<button class="${dataAlert?'primary':'secondary'} small edit-remote-family" data-id="${esc(p.id)}">${p.playerEmail?'Modificar datos / correo':'Informar correo y revisar datos'}</button>`:''}</div>
  <div class="family-card-panel" data-family-card-panel="docs">${federationProgressHtml(p,true)}<div class="card-actions"><button type="button" class="secondary small manage-docs" data-id="${esc(p.id)}" aria-disabled="false" onclick="openDocumentManager(this.dataset.id)">Gestionar documentación</button></div></div>
  <div class="family-card-panel" data-family-card-panel="medical"><div class="checklist"><div class="check"><span>Estado RRMM</span><strong>${esc(m.label)}</strong></div>${p.medical?`<div class="check"><span>Válido hasta</span><strong>${fmt(p.medical.fecha_valido_hasta)}</strong></div>`:''}</div>${p.appointment?`<div class="appointment-family"><strong>📅 Próximo reconocimiento médico</strong><div>${esc(formatDateTime(p.appointment.fecha_hora))}</div><div>${esc(p.appointment.lugar||'')}</div>${p.appointment.direccion?`<div>${esc(p.appointment.direccion)}</div>`:''}${p.appointment.indicaciones?`<div class="meta">${esc(p.appointment.indicaciones)}</div>`:''}</div>`:'<div class="meta">Sin cita programada.</div>'}</div>
  <div class="family-card-panel" data-family-card-panel="inscription"><div class="checklist"><div class="check"><span>Estado</span><strong>${esc(fed)}</strong></div><div class="check"><span>Equipo</span><strong>${esc(p.teamName)}</strong></div><div class="check"><span>Situación económica</span><strong>${esc(econ.label)}</strong></div><div class="check"><span>Detalle económico</span><strong>${esc(econ.detail||'')}</strong></div></div></div></article>`;
}
function bindFamilyCardTabs(){
  $$('.player-card[data-family-player]').forEach(card=>{const tabs=[...card.querySelectorAll('[data-family-card-tab]')],panels=[...card.querySelectorAll('[data-family-card-panel]')];tabs.forEach(tab=>tab.onclick=()=>{tabs.forEach(x=>x.classList.toggle('active',x===tab));panels.forEach(p=>p.classList.toggle('active',p.dataset.familyCardPanel===tab.dataset.familyCardTab))})});
}
async function renderMinorCoachConsents(){
  const box=$('#minorCoachConsentSection');
  if(box){box.classList.add('hidden');box.innerHTML=''}
  await loadFamilyMinorCoachConsents();
}
function openMinorCoachConsentDialog(id,name,action){
  pendingMinorConsentAction={id,name,action};
  const accept=action==='accept', reject=action==='reject', revoke=action==='revoke';
  $('#minorCoachConsentTitle').textContent=accept?'Autorizar funciones de entrenador':reject?'Rechazar autorización':'Revocar autorización de entrenador';
  $('#minorCoachConsentName').textContent=name;
  $('#minorCoachConsentText').textContent=accept?`Autorizo a ${name} a desempeñar funciones de entrenador en el C.D. Los Yébenes San Bruno mientras sea menor de edad. Esta autorización es independiente de mi representación del menor como jugador y podrá revocarse posteriormente.`:reject?`Vas a rechazar la solicitud para que ${name} desempeñe funciones de entrenador mientras sea menor de edad.`:`Vas a revocar la autorización para que ${name} desempeñe funciones de entrenador mientras sea menor de edad. Las asignaciones activas finalizarán inmediatamente y las futuras se cancelarán, conservándose la trazabilidad.`;
  $('#minorCoachConsentConfirm').textContent=accept?'Autorizar':reject?'Rechazar':'Revocar autorización';
  $('#minorCoachConsentFeedback').hidden=true;$('#minorCoachConsentModal').showModal();
}
async function submitMinorCoachConsent(){
  const a=pendingMinorConsentAction;if(!a)return;const b=$('#minorCoachConsentConfirm');
  const accept=a.action==='accept', reject=a.action==='reject', revoke=a.action==='revoke';
  b.disabled=true;b.textContent=accept?'Autorizando…':reject?'Rechazando…':'Revocando…';
  try{
    const call=revoke?await sb.rpc('revocar_autorizacion_entrenador_menor',{p_autorizacion_id:a.id}):await sb.rpc('responder_autorizacion_entrenador_menor',{p_autorizacion_id:a.id,p_aceptar:accept});
    if(call.error)throw call.error;
    $('#minorCoachConsentModal').close();pendingMinorConsentAction=null;await renderRemoteFamily();
  }
  catch(err){const f=$('#minorCoachConsentFeedback');f.textContent=`No se ha podido registrar la acción: ${err.message||err}`;f.hidden=false;f.className='warning-box'}
  finally{b.disabled=false;b.textContent=accept?'Autorizar':reject?'Rechazar':'Revocar autorización'}
}

async function processAdultTransitions(){
  if(!sb)return;
  try{await sb.rpc('procesar_preparacion_mayoria_edad')}catch(err){console.warn('Preparación de mayoría de edad pendiente',err)}
  try{await sb.rpc('procesar_mayorias_edad')}catch(err){console.warn('Transición de mayoría de edad pendiente',err)}
}

async function renderRemoteFamily(){
  $('#playersList').innerHTML='<div class="empty-card">Cargando jugadores…</div>';
  try{
    await loadRemoteFamilyData();
    await renderMinorCoachConsents();
    $('#playersList').innerHTML=remoteFamilyPlayers.length?remoteFamilyPlayers.map(familyPlayerTabbedCard).join(''):'<div class="empty-card">No hay jugadores asociados a tu cuenta.</div>';
    $$('.edit-remote-family').forEach(b=>b.onclick=()=>openRemoteFamilyEdit(b.dataset.id));$$('.edit-self-player').forEach(b=>b.onclick=()=>openSelfPlayerEdit(b.dataset.id));
    bindFamilyCardTabs();
    bindMinorCoachConsentButtons($('#playersList'));
    renderFamilyActionBanner();
    renderFamilyDocumentsSummary();
    $('#familyPlayerCount').textContent=currentRole==='player'?(remoteFamilyPlayers.length?'1 jugador · autorrepresentación':'Sin inscripción activa'):`${remoteFamilyPlayers.length} ${remoteFamilyPlayers.length===1?'jugador representado':'jugadores representados'}`;
    const progress=remoteFamilyPlayers.length?remoteFamilyPlayers.reduce((a,p)=>a+remoteStateProgress(p.inscription?.estado),0)/remoteFamilyPlayers.length:0;
    setFamilyProgress(progress);
  }catch(err){console.error('Carga familia Supabase',err);$('#playersList').innerHTML=`<div class="empty-card">No se pudieron cargar los jugadores: ${esc(err.message||err)}</div>`;setFamilyProgress(0)}
}


function federationReqState(req){
  const m={pendiente:['pending','Pendiente'],aportado:['pending','Aportado · pendiente de revisión'],declarado_realizado:['pending','Comunicado · pendiente de verificación'],validado:['complete','✓ Validado'],rechazado:['returned','⚠ Rechazado'],nueva_version_solicitada:['pending','↻ Nueva versión solicitada']};return m[req?.estado]||m.pendiente;
}
function currentFedDoc(player,req){
  const docs=(player?.fedDocs||[]).filter(d=>d.requisito_id===req?.id&&d.estado!=='sustituido');
  return docs.find(d=>d.id===req?.current_documento_id)||docs[0]||null;
}
function identitySubtypeLabel(v){return ({dni:'DNI',nie:'NIE',pasaporte:'Pasaporte',partida_nacimiento:'Partida de nacimiento',libro_familia:'Libro de Familia'})[v]||v||''}
function federationDocsProgress(player){const required=(player?.requirements||[]).filter(r=>r.obligatorio);const valid=required.filter(r=>r.estado==='validado').length;const total=required.length;const pct=total?Math.round(valid*100/total):0;return {valid,total,pct}}
function federationDocsComplete(player){const p=federationDocsProgress(player);return p.total>0&&p.valid===p.total}
function remoteDataValidated(player){return ['datos_validados','documentacion_validada','lista_para_federar','ficha_tramitada'].includes(player?.inscription?.estado)}
function moneyEUR(value){if(value===null||value===undefined||value==='')return '—';const n=Number(value);return Number.isFinite(n)?new Intl.NumberFormat('es-ES',{style:'currency',currency:'EUR'}).format(n):'—'}
function economicState(player){
  if(currentRole==='coach')return {key:'hidden',label:'—',detail:'Información económica restringida al club y a la familia.',ok:true};
  const e=player?.economic||null,cfg=player?.economicConfig||null;
  if(!player?.assignment)return {key:'no_team',label:'Sin equipo',detail:'Asigna un equipo antes de configurar el pago.',ok:false};
  if(!cfg||cfg.importe_inscripcion===null||cfg.importe_inscripcion===undefined)return {key:'unconfigured',label:'Importe no configurado',detail:'El club debe configurar el importe de inscripción de este equipo.',ok:false};
  if(cfg.requiere_pago_ficha===false)return {key:'not_required',label:'No requerido',detail:'Este equipo no exige pago para tramitar la ficha.',ok:true};
  if(e?.apto_para_ficha){
    if(e.estado_economico==='pagado')return {key:'paid',label:'Pagado',detail:`${moneyEUR(e.importe_pagado)} de ${moneyEUR(e.importe_total)}`,ok:true};
    if(e.fraccionamiento_clubber_validado)return {key:'installments',label:'Fraccionamiento Cluber validado',detail:`Cobrado ${moneyEUR(e.importe_pagado)} de ${moneyEUR(e.importe_total)} · domiciliación validada`,ok:true,warning:false};
  }
  if(e?.estado_economico==='parcial')return {key:'partial',label:'Pago parcial',detail:`${moneyEUR(e.importe_pagado)} de ${moneyEUR(e.importe_total)} · pendiente de completar o validar Cluber`,ok:false};
  return {key:'pending',label:'Pendiente',detail:`Pendiente ${moneyEUR(e?.importe_total??cfg.importe_inscripcion)}`,ok:false};
}
function economicSummaryHtml(player){const st=economicState(player),e=player?.economic,cfg=player?.economicConfig;return `<div class="economic-summary ${st.ok?'is-ready':'is-pending'}"><div class="row"><div><strong>${esc(st.label)}</strong><div class="meta">${esc(st.detail)}</div></div><span class="status ${st.ok?'complete':'pending'}">${st.ok?'✓ Habilitado':'Pendiente'}</span></div>${cfg?`<div class="economic-grid"><span>Importe <strong>${moneyEUR(cfg.importe_inscripcion)}</strong></span><span>Pagado <strong>${moneyEUR(e?.importe_pagado||0)}</strong></span><span>Fraccionamiento <strong>${cfg.admite_fraccionamiento?'Permitido':'No'}</strong></span></div>`:''}</div>`}
function remoteFederationReadiness(player){
  const medical=player?.medical?medicalState({date:player.medical.fecha_reconocimiento,expiry:player.medical.fecha_valido_hasta}):medicalState(null);
  const payment=economicState(player);
  const checks=[
    {key:'data',label:'Datos personales validados',ok:remoteDataValidated(player),detail:remoteDataValidated(player)?'Validados por el club':'Pendientes de validación'},
    {key:'team',label:'Equipo asignado',ok:!!player?.assignment,detail:player?.assignment?(player.teamName||'Equipo asignado'):'Sin equipo asignado'},
    {key:'docs',label:'Documentación RFFM',ok:federationDocsComplete(player),detail:(()=>{const d=federationDocsProgress(player);return `${d.valid}/${d.total} requisitos validados`})()},
    {key:'medical',label:'Reconocimiento médico vigente',ok:['ok','soon'].includes(medical.key),warning:medical.key==='soon',detail:medical.key==='ok'?`Vigente hasta ${fmt(player.medical?.fecha_valido_hasta)}`:medical.key==='soon'?`${medical.label} · válido hasta ${fmt(player.medical?.fecha_valido_hasta)}`:medical.key==='expired'?`Vencido el ${fmt(player.medical?.fecha_valido_hasta)}`:'Sin reconocimiento vigente'}
  ];
  if(currentRole!=='coach')checks.push({key:'payment',label:'Inscripción económicamente habilitada',ok:payment.ok,warning:!!payment.warning,detail:payment.detail});
  const met=checks.filter(x=>x.ok).length,total=checks.length,pct=total?Math.round(met*100/total):0;
  return {checks,met,total,pct,isReady:met===total};
}
function readinessProgressHtml(player){const r=remoteFederationReadiness(player),tabs={data:'data',team:'data',docs:'docs',medical:'medical',payment:'economic'};return `<div class="readiness-progress"><div class="docs-progress-head"><strong>Preparación de ficha · ${r.pct}%</strong><span>${r.met} de ${r.total} requisitos cumplidos</span></div><div class="docs-progress-track"><span style="width:${r.pct}%"></span></div><div class="readiness-list">${r.checks.map(c=>`<div class="readiness-item tab-jump ${c.ok?(c.warning?'warning':'ok'):'missing'}" data-jump-tab="${tabs[c.key]||'summary'}" role="button" tabindex="0"><span>${c.ok?(c.warning?'⚠':'✓'):'✕'} ${esc(c.label)}</span><small>${esc(c.detail)}</small></div>`).join('')}</div>${r.isReady?'<div class="readiness-ready">✓ Apto para tramitar la ficha con los requisitos actualmente implantados.</div>':'<div class="readiness-note">Los requisitos pendientes bloquean “Listo para federar”.</div>'}</div>`}
function federationProgressHtml(player,compact=false){const p=federationDocsProgress(player);return `<div class="docs-progress ${compact?'compact':''}"><div class="docs-progress-head"><strong>Documentación RFFM · ${p.pct}%</strong><span>${p.valid} de ${p.total} requisitos validados</span></div><div class="docs-progress-track" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${p.pct}"><span style="width:${p.pct}%"></span></div></div>`}
function renderFamilyDocumentsSummary(){
  const box=$('#familyDocumentsList');if(!box)return;
  box.innerHTML=remoteFamilyPlayers.length?remoteFamilyPlayers.map(p=>{const pr=federationDocsProgress(p);return `<article class="player-card"><div class="row"><div><h3>${esc(p.name)}</h3><div class="meta">${esc(p.categoryName)} · ${pr.valid}/${pr.total} requisitos validados</div></div><span class="status ${federationDocsComplete(p)?'complete':'pending'}">${federationDocsComplete(p)?'✓ Completa':pr.pct+'%'}</span></div>${federationProgressHtml(p,true)}<button type="button" class="secondary small manage-docs-summary" data-id="${esc(p.id)}" aria-disabled="false" onclick="openDocumentManager(this.dataset.id)">Abrir documentación</button></article>`}).join(''):'<div class="empty-card">No hay jugadores con inscripción activa.</div>';
}

function federationUploadForm(player,req,labelText){
  const subtype=req.codigo==='identidad_rffm'?`<label>Tipo de documento<select class="doc-subtype" data-req="${req.id}"><option value="dni">DNI</option><option value="nie">NIE</option><option value="pasaporte">Pasaporte</option><option value="partida_nacimiento">Partida de nacimiento</option><option value="libro_familia">Libro de Familia</option></select></label>`:'';
  const accept=req.codigo==='foto_jugador'?'image/jpeg,image/png,image/webp':'image/jpeg,image/png,image/webp,application/pdf';
  return `<div class="doc-upload replacement-upload ${subtype?'has-subtype':'no-subtype'}" data-replacement="${req.id}">${subtype}<label class="doc-file-field">${esc(labelText)}<input type="file" class="doc-file" data-req="${req.id}" accept="${accept}"></label><button type="button" class="primary small upload-fed-doc" data-req="${req.id}" data-player="${player.id}">Subir</button></div>`;
}
function documentRequirementHtml(player,req,mode='family'){
  const doc=currentFedDoc(player,req);
  const effectiveReq=(doc&&req.estado==='pendiente')?{...req,estado:'aportado'}:req;
  const [cls,label]=federationReqState(effectiveReq);const rejected=req.estado==='rechazado',newVersion=req.estado==='nueva_version_solicitada',declared=req.estado==='declarado_realizado';
  let action='';
  if(mode==='family'&&req.requiere_archivo){
    if(!doc){
      action=federationUploadForm(player,req,'Adjuntar archivo');
    }else if(rejected){
      action=federationUploadForm(player,req,'Aportar documento corregido');
    }else if(newVersion){
      action=`<div class="document-delivered is-review"><div><strong>↻ El club solicita una nueva versión</strong><div class="meta">El documento validado anterior permanece disponible hasta que aportes la nueva versión.</div></div><div class="document-actions"><button type="button" class="secondary tiny view-family-fed-doc" data-path="${esc(doc.storage_path)}">Ver versión validada</button></div></div>${federationUploadForm(player,req,'Aportar nueva versión')}`;
    }else if(req.estado==='validado'){
      action=`<div class="document-delivered is-valid"><div><strong>✓ Validado por el club</strong><div class="meta">Documento aceptado y bloqueado. Solo podrá sustituirse si el club solicita una nueva versión.</div></div><div class="document-actions"><button type="button" class="secondary tiny view-family-fed-doc" data-path="${esc(doc.storage_path)}">Ver documento</button></div></div>`;
    }else{
      action=`<div class="document-delivered is-review"><div><strong>✓ Documento aportado</strong><div class="meta">Pendiente de revisión por el club. Puedes sustituirlo mientras no haya sido validado.</div></div><div class="document-actions"><button type="button" class="secondary tiny view-family-fed-doc" data-path="${esc(doc.storage_path)}">Ver documento</button><button type="button" class="secondary tiny replace-fed-doc" data-req="${req.id}">Sustituir documento</button></div></div><div class="replacement-panel" data-replacement-panel="${req.id}" hidden>${federationUploadForm(player,req,'Seleccionar nuevo archivo')}</div>`;
    }
  }else if(mode==='family'&&!req.requiere_archivo){
    if(req.estado==='validado'){
      action=`<div class="document-delivered is-valid"><div><strong>✓ Verificado por el club</strong><div class="meta">El club ha comprobado este requisito en la RFFM.</div></div></div>`;
    }else if(declared){
      action=`<div class="document-delivered is-review"><div><strong>✓ Comunicado al club</strong><div class="meta">Has indicado que este paso ya está realizado en la RFFM. Queda pendiente de comprobación por el club.${req.declarado_realizado_at?` Comunicado el ${esc(fmt(req.declarado_realizado_at.slice(0,10)))}`:''}</div></div></div>`;
    }else{
      const txt=req.codigo==='autorizacion_tutor'?'Ya he realizado la autorización en RFFM':'Ya he realizado la firma en RFFM';
      const intro=req.codigo==='autorizacion_tutor'?'La autorización del padre, madre o tutor se realiza en el circuito de la RFFM.':'La firma online de la licencia se realiza en el circuito de la RFFM.';
      action=`<div class="rffm-external-step"><div class="meta">${intro} Cuando esté realizada, comunícalo al club para que pueda comprobarla.</div><button type="button" class="primary small declare-rffm-done" data-req="${req.id}">${rejected?'✓ Ya lo he subsanado en RFFM':'✓ '+txt}</button></div>`;
    }
  }
  const fileLine=doc?`<div class="meta doc-file-name">${esc(doc.nombre_original)}${doc.subtipo?' · '+esc(identitySubtypeLabel(doc.subtipo)):''}</div>`:'';
  const reason=rejected&&req.motivo_rechazo?`<div class="family-alert document-rejection"><strong>${req.requiere_archivo?'Documento rechazado':'No verificado por el club'}</strong><p>${esc(req.motivo_rechazo)}</p></div>`:'';
  const newReason=newVersion&&req.motivo_nueva_version?`<div class="family-alert"><strong>Nueva versión solicitada por el club</strong><p>${esc(req.motivo_nueva_version)}</p></div>`:'';
  return `<div class="federation-requirement"><div class="row"><div><strong>${esc(req.nombre)}</strong>${fileLine}</div><span class="status ${cls}">${esc(label)}</span></div>${reason}${newReason}${action}</div>`;
}
function renderDocumentManagerPlayer(p){
  const modal=$('#documentModal'),name=$('#documentPlayerName'),meta=$('#documentPlayerMeta'),list=$('#documentRequirementsList');
  if(!modal||!name||!meta||!list){console.error('Gestor documental incompleto en el DOM',{modal,name,meta,list});return false;}
  name.textContent=p.name;meta.textContent=`${p.categoryName} · ${dbActiveSeason()?.name||''}`;
  list.innerHTML=federationProgressHtml(p)+(p.requirements||[]).map(r=>documentRequirementHtml(p,r,'family')).join('')||'<div class="empty-card">No se han inicializado requisitos documentales.</div>';
  list.querySelectorAll('.upload-fed-doc').forEach(b=>b.onclick=()=>uploadFederationDocument(p,b.dataset.req,b));
  list.querySelectorAll('.replace-fed-doc').forEach(b=>b.onclick=()=>{const panel=list.querySelector(`[data-replacement-panel="${b.dataset.req}"]`);if(panel)panel.hidden=!panel.hidden});
  list.querySelectorAll('.view-family-fed-doc').forEach(b=>b.onclick=async()=>{try{await openFederationDocument(b.dataset.path)}catch(err){alert(`No se puede abrir: ${err.message||err}`)}});
  list.querySelectorAll('.declare-rffm-done').forEach(b=>b.onclick=()=>declareRffmRequirementDone(p,b.dataset.req,b));
  return true;
}
async function openDocumentManager(playerId){
  const p=remoteFamilyPlayers.find(x=>x.id===playerId);
  if(!p){alert('No se ha podido localizar al jugador para abrir su documentación.');return;}
  const modal=$('#documentModal');
  if(!renderDocumentManagerPlayer(p)||!modal){alert('No se puede abrir la documentación porque falta el panel documental en esta versión.');return;}
  if(!modal.open)modal.showModal();
}
async function uploadFederationDocument(player,reqId,button){
  const req=player.requirements.find(r=>r.id===reqId);
  const form=button.closest('.doc-upload');
  const input=form?.querySelector(`.doc-file[data-req="${reqId}"]`);
  const file=input?.files?.[0];
  if(!req||!file){alert('Selecciona un archivo.');return}
  if(file.size>5*1024*1024){alert('El archivo supera 5 MB.');return}
  const subtype=req.codigo==='identidad_rffm'?(form?.querySelector(`.doc-subtype[data-req="${reqId}"]`)?.value||'dni'):null;
  const ext=(file.name.split('.').pop()||'bin').replace(/[^a-z0-9]/gi,'').toLowerCase();
  const path=`${player.inscription.id}/${req.codigo}/${crypto.randomUUID()}.${ext}`;
  const old=button.textContent;button.disabled=true;button.textContent='Subiendo…';
  try{
    const up=await sb.storage.from('documentacion-federativa').upload(path,file,{contentType:file.type||undefined,upsert:false});if(up.error)throw up.error;
    const {data:newDocId,error}=await sb.rpc('registrar_documento_federativo',{p_requisito_id:reqId,p_storage_path:path,p_nombre_original:file.name,p_mime_type:file.type||null,p_subtipo:subtype});
    if(error){await sb.storage.from('documentacion-federativa').remove([path]);throw error}

    // Actualización optimista: la nueva versión debe verse inmediatamente,
    // incluso antes de completar la recarga desde Supabase.
    (player.fedDocs||[]).forEach(d=>{if(d.requisito_id===reqId&&d.estado!=='sustituido')d.estado='sustituido'});
    player.fedDocs=player.fedDocs||[];
    player.fedDocs.unshift({id:newDocId,requisito_id:reqId,inscripcion_id:player.inscription.id,storage_path:path,nombre_original:file.name,mime_type:file.type||null,subtipo:subtype,estado:'aportado',aportado_at:new Date().toISOString()});
    req.current_documento_id=newDocId;req.estado='aportado';req.motivo_rechazo=null;req.motivo_nueva_version=null;req.nueva_version_solicitada_at=null;
    if(input)input.value='';
    renderDocumentManagerPlayer(player);

    // Sincronización autoritativa desde BD. No se vuelve a llamar showModal(),
    // porque el diálogo ya está abierto y eso podía interrumpir el refresco.
    try{
      await loadRemoteFamilyData();
      renderRemoteFamily();
      const fresh=remoteFamilyPlayers.find(x=>x.id===player.id);
      if(fresh)renderDocumentManagerPlayer(fresh);
    }catch(syncErr){
      console.warn('Documento guardado; no se pudo refrescar inmediatamente desde Supabase',syncErr);
    }
    alert('Documento aportado correctamente. Queda pendiente de revisión por el club y puedes sustituirlo mientras no sea validado.');
  }catch(err){alert(`No se ha podido subir el documento: ${err.message||err}`)}finally{button.disabled=false;button.textContent=old}
}
async function openFederationDocument(path){const {data,error}=await sb.storage.from('documentacion-federativa').createSignedUrl(path,300);if(error)throw error;const a=document.createElement('a');a.href=data.signedUrl;a.target='_blank';a.rel='noopener';document.body.appendChild(a);a.click();a.remove()}
async function declareRffmRequirementDone(player,reqId,button){
  const req=player.requirements.find(r=>r.id===reqId);if(!req)return;
  if(!confirm('¿Confirmas que este paso ya se ha realizado en la RFFM? El club deberá comprobarlo antes de validarlo.'))return;
  const old=button.textContent;button.disabled=true;button.textContent='Comunicando…';
  try{const {error}=await sb.rpc('declarar_requisito_rffm_realizado',{p_requisito_id:reqId});if(error)throw error;await loadRemoteFamilyData();renderRemoteFamily();const fresh=remoteFamilyPlayers.find(x=>x.id===player.id);if(fresh)await openDocumentManager(fresh.id);alert('Comunicado al club. Queda pendiente de verificación.')}catch(err){alert(`No se ha podido comunicar el requisito: ${err.message||err}`)}finally{button.disabled=false;button.textContent=old}
}
function renderAdminFederationRequirements(v){
  const box=$('#adminFederationRequirements');if(!box)return;const can=['admin','club'].includes(currentRole);
  box.innerHTML=federationProgressHtml(v)+(v.requirements||[]).map(req=>{const [cls,label]=federationReqState(req),doc=currentFedDoc(v,req);const actions=[];if(doc)actions.push(`<button type="button" class="secondary tiny view-fed-doc" data-path="${esc(doc.storage_path)}">Ver documento</button>`);if(can&&req.estado==='aportado')actions.push(`<button type="button" class="primary tiny validate-fed-req" data-id="${req.id}">Validar</button>`,`<button type="button" class="return-button tiny reject-fed-req" data-id="${req.id}">Rechazar</button>`);if(can&&req.estado==='declarado_realizado'&&!req.requiere_archivo)actions.push(`<button type="button" class="primary tiny validate-fed-req" data-id="${req.id}">Verificar y validar</button>`,`<button type="button" class="return-button tiny reject-fed-req" data-id="${req.id}">No se ha podido verificar</button>`);if(can&&req.estado==='validado'&&req.requiere_archivo)actions.push(`<button type="button" class="secondary tiny request-new-fed-doc" data-id="${req.id}">Solicitar nueva versión</button>`);if(can&&req.estado==='validado'&&!req.requiere_archivo)actions.push(`<button type="button" class="secondary tiny change-fed-req" data-id="${req.id}">Cambiar validación</button>`);const waiting=req.estado==='rechazado'?`<div class="meta">${req.requiere_archivo?'Esperando documento corregido de la familia.':'Esperando que tutor/jugador comunique de nuevo la realización en RFFM.'}</div>`:req.estado==='nueva_version_solicitada'?'<div class="meta">Esperando la nueva versión solicitada.</div>':req.estado==='pendiente'&&!req.requiere_archivo?'<div class="meta">Pendiente de que tutor/jugador indique que lo ha realizado en la RFFM.</div>':req.estado==='declarado_realizado'?`<div class="meta">Tutor/jugador indica realizado${req.declarado_realizado_at?` el ${esc(fmt(req.declarado_realizado_at.slice(0,10)))}`:''}. Pendiente de comprobación por el club.</div>`:'';return `<div class="federation-requirement"><div class="row"><div><strong>${esc(req.nombre)}</strong>${doc?`<div class="meta">${esc(doc.nombre_original)}${doc.subtipo?' · '+esc(identitySubtypeLabel(doc.subtipo)):''}</div>`:''}${req.motivo_rechazo?`<div class="meta return-note">Motivo del rechazo: ${esc(req.motivo_rechazo)}</div>`:''}${req.motivo_nueva_version?`<div class="meta return-note">Nueva versión solicitada: ${esc(req.motivo_nueva_version)}</div>`:''}${waiting}</div><span class="status ${cls}">${esc(label)}</span></div><div class="workflow-actions">${actions.join('')}</div></div>`}).join('')||'<div class="meta">No hay requisitos inicializados.</div>';
  $$('.view-fed-doc').forEach(b=>b.onclick=async()=>{try{await openFederationDocument(b.dataset.path)}catch(err){alert(`No se puede abrir: ${err.message||err}`)}});
  $$('.validate-fed-req').forEach(b=>b.onclick=()=>reviewFederationRequirement(v,b.dataset.id,'validado'));
  $$('.reject-fed-req').forEach(b=>b.onclick=()=>reviewFederationRequirement(v,b.dataset.id,'rechazado'));
  $$('.change-fed-req').forEach(b=>b.onclick=()=>changeFederationValidation(v,b.dataset.id));
  $$('.request-new-fed-doc').forEach(b=>b.onclick=()=>requestNewFederationVersion(v,b.dataset.id));
}
async function reviewFederationRequirement(v,reqId,state){
  let reason=null;if(state==='rechazado'){if(!confirm('¿Confirmas que el club no ha podido verificar este trámite en la RFFM? El requisito volverá a la familia/jugador para que pueda revisarlo y comunicarlo de nuevo.'))return;reason=prompt('Indica qué debe revisar la familia/jugador antes de volver a comunicarlo:');if(!reason?.trim())return}
  try{const {error}=await sb.rpc('revisar_requisito_federativo',{p_requisito_id:reqId,p_estado:state,p_motivo:reason});if(error)throw error;await renderRemoteClub();await openRemoteAdminPlayer(v.id)}catch(err){alert(`No se ha podido revisar el requisito: ${err.message||err}`)}
}
async function changeFederationValidation(v,reqId){
  const reason=prompt('Indica el motivo por el que se cambia una validación ya realizada. La familia lo verá en su ficha:');if(!reason?.trim())return;
  if(!confirm('¿Cambiar este requisito de Validado a Rechazado? Esta acción quedará visible para la familia.'))return;
  try{const {error}=await sb.rpc('revisar_requisito_federativo',{p_requisito_id:reqId,p_estado:'rechazado',p_motivo:reason.trim()});if(error)throw error;await renderRemoteClub();await openRemoteAdminPlayer(v.id)}catch(err){alert(`No se ha podido cambiar la validación: ${err.message||err}`)}
}
async function requestNewFederationVersion(v,reqId){
  const reason=prompt('Indica por qué el club solicita una nueva versión. La familia verá este motivo:');if(!reason?.trim())return;
  if(!confirm('¿Solicitar una nueva versión de este documento validado? La versión actual seguirá conservada hasta que la familia aporte la nueva.'))return;
  try{const {error}=await sb.rpc('solicitar_nueva_version_requisito',{p_requisito_id:reqId,p_motivo:reason.trim()});if(error)throw error;await renderRemoteClub();await openRemoteAdminPlayer(v.id)}catch(err){alert(`No se ha podido solicitar una nueva versión: ${err.message||err}`)}
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
  const {data:personRows,error:personErr}=personIds.length?await sb.from('personas').select('id,nombre,primer_apellido,segundo_apellido,fecha_nacimiento,email_contacto,telefono').in('id',personIds):{data:[],error:null};if(personErr)throw personErr;
  let clubIdentityRows=[];if(personIds.length){const ir=await sb.from('documentos_identidad').select('persona_id,tipo,numero,es_principal,activo,created_at').in('persona_id',personIds).eq('activo',true).order('created_at',{ascending:false});if(!ir.error)clubIdentityRows=ir.data||[];}
  const {data:repRows,error:repErr}=await sb.from('representaciones_jugador').select('id,jugador_id,representante_persona_id,fecha_desde,fecha_hasta,motivo_alta,motivo_fin,excepcion_representacion_adulto').in('jugador_id',playerIds);if(repErr)throw repErr;
  const repPersonIds=[...new Set((repRows||[]).map(x=>x.representante_persona_id).filter(Boolean))];
  const {data:repPersons,error:repPersonErr}=repPersonIds.length?await sb.from('personas').select('id,nombre,primer_apellido,segundo_apellido').in('id',repPersonIds):{data:[],error:null};if(repPersonErr)throw repPersonErr;
  const insIds=(insRows||[]).map(x=>x.id);
  const {data:assignRows,error:aErr}=insIds.length?await sb.from('asignaciones_jugador_equipo').select('id,inscripcion_id,equipo_id,fecha_desde,fecha_hasta,motivo_cambio').in('inscripcion_id',insIds):{data:[],error:null};if(aErr)throw aErr;
  const {data:reqRows,error:reqErr}=insIds.length?await sb.from('requisitos_federativos_inscripcion').select('id,inscripcion_id,codigo,nombre,obligatorio,requiere_archivo,estado,current_documento_id,motivo_rechazo,revisado_at,nueva_version_solicitada_at,motivo_nueva_version,declarado_realizado_at,declarado_realizado_por').in('inscripcion_id',insIds).order('created_at',{ascending:true}):{data:[],error:null};if(reqErr)throw reqErr;
  const {data:fedDocRows,error:fedDocErr}=insIds.length?await sb.from('documentos_federativos').select('id,requisito_id,inscripcion_id,storage_path,nombre_original,mime_type,subtipo,estado,motivo_rechazo,aportado_at,revisado_at').in('inscripcion_id',insIds).order('aportado_at',{ascending:false}):{data:[],error:null};if(fedDocErr)throw fedDocErr;
  const {data:medicalRows,error:mErr}=await sb.from('reconocimientos_medicos').select('id,jugador_id,fecha_reconocimiento,fecha_valido_hasta,fecha_validacion_rffm,centro_medico,observaciones,created_at').in('jugador_id',playerIds).order('fecha_reconocimiento',{ascending:false});if(mErr)throw mErr;
  remoteMedicalRows=medicalRows||[];
  const {data:appointmentRows,error:apptErr}=await sb.from('citas_reconocimiento_medico').select('id,jugador_id,fecha_hora,lugar,direccion,indicaciones,estado,comunicada_at,created_at,updated_at').in('jugador_id',playerIds).order('fecha_hora',{ascending:false});if(apptErr)throw apptErr;remoteMedicalAppointments=appointmentRows||[];
  const appointmentIds=(appointmentRows||[]).map(x=>x.id);let notificationRows=[];
  if(appointmentIds.length&&['admin','club'].includes(currentRole)){const nr=await sb.from('notificaciones_salida').select('id,cita_id,destinatario_tipo,destinatario_email,estado,intentos,enviado_at,ultimo_error,created_at').in('cita_id',appointmentIds).order('created_at',{ascending:false});if(!nr.error)notificationRows=nr.data||[];}
  let economicRows=[],paymentRows=[],clubberRows=[],economicConfigRows=[];
  if(['admin','club'].includes(currentRole)&&insIds.length){
    const [er,pr,cr]=await Promise.all([
      sb.from('situacion_economica_inscripcion').select('inscripcion_id,configuracion_id,equipo_id,importe_total,importe_pagado,estado_economico,fraccionamiento_clubber_validado,fecha_validacion_fraccionamiento,validado_fraccionamiento_por,origen_validacion_fraccionamiento,apto_para_ficha').in('inscripcion_id',insIds),
      sb.from('pagos_inscripcion').select('id,inscripcion_id,importe,metodo,fecha_pago,estado,referencia_externa,clubber_pago_id,observaciones,created_at').in('inscripcion_id',insIds).order('fecha_pago',{ascending:false}),
      sb.from('configuracion_economica_equipo').select('id,temporada_id,equipo_id,importe_inscripcion,admite_fraccionamiento,requiere_pago_ficha,observaciones').eq('temporada_id',season.id)
    ]);
    if(er.error)throw er.error;if(pr.error)throw pr.error;if(cr.error)throw cr.error;economicRows=er.data||[];paymentRows=pr.data||[];economicConfigRows=cr.data||[];dbEconomicConfigs=economicConfigRows;
    const vr=await sb.from('vinculos_clubber').select('id,tipo,persona_id,jugador_id,clubber_id,activo').eq('activo',true);if(!vr.error)clubberRows=vr.data||[];
  }
  const clubIdentityByPerson=new Map();for(const d of clubIdentityRows){if(!clubIdentityByPerson.has(d.persona_id)||d.es_principal)clubIdentityByPerson.set(d.persona_id,d)}
  const personsById=new Map((personRows||[]).map(x=>[x.id,x])),repPersonsById=new Map((repPersons||[]).map(x=>[x.id,x])),insByPlayer=new Map((insRows||[]).map(x=>[x.jugador_id,x]));
  const today=isoToday();
  remoteClubPlayers=(playerRows||[]).map(p=>{
    const person=personsById.get(p.persona_id)||{},ins=insByPlayer.get(p.id)||null;
    const rep=(repRows||[]).filter(r=>r.jugador_id===p.id&&(!r.fecha_desde||r.fecha_desde<=today)&&(!r.fecha_hasta||r.fecha_hasta>=today)).sort((a,b)=>String(b.fecha_desde||'').localeCompare(String(a.fecha_desde||'')))[0]||null;
    const repPerson=rep?repPersonsById.get(rep.representante_persona_id):null;const representationHistory=(repRows||[]).filter(r=>r.jugador_id===p.id).map(r=>{const rp=repPersonsById.get(r.representante_persona_id)||{};return {...r,representativeName:[rp.nombre,rp.primer_apellido,rp.segundo_apellido].filter(Boolean).join(' ')||'Representante'}});
    const assignment=ins?(assignRows||[]).filter(a=>a.inscripcion_id===ins.id&&(!a.fecha_desde||a.fecha_desde<=today)&&(!a.fecha_hasta||a.fecha_hasta>=today)).sort((a,b)=>String(b.fecha_desde||'').localeCompare(String(a.fecha_desde||'')))[0]:null;
    const team=assignment?dbTeams.find(t=>t.id===assignment.equipo_id):null;
    const isAdult=!!person.fecha_nacimiento&&ageOn(person.fecha_nacimiento)>=18;const requirements=ins?(reqRows||[]).filter(r=>r.inscripcion_id===ins.id&&!(isAdult&&r.codigo==='autorizacion_tutor')):[];const fedDocs=ins?(fedDocRows||[]).filter(d=>d.inscripcion_id===ins.id):[];const docsComplete=requirements.length>0&&requirements.filter(r=>r.obligatorio).every(r=>r.estado==='validado');
    const medicalsForPlayer=(medicalRows||[]).filter(m=>m.jugador_id===p.id).sort((a,b)=>String(b.fecha_reconocimiento||'').localeCompare(String(a.fecha_reconocimiento||'')));
    const latestRemoteMedical=medicalsForPlayer[0]||null;
    const appointments=(appointmentRows||[]).filter(a=>a.jugador_id===p.id).sort((a,b)=>String(b.fecha_hora||'').localeCompare(String(a.fecha_hora||'')));const appointment=appointments.find(a=>a.estado==='programada'&&new Date(a.fecha_hora)>=new Date())||null;const appointmentNotifications=appointment?notificationRows.filter(n=>n.cita_id===appointment.id):[];const economic=ins?economicRows.find(e=>e.inscripcion_id===ins.id)||null:null;const economicConfig=assignment?economicConfigRows.find(c=>c.equipo_id===assignment.equipo_id)||null:null;const payments=ins?paymentRows.filter(x=>x.inscripcion_id===ins.id):[];const identity=clubIdentityByPerson.get(p.persona_id)||null;const clubberPlayer=clubberRows.find(x=>x.tipo==='deportista'&&x.jugador_id===p.id)||null;const clubberTutor=rep?clubberRows.find(x=>x.tipo==='tutor'&&x.persona_id===rep.representante_persona_id)||null:null;return {id:p.id,personId:p.persona_id,name:[person.nombre,person.primer_apellido,person.segundo_apellido].filter(Boolean).join(' '),birth:person.fecha_nacimiento||'',playerEmail:person.email_contacto||'',playerPhone:person.telefono||'',childDocumentType:identity?.tipo||'',childDocumentNumber:identity?.numero||'',active:p.activo!==false,inscription:ins,categoryName:ins?dbCategoryName(ins.categoria_id):'—',representation:rep,representationHistory,tutorName:repPerson?[repPerson.nombre,repPerson.primer_apellido,repPerson.segundo_apellido].filter(Boolean).join(' '):(person.fecha_nacimiento&&ageOn(person.fecha_nacimiento)>=18?'Autorrepresentación':'Sin representante'),assignment,teamName:team?.name||'Sin equipo',requirements,fedDocs,docsLabel:docsComplete?'Completa':requirements.some(r=>r.estado==='rechazado'||r.estado==='nueva_version_solicitada')?'Revisar':requirements.some(r=>['aportado','declarado_realizado'].includes(r.estado))?'En revisión':'Pendiente',medicals:medicalsForPlayer,medical:latestRemoteMedical,appointments,appointment,appointmentNotifications,economic,economicConfig,payments,clubberPlayer,clubberTutor};
  });
  if(currentRole==='coach'){
    const coachAssignments=activeCoachAssignments(currentUser.authUserId||currentUser.id);
    const allowedTeams=new Set(coachAssignments.map(a=>a.teamId));
    remoteClubPlayers=remoteClubPlayers.filter(v=>v.assignment&&allowedTeams.has(v.assignment.equipo_id));
  }
  return remoteClubPlayers;
}

async function renderRemoteClub(){
  $('#adminTable').innerHTML='<tr><td colspan="10">Cargando fichas desde Supabase…</td></tr>';
  try{
    await loadRemoteClubData();
    const catSel=$('#clubCategoryFilter');if(catSel){const prev=catSel.value||'all';catSel.innerHTML='<option value="all">Todas las categorías</option>'+dbCategories.filter(c=>c.active).map(c=>`<option value="${c.id}">${esc(c.name)}</option>`).join('');if([...catSel.options].some(o=>o.value===prev))catSel.value=prev}
    const q=$('#searchInput').value.trim().toLowerCase(),f=$('#statusFilter').value,cf=$('#clubCategoryFilter')?.value||'all',af=$('#clubActiveFilter')?.value||'active';
    const rows=remoteClubPlayers.filter(v=>{const readiness=remoteFederationReadiness(v);const statusGroup=readiness.isReady?'complete':'pending';const d18=v.birth?dayDiff(isoToday(),addYears(v.birth,18)):null;const quick=clubQuickFilter==='all'||(clubQuickFilter==='complete'&&readiness.isReady)||(clubQuickFilter==='docs'&&!federationDocsComplete(v))||(clubQuickFilter==='review'&&(['pendiente_revision_inicial','devuelta_familia'].includes(v.inscription?.estado)||(v.requirements||[]).some(r=>['aportado','declarado_realizado'].includes(r.estado))))||(clubQuickFilter==='medical90'&&medicalState(v.medical?{date:v.medical.fecha_reconocimiento,expiry:v.medical.fecha_valido_hasta}:null).key==='soon')||(clubQuickFilter==='adult30'&&d18!==null&&d18>=0&&d18<=30)||(clubQuickFilter==='payment'&&!economicState(v).ok);return quick&&(f==='all'||statusGroup===f)&&(cf==='all'||v.inscription?.categoria_id===cf)&&(af==='all'||(af==='active')===v.active)&&v.name.toLowerCase().includes(q)});
    $('#adminTable').innerHTML=rows.length?rows.map(v=>`<tr class="admin-row ${!v.active?'inactive-row':''}" data-id="${esc(v.id)}" tabindex="0"><td><strong>${esc(v.name)}</strong>${!v.active?'<div class="meta inactive-note">Jugador inactivo</div>':''}${v.inscription?.estado==='devuelta_familia'?`<div class="meta return-note">${remotePlayerIsAdult(v)&&!v.representation?'Correcciones solicitadas al jugador':'Devuelto a familia'}</div>`:''}</td><td>${esc(v.tutorName)}</td><td>${esc(v.categoryName)}</td><td><strong>${esc(v.teamName)}</strong></td><td><span class="status ${v.active?'complete':'returned'}">${v.active?'Activo':'Inactivo'}</span></td><td>${(()=>{const m=medicalState(v.medical?{date:v.medical.fecha_reconocimiento,expiry:v.medical.fecha_valido_hasta}:null);const cls=medicalVisualClass(m);return `<span class="status ${cls}">${esc(m.label)}</span>${v.medical?.fecha_valido_hasta?`<div class="meta">Hasta ${fmt(v.medical.fecha_valido_hasta)}</div>`:''}`})()}</td><td><span class="dot ${remoteDataValidated(v)?'ok':'warn'}">${remoteDataValidated(v)?'✓ Completo':'⚠ Pendiente'}</span></td><td>${(()=>{const p=federationDocsProgress(v);return `${p.pct}% · ${p.valid}/${p.total}`})()}</td>${currentRole==='coach'?'':`<td>${(()=>{const e=economicState(v);return `<span class="status ${e.ok?'complete':'pending'}">${esc(e.label)}</span>`})()}</td>`}<td><span class="workflow-pill ${esc(v.inscription?.estado||'')}">${esc(remotePlayerStateLabel(v))}</span></td></tr>`).join(''):'<tr><td colspan="10">No hay jugadores que coincidan con los filtros.</td></tr>';
    $$('.admin-row').forEach(r=>{r.onclick=()=>openRemoteAdminPlayer(r.dataset.id);r.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();openRemoteAdminPlayer(r.dataset.id)}}});
    const operational=remoteClubPlayers.filter(v=>v.active);$('#statPlayers').textContent=operational.length;$('#statComplete').textContent=operational.filter(v=>remoteFederationReadiness(v).isReady).length;$('#statDocs').textContent=operational.filter(v=>!federationDocsComplete(v)).length;$('#statReview').textContent=operational.filter(v=>['pendiente_revision_inicial','devuelta_familia'].includes(v.inscription?.estado)||(v.requirements||[]).some(r=>['aportado','declarado_realizado'].includes(r.estado))).length;$('#statMedical90').textContent=operational.filter(v=>medicalState(v.medical?{date:v.medical.fecha_reconocimiento,expiry:v.medical.fecha_valido_hasta}:null).key==='soon').length;$('#statAdult30').textContent=operational.filter(v=>{const d=v.birth?dayDiff(isoToday(),addYears(v.birth,18)):null;return d!==null&&d>=0&&d<=30}).length;if(currentRole!=='coach')$('#statPaymentPending').textContent=operational.filter(v=>!economicState(v).ok).length;updateQuickFilterUI();
  }catch(err){console.error('Carga fichas Supabase',err);$('#adminTable').innerHTML=`<tr><td colspan="10">No se pudieron cargar las fichas: ${esc(err.message||err)}</td></tr>`}
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
let activeAdminPlayerTab='summary';
function setAdminPlayerTab(tab){
  activeAdminPlayerTab=tab||'summary';
  $$('#adminPlayerTabs [data-player-tab]').forEach(b=>b.classList.toggle('active',b.dataset.playerTab===activeAdminPlayerTab));
  $$('#adminPlayerModal [data-player-panel]').forEach(p=>p.classList.toggle('active',p.dataset.playerPanel===activeAdminPlayerTab));
  if(activeAdminPlayerTab==='economic')populateEconomicPlayerTab();
}
function updateAdminTabAlerts(v){
  const docs=!federationDocsComplete(v),m=medicalState(v.medical?{date:v.medical.fecha_reconocimiento,expiry:v.medical.fecha_valido_hasta}:null),economic=economicState(v),data=!remoteDataValidated(v)||!v.assignment;
  const paidInFull=economic.key==='paid'||economic.key==='not_required';
  const economicNeedsAttention=!paidInFull;
  const economicAmber=economicNeedsAttention&&economic.ok&&!!economic.warning;
  const set=(id,on,amber=false)=>{const el=$(id);if(!el)return;el.hidden=!on;el.classList.toggle('amber',!!amber)};
  set('#tabAlertData',data);set('#tabAlertDocs',docs);set('#tabAlertMedical',!['ok'].includes(m.key),m.key==='soon');set('#tabAlertEconomic',currentRole!=='coach'&&economicNeedsAttention,economicAmber);
}
function populateEconomicPlayerTab(){
  if(currentRole==='coach')return;
  const v=remoteClubPlayers.find(x=>x.id===selectedRemotePlayerId);if(!v)return;selectedEconomicPlayerId=v.id;const f=$('#economicPlayerForm');if(!f)return;
  $('#economicPlayerCurrent').innerHTML=economicSummaryHtml(v);f.elements.clubberPlayerId.value=v.clubberPlayer?.clubber_id||'';f.elements.clubberTutorId.value=v.clubberTutor?.clubber_id||'';f.elements.paymentAmount.value='';const paymentMethodSelect=f.elements.paymentMethod;paymentMethodSelect.innerHTML=PAYMENT_FEATURES.manualMethods.filter(m=>m.enabled).map(m=>`<option value="${esc(m.value)}">${esc(m.label)}</option>`).join('');paymentMethodSelect.value='efectivo';f.elements.paymentDate.value=isoToday();f.elements.paymentReference.value='';f.elements.paymentNotes.value='';const cfg=v.economicConfig;$('#installmentValidationSummary').textContent=v.economic?.fraccionamiento_clubber_validado?`✓ Validado el ${v.economic.fecha_validacion_fraccionamiento?formatDateTime(v.economic.fecha_validacion_fraccionamiento):''}`:(cfg?.admite_fraccionamiento?'Pendiente de validar en Cluber.':'Este equipo no admite fraccionamiento.');$('#validateClubberInstallments').disabled=!cfg?.admite_fraccionamiento||!!v.economic?.fraccionamiento_clubber_validado;$('#revokeClubberInstallments').disabled=!v.economic?.fraccionamiento_clubber_validado;$('#economicPaymentsHistory').innerHTML=(v.payments||[]).length?v.payments.map(p=>`<div class="history-item"><strong>${moneyEUR(p.importe)} · ${esc(p.metodo==='efectivo'?'Efectivo':p.metodo==='clubber'?'Cluber':'Otro')}</strong><span>${fmt(p.fecha_pago)} · ${esc(p.estado)}${p.referencia_externa?' · '+esc(p.referencia_externa):''}</span></div>`).join(''):'<div class="meta">Sin pagos registrados.</div>';
}
async function openRemoteAdminPlayer(id){
  const v=remoteClubPlayers.find(x=>x.id===id);if(!v)return;selectedRemotePlayerId=id;selectedPlayerId=id;
  const coachView=currentRole==='coach';
  const economicTab=$('#economicPlayerTabButton'),economicPanel=$('#economicPlayerPanel'),workflowSection=$('#playerWorkflowSection'),returnSection=$('#playerReturnSection');
  if(economicTab)economicTab.style.display=coachView?'none':'';if(economicPanel)economicPanel.style.display=coachView?'none':'';if(workflowSection)workflowSection.style.display=coachView?'none':'';if(returnSection)returnSection.style.display=coachView?'none':'';
  if($('#openMedicalFromPlayer'))$('#openMedicalFromPlayer').style.display=coachView?'none':'';
  if($('#togglePlayerActive'))$('#togglePlayerActive').style.display=coachView?'none':'';
  if(coachView&&activeAdminPlayerTab==='economic')activeAdminPlayerTab='summary';
  $('#adminPlayerName').textContent=v.name;$('#adminPlayerCategory').textContent=`${v.categoryName} · ${dbActiveSeason()?.name||''}`;$('#adminPlayerSource').textContent='Datos reales de Supabase';$('#adminPlayerData').textContent='Completo';{const dp=federationDocsProgress(v);$('#adminPlayerDocs').textContent=`${dp.pct}% · ${dp.valid}/${dp.total} requisitos validados`;}{const ms=medicalState(v.medical?{date:v.medical.fecha_reconocimiento,expiry:v.medical.fecha_valido_hasta}:null);$('#adminPlayerMedical').textContent=ms.key==='ok'?`Vigente hasta ${fmt(v.medical.fecha_valido_hasta)}`:ms.key==='soon'?`${ms.label} · hasta ${fmt(v.medical.fecha_valido_hasta)}`:ms.key==='expired'?`Vencido · ${fmt(v.medical?.fecha_valido_hasta)}`:'Sin RRMM vigente';$('#adminPlayerMedical').className=ms.key==='ok'?'ok-text':ms.key==='soon'?'warn-text':'error-text';}$('#adminPlayerFed').textContent=remotePlayerStateLabel(v);$('#playerOperationalStatus').textContent=v.active?'Activo':'Inactivo';$('#togglePlayerActive').textContent=v.active?'Marcar como inactivo':'Reactivar jugador';
  $('#representationSummary').innerHTML=(v.representation?`<div><strong>${esc(v.tutorName)}</strong><div class="meta">Representación activa desde ${fmt(v.representation.fecha_desde)}${v.representation.excepcion_representacion_adulto?' · excepción jurídica':''}</div></div><span class="status complete">Activa</span>`:(v.birth&&ageOn(v.birth)>=18?'<div><strong>Autorrepresentación</strong><div class="meta">Jugador mayor de edad · gestiona directamente su ficha.</div></div><span class="status complete">Activa</span>':'<div><strong>⚠ Sin representante activo</strong></div>'))+`<div class="checklist compact-person-data"><div class="check"><span>Fecha de nacimiento</span><strong>${fmt(v.birth)}</strong></div><div class="check"><span>Correo</span><strong>${esc(v.playerEmail||'—')}</strong></div><div class="check"><span>Teléfono</span><strong>${esc(v.playerPhone||'—')}</strong></div><div class="check"><span>DNI/NIE</span><strong>${v.childDocumentNumber?esc(String(v.childDocumentType||'').toUpperCase()+' · '+v.childDocumentNumber):'—'}</strong></div></div>`;
  $('#changeTutorButton').style.display='none';$('#selfRepresentationButton').style.display='none';
  const state=v.inscription?.estado||'pendiente_revision_inicial';const categoryId=v.inscription?.categoria_id;const teamOptions=dbSeasonTeams().filter(t=>t.active&&(!categoryId||t.categoryId===categoryId));$('#adminTeam').innerHTML='<option value="">Sin equipo asignado</option>'+teamOptions.map(t=>`<option value="${t.id}">${esc(t.name)}${t.modality?' · '+esc(t.modality):''}</option>`).join('');$('#adminTeam').value=v.assignment?.equipo_id||'';
  const canAssign=!['pendiente_revision_inicial','devuelta_familia','cancelada'].includes(state);$('#adminTeam').disabled=!canAssign||currentRole==='coach';$('#saveTeamAssignment').disabled=!canAssign||currentRole==='coach';$('#teamAssignHint').textContent=canAssign?'El equipo queda asociado a esta inscripción y conserva histórico de cambios.':'Valida primero la inscripción inicial antes de asignar un equipo.';
  $('#teamAssignmentHistory').innerHTML=v.assignment?`<div class="history-item"><strong>${esc(v.teamName)}</strong><span>Desde ${fmt(v.assignment.fecha_desde)}</span></div>`:'<div class="meta">Sin asignación deportiva.</div>';
  const adultSelf=remotePlayerIsAdult(v)&&!v.representation;const states=[['pendiente_revision_inicial','Pendiente de revisión inicial'],['devuelta_familia',adultSelf?'Correcciones solicitadas':'Devuelta a la familia'],['datos_validados','Datos validados'],['documentacion_validada','Documentación validada'],['lista_para_federar','Listo para federar'],['ficha_tramitada','Ficha tramitada']];$('#adminWorkflow').innerHTML=states.map(([k,l])=>`<option value="${k}">${l}</option>`).join('');$('#adminWorkflow').value=state;$('#adminWorkflow').disabled=currentRole==='coach';$('#saveWorkflow').disabled=currentRole==='coach';const primary=workflowPrimaryMeta(v);const autoState=['datos_validados','documentacion_validada'].includes(state);let primaryText=primary.text;if(state==='datos_validados')primaryText=`El estado avanza automáticamente al validar todos los requisitos documentales. Ahora hay ${federationDocsProgress(v).valid}/${federationDocsProgress(v).total} validados.`;if(state==='documentacion_validada')primaryText='Documentación completa. El sistema marcará automáticamente “Listo para federar” cuando equipo, RRMM y situación económica estén habilitados.';$('#workflowActionContext').innerHTML=`<strong>${esc(remotePlayerStateLabel(v))}</strong><p>${esc(primaryText)}</p>`;$('#advanceStatus').textContent=primary.label;$('#advanceStatus').hidden=autoState;$('#advanceStatus').disabled=currentRole==='coach'||['ficha_tramitada','cancelada'].includes(state)||autoState;
  $('#returnMessage').value=state==='devuelta_familia'?(v.inscription?.observaciones||''):'';$('#returnToFamily').disabled=currentRole==='coach'||(!v.representation&&!adultSelf);$('#returnSectionTitle').textContent=adultSelf?'Solicitar correcciones al jugador':'Solicitar correcciones a la familia';$('#returnSectionText').textContent=adultSelf?'Indica exactamente qué información debe corregir o completar el jugador.':'Indica exactamente qué información debe corregir o completar la familia.';$('#returnToFamily').textContent=adultSelf?'↩ Solicitar correcciones al jugador':'↩ Solicitar correcciones a la familia';$('#returnHint').textContent=v.representation?'La familia verá este mensaje en su ficha.':adultSelf?'El jugador recibirá la solicitud en su propia ficha y por correo si tiene dirección informada.':'No hay un tutor activo ni autorrepresentación disponible.';
  renderAdminFederationRequirements(v);$('#adminFederationReadiness').innerHTML=readinessProgressHtml(v);$$('#adminFederationReadiness .tab-jump').forEach(x=>{const go=()=>setAdminPlayerTab(x.dataset.jumpTab);x.onclick=go;x.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();go()}}});updateAdminTabAlerts(v);const msTab=medicalState(v.medical?{date:v.medical.fecha_reconocimiento,expiry:v.medical.fecha_valido_hasta}:null);$('#adminMedicalTabSummary').innerHTML=`<div class="checklist"><div class="check"><span>Estado</span><strong>${esc(msTab.label)}</strong></div>${v.medical?`<div class="check"><span>Último reconocimiento</span><strong>${fmt(v.medical.fecha_reconocimiento)}</strong></div><div class="check"><span>Válido hasta</span><strong>${fmt(v.medical.fecha_valido_hasta)}</strong></div>`:''}${v.appointment?`<div class="check"><span>Próxima cita</span><strong>${esc(formatDateTime(v.appointment.fecha_hora))}</strong></div>`:''}</div>`;
  try{const hist=await loadRemoteHistory(v.inscription.id);const events=hist.map(h=>({date:String(h.fecha||''),title:remotePlayerStateLabel(v,h.estado_nuevo),detail:h.comentario||''}));for(const r of (v.representationHistory||[])){if(r.fecha_desde)events.push({date:String(r.fecha_desde),title:'Representación iniciada',detail:`${r.representativeName}${r.motivo_alta?' · '+r.motivo_alta:''}`});if(r.fecha_hasta)events.push({date:String(r.fecha_hasta),title:r.motivo_fin==='Mayoria de edad'?'Mayoría de edad / fin de representación':'Fin de representación',detail:`${r.representativeName}${r.motivo_fin?' · '+r.motivo_fin:''}${r.motivo_fin==='Mayoria de edad'?' · El jugador pasa a autorrepresentación.':''}`})}events.sort((a,b)=>b.date.localeCompare(a.date));$('#playerHistory').innerHTML=events.length?events.map(e=>`<div class="history-item"><strong>${esc(e.title)}</strong><span>${fmt(String(e.date||'').slice(0,10))}${e.detail?' · '+esc(e.detail):''}</span></div>`).join(''):'<div class="meta">Sin movimientos registrados.</div>'}catch(err){$('#playerHistory').innerHTML='<div class="meta">No se pudo cargar el histórico.</div>'}
  setAdminPlayerTab(activeAdminPlayerTab||'summary');$('#adminPlayerModal').showModal();
}
function openAdminPlayer(id){if(currentUser?.source==='supabase')return openRemoteAdminPlayer(id);alert('Esta ficha pertenece al prototipo local.');}
async function saveRemoteTeamAssignment(){const v=remoteClubPlayers.find(x=>x.id===selectedRemotePlayerId);if(!v||currentRole==='coach')return;const teamId=$('#adminTeam').value||null;if(['pendiente_revision_inicial','devuelta_familia','cancelada'].includes(v.inscription?.estado)){alert('Valida primero la inscripción inicial.');return}try{const old=v.assignment;if(old?.equipo_id===teamId)return;if(old){const {error}=await sb.from('asignaciones_jugador_equipo').update({fecha_hasta:isoToday(),motivo_cambio:teamId?'Cambio de equipo':'Equipo retirado'}).eq('id',old.id);if(error)throw error}if(teamId){const {error}=await sb.from('asignaciones_jugador_equipo').insert({inscripcion_id:v.inscription.id,equipo_id:teamId,fecha_desde:isoToday(),asignado_por:currentUser.authUserId||currentUser.id,motivo_cambio:old?'Cambio de equipo':'Asignación inicial'});if(error)throw error}await renderRemoteClub();await openRemoteAdminPlayer(v.id)}catch(err){alert(`No se ha podido guardar el equipo: ${err.message||err}`)}}
async function advanceRemoteSelected(){const v=remoteClubPlayers.find(x=>x.id===selectedRemotePlayerId);if(!v||currentRole==='coach')return;const order=['pendiente_revision_inicial','datos_validados','documentacion_validada','lista_para_federar','ficha_tramitada'];let ix=order.indexOf(v.inscription.estado);if(v.inscription.estado==='devuelta_familia')ix=0;const next=order[Math.min(Math.max(ix,0)+1,order.length-1)];const gate=validateRemoteFederationGate(v,next);if(gate){alert(gate);return}try{await updateRemoteInscriptionState(v,next,`Estado avanzado por ${currentUser.name}`,next==='datos_validados'?'':v.inscription.observaciones);await renderRemoteClub();await openRemoteAdminPlayer(v.id)}catch(err){alert(`No se ha podido avanzar el estado: ${err.message||err}`)}}
async function setRemoteWorkflowSelected(){const v=remoteClubPlayers.find(x=>x.id===selectedRemotePlayerId);if(!v||currentRole==='coach')return;const next=$('#adminWorkflow').value;if(!next)return;const gate=validateRemoteFederationGate(v,next);if(gate){alert(gate);$('#adminWorkflow').value=v.inscription.estado;return}try{await updateRemoteInscriptionState(v,next,`Estado cambiado manualmente por ${currentUser.name}`,next==='devuelta_familia'?v.inscription.observaciones||'Revisión solicitada por el club':'');await renderRemoteClub();await openRemoteAdminPlayer(v.id)}catch(err){alert(`No se ha podido guardar el estado: ${err.message||err}`)}}
async function returnRemoteSelected(){const v=remoteClubPlayers.find(x=>x.id===selectedRemotePlayerId);if(!v||currentRole==='coach')return;const msg=$('#returnMessage').value.trim(),adultSelf=remotePlayerIsAdult(v)&&!v.representation;if(!msg){alert(adultSelf?'Indica qué debe revisar el jugador.':'Indica qué debe revisar la familia.');return}if(!v.representation&&!adultSelf){alert('El jugador no tiene tutor activo ni puede autorrepresentarse.');return}const button=$('#returnToFamily');if(button?.disabled)return;const oldText=button?.textContent||'';if(button){button.disabled=true;button.textContent='Enviando…'}try{const {error}=await sb.rpc('solicitar_correcciones_inscripcion',{p_inscripcion_id:v.inscription.id,p_mensaje:msg});if(error)throw error;await tryProcessNotifications();$('#adminPlayerModal').close();await renderRemoteClub();alert(adultSelf?'Solicitud enviada al jugador.':'Solicitud enviada a la familia.')}catch(err){alert(`No se han podido solicitar las correcciones: ${err.message||err}`)}finally{if(button){button.disabled=false;button.textContent=oldText}}}
async function toggleRemotePlayerActive(){const v=remoteClubPlayers.find(x=>x.id===selectedRemotePlayerId);if(!v||!['admin','club'].includes(currentRole))return;try{const next=!v.active;const patch={activo:next};if(!next){patch.fecha_baja=isoToday();patch.motivo_baja='Baja operativa desde panel del club'}else{patch.fecha_baja=null;patch.motivo_baja=null}const {error}=await sb.from('jugadores').update(patch).eq('id',v.id);if(error)throw error;await renderRemoteClub();await openRemoteAdminPlayer(v.id)}catch(err){alert(`No se ha podido cambiar el estado del jugador: ${err.message||err}`)}}
function playerEmailIsRequired(birth,personId=''){const age=ageOn(birth);return (age!==null&&age>=16&&age<18)||familyCoachConsentsFor(personId).some(x=>['pendiente_email','pendiente','aceptada'].includes(x.estado))}
function playerDocumentIsRequired(birth){const age=ageOn(birth);return age!==null&&age>=14&&age<18}
function syncPlayerRequirements(){const f=$('#playerForm');if(!f)return;const p=editingPlayerId?remoteFamilyPlayers.find(x=>x.id===editingPlayerId):null,birth=String(f.elements.birth?.value||''),emailRequired=playerEmailIsRequired(birth,p?.personId||''),docRequired=playerDocumentIsRequired(birth);if(f.elements.playerEmail)f.elements.playerEmail.required=emailRequired;if(f.elements.playerEmailConfirm)f.elements.playerEmailConfirm.required=emailRequired;const label=$('#playerEmailRequirementLabel'),confirmLabel=$('#playerEmailConfirmRequirementLabel'),hint=$('#playerEmailHint');if(label)label.textContent=emailRequired?'(obligatorio)':'(opcional hasta los 15 años)';if(confirmLabel)confirmLabel.textContent=emailRequired?'(obligatorio)':'(opcional)';const coachNeeds=familyCoachConsentsFor(p?.personId||'').some(x=>['pendiente_email','pendiente','aceptada'].includes(x.estado));if(hint)hint.textContent=emailRequired?(coachNeeds?'Correo obligatorio para ejercer como entrenador menor.':'Necesitamos un correo propio del jugador para continuar con su gestión y preparar su autonomía digital.'):'Será obligatorio desde los 16 años y también para ejercer como entrenador menor.';if(f.elements.dni)f.elements.dni.required=docRequired;if(f.elements.childDocumentType)f.elements.childDocumentType.required=docRequired;const dl=$('#childDocumentRequirementLabel'),dtl=$('#childDocumentTypeRequirementLabel'),dh=$('#childDocumentHint');if(dl)dl.textContent=docRequired?'(obligatorio)':'(opcional hasta los 13 años)';if(dtl)dtl.textContent=docRequired?'(DNI/NIE obligatorio)':'(opcional hasta los 13 años)';if(dh)dh.textContent=docRequired?'DNI o NIE obligatorio a partir de los 14 años.':'DNI/NIE obligatorio a partir de los 14 años.'}
const syncPlayerEmailRequirement=syncPlayerRequirements;
async function openSelfPlayerEdit(id){
  const p=remoteFamilyPlayers.find(x=>x.id===id);if(!p||currentRole!=='player')return;
  const correctionMode=p.inscription?.estado==='devuelta_familia';
  const parts=p.name.split(' '),dlg=document.createElement('dialog');dlg.className='account-access-modal';
  const correctionHtml=correctionMode?`<div class="family-alert correction-context"><strong>Correcciones solicitadas por el club</strong><p>${esc(p.inscription?.observaciones||'Revisa los datos de tu ficha y confirma que son correctos.')}</p></div>`:'';
  dlg.innerHTML=`<form class="admin-detail self-player-form"><div class="modal-head"><div><span class="eyebrow dark">${correctionMode?'Revisión de ficha':'Mi ficha'}</span><h2>${correctionMode?'Revisar y responder al club':'Modificar mis datos'}</h2><div class="meta">${correctionMode?'Revisa la indicación del club. Puedes confirmar los datos aunque no necesites modificar ningún campo.':'Los cambios sensibles vuelven a dejar la ficha pendiente de revisión por el club. El correo se cambia desde Perfil.'}</div></div><button type="button" class="icon-button close-self">✕</button></div>${correctionHtml}<div class="form-grid"><label>Nombre<input name="name" required value="${esc(parts[0]||'')}"></label><label>Primer apellido<input name="surname1" required value="${esc(parts[1]||'')}"></label><label>Segundo apellido<input name="surname2" value="${esc(parts.slice(2).join(' '))}"></label><label>Fecha de nacimiento<input name="birth" type="date" required value="${esc(p.birth||'')}"></label><label>Teléfono<input name="phone" type="tel" value="${esc(p.playerPhone||'')}"></label><label>Correo electrónico<input value="${esc(p.playerEmail||'')}" readonly class="readonly-field"><small>Se modifica desde Perfil.</small></label><label>Tipo de documento<select name="docType"><option value="dni">DNI</option><option value="nie">NIE</option></select></label><label>Número de documento<input name="docNumber" required value="${esc(p.childDocumentNumber||'')}"></label></div><div class="modal-actions"><button type="button" class="secondary close-self">Cancelar</button><button type="submit" class="primary">${correctionMode?'✓ Guardar y enviar al club para revisión':'Guardar cambios'}</button></div></form>`;
  document.body.appendChild(dlg);dlg.querySelector('[name="docType"]').value=['dni','nie'].includes(p.childDocumentType)?p.childDocumentType:'dni';dlg.querySelectorAll('.close-self').forEach(x=>x.onclick=()=>dlg.close());
  dlg.querySelector('form').onsubmit=async e=>{e.preventDefault();const fd=new FormData(e.currentTarget),docType=String(fd.get('docType')||''),docNumber=normDni(fd.get('docNumber')||''),name=String(fd.get('name')||'').trim(),surname1=String(fd.get('surname1')||'').trim(),surname2=String(fd.get('surname2')||'').trim(),birth=String(fd.get('birth')||''),phone=String(fd.get('phone')||'').trim();const de=validateSpanishIdentity(docType,docNumber,{required:true});if(de){alert(de);return}const oldParts=p.name.split(' '),sensitiveChanged=name!==(oldParts[0]||'')||surname1!==(oldParts[1]||'')||surname2!==oldParts.slice(2).join(' ')||birth!==String(p.birth||'')||docType!==String(p.childDocumentType||'').toLowerCase()||docNumber!==normDni(p.childDocumentNumber||'');const contactChanged=phone!==String(p.playerPhone||'').trim(),anyChanged=sensitiveChanged||contactChanged;if(!correctionMode&&!anyChanged){alert('No hay cambios que guardar.');return}const submit=e.currentTarget.querySelector('[type="submit"]');const originalText=submit.textContent;submit.disabled=true;submit.textContent=correctionMode?'Enviando al club…':'Guardando…';try{const rpc=correctionMode?'responder_correcciones_jugador':'actualizar_jugador_autorrepresentado';const {error}=await sb.rpc(rpc,{p_nombre:name,p_primer_apellido:surname1,p_segundo_apellido:surname2||null,p_fecha_nacimiento:birth,p_telefono:phone||null,p_tipo_documento:docType,p_numero_documento:docNumber});if(error)throw error;dlg.close();dlg.remove();await renderRemoteFamily();alert(correctionMode?'Correcciones enviadas al club para revisión.':sensitiveChanged?'Datos identificativos actualizados. La ficha queda pendiente de revisión por el club.':'Datos de contacto actualizados.')}catch(err){alert(`No se han podido guardar los cambios: ${err.message||err}`)}finally{submit.disabled=false;submit.textContent=originalText}};
  dlg.addEventListener('close',()=>dlg.remove(),{once:true});dlg.showModal();
}
async function openRemoteFamilyEdit(id){
  const p=remoteFamilyPlayers.find(x=>x.id===id);if(!p||currentRole!=='family')return;
  editingPlayerId=id;editingFromCorrection=p.inscription?.estado==='devuelta_familia';
  const parts=p.name.split(' '),f=$('#playerForm');f.reset();
  f.elements.name.value=parts[0]||'';f.elements.surname1.value=parts[1]||'';f.elements.surname2.value=parts.slice(2).join(' ');f.elements.birth.value=p.birth||'';
  if(f.elements.playerEmail)f.elements.playerEmail.value=p.playerEmail||'';if(f.elements.playerEmailConfirm)f.elements.playerEmailConfirm.value=p.playerEmail||'';
  if(f.elements.childDocumentType&&p.childDocumentType)f.elements.childDocumentType.value=p.childDocumentType;if(f.elements.dni)f.elements.dni.value=p.childDocumentNumber||'';
  f.elements.email.value=currentUser.email||'';f.elements.phone.value=currentUser.phone||'';
  syncGuardianDocumentField();syncPlayerRequirements();
  $('#playerModalEyebrow').textContent=editingFromCorrection?'Revisión de ficha':'Datos del jugador';
  $('#playerModalTitle').textContent='Revisar datos del jugador';
  const context=$('#playerCorrectionContext'),message=$('#playerCorrectionMessage');
  context?.classList.toggle('hidden',!editingFromCorrection);if(message)message.textContent=editingFromCorrection?(p.inscription?.observaciones||'Revisa los datos y confirma que son correctos.'):'';
  $('#savePlayer').textContent=editingFromCorrection?'✓ Guardar y enviar al club para revisión':'Guardar cambios';
  refreshCalculatedCategory(f);blockPasteOnEmailConfirm(f);$('#playerModal').showModal();
}

function mustChangeTemporaryPassword(authUser){return authUser?.app_metadata?.must_change_password===true}
async function invokeAccessManager(body){
  if(!sb)throw new Error('No se ha podido cargar Supabase.');
  const {data,error}=await sb.functions.invoke('gestionar-acceso',{body});
  if(error){
    const msg=data?.error||data?.message||error.message||'Error en la gestión de acceso';
    throw new Error(msg);
  }
  if(data?.error)throw new Error(data.error);
  return data;
}
async function changeOwnPassword(password){
  // La Edge Function actualiza la contraseña y limpia must_change_password.
  // No forzamos refreshSession aquí: en una sesión nacida de una invitación
  // el refresh token puede no estar disponible todavía y Supabase devolvería
  // 'Invalid Refresh Token' aunque la actualización ya se hubiera realizado.
  return await invokeAccessManager({action:'change_own_password',new_password:password});
}
function promptMandatoryPasswordChange(authUser){
  return new Promise(resolve=>{
    const dialog=$('#forcePasswordChangeModal'),form=$('#forcePasswordChangeForm');
    if(!dialog||!form){resolve(authUser);return}
    form.reset();dialog.oncancel=e=>e.preventDefault();
    $('#forcePasswordLogout').onclick=async()=>{await sb.auth.signOut();dialog.close();currentUser=null;currentRole=null;showAuth('login');resolve(null)};
    form.onsubmit=async e=>{e.preventDefault();const fd=new FormData(form),p=String(fd.get('password')||''),p2=String(fd.get('password2')||''),btn=form.querySelector('button[type="submit"]');if(p!==p2){alert('Las contraseñas no coinciden.');return}if(p.length<8){alert('La contraseña debe tener al menos 8 caracteres.');return}btn.disabled=true;btn.textContent='Actualizando…';try{await changeOwnPassword(p);const {data,error}=await sb.auth.getUser();if(error)throw error;dialog.close();resolve(data.user)}catch(err){alert(`No se ha podido cambiar la contraseña: ${err.message||err}`)}finally{btn.disabled=false;btn.textContent='Guardar contraseña y continuar'}};
    dialog.showModal();
  });
}
async function prepareAuthenticatedUser(authUser){
  if(!authUser)return null;
  if(mustChangeTemporaryPassword(authUser))return await promptMandatoryPasswordChange(authUser);
  return authUser;
}
function setSimpleTabs(scope,tab){const root=$(scope);if(!root)return;root.querySelectorAll('[data-account-tab]').forEach(b=>b.classList.toggle('active',b.dataset.accountTab===tab));root.querySelectorAll('[data-account-panel]').forEach(p=>p.classList.toggle('active',p.dataset.accountPanel===tab))}
function setMedicalTab(tab){const root=$('#medicalModal');if(!root)return;root.querySelectorAll('[data-medical-tab]').forEach(b=>b.classList.toggle('active',b.dataset.medicalTab===tab));root.querySelectorAll('[data-medical-panel]').forEach(p=>p.classList.toggle('active',p.dataset.medicalPanel===tab))}
function openAccountProfile(){
  if(!currentUser)return;const d=$('#accountProfileModal');if(!d)return;
  $('#accountProfileMeta').textContent=currentUser.email||currentUser.name||'';
  $('#accountProfileRoles').innerHTML=availableRoles(currentUser).map(r=>`<span class="role-badge">${esc(roleLabel(r))}</span>`).join('');
  $('#accountPasswordForm').reset();if($('#accountEmail'))$('#accountEmail').value=currentUser.email||'';if($('#accountEmailConfirm'))$('#accountEmailConfirm').value=currentUser.email||'';const ef=$('#accountEmailFeedback');if(ef){ef.hidden=true;ef.textContent=''}const av=$('#selfCoachAvailabilityWrap'),c=coaches.find(x=>x.personId===currentUser.personId||x.userId===currentUser.authUserId),tab=$('#accountAvailabilityTab'),empty=$('#accountNoCoachAvailability');if(av){av.hidden=!c;if(c)renderCoachAvailabilityPanel('#selfCoachAvailabilityPanel',c,{self:true})}if(tab)tab.hidden=!c;if(empty)empty.hidden=!!c;setSimpleTabs('#accountProfileModal','profile');d.showModal();
}
async function createTemporaryAccessForSelectedPerson(){
  const p=dbPersons.find(x=>x.id===selectedPersonAdminId);if(!p)return;
  if(!p.email_contacto){alert('La Persona necesita un correo electrónico antes de enviar la invitación.');return}
  const roles=remotePersonRoleCodes(p.id);if(!roles.some(r=>['administrador','club','entrenador'].includes(r))){alert('Asigna primero Administrador, Club o Entrenador.');return}
  const b=$('#createTemporaryAccess');if(b){b.disabled=true;b.textContent='Enviando invitación…'}
  try{
    const data=await invokeAccessManager({action:'invite_internal_user',persona_id:p.id,redirect_to:AUTH_REDIRECT_URL});
    await loadSupabasePersons();renderPersons();await openPersonAdmin(p.id,'access');
    alert(data.invitation_sent?'Invitación enviada. El usuario podrá establecer su propia contraseña desde el correo recibido.':'La cuenta ya existía y ha quedado vinculada a esta Persona.');
  }catch(err){alert(`No se ha podido preparar el acceso: ${err.message||err}`)}finally{if(b){b.disabled=false;b.textContent='Enviar invitación de acceso'}}
}

async function getInternalAccessState(personId){
  if(!personId)return null;
  return await invokeAccessManager({action:'get_internal_access_state',persona_id:personId});
}
async function resendInternalInvitationForSelectedPerson(){
  const p=dbPersons.find(x=>x.id===selectedPersonAdminId);if(!p)return;
  const b=$('#resendInternalInvitation');if(b){b.disabled=true;b.textContent='Enviando…'}
  try{
    await invokeAccessManager({action:'resend_internal_invitation',persona_id:p.id,redirect_to:AUTH_REDIRECT_URL});
    await openPersonAdmin(p.id,'access');
    alert('Nuevo enlace de activación enviado. Utiliza el correo más reciente para establecer la contraseña.');
  }catch(err){alert(`No se ha podido reenviar el enlace de activación: ${err.message||err}`)}finally{if(b){b.disabled=false;b.textContent='Reenviar enlace de activación'}}
}

async function restoreSupabaseSession(){
  if(!sb){showAuth('login');alert('No se ha podido cargar el cliente de Supabase. Comprueba la conexión a Internet.');return;}
  try{
    const {data,error}=await sb.auth.getSession();
    if(error)throw error;
    let authUser=data.session?.user||null;
    if(!authUser){currentUser=null;currentRole=null;localStorage.removeItem(K.sessionRole);showAuth('login');return;}
    authUser=await prepareAuthenticatedUser(authUser);if(!authUser)return;
    await processAdultTransitions();
    currentUser=await loadIdentityWithPending(authUser);
    await loadSupabaseStructure();
    await tryProcessNotifications();
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

function setConfirmationContext(email='',message=''){const box=$('#confirmationContext'),input=$('#loginForm')?.elements?.email,text=$('#confirmationContextText');if(!box)return;const value=String(email||input?.value||'').trim().toLowerCase();if(value&&input&&!input.value)input.value=value;if(text)text.textContent=message||`Revisa el correo que enviamos a ${value||'tu dirección'} al registrarte.`;box.classList.remove('hidden')}
function clearConfirmationContext(){const box=$('#confirmationContext');if(box)box.classList.add('hidden')}
function showAuth(mode='login'){ $('#authScreen').classList.remove('hidden');$('#appShell').classList.add('hidden');const login=mode==='login';$('#loginForm').classList.toggle('hidden',!login);$('#familySignupForm').classList.toggle('hidden',login);$('#showLogin').classList.toggle('active',login);$('#showFamilySignup').classList.toggle('active',!login);$('#authSeasonLabel').textContent=currentSeason()?.name||'2026/2027';if(!login)clearConfirmationContext() }
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
  if(familyLike){['clubView','medicalView','coachesView','structureView','usersView','personsView'].forEach(v=>$('#'+v)?.classList.remove('active'));$('#addPlayerButton').classList.toggle('hidden',currentRole==='player');$('#familyHeroEyebrow').textContent=currentRole==='player'?'Área del jugador':'Área de familias';$('#familyHeroTitle').textContent=currentRole==='player'?'Gestiona tu ficha desde el móvil':'Gestiona la ficha de los menores a tu cargo';$('#familyHeroText').textContent=currentRole==='player'?'Consulta tu inscripción, documentación y estado federativo.':'Completa datos, adjunta documentación y consulta el estado de cada inscripción.';$('#familyTitle').textContent=currentRole==='player'?'Mi ficha':currentUser.name;const fpEyebrow=$('#familyPlayersSection .eyebrow');if(fpEyebrow){fpEyebrow.hidden=currentRole==='player';fpEyebrow.textContent='Mis jugadores';}const fsEyebrow=$('#familyStatusSection .eyebrow');if(fsEyebrow)fsEyebrow.textContent=currentRole==='player'?'Estado de mi ficha':'Estado familiar';(currentUser.source==='supabase'?renderRemoteFamily():renderFamily());return}
  $('#familyView').classList.remove('active');setView('clubView');const isCoach=currentRole==='coach';
  const medicalNavButton=$('#medicalNavButton'),coachesNavButton=$('#coachesNavButton'),structureNavButton=$('#structureNavButton'),usersNavButton=$('#usersNavButton'),personsNavButton=$('#personsNavButton'),openCoachModal=$('#openCoachModal');
  if(medicalNavButton)medicalNavButton.style.display=isCoach?'none':'flex';
  if(coachesNavButton)coachesNavButton.style.display=isCoach?'none':'flex';
  if(structureNavButton)structureNavButton.style.display=isCoach?'none':'flex';
  // V61 consolidó Usuarios dentro de Personas. usersNavButton es opcional para mantener compatibilidad con HTML anterior.
  if(usersNavButton)usersNavButton.style.display=currentRole==='admin'?'flex':'none';
  if(personsNavButton)personsNavButton.style.display=currentRole==='admin'?'flex':'none';
  if(openCoachModal)openCoachModal.style.display=currentRole==='admin'?'inline-flex':'none';
  if($('#paymentPendingStat'))$('#paymentPendingStat').style.display=isCoach?'none':'';if($('#paymentTableHead'))$('#paymentTableHead').style.display=isCoach?'none':'';if(isCoach&&clubQuickFilter==='payment')clubQuickFilter='all';
  const clubNav=$('#clubNav'),clubHeroTitle=$('#clubHeroTitle'),clubHeroText=$('#clubHeroText');
  if(clubNav)clubNav.style.gridTemplateColumns=isCoach?'repeat(2,1fr)':currentRole==='admin'?'repeat(6,1fr)':'repeat(5,1fr)';
  if(clubHeroTitle)clubHeroTitle.textContent=isCoach?'Jugadores de mis equipos':'Control de fichas federativas';
  if(clubHeroText)clubHeroText.textContent=isCoach?'Consulta los jugadores asignados a tus equipos con una asignación vigente.':'Revisa inscripciones, representación, equipos, reconocimientos y preparación federativa.';
  renderClub();if(!isCoach){renderMedical();renderCoaches();renderStructure()}if(currentRole==='admin'){renderClubUsers();renderPersons();}
}

function renderFamily(){
  const mine=familyAccessPlayers();
  $('#playersList').innerHTML=mine.length?mine.map(p=>{const v=playerVM(p),i=v.i;if(!i)return '';const rep=v.rep;const repLine=currentRole==='player'?'Autorrepresentación activa':`Tutor activo: ${esc(repUserName(rep))}`;return `<article class="player-card ${i.familyActionRequired?'needs-action':''}"><div class="row"><div><h3>${esc(p.name)}</h3><div class="meta">${esc(v.category)} · ${esc(seasonName(i.seasonId))}</div></div><span class="status ${i.familyActionRequired?'returned':i.status}">${i.familyActionRequired?'↩ Revisar':i.status==='complete'?'✓ Completa':'⚠ Pendiente'}</span></div><div class="meta representation-line">${repLine}</div>${i.familyActionRequired?`<div class="family-alert"><strong>El club solicita cambios</strong><p>${esc(i.returnMessage||'Revisa la información de la ficha.')}</p><button class="primary small edit-family" data-id="${esc(p.id)}">Revisar y modificar</button></div>`:''}<div class="checklist"><div class="check"><span>Datos personales</span><strong>${p.data?'✓':'!'}</strong></div><div class="check"><span>Documentación</span><strong>${esc(i.docs)}</strong></div><div class="check"><span>Equipo</span><strong>${esc(v.team)}</strong></div><div class="check"><span>Federación</span><strong>${esc(i.federation)}</strong></div></div></article>`}).join(''):'<div class="empty-card">No hay jugadores asociados a tu cuenta.</div>';
  $$('.edit-family').forEach(b=>b.onclick=()=>openPlayerForEdit(b.dataset.id));$('#familyPlayerCount').textContent=currentRole==='player'?'1 jugador · autorrepresentación':`${mine.length} ${mine.length===1?'jugador representado':'jugadores representados'}`;
}
function quickFilterLabel(kind,value){const maps={club:{all:'Todos los jugadores',complete:'Completos',docs:'Documentos pendientes',review:'Por revisar',medical90:'RRMM vence ≤ 90 días',adult30:'Mayoría de edad ≤ 30 días',payment:'Pago pendiente'},medical:{all:'Todos los jugadores',ok:'Vigente > 90 días',soon:'Vence ≤ 90 días',expired_or_missing:'Vencidos / sin RRMM'}};return maps[kind]?.[value]||value}
function updateQuickFilterUI(){
  $$('[data-club-quick]').forEach(x=>x.classList.toggle('active-filter',x.dataset.clubQuick===clubQuickFilter));
  $$('[data-medical-quick]').forEach(x=>x.classList.toggle('active-filter',x.dataset.medicalQuick===medicalQuickFilter));
  const c=$('#clubQuickFilterChip');if(c){c.classList.toggle('hidden',clubQuickFilter==='all');c.innerHTML=clubQuickFilter==='all'?'':`Filtro rápido: <strong>${esc(quickFilterLabel('club',clubQuickFilter))}</strong> <button type="button" aria-label="Quitar filtro">×</button>`;const b=c.querySelector('button');if(b)b.onclick=()=>{clubQuickFilter='all';renderClub()}}
  const m=$('#medicalQuickFilterChip');if(m){m.classList.toggle('hidden',medicalQuickFilter==='all');m.innerHTML=medicalQuickFilter==='all'?'':`Filtro rápido: <strong>${esc(quickFilterLabel('medical',medicalQuickFilter))}</strong> <button type="button" aria-label="Quitar filtro">×</button>`;const b=m.querySelector('button');if(b)b.onclick=()=>{medicalQuickFilter='all';renderMedical()}}
}
function renderClub(){if(currentUser?.source==='supabase')return renderRemoteClub();return renderLocalClub();}
function renderLocalClub(){
  const source=visiblePlayers().map(playerVM).filter(v=>v.i);
  const q=$('#searchInput').value.trim().toLowerCase(),f=$('#statusFilter').value,cf=$('#clubCategoryFilter')?.value||'all',af=$('#clubActiveFilter')?.value||'active';
  const catSel=$('#clubCategoryFilter');if(catSel){const prev=catSel.value||'all';catSel.innerHTML='<option value="all">Todas las categorías</option>'+categories.filter(c=>c.active).map(c=>`<option value="${c.id}">${esc(c.name)}</option>`).join('');if([...catSel.options].some(o=>o.value===prev))catSel.value=prev}
  const rows=source.filter(v=>{const d=daysTo18(v.p);const quick=clubQuickFilter==='all'||(clubQuickFilter==='complete'&&v.i.status==='complete')||(clubQuickFilter==='docs'&&v.i.docs!=='Completa')||(clubQuickFilter==='review'&&(v.i.workflow==='review'||v.i.familyActionRequired))||(clubQuickFilter==='medical90'&&medicalState(latestMedical(v.p.id)).key==='soon')||(clubQuickFilter==='adult30'&&d!==null&&d>=0&&d<=30&&!currentPlayerUser(v.p));return quick&&(f==='all'||v.i.status===f)&&(cf==='all'||v.i.categoryId===cf)&&(af==='all'||(af==='active')===(v.p.active!==false))&&v.p.name.toLowerCase().includes(q)});
  $('#adminTable').innerHTML=rows.length?rows.map(v=>`<tr class="admin-row ${v.p.active===false?'inactive-row':''}" data-id="${esc(v.p.id)}" tabindex="0"><td><strong>${esc(v.p.name)}</strong>${v.p.active===false?'<div class="meta inactive-note">Jugador inactivo</div>':''}${v.i.familyActionRequired?'<div class="meta return-note">Devuelto a familia</div>':''}${adultAlertHtml(v.p)}</td><td>${esc(repUserName(v.rep))}</td><td>${esc(v.category)}</td><td><strong>${esc(v.team)}</strong></td><td><span class="status ${v.p.active!==false?'complete':'returned'}">${v.p.active!==false?'Activo':'Inactivo'}</span></td><td><span class="dot ${v.p.data?'ok':'warn'}">${v.p.data?'✓ Completo':'⚠ Revisar'}</span></td><td>${esc(v.i.docs)}</td><td>—</td><td><span class="workflow-pill ${esc(v.i.workflow)}">${esc(workflowLabel(v.i.workflow))}</span></td></tr>`).join(''):'<tr><td colspan="10">No hay jugadores que coincidan con los filtros.</td></tr>';
  $$('.admin-row').forEach(r=>{r.onclick=()=>openAdminPlayer(r.dataset.id);r.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();openAdminPlayer(r.dataset.id)}}});
  const operational=source.filter(v=>v.p.active!==false);$('#statPlayers').textContent=operational.length;$('#statComplete').textContent=operational.filter(v=>v.i.status==='complete').length;$('#statDocs').textContent=operational.filter(v=>v.i.docs!=='Completa').length;$('#statReview').textContent=operational.filter(v=>v.i.workflow==='review'||v.i.familyActionRequired).length;$('#statMedical90').textContent=operational.filter(v=>medicalState(latestMedical(v.p.id)).key==='soon').length;$('#statAdult30').textContent=operational.filter(v=>{const d=daysTo18(v.p);return d!==null&&d>=0&&d<=30&&!currentPlayerUser(v.p)}).length;updateQuickFilterUI();
}
function adultAlertHtml(p){const d=daysTo18(p),a=ageOn(p.birth);if(a!==null&&a>=18&&!currentPlayerUser(p)&&!activeRepresentation(p.id)?.legalException)return '<div class="meta adult-alert">⚠ Pendiente autorrepresentación</div>';if(d!==null&&d>=0&&d<=30&&!currentPlayerUser(p))return `<div class="meta adult-alert">Cumple 18 en ${d} días</div>`;return ''}

function formatDateTime(v){if(!v)return '—';const d=new Date(v);return Number.isNaN(d.getTime())?'—':new Intl.DateTimeFormat('es-ES',{dateStyle:'short',timeStyle:'short'}).format(d)}
function medicalState(m){if(!m?.expiry)return {key:'missing',label:'Sin fecha',days:null,window:null};const days=dayDiff(isoToday(),m.expiry);if(days<0)return {key:'expired',label:'Vencido',days,window:'expired'};if(days<=30)return {key:'soon',label:`Vence en ${days} días`,days,window:'30'};if(days<=90)return {key:'soon',label:`Vence en ${days} días`,days,window:'90'};return {key:'ok',label:'En vigor',days,window:'ok'}}
function medicalVisualClass(m){return m?.key==='ok'?'complete':m?.key==='soon'?(m?.window==='30'?'medical-urgent':'pending'):'returned'}
function medicalGuidance(m,expiry){if(m?.key==='ok')return `Válido hasta ${fmt(expiry)}. No es necesario programar una renovación todavía.`;if(m?.key==='soon'&&m?.window==='30')return `Vence en los próximos 30 días${expiry?' · '+fmt(expiry):''}. Conviene programar la renovación cuanto antes.`;if(m?.key==='soon')return `Vence en los próximos 90 días${expiry?' · '+fmt(expiry):''}. Conviene planificar la renovación.`;if(m?.key==='expired')return `El reconocimiento está vencido${expiry?' desde '+fmt(expiry):''}. Programa una nueva cita RRMM.`;return 'No hay un reconocimiento médico vigente registrado. Programa una cita RRMM si corresponde.'}
async function renderRemoteMedical(){
  if(!$('#medicalTable'))return;
  try{
    await loadRemoteClubData();
    const q=($('#medicalSearch')?.value||'').trim().toLowerCase(),f=$('#medicalFilter')?.value||'all';
    const source=remoteClubPlayers.filter(v=>v.active).map(v=>{const m=v.medical?{date:v.medical.fecha_reconocimiento,expiry:v.medical.fecha_valido_hasta}:null;return {...v,m,state:medicalState(m)}});
    const rows=source.filter(x=>{const appt=!!x.appointment;const special=f==='appointment_scheduled'?appt:f==='appointment_pending'?(x.state.key==='soon'&&!appt):null;const quick=medicalQuickFilter==='all'||x.state.key===medicalQuickFilter||(medicalQuickFilter==='expired_or_missing'&&['expired','missing'].includes(x.state.key));return quick&&(!q||x.name.toLowerCase().includes(q))&&(f==='all'||(special!==null?special:x.state.key===f))});
    $('#medicalTable').innerHTML=rows.length?rows.map(x=>{const ap=x.appointment;const apHtml=ap?`<span class="appointment-badge scheduled">📅 ${esc(formatDateTime(ap.fecha_hora))}</span><div class="meta">${esc(ap.lugar||'')}</div>`:(x.state.key==='soon'?'<span class="appointment-badge pending">⚠ Cita pendiente</span>':'—');return `<tr class="medical-row" data-id="${esc(x.id)}" tabindex="0"><td><strong>${esc(x.name)}</strong></td><td>${esc(x.categoryName)}</td><td>${fmt(x.m?.date)}</td><td>${fmt(x.m?.expiry)}</td><td><span class="medical-badge ${x.state.key}">${esc(x.state.label)}</span></td><td>${apHtml}</td></tr>`}).join(''):'<tr><td colspan="6">No hay jugadores que coincidan con el filtro.</td></tr>';
    $$('.medical-row').forEach(r=>{r.onclick=()=>openRemoteMedical(r.dataset.id);r.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();openRemoteMedical(r.dataset.id)}}});
    $('#medicalTotal').textContent=source.length;$('#medicalOk').textContent=source.filter(x=>x.state.key==='ok').length;$('#medicalSoon').textContent=source.filter(x=>x.state.key==='soon').length;$('#medicalExpired').textContent=source.filter(x=>['expired','missing'].includes(x.state.key)).length;updateQuickFilterUI();
  }catch(err){console.error('Carga RRMM Supabase',err);$('#medicalTable').innerHTML=`<tr><td colspan="5">No se pudieron cargar los reconocimientos: ${esc(err.message||err)}</td></tr>`}
}
let editingMedicalAppointment=false;
function localDateTimeInputValue(v){if(!v)return '';const d=new Date(v);if(Number.isNaN(d.getTime()))return '';const pad=n=>String(n).padStart(2,'0');return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`}
function medicalAppointmentNotificationHtml(v){const rows=v?.appointmentNotifications||[];if(!v?.appointment)return '';if(!rows.length)return 'Notificación todavía no generada.';const sent=rows.filter(x=>x.estado==='enviado').length,pending=rows.filter(x=>x.estado==='pendiente').length,errors=rows.filter(x=>x.estado==='error').length;const parts=[];if(sent)parts.push(`✓ ${sent} ${sent===1?'notificación enviada':'notificaciones enviadas'}`);if(pending)parts.push(`⏳ ${pending} pendiente${pending===1?'':'s'}`);if(errors)parts.push(`⚠ ${errors} con error`);return parts.join(' · ')||'Notificaciones canceladas.'}
function renderMedicalRecognitionStatus(v){const box=$('#medicalRecognitionStatus');if(!box)return;const raw=v?.medical?{date:v.medical.fecha_reconocimiento,expiry:v.medical.fecha_valido_hasta}:null;const st=medicalState(raw);const needsAction=['soon','expired','missing'].includes(st.key);box.innerHTML=`<div class="medical-status-card ${st.key}${st.window==='30'?' urgent':''}"><div><span class="meta">Estado actual</span><strong class="status ${medicalVisualClass(st)}">${esc(st.label)}</strong><p>${esc(medicalGuidance(st,raw?.expiry))}</p></div>${needsAction?'<button type="button" class="secondary small" id="jumpToMedicalAppointment">Programar cita RRMM</button>':''}</div>`;const b=$('#jumpToMedicalAppointment');if(b)b.onclick=()=>setMedicalTab('appointment')}
function setMedicalAppointmentEditor(v,edit=false){
  const f=$('#medicalForm'),ap=v?.appointment||null;editingMedicalAppointment=!!(ap&&edit);
  const editor=$('#medicalAppointmentEditor'),actions=$('#medicalAppointmentActions'),current=$('#medicalAppointmentCurrent'),cancelEdit=$('#cancelMedicalAppointmentEdit'),save=$('#saveMedicalAppointment');
  if(ap&&!edit){
    current.innerHTML=`<div class="appointment-summary"><strong>📅 ${esc(formatDateTime(ap.fecha_hora))}</strong><div>${esc(ap.lugar||'')}</div>${ap.direccion?`<div>${esc(ap.direccion)}</div>`:''}${ap.indicaciones?`<div class="meta">${esc(ap.indicaciones)}</div>`:''}</div>`;
    editor.hidden=true;actions.hidden=false;cancelEdit.hidden=true;
  }else{
    current.innerHTML=ap?'<div class="meta">Editando la cita programada.</div>':'<div class="meta">Sin cita programada.</div>';
    editor.hidden=false;actions.hidden=true;cancelEdit.hidden=!ap;
    f.elements.appointmentDateTime.value=ap?localDateTimeInputValue(ap.fecha_hora):'';
    f.elements.appointmentPlace.value=ap?.lugar||'';f.elements.appointmentAddress.value=ap?.direccion||'';f.elements.appointmentNotes.value=ap?.indicaciones||'';
    save.textContent=ap?'Guardar cambios y comunicar':'Guardar y comunicar cita';
  }
  $('#medicalAppointmentNotification').textContent=medicalAppointmentNotificationHtml(v);
}
async function openRemoteMedical(id){
  const v=remoteClubPlayers.find(x=>x.id===id);if(!v)return;selectedMedicalPlayerId=id;
  $('#medicalPlayerName').textContent=v.name;$('#medicalPlayerMeta').textContent=v.categoryName;
  const f=$('#medicalForm'),m=v.medical;f.elements.medicalDate.value=m?.fecha_reconocimiento||'';f.elements.medicalExpiry.value=m?.fecha_valido_hasta||'';
  renderMedicalRecognitionStatus(v);
  setMedicalAppointmentEditor(v,false);
  const hist=(v.medicals||[]).slice().sort((a,b)=>String(b.fecha_reconocimiento||'').localeCompare(String(a.fecha_reconocimiento||'')));
  $('#medicalHistory').innerHTML=hist.length?hist.map(x=>`<div class="history-item"><strong>${fmt(x.fecha_reconocimiento)} → ${fmt(x.fecha_valido_hasta)}</strong><span>${x.fecha_validacion_rffm?'Validado '+fmt(x.fecha_validacion_rffm):'Registrado por el club'}${x.centro_medico?' · '+esc(x.centro_medico):''}</span></div>`).join(''):'<div class="meta">Sin reconocimientos anteriores.</div>';
  const dateInput=f.elements.medicalDate,expiryInput=f.elements.medicalExpiry;if(dateInput&&!dateInput.dataset.v83Bound){dateInput.dataset.v83Bound='1';dateInput.addEventListener('change',()=>{if(dateInput.value)expiryInput.value=addMonths(dateInput.value,18)})}
  setMedicalTab('recognition');$('#medicalModal').showModal();
}
async function tryProcessNotifications(){
  if(!sb||!currentUser||!(currentUser.roles||[]).some(r=>['admin','club'].includes(r)))return null;
  try{const {data,error}=await sb.functions.invoke('procesar-notificaciones',{body:{limit:20}});if(error)throw error;return data}catch(err){console.warn('Procesador de notificaciones no disponible',err);return null}
}
async function saveRemoteMedicalAppointment(){
  if(!['admin','club'].includes(currentRole))return;
  const button=$('#saveMedicalAppointment');
  if(button?.disabled)return;
  const f=$('#medicalForm');
  const dt=f.elements.appointmentDateTime.value,place=f.elements.appointmentPlace.value.trim(),address=f.elements.appointmentAddress.value.trim(),notes=f.elements.appointmentNotes.value.trim();
  if(!dt||!place){alert('Indica fecha/hora y lugar de la cita.');return}
  const previousText=button?.textContent||'Guardar y comunicar cita';
  if(button){button.disabled=true;button.textContent='Guardando y notificando…';button.setAttribute('aria-busy','true')}
  try{
    const v=remoteClubPlayers.find(x=>x.id===selectedMedicalPlayerId),ap=v?.appointment;
    const fn=ap&&editingMedicalAppointment?'modificar_cita_rrmm':'programar_cita_rrmm';
    const args=fn==='modificar_cita_rrmm'?{p_cita_id:ap.id,p_fecha_hora:new Date(dt).toISOString(),p_lugar:place,p_direccion:address||null,p_indicaciones:notes||null}:{p_jugador_id:selectedMedicalPlayerId,p_fecha_hora:new Date(dt).toISOString(),p_lugar:place,p_direccion:address||null,p_indicaciones:notes||null};
    const {error}=await sb.rpc(fn,args);if(error)throw error;
    const sent=await tryProcessNotifications();
    if(sent?.sent>0){
      alert(`Cita guardada y ${sent.sent} notificación${sent.sent===1?'':'es'} enviada${sent.sent===1?'':'s'}.`);
    }else if(sent?.deferred>0){
      alert('Cita guardada. El envío ha quedado pendiente de reintento automático por límite temporal del proveedor de correo.');
    }else{
      alert('Cita guardada. La notificación ha quedado preparada para su envío.');
    }
    await renderRemoteMedical();await openRemoteMedical(selectedMedicalPlayerId);await renderRemoteFamily?.();
  }catch(err){
    alert(`No se ha podido guardar la cita: ${err.message||err}`)
  }finally{
    const b=$('#saveMedicalAppointment');
    if(b){b.disabled=false;b.removeAttribute('aria-busy');if(b.textContent==='Guardando y notificando…')b.textContent=previousText}
  }
}
async function cancelRemoteMedicalAppointment(){
  if(!['admin','club'].includes(currentRole))return;
  const button=$('#cancelMedicalAppointment');if(button?.disabled)return;
  const v=remoteClubPlayers.find(x=>x.id===selectedMedicalPlayerId),ap=v?.appointment;if(!ap)return;if(!confirm('¿Cancelar esta cita? Se conservará en el histórico y se preparará un aviso de cancelación.'))return;
  const previousText=button?.textContent||'Cancelar cita';if(button){button.disabled=true;button.textContent='Cancelando…';button.setAttribute('aria-busy','true')}
  try{const {error}=await sb.rpc('cancelar_cita_rrmm',{p_cita_id:ap.id});if(error)throw error;await tryProcessNotifications();await renderRemoteMedical();await openRemoteMedical(selectedMedicalPlayerId);await renderRemoteFamily?.()}catch(err){alert(`No se ha podido cancelar la cita: ${err.message||err}`)}finally{const b=$('#cancelMedicalAppointment');if(b){b.disabled=false;b.removeAttribute('aria-busy');if(b.textContent==='Cancelando…')b.textContent=previousText}}
}
async function saveRemoteMedical(form){
  if(!['admin','club'].includes(currentRole))return;const fd=new FormData(form),date=String(fd.get('medicalDate')||''),expiry=String(fd.get('medicalExpiry')||'');if(!date){alert('Indica la fecha del reconocimiento.');return}const calculated=expiry||addMonths(date,18);if(calculated<date){alert('La fecha de validez no puede ser anterior a la fecha del reconocimiento.');return}
  try{
    const payload={jugador_id:selectedMedicalPlayerId,fecha_reconocimiento:date,fecha_valido_hasta:calculated,fecha_validacion_rffm:isoToday(),registrado_por:currentUser.authUserId||currentUser.id};
    const {error}=await sb.from('reconocimientos_medicos').insert(payload);if(error)throw error;
    $('#medicalModal').close();await renderRemoteMedical();await renderRemoteClub();
  }catch(err){alert(`No se ha podido registrar el reconocimiento: ${err.message||err}`)}
}
function remoteMedicalIsValid(v){const state=medicalState(v?.medical?{date:v.medical.fecha_reconocimiento,expiry:v.medical.fecha_valido_hasta}:null);return ['ok','soon'].includes(state.key)}
function validateRemoteFederationGate(v,targetState){
  if(targetState==='documentacion_validada'&&!(v.requirements?.length&&v.requirements.filter(r=>r.obligatorio).every(r=>r.estado==='validado')))return 'Valida todos los requisitos documentales obligatorios antes de marcar la documentación como validada.';
  if(!['lista_para_federar','ficha_tramitada'].includes(targetState))return null;
  const r=remoteFederationReadiness(v);
  if(!r.checks.find(x=>x.key==='data')?.ok)return 'Los datos personales deben estar validados por el club.';
  if(!r.checks.find(x=>x.key==='team')?.ok)return 'Asigna primero un equipo al jugador.';
  if(!r.checks.find(x=>x.key==='docs')?.ok)return 'Falta validar documentación obligatoria de la RFFM.';
  if(!r.checks.find(x=>x.key==='medical')?.ok)return 'El jugador necesita un reconocimiento médico en vigor antes de quedar listo para federar.';
  if(!r.checks.find(x=>x.key==='payment')?.ok)return 'La inscripción debe estar pagada al 100% o tener un fraccionamiento Cluber validado por el club.';
  return null;
}
function renderMedical(){if(currentUser?.source==='supabase')return renderRemoteMedical();if(!$('#medicalTable'))return;const q=($('#medicalSearch')?.value||'').trim().toLowerCase(),f=$('#medicalFilter')?.value||'all';const source=players.filter(p=>p.active!==false&&inscriptionFor(p.id)).map(p=>({p,i:inscriptionFor(p.id),m:latestMedical(p.id)})).map(x=>({...x,state:medicalState(x.m)}));const rows=source.filter(x=>{const quick=medicalQuickFilter==='all'||x.state.key===medicalQuickFilter||(medicalQuickFilter==='expired_or_missing'&&['expired','missing'].includes(x.state.key));return quick&&(!q||x.p.name.toLowerCase().includes(q))&&(f==='all'||x.state.key===f)});$('#medicalTable').innerHTML=rows.length?rows.map(x=>`<tr class="medical-row" data-id="${esc(x.p.id)}" tabindex="0"><td><strong>${esc(x.p.name)}</strong></td><td>${esc(categoryName(x.i.categoryId))}</td><td>${fmt(x.m?.date)}</td><td>${fmt(x.m?.expiry)}</td><td><span class="medical-badge ${x.state.key}">${esc(x.state.label)}</span></td></tr>`).join(''):'<tr><td colspan="5">No hay jugadores que coincidan con el filtro.</td></tr>';$$('.medical-row').forEach(r=>r.onclick=()=>openMedical(r.dataset.id));$('#medicalTotal').textContent=source.length;$('#medicalOk').textContent=source.filter(x=>x.state.key==='ok').length;$('#medicalSoon').textContent=source.filter(x=>x.state.key==='soon').length;$('#medicalExpired').textContent=source.filter(x=>['expired','missing'].includes(x.state.key)).length;updateQuickFilterUI()}
function openMedical(id){if(currentUser?.source==='supabase')return openRemoteMedical(id);selectedMedicalPlayerId=id;const p=players.find(x=>x.id===id),m=latestMedical(id);if(!p)return;$('#medicalPlayerName').textContent=p.name;$('#medicalPlayerMeta').textContent=categoryName(inscriptionFor(id)?.categoryId);const f=$('#medicalForm');f.elements.medicalDate.value=m?.date||'';f.elements.medicalExpiry.value=m?.expiry||'';renderMedicalRecognitionStatus({medical:m?{fecha_reconocimiento:m.date,fecha_valido_hasta:m.expiry}:null});$('#medicalHistory').innerHTML=medicals.filter(x=>x.playerId===id).sort((a,b)=>(b.date||'').localeCompare(a.date||'')).map(x=>`<div class="history-item"><strong>${fmt(x.date)} → ${fmt(x.expiry)}</strong><span>Validez registrada${x.validatedAt?' · validado '+fmt(x.validatedAt):''}</span></div>`).join('')||'<div class="meta">Sin reconocimientos anteriores.</div>';setMedicalTab('recognition');$('#medicalModal').showModal()}

function assignmentState(a,when=isoToday()){if(a.startDate&&when<a.startDate)return'upcoming';if(a.endDate&&when>a.endDate)return'finished';return'active'}
function assignmentStateLabel(s){return s==='upcoming'?'Próxima':s==='finished'?'Finalizada':'Activa'}
function assignmentStateClass(s){return s==='active'?'complete':s==='upcoming'?'pending':'returned'}
function renderAssignmentList(target,arr,cls){const e=$(target);if(!e)return;e.innerHTML=arr.length?arr.map((a,i)=>`<div class="assignment-card"><div><strong>${esc(coachTeamName(a.teamId))}</strong><div class="meta">${esc(coachRoleLabel(a.coachRole))} · ${fmt(a.startDate)} → ${fmt(a.endDate)}</div></div><span class="status ${assignmentStateClass(assignmentState(a))}">${assignmentStateLabel(assignmentState(a))}</span><button type="button" class="secondary tiny ${cls}" data-index="${i}">Quitar</button></div>`).join(''):'<div class="meta">Todavía no hay equipos asignados.</div>'}
function fillAssignmentTeamSelect(id){const s=$(id);if(!s)return;const source=dbStructureLoaded?sortTeamsByCategoryAge(dbSeasonTeams(),true):sortTeamsByCategoryAge(currentSeasonTeams(),false);s.innerHTML='<option value="">Seleccionar equipo</option>'+source.filter(t=>t.active).map(t=>`<option value="${esc(t.id)}">${esc(t.name)} · ${esc(dbStructureLoaded?dbCategoryName(t.categoryId):categoryName(t.categoryId))}</option>`).join('')}
function addAssignmentFrom(prefix,target,render){const team=$(`#${prefix}Team`).value,role=$(`#${prefix}Role`).value,startDate=$(`#${prefix}Start`).value,endDate=$(`#${prefix}End`).value;if(!team||!startDate){alert('Selecciona equipo y completa la fecha de inicio.');return false}if(endDate&&endDate<startDate){alert('La fecha de fin no puede ser anterior al inicio.');return false}const newEnd=endDate||'9999-12-31';if(target.some(a=>{const aEnd=a.endDate||'9999-12-31';return a.teamId===team&&!(newEnd<a.startDate||startDate>aEnd)})){alert('Ya existe una asignación solapada para ese equipo.');return false}target.push({teamId:team,coachRole:role,startDate,endDate:endDate||''});render();return true}
function renderCoaches(){
  if(!$('#coachesTable'))return;
  const remote=dbStructureLoaded;
  const teamSource=remote?sortTeamsByCategoryAge(dbSeasonTeams(),true):sortTeamsByCategoryAge(currentSeasonTeams(),false);
  const catSource=remote?dbCategories:categories;
  const teamSel=$('#coachTeamFilter'),catSel=$('#coachCategoryFilter');const tv=teamSel?.value||'all',cv=catSel?.value||'all';
  if(teamSel){teamSel.innerHTML='<option value="all">Todos los equipos</option>'+teamSource.filter(t=>t.active).map(t=>`<option value="${t.id}">${esc(t.name)}</option>`).join('');if([...teamSel.options].some(o=>o.value===tv))teamSel.value=tv}
  if(catSel){catSel.innerHTML='<option value="all">Todas las categorías</option>'+catSource.filter(c=>c.active).map(c=>`<option value="${c.id}">${esc(c.name)}</option>`).join('');if([...catSel.options].some(o=>o.value===cv))catSel.value=cv}
  const q=String($('#coachSearch')?.value||'').trim().toLowerCase();
  const cf=catSel?.value||'all',tf=teamSel?.value||'all',rf=$('#coachRoleFilter')?.value||'all',mf=$('#coachMedicalFilter')?.value||'all',df=$('#coachDelegateFilter')?.value||'all',lf=$('#coachLicenseFilter')?.value||'all',bf=$('#coachBenchFilter')?.value||'all',pf=$('#coachPlayerFilter')?.value||'all',sf=$('#coachStatusFilter')?.value||'all';
  const rows=coaches.filter(c=>{const aa=c.assignments||[],searchText=[c.name,c.email,...aa.map(a=>coachTeamName(a.teamId)),...(c.formations||[]).map(coachFormationLabel),...(c.licenses||[]).map(x=>x.tipo)].join(' ').toLowerCase();const delegateMatch=df==='all'||(df==='yes'&&c.delegateCourse)||(df==='progress'&&c.delegateInProgress)||(df==='no'&&!c.delegateCourse&&!c.delegateInProgress);const med=c.medicalState?.key||'missing';return(!q||searchText.includes(q))&&(cf==='all'||aa.some(a=>coachTeamCategoryId(a.teamId)===cf))&&(tf==='all'||aa.some(a=>a.teamId===tf))&&(rf==='all'||aa.some(a=>a.coachRole===rf))&&(mf==='all'||med===mf)&&delegateMatch&&(lf==='all'||(lf==='yes')===!!c.hasLicense)&&(bf==='all'||c.benchState===bf)&&(pf==='all'||(pf==='yes')===!!c.isPlayer)&&(sf==='all'||c.seasonState===sf)});
  $('#coachesTable').innerHTML=rows.length?rows.map(c=>{
    const activeAssignments=(c.assignments||[]).filter(a=>assignmentState(a)!=='finished');
    const ah=activeAssignments.map(a=>`<span class="coach-team-summary"><strong>${esc(coachTeamName(a.teamId))}</strong><span>${esc(coachRoleLabel(a.coachRole))}</span></span>`).join('')||'<span class="meta">Sin asignación actual</span>';
    const med=c.medicalState||{key:'missing',label:'Sin RRMM'},medClass=medicalVisualClass(med);
    const stateLabel=c.seasonState==='activo'?'Activo':c.seasonState==='sin_asignacion'?'Sin asignación':'Baja',stateClass=c.seasonState==='activo'?'complete':c.seasonState==='sin_asignacion'?'pending':'returned';
    const availability=c.seasonState==='sin_asignacion'?'Disponibilidad no requerida':c.availabilityConfirmed?`Disponibilidad confirmada${c.availabilityConfirmedAt?' · '+fmt(String(c.availabilityConfirmedAt).slice(0,10)):''}`:'Disponibilidad pendiente';
    const delegate=c.delegateCourse?'Delegado ✓':c.delegateInProgress?'Delegado en curso':'Sin Delegado';
    return `<tr class="coach-row" data-id="${esc(c.id)}" tabindex="0"><td><strong>${esc(c.name)}</strong><div class="meta">${esc(c.email||'Sin correo')}${c.isPlayer?' · Jugador + entrenador':''}</div>${coachMinorConsentBadge(c)}</td><td><div class="coach-team-list">${ah}</div></td><td><div class="coach-indicators"><span class="status ${medClass}">RRMM · ${esc(med.label)}</span><span class="status ${coachBenchClass(c)}">Banquillo · ${esc(coachBenchLabel(c))}</span><span class="coach-mini-indicator">${esc(delegate)}</span>${c.hasLicense?'<span class="coach-mini-indicator">Licencia RFFM ✓</span>':''}</div></td><td><span class="status ${stateClass}">${esc(stateLabel)}</span><div class="meta">${esc(availability)}</div></td></tr>`
  }).join(''):'<tr><td colspan="4">No hay entrenadores que coincidan con los filtros.</td></tr>';
  $$('.coach-row').forEach(r=>{r.onclick=()=>openCoachForEdit(r.dataset.id);r.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();openCoachForEdit(r.dataset.id)}}});
  const op=coaches.filter(c=>c.seasonState!=='baja'),set=(id,v)=>{const el=$(id);if(el)el.textContent=String(v)};
  set('#coachStatActive',op.filter(c=>c.seasonState==='activo').length);set('#coachStatMedical',op.filter(c=>['expired','missing'].includes(c.medicalState?.key||'missing')).length);set('#coachStatDelegate',op.filter(c=>!c.delegateCourse).length);set('#coachStatLicense',op.filter(c=>!c.hasLicense).length);set('#coachStatConsent',op.filter(c=>c.isMinor&&c.minorConsentStatus!=='aceptada').length);
}
function renderCoachNormalizedSummary(c){
  const el=$('#coachNormalizedSummary');if(!el)return;
  if(!c){el.innerHTML='<div class="info-card"><strong>Formación y licencias</strong><p>Guarda primero el entrenador. Después podrás completar la información normalizada de formación, licencias RFFM, RRMM y disponibilidad.</p></div>';return}
  const forms=(c.formations||[]).map(f=>`<div class="relation-line"><strong>${esc(coachFormationLabel(f))}</strong><span>${esc(f.estado||'')} · ${esc(f.verificacion_estado||'pendiente')}</span></div>`).join('')||'<div class="meta">Sin formaciones registradas.</div>';
  const licenses=(c.licenses||[]).map(l=>`<div class="relation-line"><strong>Licencia ${esc(l.tipo)}</strong><span>${l.verificacion_estado==='verificada'?'Verificada':'Pendiente'}${l.fecha_caducidad?' · hasta '+fmt(l.fecha_caducidad):''}${l.estado_excepcional?' · '+esc(l.estado_excepcional):''}</span></div>`).join('')||'<div class="meta">Sin licencias RFFM registradas para la temporada activa.</div>';
  el.innerHTML=`<section class="person-admin-card"><span class="eyebrow dark">Formación y titulaciones</span>${forms}</section><section class="person-admin-card"><span class="eyebrow dark">Licencias RFFM · temporada activa</span>${licenses}</section><section class="person-admin-card"><span class="eyebrow dark">Conclusión automática</span><div class="relation-line"><strong>Banquillo</strong><span class="status ${coachBenchClass(c)}">${esc(coachBenchLabel(c))}</span></div><p class="meta bench-reason">${esc(coachBenchReason(c))}</p></section>`;
}

const COACH_DAY_NAMES=['','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];
function coachAvailabilityLimits(day){return day<=5?{open:'16:00',close:'00:00'}:{open:'08:00',close:'00:00'}}
function minutesOfTime(v,{end=false}={}){if(!v)return null;const x=String(v).slice(0,5);if(end&&x==='00:00')return 1440;const [h,m]=x.split(':').map(Number);return Number.isFinite(h)&&Number.isFinite(m)?h*60+m:null}
function coachTimeOptions(day,{includeMidnight=true}={}){const lim=coachAvailabilityLimits(day),start=minutesOfTime(lim.open),out=[];for(let m=start;m<1440;m+=30){const h=String(Math.floor(m/60)).padStart(2,'0'),mm=String(m%60).padStart(2,'0');out.push(`${h}:${mm}`)}if(includeMidnight)out.push('00:00');return out}
function coachAvailabilityDraft(c){const rows=new Map((c?.availability||[]).map(x=>[Number(x.dia_semana),x]));return Array.from({length:7},(_,i)=>{const day=i+1,r=rows.get(day);return{day,tipo:r?.tipo||'',hora_desde:r?.hora_desde?String(r.hora_desde).slice(0,5):'',hora_hasta:r?.hora_hasta?String(r.hora_hasta).slice(0,5):''}})}
function coachAvailabilityLabel(r){if(!r?.tipo)return'Sin indicar';if(r.tipo==='no_disponible')return'No disponible';if(r.tipo==='todo_dia')return'Todo el horario del club';if(r.tipo==='desde')return`Desde ${r.hora_desde||'—'} hasta cierre`;if(r.tipo==='franja')return`${r.hora_desde||'—'}–${r.hora_hasta||'—'}`;return r.tipo}
function coachAvailabilityScheduleCount(c){const teams=new Set((c?.assignments||[]).filter(a=>assignmentState(a)==='active').map(a=>a.teamId));return dbTeamSchedules.filter(x=>teams.has(x.equipo_id)&&x.activo!==false).length}
function coachAvailabilityConflictRows(c,draft){const byDay=new Map(draft.map(r=>[r.day,r])),currentTeams=new Set((c?.assignments||[]).filter(a=>assignmentState(a)==='active').map(a=>a.teamId)),issues=[];for(const h of dbTeamSchedules.filter(x=>currentTeams.has(x.equipo_id)&&x.activo!==false)){const r=byDay.get(Number(h.dia_semana)),team=coachTeamName(h.equipo_id),start=minutesOfTime(h.hora_inicio),end=minutesOfTime(h.hora_fin,{end:true});if(!r?.tipo){issues.push(`${COACH_DAY_NAMES[h.dia_semana]} ${String(h.hora_inicio).slice(0,5)}–${String(h.hora_fin).slice(0,5)} · ${team}: disponibilidad sin indicar`);continue}if(r.tipo==='no_disponible'){issues.push(`${COACH_DAY_NAMES[h.dia_semana]} · ${team}: marcado no disponible`);continue}const lim=coachAvailabilityLimits(Number(h.dia_semana)),open=minutesOfTime(lim.open),close=minutesOfTime(lim.close,{end:true});let aStart=open,aEnd=close;if(r.tipo==='desde')aStart=minutesOfTime(r.hora_desde);if(r.tipo==='franja'){aStart=minutesOfTime(r.hora_desde);aEnd=minutesOfTime(r.hora_hasta,{end:true})}if(start<aStart||end>aEnd)issues.push(`${COACH_DAY_NAMES[h.dia_semana]} ${String(h.hora_inicio).slice(0,5)}–${String(h.hora_fin).slice(0,5)} · ${team}: fuera de disponibilidad (${coachAvailabilityLabel(r)})`)}return issues}
function coachAvailabilityRowHtml(r,prefix){const lim=coachAvailabilityLimits(r.day),starts=coachTimeOptions(r.day,{includeMidnight:false}),ends=coachTimeOptions(r.day,{includeMidnight:true}),showStart=['desde','franja'].includes(r.tipo),showEnd=r.tipo==='franja';return`<div class="availability-row" data-day="${r.day}"><div class="availability-day"><strong>${COACH_DAY_NAMES[r.day]}</strong><span class="meta">${lim.open}–00:00</span></div><label>Disponibilidad<select data-avail-type><option value="" ${!r.tipo?'selected':''}>Sin indicar</option><option value="no_disponible" ${r.tipo==='no_disponible'?'selected':''}>No disponible</option><option value="todo_dia" ${r.tipo==='todo_dia'?'selected':''}>Todo el horario del club</option><option value="desde" ${r.tipo==='desde'?'selected':''}>Disponible desde</option><option value="franja" ${r.tipo==='franja'?'selected':''}>Franja horaria</option></select></label><label class="availability-time ${showStart?'':'hidden'}">Desde<select data-avail-start>${starts.map(v=>`<option value="${v}" ${r.hora_desde===v?'selected':''}>${v}</option>`).join('')}</select></label><label class="availability-time ${showEnd?'':'hidden'}">Hasta<select data-avail-end>${ends.map(v=>`<option value="${v}" ${r.hora_hasta===v?'selected':''}>${v}</option>`).join('')}</select></label></div>`}
function coachAvailabilityReadOnlyRowHtml(r){const lim=coachAvailabilityLimits(r.day);return`<div class="availability-row availability-row-readonly"><div class="availability-day"><strong>${COACH_DAY_NAMES[r.day]}</strong><span class="meta">${lim.open}–00:00</span></div><div class="availability-readonly-value"><span class="meta">Disponibilidad</span><strong>${esc(coachAvailabilityLabel(r))}</strong></div></div>`}
function readCoachAvailabilityFrom(root){const rows=[];root.querySelectorAll('.availability-row').forEach(el=>{const day=Number(el.dataset.day),tipo=el.querySelector('[data-avail-type]')?.value||'',hora_desde=el.querySelector('[data-avail-start]')?.value||'',hora_hasta=el.querySelector('[data-avail-end]')?.value||'';rows.push({day,tipo,hora_desde,hora_hasta})});return rows}
function validateCoachAvailability(rows,{confirm=false}={}){if(confirm&&rows.some(r=>!r.tipo))return'Para confirmar la disponibilidad debes indicar los siete días.';for(const r of rows){if(!r.tipo)continue;const lim=coachAvailabilityLimits(r.day),min=minutesOfTime(lim.open),start=minutesOfTime(r.hora_desde),end=minutesOfTime(r.hora_hasta,{end:true});if(['desde','franja'].includes(r.tipo)&&(!Number.isFinite(start)||start<min||start>=1440))return`${COACH_DAY_NAMES[r.day]}: la hora de inicio debe estar entre ${lim.open} y 23:30.`;if(r.tipo==='franja'&&(!Number.isFinite(end)||end<=start||end>1440))return`${COACH_DAY_NAMES[r.day]}: la hora de fin debe ser posterior al inicio; 00:00 representa el cierre del día.`}return''}
async function saveCoachAvailability(c,root,confirm){if(!sb||!c)return;const season=dbActiveSeason();if(!season){alert('No hay temporada activa.');return}const rows=readCoachAvailabilityFrom(root),err=validateCoachAvailability(rows,{confirm});if(err){alert(err);return}const payload=rows.filter(r=>r.tipo).map(r=>({dia_semana:r.day,tipo:r.tipo,hora_desde:['desde','franja'].includes(r.tipo)?r.hora_desde:null,hora_hasta:r.tipo==='franja'?r.hora_hasta:null}));const btn=confirm?root.querySelector('[data-confirm-availability]'):root.querySelector('[data-save-availability]'),old=btn?.textContent;if(btn){btn.disabled=true;btn.textContent=confirm?'Confirmando…':'Guardando…'}try{const {error}=await sb.rpc('guardar_disponibilidad_entrenador',{p_entrenador_id:c.id,p_temporada_id:season.id,p_disponibilidad:payload,p_confirmar:confirm});if(error)throw error;await loadSupabaseCoaches();const fresh=coaches.find(x=>x.id===c.id);renderCoachAvailabilityPanel(root,fresh,{self:root.id==='selfCoachAvailabilityPanel'});renderCoaches();alert(confirm?'Disponibilidad confirmada correctamente.':'Disponibilidad guardada como borrador. Queda pendiente de confirmar.')}catch(e){alert(`No se ha podido guardar la disponibilidad: ${e.message||e}`)}finally{if(btn&&old){btn.disabled=false;btn.textContent=old}}}
function renderCoachAvailabilityPanel(rootOrSelector,c,{self=false}={}){
  const root=typeof rootOrSelector==='string'?$(rootOrSelector):rootOrSelector;
  if(!root)return;
  if(!c){
    root.innerHTML='<div class="meta">Guarda primero el entrenador para gestionar su disponibilidad.</div>';
    return;
  }
  let draft=coachAvailabilityDraft(c);
  const confirmedDate=c.availabilityConfirmedAt?fmt(String(c.availabilityConfirmedAt).slice(0,10)):'';
  const state=c.availabilityConfirmed
    ? `<span class="status complete">Confirmada</span>${confirmedDate?`<span class="meta"> ${confirmedDate}</span>`:''}`
    : '<span class="status pending">Pendiente de confirmar</span>';
  if(!self){
    const ownerState=c.availabilityConfirmed
      ? `<span class="status complete">Confirmada por el entrenador</span>${confirmedDate?`<span class="meta"> ${confirmedDate}</span>`:''}`
      : '<span class="status pending">Pendiente de confirmar por el entrenador</span>';
    root.innerHTML=`<div class="availability-head"><div><strong>Disponibilidad semanal · ${esc(dbActiveSeason()?.name||'temporada activa')}</strong><div class="meta">Información declarada por el propio entrenador. Club y Administrador disponen únicamente de consulta.</div></div><div>${ownerState}</div></div><div class="availability-grid availability-grid-readonly">${draft.map(coachAvailabilityReadOnlyRowHtml).join('')}</div><div class="availability-conflicts" data-availability-conflicts></div><div class="meta">Solo el entrenador puede crear, modificar, guardar como borrador o confirmar su disponibilidad.</div>`;
    const issues=coachAvailabilityConflictRows(c,draft),box=root.querySelector('[data-availability-conflicts]');
    if(box){const n=coachAvailabilityScheduleCount(c);box.innerHTML=!n?'<div class="info-card"><strong>Sin horarios de equipo cargados para comprobar incompatibilidades.</strong></div>':issues.length?`<div class="warning-box"><strong>${issues.length} aviso(s) con horarios de equipo</strong><ul>${issues.map(x=>`<li>${esc(x)}</li>`).join('')}</ul></div>`:'<div class="success-box"><strong>Sin incompatibilidades detectadas con los horarios de equipo cargados.</strong></div>'}
    return;
  }
  root.innerHTML=`<div class="availability-head"><div><strong>Disponibilidad semanal · ${esc(dbActiveSeason()?.name||'temporada activa')}</strong><div class="meta">Una franja por día. L–V 16:00–00:00 · S–D 08:00–00:00. “Todo el horario” se refiere al horario de apertura del club.</div></div><div>${state}</div></div><div class="availability-grid">${draft.map(r=>coachAvailabilityRowHtml(r,'self')).join('')}</div><div class="availability-conflicts" data-availability-conflicts></div><div class="availability-actions"><button type="button" class="secondary" data-save-availability>Guardar borrador</button><button type="button" class="primary" data-confirm-availability>Confirmar disponibilidad</button></div><div class="meta">Modificar una disponibilidad ya confirmada y guardarla como borrador la dejará pendiente de confirmar. Las incompatibilidades con horarios de equipo son avisos y no bloquean el guardado.</div>`;
  const refresh=()=>{
    draft=readCoachAvailabilityFrom(root);
    root.querySelectorAll('.availability-row').forEach(el=>{
      const tipo=el.querySelector('[data-avail-type]').value;
      const times=el.querySelectorAll('.availability-time');
      times[0]?.classList.toggle('hidden',!['desde','franja'].includes(tipo));
      times[1]?.classList.toggle('hidden',tipo!=='franja');
    });
    const issues=coachAvailabilityConflictRows(c,draft);
    const box=root.querySelector('[data-availability-conflicts]');
    if(box){
      const n=coachAvailabilityScheduleCount(c);box.innerHTML=!n
        ? '<div class="info-card"><strong>Sin horarios de equipo cargados para comprobar incompatibilidades.</strong></div>'
        : issues.length
        ? `<div class="warning-box"><strong>${issues.length} aviso(s) con horarios de equipo</strong><ul>${issues.map(x=>`<li>${esc(x)}</li>`).join('')}</ul></div>`
        : '<div class="success-box"><strong>Sin incompatibilidades detectadas con los horarios de equipo cargados.</strong></div>';
    }
  };
  root.querySelectorAll('select').forEach(el=>el.addEventListener('change',refresh));
  root.querySelector('[data-save-availability]')?.addEventListener('click',()=>saveCoachAvailability(c,root,false));
  root.querySelector('[data-confirm-availability]')?.addEventListener('click',()=>saveCoachAvailability(c,root,true));
  refresh();
}

function coachAdminTab(name='summary'){
  const modal=$('#coachModal');if(!modal)return;
  modal.querySelectorAll('[data-coach-tab]').forEach(b=>{const on=b.dataset.coachTab===name;b.classList.toggle('active',on);b.setAttribute('aria-selected',on?'true':'false')});
  modal.querySelectorAll('[data-coach-panel]').forEach(p=>p.classList.toggle('active',p.dataset.coachPanel===name));
}
function bindCoachAdminTabs(){const modal=$('#coachModal');if(!modal)return;modal.querySelectorAll('[data-coach-tab]').forEach(b=>b.onclick=()=>coachAdminTab(b.dataset.coachTab))}
function renderCoachAdminSummary(c){const el=$('#coachAdminSummary');if(!el)return;if(!c){el.innerHTML='<div class="info-card"><strong>Nuevo entrenador</strong><p>Completa Datos y, si procede, Equipos. La información restante estará disponible tras guardar.</p></div>';return}const active=(c.assignments||[]).filter(a=>assignmentState(a)==='active');const teams=active.map(a=>`<div class="coach-summary-line"><strong>${esc(coachTeamName(a.teamId))}</strong><span>${esc(coachRoleLabel(a.coachRole))}</span></div>`).join('')||'<div class="meta">Sin asignación actual.</div>';const med=c.medicalState||{key:'missing',label:'Sin fecha'};const av=c.seasonState==='sin_asignacion'?'No requerida mientras no tenga asignación':c.availabilityConfirmed?`Confirmada${c.availabilityConfirmedAt?' · '+fmt(String(c.availabilityConfirmedAt).slice(0,10)):''}`:'Pendiente de confirmar';el.innerHTML=`<div class="coach-summary-grid"><section class="person-admin-card"><span class="eyebrow dark">Estado</span><div class="relation-line"><strong>${c.seasonState==='activo'?'Activo':c.seasonState==='sin_asignacion'?'Sin asignación':'Baja'}</strong><span>${esc(av)}</span></div></section><section class="person-admin-card"><span class="eyebrow dark">Equipos actuales</span>${teams}</section><section class="person-admin-card"><span class="eyebrow dark">Indicadores</span><div class="coach-indicators"><span class="status ${medicalVisualClass(med)}">RRMM · ${esc(med.label)}</span><span class="status ${coachBenchClass(c)}">Banquillo · ${esc(coachBenchLabel(c))}</span><span class="coach-mini-indicator">${esc(c.delegateCourse?'Delegado ✓':c.delegateInProgress?'Delegado en curso':'Sin Delegado')}</span></div></section></div>`}
function renderCoachAdminMedical(c){const el=$('#coachAdminMedical');if(!el)return;if(!c){el.innerHTML='<div class="meta">Guarda primero el entrenador.</div>';return}const m=c.medicalState||{key:'missing',label:'Sin fecha'};el.innerHTML=`<div class="person-admin-card"><span class="eyebrow dark">Reconocimiento médico</span><div class="relation-line"><strong>Estado</strong><span class="status ${medicalVisualClass(m)}">${esc(m.label)}</span></div>${c.medical?.fecha_reconocimiento?`<div class="relation-line"><strong>Último reconocimiento</strong><span>${fmt(c.medical.fecha_reconocimiento)}</span></div>`:''}${c.medical?.fecha_valido_hasta?`<div class="relation-line"><strong>Válido hasta</strong><span>${fmt(c.medical.fecha_valido_hasta)}</span></div>`:''}<p class="meta">El RRMM es transversal a la Persona y coincide con el mostrado en Fichas.</p></div>`}
function renderCoachAdminHistory(c){const el=$('#coachAdminHistory');if(!el)return;if(!c){el.innerHTML='<div class="meta">Guarda primero el entrenador.</div>';return}const rows=(c.assignments||[]).slice().sort((a,b)=>String(b.startDate||'').localeCompare(String(a.startDate||''))).map(a=>`<div class="history-item"><strong>${esc(coachTeamName(a.teamId))} · ${esc(coachRoleLabel(a.coachRole))}</strong><span>${fmt(a.startDate)} → ${fmt(a.endDate)}</span></div>`).join('');el.innerHTML=`<div class="person-admin-card"><span class="eyebrow dark">Histórico deportivo disponible</span>${rows||'<div class="meta">Sin etapas registradas.</div>'}<p class="meta">Este panel reúne el histórico actualmente disponible sin alterar el modelo de datos.</p></div>`}

function renderCoachAssignments(){renderAssignmentList('#coachAssignmentsList',pendingCoachAssignments,'remove-coach-assignment');$$('.remove-coach-assignment').forEach(b=>b.onclick=()=>{pendingCoachAssignments.splice(+b.dataset.index,1);renderCoachAssignments()})}

async function fillCoachPersonSelect(preselect=null){
  if(!dbPersons.length)await loadSupabasePersons();
  const sel=$('#coachPersonSelect');if(!sel)return;
  const trainerPersonIds=new Set(coaches.map(c=>c.personId));
  const options=dbPersons.filter(p=>p.activo!==false).map(p=>({p,isCoach:trainerPersonIds.has(p.id)}));
  sel.innerHTML='<option value="">Selecciona una persona…</option>'+options.map(({p,isCoach})=>`<option value="${esc(p.id)}" ${isCoach?'data-coach="yes"':''}>${esc(remotePersonName(p))}${p.email_contacto?' · '+esc(p.email_contacto):''}${isCoach?' · ya entrenador':''}</option>`).join('');
  if(preselect&&[...sel.options].some(o=>o.value===preselect))sel.value=preselect;
}
function applyCoachPersonToForm(personId){
  const p=dbPersons.find(x=>x.id===personId),f=$('#coachForm');if(!p||!f)return;selectedCoachPersonId=p.id;
  f.elements.firstName.value=p.nombre||'';f.elements.lastName1.value=p.primer_apellido||'';f.elements.lastName2.value=p.segundo_apellido||'';f.elements.email.value=p.email_contacto||'';f.elements.phone.value=p.telefono||'';
  ['firstName','lastName1','lastName2','email','phone'].forEach(n=>{if(f.elements[n])f.elements[n].readOnly=true});
}
async function openCoachForNew(personId=null){
  if(!['admin','club'].includes(currentRole)){alert('Solo Club o Administrador pueden dar de alta entrenadores.');return}
  editingCoachId=null;selectedCoachPersonId=null;pendingCoachAssignments=[];setCoachAssignmentGuard('');const cp=$('#coachMinorConsentPanel');if(cp){cp.hidden=true;cp.innerHTML=''}const f=$('#coachForm');f.reset();
  ['firstName','lastName1','lastName2','email','phone'].forEach(n=>{if(f.elements[n])f.elements[n].readOnly=true});
  f.elements.active.value='yes';fillAssignmentTeamSelect('#coachAssignmentTeam');$('#coachAssignmentStart').value=isoToday();$('#coachAssignmentEnd').value=dbActiveSeason()?.endDate||'';renderCoachAssignments();renderCoachAvailabilityPanel('#coachAvailabilityPanel',null);
  await fillCoachPersonSelect(personId);$('#coachPersonSelectorWrap').hidden=false;$('#coachModalTitle').textContent='Asignar rol Entrenador';
  if(personId){applyCoachPersonToForm(personId)}
  renderCoachNormalizedSummary(null);renderCoachAdminSummary(null);renderCoachAdminMedical(null);renderCoachAdminHistory(null);bindCoachAdminTabs();coachAdminTab('data');
  $('#coachModal').showModal();
}
function setCoachAssignmentGuard(message='',kind='warning'){
  const el=$('#coachAssignmentGuard');if(!el)return;el.textContent=message;el.hidden=!message;el.className=message?(kind==='ok'?'success-box':'warning-box'):'';
}
function openCoachForEdit(id){const c=coaches.find(x=>x.id===id);if(!c)return;setCoachAssignmentGuard('');editingCoachId=id;selectedCoachPersonId=c.personId;$('#coachPersonSelectorWrap').hidden=true;pendingCoachAssignments=(c.assignments||[]).filter(a=>assignmentState(a)!=='finished').map(a=>({...a}));const f=$('#coachForm');f.elements.firstName.value=c.firstName||String(c.name||'').split(' ')[0]||'';f.elements.lastName1.value=c.lastName1||String(c.name||'').split(' ').slice(1).join(' ');f.elements.lastName2.value=c.lastName2||'';f.elements.email.value=c.email||'';f.elements.phone.value=c.phone||'';f.elements.active.value=c.active?'yes':'no';fillAssignmentTeamSelect('#coachAssignmentTeam');renderCoachAssignments();['firstName','lastName1','lastName2','email','phone'].forEach(n=>{if(f.elements[n])f.elements[n].readOnly=true});$('#coachModalTitle').textContent='Editar entrenador';renderCoachMinorConsentPanel();renderCoachNormalizedSummary(c);renderCoachAvailabilityPanel('#coachAvailabilityPanel',c);renderCoachAdminSummary(c);renderCoachAdminMedical(c);renderCoachAdminHistory(c);bindCoachAdminTabs();coachAdminTab('summary');$('#coachModal').showModal()}
async function saveRemoteCoach(form){
  if(!['admin','club'].includes(currentRole))return;
  const fd=new FormData(form),old=coaches.find(c=>c.id===editingCoachId),personId=old?.personId||selectedCoachPersonId||$('#coachPersonSelect')?.value,btn=form.querySelector('button[type="submit"]');
  if(!personId){alert('Selecciona primero una Persona existente.');return}
  if(!editingCoachId&&!['admin','club'].includes(currentRole)){alert('Solo Club o Administrador pueden dar de alta entrenadores.');return}
  const person=dbPersons.find(x=>x.id===personId);const personEmail=String(person?.email_contacto||old?.email||fd.get('email')||'').trim().toLowerCase();if(fd.get('active')==='yes'&&!personEmail){alert('Todo entrenador activo necesita un correo electrónico propio antes de completar el alta.');return}
  if(btn){btn.disabled=true;btn.textContent='Guardando…'}
  try{
    const {data:coachId,error}=await sb.rpc('asignar_rol_entrenador',{p_persona_id:personId,p_licencia_tipo:old?.legacyLicenseType||null,p_licencia_numero:old?.legacyLicenseNumber||null,p_curso_delegado:old?.legacyDelegateCourse===true,p_activo:fd.get('active')==='yes',p_observaciones:old?.legacyNotes||null});if(error)throw error;await tryProcessNotifications();
    const linkedAuthUserId=person?.auth_user_id||old?.userId||null;
    if(!linkedAuthUserId&&fd.get('active')==='yes')await invokeAccessManager({action:'invite_coach_user',persona_id:personId,redirect_to:AUTH_REDIRECT_URL});
    const payload=pendingCoachAssignments.map(a=>({team_id:a.teamId,funcion:a.coachRole,fecha_desde:a.startDate,fecha_hasta:a.endDate||null,reemplazar_principal:a.replacePrincipal===true}));
    const {error:aerr}=await sb.rpc('guardar_asignaciones_entrenador',{p_entrenador_id:coachId,p_asignaciones:payload});if(aerr)throw aerr;
    await loadSupabaseCoaches();if((currentUser.roles||[]).includes('admin'))await loadSupabasePersons();editingCoachId=null;selectedCoachPersonId=null;pendingCoachAssignments=[];form.reset();$('#coachModal').close();renderCoaches();renderStructure();renderPersons();
  }catch(err){
    console.error('Guardar entrenador',err);
    if(editingCoachId){
      try{await loadSupabaseCoaches();const persisted=coaches.find(c=>c.id===editingCoachId);pendingCoachAssignments=(persisted?.assignments||[]).filter(a=>assignmentState(a)!=='finished').map(a=>({...a}));renderCoachAssignments()}catch(reloadErr){console.warn('No se pudo restaurar la asignación persistida',reloadErr)}
    }
    setCoachAssignmentGuard(String(err.message||err).includes('autorizacion expresa')?'No se ha añadido la asignación: falta la autorización expresa del tutor.':'');
    alert(`No se ha podido guardar el entrenador: ${err.message||err}`)
  }finally{if(btn){btn.disabled=false;btn.textContent='Guardar entrenador'}}
}
function renderTeamsSummary(){if(!$('#teamsTable'))return;const source=dbStructureLoaded?sortTeamsByCategoryAge(dbSeasonTeams(),true):sortTeamsByCategoryAge(currentSeasonTeams(),false);const catName=id=>dbStructureLoaded?dbCategoryName(id):categoryName(id);$('#teamsTable').innerHTML=source.map(t=>`<tr><td><strong>${esc(t.name)}</strong></td><td>${esc(catName(t.categoryId))}</td><td>${dbStructureLoaded?'—':playerTeams.filter(a=>a.teamId===t.id&&a.seasonId===currentSeasonId&&assignmentState(a)==='active').length}</td><td>${coaches.filter(c=>c.active&&(c.assignments||[]).some(a=>a.teamId===t.id&&assignmentState(a)==='active')).length||'—'}</td><td><span class="status ${t.active?'complete':'returned'}">${t.active?'Activo':'Inactivo'}</span></td></tr>`).join('')}

function renderClubUsers(){if(!$('#clubUsersTable'))return;const rows=users.filter(u=>internalRoles(u).length);$('#clubUsersTable').innerHTML=rows.map(u=>{const c=coaches.find(x=>x.userId===u.id),ts=c?(c.assignments||[]).filter(a=>assignmentState(a)==='active').map(a=>teamName(a.teamId)).join(', '):'—';const badges=(u.roles||[]).map(r=>`<span class="role-badge">${esc(roleLabel(r))}</span>`).join('');return`<tr><td><strong>${esc(u.name)}</strong></td><td>${esc(u.email)}</td><td><div class="role-badges">${badges}</div></td><td>${esc(ts||'—')}</td><td><span class="status ${u.active?'complete':'returned'}">${u.active?'Activo':'Inactivo'}</span></td><td><button class="secondary tiny toggle-user" data-id="${u.id}">${u.active?'Desactivar':'Activar'}</button></td></tr>`}).join('');$$('.toggle-user').forEach(b=>b.onclick=()=>{users=users.map(u=>u.id===b.dataset.id?{...u,active:!u.active}:u);saveUsers();renderClubUsers()})}

function renderPersons(){
  if(!$('#personsTable'))return;
  if(currentUser?.source==='supabase')return renderRemotePersons();
  const pairs=duplicatePairs();$('#duplicateCount').textContent=String(pairs.length);$('#duplicateList').innerHTML=pairs.length?pairs.map(d=>`<div class="duplicate-card"><div><strong>${esc(d.a.name)} ↔ ${esc(d.b.name)}</strong><span>${esc(d.reasons.join(', '))}</span></div><button class="secondary tiny merge-persons" data-a="${d.a.id}" data-b="${d.b.id}">Fusionar</button></div>`).join(''):'<div class="empty-note">No se han detectado posibles duplicados.</div>';$('#personsTable').innerHTML=persons.map(p=>{const us=users.filter(u=>u.personId===p.id),ps=players.filter(x=>x.personId===p.id),roles=[...new Set(us.flatMap(u=>u.roles||[]))];const emails=[...new Set(us.flatMap(u=>[u.email,...(u.emailAliases||[])]).filter(Boolean))];return`<tr><td><strong>${esc(p.name)}</strong></td><td>${esc(emails.join(', ')||'—')}</td><td><div class="role-badges">${roles.map(r=>`<span class="role-badge">${esc(roleLabel(r))}</span>`).join('')||'—'}</div></td><td>—</td><td></td></tr>`}).join('');
}
async function loadRemotePersonRelations(personId){
  const today=isoToday();
  const [playerRes,repRes,coachRes]=await Promise.all([
    sb.from('jugadores').select('id,activo,fecha_alta,fecha_baja').eq('persona_id',personId),
    sb.from('representaciones_jugador').select('id,jugador_id,fecha_desde,fecha_hasta,excepcion_representacion_adulto').eq('representante_persona_id',personId),
    sb.from('entrenadores').select('id,activo,licencia_tipo,licencia_numero,curso_delegado').eq('persona_id',personId)
  ]);
  if(playerRes.error)throw playerRes.error;if(repRes.error)throw repRes.error;if(coachRes.error)throw coachRes.error;
  const reps=(repRes.data||[]).filter(r=>(!r.fecha_desde||r.fecha_desde<=today)&&(!r.fecha_hasta||r.fecha_hasta>=today));
  const coach=(coachRes.data||[])[0]||null;
  let assignments=[];
  if(coach){const ar=await sb.from('asignaciones_entrenador_equipo').select('id,equipo_id,funcion,fecha_desde,fecha_hasta,cancelada_at,motivo_fin').eq('entrenador_id',coach.id);if(ar.error)throw ar.error;assignments=(ar.data||[]).filter(a=>!a.cancelada_at)}
  return {players:playerRes.data||[],representations:reps,coach,assignments};
}
function setPersonAdminTab(tab){
  $$('#personAdminTabs [data-person-tab]').forEach(b=>b.classList.toggle('active',b.dataset.personTab===tab));
  $$('#personAdminModal [data-person-panel]').forEach(p=>p.classList.toggle('active',p.dataset.personPanel===tab));
}
async function openPersonAdmin(personId,tab='identity'){
  if(currentRole!=='admin')return;
  await loadSupabasePersons();await loadSupabaseCoaches();
  const person=dbPersons.find(p=>p.id===personId);if(!person)return;
  selectedPersonAdminId=personId;
  const rel=await loadRemotePersonRelations(personId);
  const roles=remotePersonRoleCodes(personId);
  const f=$('#personAdminIdentityForm');
  f.elements.firstName.value=person.nombre||'';f.elements.lastName1.value=person.primer_apellido||'';f.elements.lastName2.value=person.segundo_apellido||'';f.elements.birth.value=person.fecha_nacimiento||'';f.elements.email.value=person.email_contacto||'';if(f.elements.emailConfirm)f.elements.emailConfirm.value=person.email_contacto||'';f.elements.phone.value=person.telefono||'';f.elements.active.value=person.activo===false?'no':'yes';
  $('#personAdminName').textContent=remotePersonName(person);$('#personAdminMeta').textContent=person.email_contacto||'Sin correo de contacto';
  $('#personRoleAdmin').checked=roles.includes('administrador');$('#personRoleClub').checked=roles.includes('club');$('#personRoleCoach').checked=roles.includes('entrenador');
  $('#personPlayerRoleHint').textContent='Tutor/Familia y Jugador se adquieren por autoregistro. Si el Entrenador es menor, necesita autorización expresa del tutor para recibir asignaciones.';
  const isTutor=roles.includes('tutor')||rel.representations.length>0;
  $('#personDerivedRoles').innerHTML=`<div class="derived-role-row"><span>Tutor / Familia</span><strong>${isTutor?'✓ Activo':'—'}</strong></div><div class="derived-role-row"><span>Jugador federado</span><strong>${rel.players.length?`✓ ${rel.players.some(x=>x.activo!==false)?'Activo':'Histórico'}`:'—'}</strong></div>`;
  let accessState=null;
  if(person.auth_user_id){try{accessState=await getInternalAccessState(person.id)}catch(err){console.warn('No se pudo consultar el estado Auth',err)}}
  const linked=!!person.auth_user_id,confirmed=!!accessState?.confirmed;
  if(!linked){
    $('#personAuthState').innerHTML=`<span class="status pending">Sin cuenta vinculada</span><div class="meta">${person.email_contacto?'Puedes enviar una invitación o vincular una cuenta Auth ya existente.':'Añade primero un correo de contacto.'}</div>`;
  }else if(confirmed){
    $('#personAuthState').innerHTML=`<span class="status complete">Cuenta activada</span><div class="meta">Auth: ${esc(person.auth_user_id)}</div>`;
  }else{
    $('#personAuthState').innerHTML=`<span class="status pending">Pendiente de activación</span><div class="meta">Auth: ${esc(person.auth_user_id)} · El usuario todavía no ha completado el acceso.</div>`;
  }
  $('#linkPersonAuth').hidden=linked;$('#linkPersonAuth').disabled=!person.email_contacto;
  $('#createTemporaryAccess').hidden=linked;$('#createTemporaryAccess').disabled=!person.email_contacto;
  const resendBtn=$('#resendInternalInvitation');if(resendBtn){resendBtn.hidden=!linked||confirmed;resendBtn.disabled=!person.email_contacto}
  const teamNames=rel.assignments.map(a=>{const t=dbTeams.find(x=>x.id===a.equipo_id);return `${t?.name||'Equipo'} · ${coachRoleLabel(a.funcion)}${a.fecha_hasta?' · hasta '+fmt(a.fecha_hasta):''}`});
  $('#personRelationsPanel').innerHTML=`<section class="person-admin-card"><span class="eyebrow dark">Jugador</span>${rel.players.length?rel.players.map(x=>`<div class="relation-line"><strong>Ficha de jugador</strong><span>${x.activo!==false?'Activa':'Inactiva'}</span></div>`).join(''):'<div class="meta">No tiene ficha de jugador.</div>'}</section><section class="person-admin-card"><span class="eyebrow dark">Familia / representación</span>${rel.representations.length?`<div class="relation-line"><strong>${rel.representations.length} representación(es) activa(s)</strong><span>Perfil Familia derivado</span></div>`:'<div class="meta">No representa actualmente a ningún jugador.</div>'}</section><section class="person-admin-card"><span class="eyebrow dark">Entrenador</span>${rel.coach?`<div class="relation-line"><strong>${rel.coach.activo!==false?'Entrenador activo':'Entrenador inactivo'}</strong><span>${teamNames.join('<br>')||'Sin asignaciones activas'}</span></div><button type="button" class="secondary small" id="openCoachFromPerson">Abrir ficha de entrenador</button>`:'<div class="meta">No tiene extensión de entrenador.</div>'}</section>`;
  const coachBtn=$('#openCoachFromPerson');if(coachBtn)coachBtn.onclick=()=>{const c=coaches.find(x=>x.personId===personId);if(c){$('#personAdminModal').close();openCoachForEdit(c.id)}};
  setPersonAdminTab(tab);if(!$('#personAdminModal').open)$('#personAdminModal').showModal();
}
async function renderRemotePersons(){
  const body=$('#personsTable');if(!body||currentRole!=='admin')return;
  try{await loadSupabasePersons();await loadSupabaseCoaches();$('#duplicateCount').textContent='—';$('#duplicateList').innerHTML='<div class="empty-note">Persona es la identidad maestra. Perfiles y relaciones se administran desde su ficha sin duplicar identidades.</div>';
    const rows=[];
    for(const p of dbPersons){
      const roles=remotePersonRoleCodes(p.id),coach=coaches.find(c=>c.personId===p.id),player=await sb.from('jugadores').select('id,activo',{count:'exact',head:true}).eq('persona_id',p.id),rep=await sb.from('representaciones_jugador').select('id',{count:'exact',head:true}).eq('representante_persona_id',p.id).or(`fecha_hasta.is.null,fecha_hasta.gte.${isoToday()}`);
      const relationBits=[];if((player.count||0)>0)relationBits.push('Jugador');if((rep.count||0)>0)relationBits.push('Tutor/Familia');if(coach)relationBits.push('Entrenador');
      const accessRoles=roles.filter(r=>['administrador','club','entrenador','jugador','tutor'].includes(r));
      rows.push(`<tr><td><strong>${esc(remotePersonName(p))}</strong><div class="meta">${p.fecha_nacimiento?fmt(p.fecha_nacimiento):'Nacimiento no informado'}</div></td><td>${esc(p.email_contacto||'—')}</td><td><div class="role-badges">${accessRoles.map(r=>`<span class="role-badge">${esc(r==='tutor'?'Tutor/Familia':r)}</span>`).join('')||'—'}</div></td><td>${esc(relationBits.join(' · ')||'—')}</td><td>${p.auth_user_id?'<span class="status complete">Vinculada</span>':'<span class="status pending">Sin cuenta</span>'}</td><td><span class="status ${p.activo===false?'returned':'complete'}">${p.activo===false?'Inactiva':'Activa'}</span></td><td><button class="secondary tiny open-person-admin" data-person="${p.id}">Abrir</button></td></tr>`);
    }
    body.innerHTML=rows.join('')||'<tr><td colspan="7">No hay personas registradas.</td></tr>';$$('.open-person-admin').forEach(b=>b.onclick=()=>openPersonAdmin(b.dataset.person));
  }catch(err){body.innerHTML=`<tr><td colspan="7">No se pudieron cargar las personas: ${esc(err.message||err)}</td></tr>`}
}
async function createRemotePerson(form){
  if(currentRole!=='admin')return;const fd=new FormData(form);const email=String(fd.get('email')||'').trim(),emailConfirm=String(fd.get('emailConfirm')||'').trim();const emailError=validateRepeatedEmail(email,emailConfirm,{required:false});if(emailError){alert(emailError);return}
  const roleAdmin=fd.get('roleAdmin')==='on',roleClub=fd.get('roleClub')==='on',roleCoach=fd.get('roleCoach')==='on',sendInvite=roleAdmin||roleClub||roleCoach;
  if(sendInvite&&!email){alert('Indica un correo electrónico para enviar la invitación.');return}
  const submit=form.querySelector('button[type="submit"]');if(submit){submit.disabled=true;submit.textContent='Creando…'}
  try{
    const {data,error}=await sb.rpc('guardar_persona_admin',{p_persona_id:null,p_nombre:String(fd.get('firstName')||'').trim(),p_primer_apellido:String(fd.get('lastName1')||'').trim(),p_segundo_apellido:String(fd.get('lastName2')||'').trim()||null,p_email:email||null,p_telefono:String(fd.get('phone')||'').trim()||null,p_fecha_nacimiento:String(fd.get('birth')||'')||null,p_activo:true});if(error)throw error;
    if(roleAdmin||roleClub||roleCoach){const rr=await sb.rpc('actualizar_perfiles_persona_admin',{p_persona_id:data,p_administrador:roleAdmin,p_club:roleClub,p_entrenador:roleCoach,p_jugador:null});if(rr.error)throw rr.error;await tryProcessNotifications()}
    if(sendInvite){await invokeAccessManager({action:'invite_internal_user',persona_id:data,redirect_to:AUTH_REDIRECT_URL})}
    form.reset();$('#personModal').close();await loadSupabasePersons();await loadSupabaseCoaches();await renderRemotePersons();renderCoaches();renderStructure();await openPersonAdmin(data,'access');
    if(sendInvite)alert('Persona creada e invitación enviada. El usuario establecerá su propia contraseña.');
  }catch(err){alert(`No se ha podido crear la Persona: ${err.message||err}`)}finally{if(submit){submit.disabled=false;submit.textContent='Crear persona'}}
}

async function savePersonAdminIdentity(form){
  const p=dbPersons.find(x=>x.id===selectedPersonAdminId);if(!p)return;const fd=new FormData(form),btn=form.querySelector('button[type="submit"]');btn.disabled=true;btn.textContent='Guardando…';
  try{const newEmail=String(fd.get('email')||'').trim().toLowerCase(),emailConfirm=String(fd.get('emailConfirm')||'').trim().toLowerCase();const emailError=validateRepeatedEmail(newEmail,emailConfirm,{required:!!newEmail});if(emailError)throw new Error(emailError);if(p.auth_user_id&&!newEmail)throw new Error('Una Persona con cuenta de acceso no puede quedarse sin correo.');if(newEmail!==String(p.email_contacto||'').trim().toLowerCase()&&newEmail){await invokeAccessManager({action:'change_person_email',persona_id:p.id,new_email:newEmail})}const {error}=await sb.rpc('guardar_persona_admin',{p_persona_id:p.id,p_nombre:String(fd.get('firstName')||'').trim(),p_primer_apellido:String(fd.get('lastName1')||'').trim(),p_segundo_apellido:String(fd.get('lastName2')||'').trim()||null,p_email:newEmail||null,p_telefono:String(fd.get('phone')||'').trim()||null,p_fecha_nacimiento:String(fd.get('birth')||'')||null,p_activo:fd.get('active')==='yes'});if(error)throw error;await loadSupabasePersons();await openPersonAdmin(p.id,'identity');renderPersons();
  }catch(err){alert(`No se ha podido guardar la Persona: ${err.message||err}`)}finally{btn.disabled=false;btn.textContent='Guardar identidad'}
}
async function savePersonAdminRoles(){
  const p=dbPersons.find(x=>x.id===selectedPersonAdminId);if(!p)return;const b=$('#savePersonRoles'),feedback=$('#personRoleSaveFeedback');b.disabled=true;b.textContent='Guardando…';if(feedback){feedback.hidden=true;feedback.textContent=''}
  try{
    const wantsCoach=$('#personRoleCoach').checked;
    const args={p_persona_id:p.id,p_administrador:$('#personRoleAdmin').checked,p_club:$('#personRoleClub').checked,p_entrenador:wantsCoach,p_jugador:null};const {error}=await sb.rpc('actualizar_perfiles_persona_admin',args);if(error)throw error;await tryProcessNotifications();
    let message='Perfiles actualizados correctamente.';
    if(wantsCoach&&p.fecha_nacimiento){const d=new Date();d.setFullYear(d.getFullYear()-18);if(p.fecha_nacimiento>d.toISOString().slice(0,10)){const {data}=await sb.from('autorizaciones_menor').select('estado,tutor_persona_id').eq('persona_menor_id',p.id).eq('tipo','entrenador_menor').in('estado',['pendiente','aceptada']).maybeSingle();if(data?.estado==='pendiente'){let tutorName='su tutor';const tp=dbPersons.find(x=>x.id===data.tutor_persona_id);if(tp)tutorName=remotePersonName(tp);message=`Perfil Entrenador añadido. Pendiente de autorización de ${tutorName}.`}else if(data?.estado==='aceptada')message='Perfil Entrenador activo y autorización del tutor vigente.'}}
    await loadSupabasePersons();await loadSupabaseCoaches();await openPersonAdmin(p.id,'access');renderPersons();renderCoaches();renderStructure();
    const f=$('#personRoleSaveFeedback');if(f){f.textContent=message;f.hidden=false;f.className='success-box'}
  }catch(err){alert(`No se han podido actualizar los perfiles: ${err.message||err}`)}finally{b.disabled=false;b.textContent='Guardar perfiles'}
}
async function linkPersonAuth(){const p=dbPersons.find(x=>x.id===selectedPersonAdminId);if(!p)return;try{const {error}=await sb.rpc('vincular_auth_persona_por_email_admin',{p_persona_id:p.id});if(error)throw error;await loadSupabasePersons();await openPersonAdmin(p.id,'access');renderPersons()}catch(err){alert(`No se ha podido vincular la cuenta: ${err.message||err}`)}}


async function loadEconomicConfigs(){
  if(!sb||!['admin','club'].includes(currentRole)||!dbActiveSeason())return [];
  const {data,error}=await sb.from('configuracion_economica_equipo').select('id,temporada_id,equipo_id,importe_inscripcion,admite_fraccionamiento,requiere_pago_ficha,observaciones').eq('temporada_id',dbActiveSeason().id);
  if(error)throw error;dbEconomicConfigs=data||[];return dbEconomicConfigs;
}
function renderEconomicTeamConfig(){
  const body=$('#economicTeamsTable');if(!body)return;
  if(!['admin','club'].includes(currentRole)){body.innerHTML='<tr><td colspan="6">Sin acceso a configuración económica.</td></tr>';return}
  loadEconomicConfigs().then(()=>{
    body.innerHTML=sortTeamsByCategoryAge(dbSeasonTeams(),true).map(t=>{const c=dbEconomicConfigs.find(x=>x.equipo_id===t.id);return `<tr><td><strong>${esc(t.name)}</strong><div class="meta">${esc(dbCategoryName(t.categoryId))}</div></td><td>${c?moneyEUR(c.importe_inscripcion):'Sin configurar'}</td><td>${c?(c.admite_fraccionamiento?'Sí':'No'):'—'}</td><td>${c?(c.requiere_pago_ficha?'Sí':'No'):'—'}</td><td><span class="status ${c&&(!c.requiere_pago_ficha||Number(c.importe_inscripcion)>0)?'complete':'pending'}">${c&&(!c.requiere_pago_ficha||Number(c.importe_inscripcion)>0)?'Configurado':'Pendiente'}</span></td><td><button class="secondary tiny edit-economic-config" data-id="${t.id}">${c?'Editar':'Configurar'}</button></td></tr>`}).join('');
    $$('.edit-economic-config').forEach(b=>b.onclick=()=>openEconomicConfig(b.dataset.id));
  }).catch(err=>{body.innerHTML=`<tr><td colspan="6">No se pudo cargar la configuración: ${esc(err.message||err)}</td></tr>`});
}
function openEconomicConfig(teamId){
  if(!['admin','club'].includes(currentRole))return;selectedEconomicTeamId=teamId;const t=dbTeams.find(x=>x.id===teamId),c=dbEconomicConfigs.find(x=>x.equipo_id===teamId),f=$('#economicConfigForm');if(!t||!f)return;
  $('#economicConfigTitle').textContent=t.name;f.elements.amount.value=c?.importe_inscripcion??'';f.elements.installments.value=c?.admite_fraccionamiento===false?'no':'yes';f.elements.required.value=c?.requiere_pago_ficha===false?'no':'yes';f.elements.notes.value=c?.observaciones||'';$('#economicConfigModal').showModal();
}
async function saveEconomicConfig(form){
  if(!selectedEconomicTeamId||!['admin','club'].includes(currentRole))return;const fd=new FormData(form),amount=Number(fd.get('amount'));
  if(!Number.isFinite(amount)||amount<0){alert('Indica un importe válido.');return}
  const args={p_equipo_id:selectedEconomicTeamId,p_importe_inscripcion:amount,p_admite_fraccionamiento:fd.get('installments')==='yes',p_requiere_pago_ficha:fd.get('required')==='yes',p_observaciones:String(fd.get('notes')||'').trim()||null};
  const btn=form.querySelector('button[type="submit"]');if(btn){btn.disabled=true;btn.textContent='Guardando…'}
  try{const {error}=await sb.rpc('configurar_economia_equipo',args);if(error)throw error;$('#economicConfigModal').close();await loadEconomicConfigs();await renderRemoteClub();renderStructure();}catch(err){alert(`No se ha podido guardar la configuración: ${err.message||err}`)}finally{if(btn){btn.disabled=false;btn.textContent='Guardar configuración'}}
}
function renderEconomicPlayerCurrent(v){const box=$('#economicPlayerCurrent');if(box)box.innerHTML=economicSummaryHtml(v)}
function openEconomicPlayer(){setAdminPlayerTab('economic')}
async function closeEconomicPlayerAndReturn(){setAdminPlayerTab('summary')}
async function refreshEconomicPlayerModal(){await renderRemoteClub();const v=remoteClubPlayers.find(x=>x.id===selectedEconomicPlayerId||x.id===selectedRemotePlayerId);if(v){selectedRemotePlayerId=v.id;selectedEconomicPlayerId=v.id;populateEconomicPlayerTab();updateAdminTabAlerts(v);$('#adminFederationReadiness').innerHTML=readinessProgressHtml(v)}}
async function saveClubberIds(){const v=remoteClubPlayers.find(x=>x.id===selectedEconomicPlayerId),f=$('#economicPlayerForm');if(!v)return;const b=$('#saveClubberIds');b.disabled=true;b.textContent='Guardando…';try{const {error}=await sb.rpc('actualizar_vinculos_clubber',{p_jugador_id:v.id,p_clubber_deportista_id:f.elements.clubberPlayerId.value.trim()||null,p_tutor_persona_id:v.representation?.representante_persona_id||null,p_clubber_tutor_id:f.elements.clubberTutorId.value.trim()||null});if(error)throw error;await refreshEconomicPlayerModal()}catch(err){alert(`No se han podido guardar los IDs Cluber: ${err.message||err}`)}finally{b.disabled=false;b.textContent='Guardar IDs Cluber'}}
async function registerEconomicPayment(){const v=remoteClubPlayers.find(x=>x.id===selectedEconomicPlayerId),f=$('#economicPlayerForm');if(!v)return;const amount=Number(f.elements.paymentAmount.value);if(!Number.isFinite(amount)||amount<=0){alert('Indica un importe mayor que cero.');return}const requestedMethod=f.elements.paymentMethod.value;const allowed=PAYMENT_FEATURES.manualMethods.some(m=>m.enabled&&m.value===requestedMethod);if(!allowed||requestedMethod!=='efectivo'){alert('Actualmente solo se permite registrar manualmente pagos en efectivo. Los pagos de Cluber se incorporarán mediante importación.');return}const b=$('#registerEconomicPayment');b.disabled=true;b.textContent='Registrando…';try{const {error}=await sb.rpc('registrar_pago_inscripcion',{p_inscripcion_id:v.inscription.id,p_importe:amount,p_metodo:'efectivo',p_fecha_pago:f.elements.paymentDate.value||isoToday(),p_referencia_externa:f.elements.paymentReference.value.trim()||null,p_clubber_pago_id:null,p_observaciones:f.elements.paymentNotes.value.trim()||null});if(error)throw error;await refreshEconomicPlayerModal()}catch(err){alert(`No se ha podido registrar el pago: ${err.message||err}`)}finally{b.disabled=false;b.textContent='Registrar pago en efectivo'}}
async function setClubberInstallments(valid){const v=remoteClubPlayers.find(x=>x.id===selectedEconomicPlayerId);if(!v)return;if(valid&&!confirm('Confirma que el club ha verificado en Cluber la domiciliación/fraccionamiento de las cuotas.'))return;if(!valid&&!confirm('¿Revocar la validación del fraccionamiento Cluber?'))return;try{const {error}=await sb.rpc('validar_fraccionamiento_clubber',{p_inscripcion_id:v.inscription.id,p_validado:valid,p_observaciones:null});if(error)throw error;await refreshEconomicPlayerModal()}catch(err){alert(`No se ha podido actualizar el fraccionamiento: ${err.message||err}`)}}
function renderStructure(){
  if(!$('#seasonsTable'))return;
  const can=currentRole==='admin';
  const canEconomic=['admin','club'].includes(currentRole);
  if(dbStructureLoaded){
    const active=dbActiveSeason();
    $('#openSeasonModal').style.display='none';
    $('#openTeamModal').style.display='none';
    $('#seasonsTable').innerHTML=dbSeasons.map(s=>`<tr><td><strong>${esc(s.name)}</strong></td><td>${fmt(s.startDate)}</td><td>${fmt(s.endDate)}</td><td>${s.id===active?.id?'<span class="status complete">Actual</span>':'—'}</td><td>${s.status==='cerrada'?'Cerrada':s.status==='activa'?'Activa':'Planificación'}</td><td>—</td></tr>`).join('');
    const body=$('#structureTeamsTable');
    body.innerHTML='<tr><td colspan="10">Cargando equipos y configuración económica…</td></tr>';
    loadEconomicConfigs().then(()=>{
      body.innerHTML=sortTeamsByCategoryAge(dbSeasonTeams(),true).map(t=>{
        const c=dbEconomicConfigs.find(x=>x.equipo_id===t.id);
        const playersCount=remoteClubPlayers.filter(p=>p.assignment?.equipo_id===t.id&&p.active).length;
        const amount=c?moneyEUR(c.importe_inscripcion):'<span class="meta">Sin configurar</span>';
        const configured=!!c&&(!c.requiere_pago_ficha||Number(c.importe_inscripcion)>0);
        return `<tr class="structure-team-row" data-id="${esc(t.id)}" tabindex="0"><td><strong>${esc(t.name)}</strong>${t.code?`<div class="meta">${esc(t.code)}</div>`:''}</td><td>${esc(dbCategoryName(t.categoryId))}</td><td>${t.modality?esc(t.modality):'—'}</td><td>${playersCount||'—'}</td><td>${coaches.filter(c=>c.active&&(c.assignments||[]).some(a=>a.teamId===t.id&&assignmentState(a)==='active')).length||'—'}</td><td>${amount}</td><td>${c?(c.admite_fraccionamiento?'Sí':'No'):'—'}</td><td>${c?(c.requiere_pago_ficha?'Sí':'No'):'—'}</td><td><span class="status ${t.active&&configured?'complete':t.active?'pending':'returned'}">${!t.active?'Inactivo':configured?'Activo':'Economía pendiente'}</span></td><td>${canEconomic?`<button class="secondary tiny edit-team" data-id="${esc(t.id)}">Abrir</button>`:'<span class="meta">Consulta</span>'}</td></tr>`;
      }).join('')||'<tr><td colspan="10">No hay equipos configurados para la temporada.</td></tr>';
      $$('.structure-team-row').forEach(r=>{
        if(canEconomic){r.onclick=e=>{if(e.target.closest('button'))return;openTeamEdit(r.dataset.id)};r.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();openTeamEdit(r.dataset.id)}}}
      });
      $$('.edit-team').forEach(b=>b.onclick=e=>{e.stopPropagation();openTeamEdit(b.dataset.id)});
    }).catch(err=>{body.innerHTML=`<tr><td colspan="10">No se pudo cargar la configuración: ${esc(err.message||err)}</td></tr>`});
    return;
  }
  $('#openSeasonModal').style.display=can?'inline-flex':'none';$('#openTeamModal').style.display=can?'inline-flex':'none';$('#seasonsTable').innerHTML=seasons.map(s=>`<tr><td><strong>${esc(s.name)}</strong></td><td>${fmt(s.startDate)}</td><td>${fmt(s.endDate)}</td><td>${s.id===currentSeasonId?'<span class="status complete">Actual</span>':'—'}</td><td>${s.active?'Activa':'Cerrada'}</td><td>${can&&s.id!==currentSeasonId?`<button class="secondary tiny activate-season" data-id="${s.id}">Usar</button>`:''}</td></tr>`).join('');$$('.activate-season').forEach(b=>b.onclick=()=>{currentSeasonId=b.dataset.id;writeJSON(K.currentSeason,currentSeasonId);recalculateSeasonCategories(currentSeasonId);recordAudit('Cambio de temporada activa','',seasonName(currentSeasonId));$('#currentSeasonLabel').textContent=seasonName(currentSeasonId);renderStructure();renderClub();renderMedical();renderCoaches()});$('#structureTeamsTable').innerHTML=sortTeamsByCategoryAge(currentSeasonTeams(),false).map(t=>`<tr><td><strong>${esc(t.name)}</strong></td><td>${esc(categoryName(t.categoryId))}</td><td>${t.modality?esc(t.modality):'—'}</td><td>${playerTeams.filter(a=>a.teamId===t.id&&a.seasonId===currentSeasonId&&assignmentState(a)==='active').length}</td><td>${coaches.filter(c=>c.active&&(c.assignments||[]).some(a=>a.teamId===t.id&&assignmentState(a)==='active')).length}</td><td>—</td><td>—</td><td>—</td><td><span class="status ${t.active?'complete':'returned'}">${t.active?'Activo':'Inactivo'}</span></td><td>${can?`<button class="secondary tiny edit-team" data-id="${t.id}">Editar</button>`:''}</td></tr>`).join('');$$('.edit-team').forEach(b=>b.onclick=()=>openTeamEdit(b.dataset.id))
}
function saveTeamAssignment(){if(currentRole==='coach')return;const p=players.find(x=>x.id===selectedPlayerId),i=inscriptionFor(selectedPlayerId);if(!p||!i||i.workflow==='review')return;const teamId=$('#adminTeam').value,old=activeTeamAssignment(p.id);if(old?.teamId===teamId)return;if(old){old.endDate=isoToday();old.reason='Cambio de equipo';}if(teamId){playerTeams.push({id:uid('pt'),playerId:p.id,seasonId:currentSeasonId,teamId,startDate:isoToday(),endDate:currentSeason().endDate,reason:old?'Cambio de equipo':'Asignación inicial'})}savePlayerTeams();recordAudit('Asignación de equipo',p.id,teamId?`Asignado a ${teamName(teamId)}`:'Equipo retirado');openAdminPlayer(p.id);renderClub();renderCoaches();renderStructure()}
function advanceSelected(){const i=inscriptionFor(selectedPlayerId);if(currentRole==='coach'||!i)return;const ix=Math.max(0,WORKFLOW.findIndex(x=>x.key===i.workflow)),n=WORKFLOW[Math.min(ix+1,WORKFLOW.length-1)];updateInscription(selectedPlayerId,x=>({...x,workflow:n.key,federation:n.federation,status:['ready','federated'].includes(n.key)?'complete':'pending',familyActionRequired:false,returnMessage:''}),'Avance de estado');openAdminPlayer(selectedPlayerId)}
function setWorkflowSelected(){if(currentRole==='coach')return;const wf=WORKFLOW.find(x=>x.key===$('#adminWorkflow').value);if(!wf)return;updateInscription(selectedPlayerId,x=>({...x,workflow:wf.key,federation:wf.federation,status:['ready','federated'].includes(wf.key)?'complete':'pending',familyActionRequired:false,returnMessage:''}),'Cambio manual de estado');openAdminPlayer(selectedPlayerId)}
function returnSelected(){const v=playerVM(players.find(x=>x.id===selectedPlayerId));if(currentRole==='coach'||v.rep?.type!=='guardian')return;const m=$('#returnMessage').value.trim();if(!m){alert('Indica qué debe revisar la familia.');return}updateInscription(selectedPlayerId,x=>({...x,workflow:'review',federation:'Devuelto a familia',status:'pending',familyActionRequired:true,returnMessage:m}),'Devuelto a familia: '+m);$('#adminPlayerModal').close()}

function syncGuardianDocumentField(){const f=$('#playerForm'),wrap=$('#guardianDniField'),input=f?.elements?.guardianDni,hint=$('#guardianDniHint');if(!f||!wrap||!input)return;const familyMode=currentRole==='family';wrap.classList.toggle('hidden',!familyMode);input.disabled=!familyMode;input.required=familyMode;if(!familyMode){input.value='';return}const dni=currentUser?.source==='supabase'?normDni(currentUser.documentNumber||''):normDni(personForUser(currentUser?.id)?.dni||'');input.value=dni;input.readOnly=!!dni;if(hint)hint.textContent=dni?'Documento propio del tutor, recuperado automáticamente de su cuenta.':'No hay DNI/NIE de tutor registrado. Completa la identidad antes de inscribir un menor.'}
function openPlayerForNew(){editingPlayerId=null;editingFromCorrection=false;const f=$('#playerForm');f.reset();f.elements.email.value=currentUser?.email||'';f.elements.phone.value=currentUser?.phone||'';syncGuardianDocumentField();syncPlayerRequirements();$('#playerModalEyebrow').textContent='Nueva inscripción';$('#playerCorrectionContext')?.classList.add('hidden');$('#playerModalTitle').textContent='Datos del jugador';$('#savePlayer').textContent='Guardar jugador';refreshCalculatedCategory(f);blockPasteOnEmailConfirm(f);$('#playerModal').showModal()}
function openPlayerForEdit(id){const p=familyAccessPlayers().find(x=>x.id===id);if(!p)return;editingPlayerId=id;const f=$('#playerForm'),parts=p.name.split(' '),i=inscriptionFor(id);f.elements.name.value=parts[0]||'';f.elements.surname1.value=parts[1]||'';f.elements.surname2.value=parts.slice(2).join(' ');f.elements.birth.value=p.birth||'';f.elements.dni.value=p.dni||'';f.elements.email.value=currentUser.email||'';f.elements.phone.value=currentUser.phone||'';syncGuardianDocumentField();$('#playerModalTitle').textContent='Revisar datos del jugador';$('#savePlayer').textContent='Guardar cambios';refreshCalculatedCategory(f);$('#playerModal').showModal()}

function openChangeTutor(){if(currentRole!=='admin')return;const p=players.find(x=>x.id===selectedPlayerId);if(!p)return;const eligible=users.filter(u=>hasRole(u,'family')&&u.active);$('#tutorUserSelect').innerHTML='<option value="">Seleccionar tutor registrado</option>'+eligible.map(u=>`<option value="${u.id}">${esc(u.name)} · ${esc(u.email)}</option>`).join('');$('#changeTutorForm').reset();$('#changeTutorModal').showModal()}
function openSelfRepresentation(){if(currentRole!=='admin')return;const p=players.find(x=>x.id===selectedPlayerId);if(!p)return;const pu=currentPlayerUser(p),d=daysTo18(p),a=ageOn(p.birth);const f=$('#selfRepresentationForm');f.reset();if(pu)f.elements.email.value=pu.email;$('#selfRepresentationHint').textContent=a>=18?'El jugador ya es mayor de edad: la cuenta se activará ahora y la representación ordinaria del tutor finalizará.':`La cuenta quedará preparada y se activará al cumplir 18 años${d!==null?` (en ${d} días)`:''}.`;$('#selfRepresentationModal').showModal()}

function openTeamEdit(id){
  editingTeamId=id;
  const remote=dbStructureLoaded;
  const t=remote?dbTeams.find(x=>x.id===id):teams.find(x=>x.id===id);if(!t)return;
  fillTeamCategorySelect();
  const f=$('#teamForm'),c=remote?dbEconomicConfigs.find(x=>x.equipo_id===id):null;
  f.elements.name.value=t.name||'';f.elements.categoryId.value=t.categoryId||'';f.elements.code.value=t.code||'';f.elements.modality.value=t.modality||'';f.elements.gender.value=t.gender||'';f.elements.active.value=t.active?'yes':'no';
  f.elements.amount.value=c?.importe_inscripcion??'';f.elements.installments.value=c?.admite_fraccionamiento===false?'no':'yes';f.elements.required.value=c?.requiere_pago_ficha===false?'no':'yes';f.elements.notes.value=c?.observaciones||'';
  const sportsEditable=['admin','club'].includes(currentRole);['name','categoryId','code','modality','gender','active'].forEach(n=>{if(f.elements[n])f.elements[n].disabled=remote&&!sportsEditable});
  ['amount','installments','required','notes'].forEach(n=>{if(f.elements[n])f.elements[n].disabled=remote&&!['admin','club'].includes(currentRole)});
  $('#teamModalSeason').textContent=remote?`Temporada ${dbActiveSeason()?.name||''} · ${currentRole==='club'?'Gestión deportiva del club':'Administración'}`:`Temporada ${seasonName(currentSeasonId)}`;
  $('#teamModalTitle').textContent=t.name||'Editar equipo';
  const teamModal=$('#teamModal'),closeTeam=$('#closeTeamModal'),cancelTeam=$('#cancelTeam'),teamForm=$('#teamForm');
  if(closeTeam)closeTeam.onclick=()=>teamModal?.close();
  if(cancelTeam)cancelTeam.onclick=()=>teamModal?.close();
  if(teamForm)teamForm.onsubmit=e=>{e.preventDefault();saveUnifiedTeam(e.currentTarget)};
  teamModal?.showModal()
}
function fillTeamCategorySelect(){const s=$('#teamCategorySelect'),source=dbStructureLoaded?dbCategories:categories;s.innerHTML=source.filter(c=>c.active).map(c=>`<option value="${c.id}">${esc(c.name)}</option>`).join('')}
async function saveUnifiedTeam(form){
  const fd=new FormData(form),remote=dbStructureLoaded;
  if(remote){
    if(!editingTeamId||!['admin','club'].includes(currentRole))return;
    const button=form.querySelector('button[type="submit"]');if(button){button.disabled=true;button.textContent='Guardando…'}
    try{
      if(['admin','club'].includes(currentRole)){
        const payload={nombre:String(fd.get('name')||'').trim(),categoria_id:fd.get('categoryId'),codigo:String(fd.get('code')||'').trim()||null,modalidad:String(fd.get('modality')||'')||null,genero:String(fd.get('gender')||'')||null,activo:fd.get('active')==='yes'};
        if(!payload.nombre){alert('Indica el nombre del equipo.');return}
        const {error}=await sb.from('equipos').update(payload).eq('id',editingTeamId);if(error)throw error;
      }
      const amountRaw=String(fd.get('amount')??'').trim();
      if(amountRaw!==''){
        const amount=Number(amountRaw);if(!Number.isFinite(amount)||amount<0){alert('Indica un importe válido.');return}
        const {error}=await sb.rpc('configurar_economia_equipo',{p_equipo_id:editingTeamId,p_importe_inscripcion:amount,p_admite_fraccionamiento:fd.get('installments')==='yes',p_requiere_pago_ficha:fd.get('required')==='yes',p_observaciones:String(fd.get('notes')||'').trim()||null});if(error)throw error;
      }
      await loadSupabaseStructure();await loadEconomicConfigs();await renderRemoteClub();$('#teamModal').close();renderStructure();
    }catch(err){alert(`No se ha podido guardar el equipo: ${err.message||err}`)}finally{if(button){button.disabled=false;button.textContent='Guardar equipo'}}
    return;
  }
  if(currentRole!=='admin')return;
  if(editingTeamId){const t=teams.find(x=>x.id===editingTeamId);Object.assign(t,{name:fd.get('name'),categoryId:fd.get('categoryId'),code:fd.get('code')||'',modality:fd.get('modality')||'',gender:fd.get('gender')||'',active:fd.get('active')==='yes'})}else teams.push({id:uid('t'),seasonId:currentSeasonId,name:fd.get('name'),categoryId:fd.get('categoryId'),code:fd.get('code')||'',modality:fd.get('modality')||'',gender:fd.get('gender')||'',active:fd.get('active')==='yes'});saveTeams();recordAudit('Equipo actualizado','',fd.get('name'));$('#teamModal').close();renderStructure();renderCoaches();
}

function renderUserAssignments(){renderAssignmentList('#clubUserAssignmentsList',pendingUserAssignments,'remove-user-assignment');$$('.remove-user-assignment').forEach(b=>b.onclick=()=>{pendingUserAssignments.splice(+b.dataset.index,1);renderUserAssignments()})}
function syncCoachUserFields(){const role=$('#clubUserRole'),fields=$('#coachUserFields');if(!role||!fields)return;const x=role.value==='coach';fields.classList.toggle('hidden',!x);if(x){fillAssignmentTeamSelect('#clubUserAssignmentTeam');renderUserAssignments()}}

$('#showLogin').onclick=()=>showAuth('login');$('#showFamilySignup').onclick=()=>showAuth('signup');
function syncSignupMode(){const self=document.querySelector('input[name="signupMode"]:checked')?.value==='self';$('#selfSignupFields').classList.toggle('hidden',!self);$('#guardianSignupFields').classList.toggle('hidden',self);const f=$('#familySignupForm'),tutorDni=f?.elements?.tutorDni,tutorType=f?.elements?.tutorDocumentType,selfDni=f?.elements?.selfDni,selfType=f?.elements?.selfDocumentType;if(tutorDni){tutorDni.required=!self;tutorDni.disabled=self}if(tutorType)tutorType.disabled=self;if(selfDni)selfDni.disabled=!self;if(selfType)selfType.disabled=!self;refreshCalculatedCategory(f)}
$$('input[name="signupMode"]').forEach(r=>r.onchange=syncSignupMode);syncSignupMode();
$('#loginForm').onsubmit=async e=>{e.preventDefault();const form=e.currentTarget;if(!sb){alert('No se ha podido cargar Supabase. Comprueba tu conexión.');return}const fd=new FormData(form),email=String(fd.get('email')||'').trim(),password=String(fd.get('password')||'');const submit=form.querySelector('button[type="submit"]');if(submit){submit.disabled=true;submit.textContent='Entrando…'}clearConfirmationContext();try{const {data,error}=await sb.auth.signInWithPassword({email,password});if(error)throw error;const readyUser=await prepareAuthenticatedUser(data.user);if(!readyUser)return;await processAdultTransitions();currentUser=await loadIdentityWithPending(readyUser);await loadSupabaseStructure();await tryProcessNotifications();const avail=availableRoles(currentUser);if(!avail.length){await sb.auth.signOut();currentUser=null;throw new Error('Tu cuenta no tiene ningún perfil activo en el club.')}currentRole=avail.length===1?avail[0]:null;form.reset();if(currentRole){localStorage.setItem(K.sessionRole,currentRole);showApp()}else{localStorage.removeItem(K.sessionRole);showRoleChooser()}}catch(err){console.error('Login Supabase',err);const msg=String(err?.message||err||'');if(/email.*not.*confirm|not.*confirmed|confirm.*email/i.test(msg)){setConfirmationContext(email,'Tu cuenta todavía no está confirmada. Revisa el correo de alta o solicita uno nuevo.');alert('Tu cuenta todavía no está confirmada. Revisa tu correo o utiliza “Reenviar correo de confirmación”.')}else{alert(msg==='Invalid login credentials'?'Correo o contraseña incorrectos.':`No se ha podido iniciar sesión: ${msg}`)}}finally{if(submit){submit.disabled=false;submit.textContent='Entrar'}}};
$('#familySignupForm').onsubmit=async e=>{
  e.preventDefault();const form=e.currentTarget;if(!sb){alert('No se ha podido cargar Supabase.');return}
  const fd=new FormData(form),mode=String(fd.get('signupMode')||'guardian'),password=String(fd.get('password')||''),password2=String(fd.get('password2')||''),email=String(fd.get('email')||'').trim().toLowerCase(),emailConfirm=String(fd.get('emailConfirm')||'').trim().toLowerCase(),birth=String(fd.get('birth')||'');
  const emailError=validateRepeatedEmail(email,emailConfirm,{required:true});if(emailError){alert(emailError);return}
  if(password!==password2){alert('Las contraseñas no coinciden.');return}
  const age=ageOn(birth);if(age===null||age<18){alert('El registro de cuenta solo está disponible para mayores de 18 años. Si el jugador es menor, debe registrarlo su tutor.');return}
  const documentNumber=normDni(mode==='guardian'?fd.get('tutorDni'):fd.get('selfDni'));
  const documentType=String(mode==='guardian'?fd.get('tutorDocumentType'):fd.get('selfDocumentType')||'dni');
  if(mode==='guardian'&&!documentNumber){alert('El DNI/NIE del tutor es obligatorio.');return}
  const identityError=validateSpanishIdentity(documentType,documentNumber,{required:mode==='guardian'});if(identityError){alert(identityError);return}
  const payload={mode,firstName:String(fd.get('firstName')||'').trim(),surname1:String(fd.get('surname1')||'').trim(),surname2:String(fd.get('surname2')||'').trim(),birth,phone:String(fd.get('phone')||'').trim(),email,documentType,documentNumber};
  const submit=form.querySelector('button[type="submit"]');if(submit){submit.disabled=true;submit.textContent='Creando cuenta…'}
  try{
    localStorage.setItem(PENDING_SIGNUP_KEY,JSON.stringify(payload));
    const {data,error}=await sb.auth.signUp({email,password,options:{emailRedirectTo:AUTH_REDIRECT_URL}});if(error)throw error;
    if(data.user&&Array.isArray(data.user.identities)&&data.user.identities.length===0){form.reset();showAuth('login');const loginEmail=$('#loginForm')?.elements?.email;if(loginEmail)loginEmail.value=email;alert('Ya existe una cuenta con ese correo. Inicia sesión con tu contraseña habitual y la aplicación añadirá el nuevo perfil a tu Persona existente.');return}
    if(data.session){
      await registerProfileFromPayload(payload);currentUser=await loadSupabaseIdentity(data.user);await loadSupabaseStructure();currentRole=mode==='guardian'?'family':'player';localStorage.setItem(K.sessionRole,currentRole);form.reset();showApp();
    }else{
      form.reset();showAuth('login');const loginEmail=$('#loginForm')?.elements?.email;if(loginEmail)loginEmail.value=email;setConfirmationContext(email,`Cuenta creada. Hemos enviado un correo de confirmación a ${email}. Si no lo recibes, puedes solicitar uno nuevo aquí.`);alert('Cuenta creada. Revisa tu correo y confirma la dirección antes de iniciar sesión.');
    }
  }catch(err){console.error('Alta Supabase',err);alert(`No se ha podido crear la cuenta: ${err.message||err}`)}finally{if(submit){submit.disabled=false;submit.textContent='Crear cuenta'}}
};
$('#forgotPasswordButton').onclick=requestPasswordRecovery;
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
    alert(`Confirmación de alta reenviada a ${email}. Usa únicamente el enlace del mensaje más reciente.`);
  }catch(err){
    console.error('Reenvío confirmación Supabase',err);
    const msg=String(err?.message||err||'');
    if(/rate limit|security purposes|seconds/i.test(msg)){
      alert('Supabase limita temporalmente los reenvíos por seguridad. Espera unos segundos y vuelve a intentarlo.');
    }else{
      alert(`No se ha podido reenviar la confirmación de alta: ${msg}`);
    }
  }finally{
    if(button){button.disabled=false;button.textContent=originalText}
  }
};

function authRedirectType(){
  const url=new URL(window.location.href),search=new URLSearchParams(url.search),hash=new URLSearchParams((url.hash||'').replace(/^#/,''));
  return String(search.get('type')||hash.get('type')||'').toLowerCase();
}
function clearAuthCallbackUrl(){
  const url=new URL(window.location.href);['code','type','token','token_hash','error','error_code','error_description'].forEach(k=>url.searchParams.delete(k));url.hash='';history.replaceState({},document.title,url.toString());
}
async function requestPasswordRecovery(){
  if(!sb){alert('No se ha podido cargar Supabase. Comprueba tu conexión.');return}
  const email=String($('#loginForm')?.elements?.email?.value||'').trim().toLowerCase();
  if(!email){alert('Introduce primero tu correo electrónico.');$('#loginForm')?.elements?.email?.focus();return}
  const b=$('#forgotPasswordButton'),txt=b?.textContent||'¿Has olvidado tu contraseña?';if(b){b.disabled=true;b.textContent='Enviando…'}
  try{const {error}=await sb.auth.resetPasswordForEmail(email,{redirectTo:AUTH_REDIRECT_URL});if(error)throw error;alert(`Te hemos enviado un enlace de recuperación a ${email}. Usa el mensaje más reciente.`)}catch(err){const msg=String(err?.message||err||'');alert(/rate limit|security purposes|seconds/i.test(msg)?'Supabase limita temporalmente los envíos por seguridad. Espera unos segundos y vuelve a intentarlo.':`No se ha podido enviar el correo de recuperación: ${msg}`)}finally{if(b){b.disabled=false;b.textContent=txt}}
}
async function handlePasswordRecovery(){
  if(authRedirectType()!=='recovery')return false;
  const dialog=$('#passwordRecoveryModal'),form=$('#passwordRecoveryForm');if(!dialog||!form)return false;
  try{const {data,error}=await sb.auth.getSession();if(error)throw error;if(!data.session)throw new Error('La sesión de recuperación no está disponible o ha caducado.');
    showAuth('login');form.reset();
    return await new Promise(resolve=>{
      $('#recoveryCancel').onclick=async()=>{await sb.auth.signOut();dialog.close();clearAuthCallbackUrl();resolve(true)};
      form.onsubmit=async e=>{e.preventDefault();const fd=new FormData(form),p=String(fd.get('password')||''),p2=String(fd.get('password2')||''),btn=form.querySelector('button[type="submit"]');if(p!==p2){alert('Las contraseñas no coinciden.');return}if(p.length<8){alert('La contraseña debe tener al menos 8 caracteres.');return}btn.disabled=true;btn.textContent='Guardando…';try{const {error}=await sb.auth.updateUser({password:p});if(error)throw error;await sb.auth.signOut();dialog.close();clearAuthCallbackUrl();showAuth('login');alert('Contraseña actualizada correctamente. Ya puedes iniciar sesión con la nueva contraseña.');resolve(true)}catch(err){alert(`No se ha podido actualizar la contraseña: ${err.message||err}`)}finally{btn.disabled=false;btn.textContent='Guardar nueva contraseña'}};
      dialog.showModal();
    });
  }catch(err){clearAuthCallbackUrl();showAuth('login');alert(`No se ha podido abrir la recuperación de contraseña: ${err.message||err}`);return true}
}

function showAuthRedirectError(){
  const url=new URL(window.location.href);
  const params=new URLSearchParams(url.search);
  const hashParams=new URLSearchParams((url.hash||'').replace(/^#/,''));
  const code=params.get('error_code')||hashParams.get('error_code');
  const description=params.get('error_description')||hashParams.get('error_description');
  if(!code&&!description)return;
  const expired=code==='otp_expired'||/expired|invalid/i.test(description||'');
  setTimeout(()=>alert(expired?'El enlace no es válido o ha caducado. Si era un alta propia, solicita una nueva confirmación; si era una recuperación de contraseña, vuelve a pedir un enlace de recuperación.':`No se ha podido completar la confirmación: ${description||code}`),0);
  ['error','error_code','error_description'].forEach(k=>url.searchParams.delete(k));
  if(url.hash)url.hash='';
  history.replaceState({},document.title,url.toString());
}
showAuthRedirectError();

$('#logoutButton').onclick=async()=>{localStorage.removeItem(K.sessionRole);currentUser=null;currentRole=null;if(sb)await sb.auth.signOut();showAuth('login')};$('#roleSwitchButton').onclick=()=>showRoleChooser(true);$('#closeRoleChooser').onclick=()=>$('#roleChooserModal').close();if($('#clubProfileButton'))$('#clubProfileButton').onclick=openAccountProfile;if($('#closeAccountProfileModal'))$('#closeAccountProfileModal').onclick=()=>$('#accountProfileModal').close();if($('#changeAccountEmail'))$('#changeAccountEmail').onclick=async()=>{const input=$('#accountEmail'),confirmInput=$('#accountEmailConfirm'),feedback=$('#accountEmailFeedback'),b=$('#changeAccountEmail'),email=String(input?.value||'').trim().toLowerCase(),emailConfirm=String(confirmInput?.value||'').trim().toLowerCase();const emailError=validateRepeatedEmail(email,emailConfirm,{required:true});if(emailError){feedback.textContent=emailError;feedback.className='warning-box';feedback.hidden=false;return}b.disabled=true;b.textContent='Cambiando…';try{const data=await invokeAccessManager({action:'change_person_email',persona_id:currentUser.personId,new_email:email});currentUser.email=data.email;$('#accountProfileMeta').textContent=currentUser.email;if(confirmInput)confirmInput.value=data.email;feedback.textContent='Correo actualizado. A partir de ahora este será tu correo de acceso y comunicaciones.';feedback.className='success-box';feedback.hidden=false}catch(err){feedback.textContent=`No se ha podido cambiar el correo: ${err.message||err}`;feedback.className='warning-box';feedback.hidden=false}finally{b.disabled=false;b.textContent='Cambiar correo'}};if($('#closeTemporaryAccessModal'))$('#closeTemporaryAccessModal').onclick=()=>$('#temporaryAccessModal').close();if($('#acceptTemporaryAccess'))$('#acceptTemporaryAccess').onclick=()=>$('#temporaryAccessModal').close();if($('#copyTemporaryPassword'))$('#copyTemporaryPassword').onclick=async()=>{const v=$('#temporaryAccessPassword').value;try{await navigator.clipboard.writeText(v);$('#copyTemporaryPassword').textContent='Copiada';setTimeout(()=>$('#copyTemporaryPassword').textContent='Copiar',1200)}catch{alert('No se ha podido copiar automáticamente. Selecciona la contraseña manualmente.')}};if($('#accountPasswordForm'))$('#accountPasswordForm').onsubmit=async e=>{e.preventDefault();const f=e.currentTarget,fd=new FormData(f),p=String(fd.get('password')||''),p2=String(fd.get('password2')||''),b=f.querySelector('button[type="submit"]');if(p!==p2){alert('Las contraseñas no coinciden.');return}if(p.length<8){alert('La contraseña debe tener al menos 8 caracteres.');return}b.disabled=true;b.textContent='Actualizando…';try{await changeOwnPassword(p);f.reset();$('#accountProfileModal').close();alert('Contraseña actualizada correctamente.')}catch(err){alert(`No se ha podido cambiar la contraseña: ${err.message||err}`)}finally{b.disabled=false;b.textContent='Cambiar contraseña'}};

function refreshCalculatedCategory(form){const birth=form?.elements?.birth?.value||'',cat=(currentUser?.source==='supabase'&&dbStructureLoaded)?dbCategoryForBirth(birth):categoryForBirth(birth,currentSeasonId),out=form?.querySelector?.('[data-category-calculated]');if(out)out.value=cat?cat.name:'Fuera de categorías configuradas'}
$('#familySignupForm')?.elements?.birth?.addEventListener('change',()=>refreshCalculatedCategory($('#familySignupForm')));
$('#playerForm')?.elements?.birth?.addEventListener('change',()=>refreshCalculatedCategory($('#playerForm')));
if($('#playerForm')?.elements?.birth)$('#playerForm').elements.birth.addEventListener('change',()=>{refreshCalculatedCategory($('#playerForm'));syncPlayerEmailRequirement()});
$('#addPlayerButton').onclick=openPlayerForNew;$('#playerForm').onsubmit=async e=>{e.preventDefault();const form=e.currentTarget;if(currentUser?.source==='supabase'&&currentRole==='family'&&editingPlayerId){const fd=new FormData(form),birth=String(fd.get('birth')||''),age=ageOn(birth),docNumber=normDni(fd.get('dni')||''),docType=String(fd.get('childDocumentType')||''),newEmail=String(fd.get('playerEmail')||'').trim().toLowerCase(),newEmailConfirm=String(fd.get('playerEmailConfirm')||'').trim().toLowerCase(),player=remoteFamilyPlayers.find(x=>x.id===editingPlayerId);if(playerEmailIsRequired(birth,player?.personId||'')&&!newEmail){alert('Este jugador necesita un correo propio antes de continuar.');return}const emailError=validateRepeatedEmail(newEmail,newEmailConfirm,{required:!!newEmail||playerEmailIsRequired(birth,player?.personId||'')});if(emailError){alert(emailError);return}if(age!==null&&age>=14&&age<18&&(!docNumber||!['dni','nie'].includes(docType))){alert('A partir de los 14 años es obligatorio informar el DNI o NIE propio del jugador.');return}const childIdentityError=validateSpanishIdentity(docType,docNumber,{required:age!==null&&age>=14&&age<18});if(childIdentityError){alert(childIdentityError);return}const submit=$('#savePlayer');if(submit){submit.disabled=true;submit.textContent='Guardando…'}try{const correctionMode=editingFromCorrection;const rpc=correctionMode?'responder_correcciones_menor':'actualizar_menor_representado';const {error}=await sb.rpc(rpc,{p_jugador_id:editingPlayerId,p_nombre:String(fd.get('name')||'').trim(),p_primer_apellido:String(fd.get('surname1')||'').trim(),p_segundo_apellido:String(fd.get('surname2')||'').trim()||null,p_fecha_nacimiento:birth,p_tipo_documento:docNumber?docType:null,p_numero_documento:docNumber||null,p_email_jugador:newEmail||null});if(error)throw error;if(player?.personId&&newEmail&&newEmail!==String(player.playerEmail||'').trim().toLowerCase())await invokeAccessManager({action:'change_person_email',persona_id:player.personId,new_email:newEmail});const wasCorrection=editingFromCorrection;editingPlayerId=null;editingFromCorrection=false;form.reset();$('#playerModal').close();await renderRemoteFamily();alert(wasCorrection?'Correcciones enviadas al club para revisión.':'Datos actualizados. La ficha vuelve a quedar pendiente de revisión por el club.')}catch(err){console.error('Edición menor Supabase',err);alert(`No se han podido guardar los cambios: ${err.message||err}`)}finally{if(submit){submit.disabled=false;submit.textContent='Guardar jugador'}}return;}if(currentUser?.source==='supabase'&&currentRole==='family'&&!editingPlayerId){const fd=new FormData(form),birth=String(fd.get('birth')||''),age=ageOn(birth),newEmail=String(fd.get('playerEmail')||'').trim().toLowerCase(),newEmailConfirm=String(fd.get('playerEmailConfirm')||'').trim().toLowerCase(),docNumber=normDni(fd.get('dni')||''),docType=String(fd.get('childDocumentType')||'');if(age===null||age>=18){alert('Este formulario es para menores de 18 años. Un adulto debe crear su propia cuenta de Jugador.');return}if(age>=16&&!newEmail){alert('A partir de los 16 años es obligatorio informar un correo propio del jugador.');return}const emailError=validateRepeatedEmail(newEmail,newEmailConfirm,{required:!!newEmail||age>=16});if(emailError){alert(emailError);return}if(age>=14&&(!docNumber||!['dni','nie'].includes(docType))){alert('A partir de los 14 años es obligatorio informar el DNI o NIE propio del jugador.');return}const childIdentityError=validateSpanishIdentity(docType,docNumber,{required:age>=14});if(childIdentityError){alert(childIdentityError);return}if(!currentUser.documentNumber){alert('Tu perfil de Tutor no tiene DNI/NIE registrado. Contacta con el club antes de continuar.');return}const submit=$('#savePlayer');if(submit){submit.disabled=true;submit.textContent='Guardando…'}try{const {error}=await sb.rpc('registrar_menor',{p_nombre:String(fd.get('name')||'').trim(),p_primer_apellido:String(fd.get('surname1')||'').trim(),p_segundo_apellido:String(fd.get('surname2')||'').trim()||null,p_fecha_nacimiento:birth,p_tipo_documento:docNumber?docType:null,p_numero_documento:docNumber||null,p_email_jugador:newEmail||null});if(error)throw error;form.reset();$('#playerModal').close();await renderRemoteFamily();alert('Jugador registrado correctamente. La inscripción ha quedado pendiente de revisión por el club.')}catch(err){console.error('Alta menor Supabase',err);alert(`No se ha podido registrar al jugador: ${err.message||err}`)}finally{if(submit){submit.disabled=false;submit.textContent='Guardar jugador'}}return;}if(currentRole==='player'&&!editingPlayerId)return;const fd=new FormData(e.currentTarget),full=[fd.get('name'),fd.get('surname1'),fd.get('surname2')].filter(Boolean).join(' '),birth=fd.get('birth'),cat=categoryForBirth(birth,currentSeasonId),childDni=normDni(fd.get('dni')||'');if(!cat){alert('La fecha de nacimiento no corresponde a una categoría configurada para la temporada activa.');return}let guardianPerson=null,guardianDni='';if(currentRole==='family'){guardianPerson=personForUser(currentUser.id);guardianDni=normDni(fd.get('guardianDni')||guardianPerson?.dni||'');if(!guardianDni){alert('El DNI/NIE del tutor es obligatorio.');return}const owner=personWithOwnDni(guardianDni,guardianPerson?.id||'');if(owner){alert(`El DNI/NIE ${guardianDni} ya pertenece a otra persona registrada. El club debe revisar la identidad antes de continuar.`);return}if(guardianPerson&&!guardianPerson.dni){guardianPerson.dni=guardianDni;writeJSON(K.persons,persons)}}const dupPlayer=duplicatePlayerMatch(full,birth,childDni,editingPlayerId||'');if(dupPlayer){alert(`Posible duplicado: ya existe ${dupPlayer.name} con el mismo DNI/NIE propio o con el mismo nombre y fecha de nacimiento. El DNI del tutor no se usa para deduplicar jugadores.`);return}if(editingPlayerId){const p=players.find(x=>x.id===editingPlayerId);if(!p)return;p.name=full;p.birth=birth||'';p.dni=childDni;p.data=true;const pp=personForPlayer(p.id);if(pp)pp.dni=childDni;const i=inscriptionFor(p.id);if(i){const old=i.workflow;i.categoryId=cat?.id||i.categoryId;i.workflow='review';i.federation='Modificado por usuario · pendiente de revisión';i.status='pending';i.familyActionRequired=false;i.returnMessage='';if(childDni){i.identityDocumentSource='player';i.identityDocumentPersonId=p.personId;i.identityDocumentSnapshot=childDni}else if(currentRole==='family'&&guardianPerson){i.identityDocumentSource='guardian';i.identityDocumentPersonId=guardianPerson.id;i.identityDocumentSnapshot=guardianDni}addStatusHistory(i.id,p.id,old,'review','Datos modificados por usuario')}recordAudit('Datos del jugador modificados',p.id,childDni?'Documento propio informado':'Sin DNI propio · utiliza documento del tutor');savePlayers();saveInscriptions();writeJSON(K.persons,persons)}else{const person={id:uid('person'),name:full,email:'',dni:childDni,createdAt:isoToday(),mergedFrom:[]};persons.push(person);const pid=uid('p'),iid=uid('i');players.push({id:pid,personId:person.id,name:full,birth:birth||'',dni:childDni,data:true,active:true});inscriptions.push({id:iid,playerId:pid,seasonId:currentSeasonId,categoryId:cat?.id||'cat-pb',docs:'Pendiente de documentos',workflow:'review',federation:'Pendiente de revisión',status:'pending',familyActionRequired:false,returnMessage:'',createdAt:isoToday(),identityDocumentSource:childDni?'player':'guardian',identityDocumentPersonId:childDni?person.id:guardianPerson?.id||'',identityDocumentSnapshot:childDni||guardianDni});representations.push({id:uid('r'),playerId:pid,userId:currentUser.id,type:'guardian',startDate:isoToday(),endDate:'',reason:'Inscripción inicial',legalException:false});addStatusHistory(iid,pid,'','review','Inscripción creada por familia');recordAudit('Alta de jugador',pid,childDni?'Con DNI/NIE propio':'Sin DNI propio · documento del tutor reutilizado');savePlayers();saveInscriptions();saveReps();writeJSON(K.persons,persons)}renderFamily();e.currentTarget.reset();editingPlayerId=null;$('#playerModal').close()};$$('#playerForm [value="cancel"]').forEach(b=>b.onclick=()=>{$('#playerForm').reset();editingPlayerId=null;editingFromCorrection=false;$('#playerCorrectionContext')?.classList.add('hidden');$('#playerModal').close()});

$('#searchInput').oninput=renderClub;['statusFilter','clubCategoryFilter','clubActiveFilter'].forEach(id=>$('#'+id).onchange=renderClub);$$('[data-club-quick]').forEach(el=>{const go=()=>{const v=el.dataset.clubQuick;clubQuickFilter=(clubQuickFilter===v&&v!=='all')?'all':v;renderClub()};el.onclick=go;el.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();go()}}});$('#saveTeamAssignment').onclick=()=>currentUser?.source==='supabase'?saveRemoteTeamAssignment():saveTeamAssignment();$('#advanceStatus').onclick=()=>currentUser?.source==='supabase'?advanceRemoteSelected():advanceSelected();$('#saveWorkflow').onclick=()=>currentUser?.source==='supabase'?setRemoteWorkflowSelected():setWorkflowSelected();$('#returnToFamily').onclick=()=>currentUser?.source==='supabase'?returnRemoteSelected():returnSelected();$('#closeAdminModal').onclick=()=>$('#adminPlayerModal').close();$('#changeTutorButton').onclick=openChangeTutor;$('#selfRepresentationButton').onclick=openSelfRepresentation;
$$('[data-club-view]').forEach(b=>b.onclick=()=>{if(currentRole==='coach'&&b.dataset.clubView!=='clubView')return;if(['usersView','personsView'].includes(b.dataset.clubView)&&currentRole!=='admin')return;setView(b.dataset.clubView);if(b.dataset.clubView==='clubView')renderClub();if(b.dataset.clubView==='medicalView')renderMedical();if(b.dataset.clubView==='coachesView'){if(currentUser?.source==='supabase'){loadSupabaseCoaches().then(()=>renderCoaches()).catch(err=>{console.error('Recarga entrenadores',err);renderCoaches()})}else renderCoaches();}if(b.dataset.clubView==='structureView')renderStructure();if(b.dataset.clubView==='usersView')renderClubUsers();if(b.dataset.clubView==='personsView')renderPersons()});
function setFamilyMainTab(tab){
  $$('[data-family-tab]').forEach(x=>x.classList.toggle('active',x.dataset.familyTab===tab));
  const playersSec=$('#familyPlayersSection'),statusSec=$('#familyStatusSection'),hero=$('#familyHero');
  if(playersSec)playersSec.hidden=false;
  if(statusSec)statusSec.hidden=false;
  if(hero)hero.hidden=false;
  $('#familyHeroEyebrow').textContent=currentRole==='player'?'Área del jugador':'Área de familias';
  $('#familyHeroTitle').textContent=currentRole==='player'?'Gestiona tu ficha federativa':'Gestiona la ficha de tus hijos desde el móvil';
  $('#familyHeroText').textContent=currentRole==='player'?'Consulta tu inscripción, documentación y estado federativo.':'Completa datos, adjunta documentación y consulta el estado de cada inscripción.';
  const fpEyebrow=$('#familyPlayersSection .eyebrow');if(fpEyebrow){fpEyebrow.hidden=currentRole==='player';fpEyebrow.textContent='Mis jugadores';}
  if(tab==='players'&&playersSec){playersSec.scrollIntoView({behavior:'smooth'});return;}
  if(tab==='profile'){openAccountProfile();return;}
  window.scrollTo({top:0,behavior:'smooth'});
}
$$('[data-family-tab]').forEach(b=>b.onclick=()=>setFamilyMainTab(b.dataset.familyTab));

// V51: la delegación documental se registra al inicio del script.

$('#togglePlayerActive').onclick=()=>{if(currentUser?.source==='supabase')return toggleRemotePlayerActive();if(currentRole!=='admin'&&currentRole!=='club')return;const p=players.find(x=>x.id===selectedPlayerId);if(!p)return;const next=p.active===false;p.active=next;savePlayers();recordAudit(next?'Jugador reactivado':'Jugador marcado inactivo',p.id,next?'Vuelve a operación diaria':'Salida o baja operativa');openAdminPlayer(p.id);renderClub();renderMedical()};
$('#changeTutorForm').onsubmit=e=>{e.preventDefault();if(currentRole!=='admin')return;const fd=new FormData(e.currentTarget),p=players.find(x=>x.id===selectedPlayerId),newUser=users.find(u=>u.id===fd.get('tutorUserId'));if(!p||!newUser)return;const newTutorPerson=personForUser(newUser.id);if(!normDni(newTutorPerson?.dni||'')){alert('El tutor seleccionado no tiene DNI/NIE propio registrado. Completa su identidad antes de asignarlo como representante.');return}const legal=fd.get('legalException')==='on',a=ageOn(p.birth);if(a>=18&&!legal){alert('El jugador ya es mayor de edad. Solo puede mantenerse un tutor si se registra una excepción jurídica.');return}const old=activeRepresentation(p.id);if(old)old.endDate=isoToday();representations.push({id:uid('r'),playerId:p.id,userId:newUser.id,type:'guardian',startDate:isoToday(),endDate:'',reason:fd.get('reason'),legalException:legal});saveReps();recordAudit('Cambio de tutor',p.id,`${repUserName(old)} → ${newUser.name}. Motivo: ${fd.get('reason')}`);$('#changeTutorModal').close();openAdminPlayer(p.id);renderClub()};
$('#closeChangeTutorModal').onclick=$('#cancelChangeTutor').onclick=()=>$('#changeTutorModal').close();
$('#selfRepresentationForm').onsubmit=e=>{e.preventDefault();if(currentRole!=='admin')return;const fd=new FormData(e.currentTarget),p=players.find(x=>x.id===selectedPlayerId);if(!p)return;const email=String(fd.get('email')).toLowerCase();let pu=currentPlayerUser(p),byEmail=users.find(u=>u.email.toLowerCase()===email);const birthday=eighteenthBirthday(p),adult=ageOn(p.birth)>=18;if(!pu&&byEmail){byEmail=normalizeUser(byEmail);if(!hasRole(byEmail,'player'))byEmail.roles.push('player');byEmail.playerId=p.id;byEmail.pendingActivationDate=adult?'':birthday;pu=byEmail}else if(pu){pu=normalizeUser(pu);if(!hasRole(pu,'player'))pu.roles.push('player');pu.email=email;pu.playerId=p.id;pu.pendingActivationDate=adult?'':birthday}else{pu={id:uid('u-person'),personId:p.personId,name:p.name,email,phone:'',password:fd.get('password'),roles:['player'],active:true,playerId:p.id,pendingActivationDate:adult?'':birthday};users.push(pu)}if(fd.get('password'))pu.password=fd.get('password');if(adult){pu.active=true;pu.pendingActivationDate='';const old=activeRepresentation(p.id);if(old?.type==='guardian'&&!old.legalException)old.endDate=isoToday();if(!activeRepresentation(p.id)||activeRepresentation(p.id)?.type!=='self')representations.push({id:uid('r'),playerId:p.id,userId:pu.id,type:'self',startDate:isoToday(),endDate:'',reason:'Mayoría de edad',legalException:false})}saveUsers();saveReps();recordAudit(adult?'Autorrepresentación activada':'Cuenta de jugador preparada',p.id,pu.email);$('#selfRepresentationModal').close();openAdminPlayer(p.id);renderClub()};
$('#closeSelfRepresentationModal').onclick=$('#cancelSelfRepresentation').onclick=()=>$('#selfRepresentationModal').close();

$('#openEconomicModal')&&($('#openEconomicModal').onclick=openEconomicPlayer);$('#closeEconomicPlayerModal')&&($('#closeEconomicPlayerModal').onclick=closeEconomicPlayerAndReturn);$('#economicPlayerModal')&&($('#economicPlayerModal').oncancel=e=>{e.preventDefault();closeEconomicPlayerAndReturn()});$$('#adminPlayerTabs [data-player-tab]').forEach(b=>b.onclick=()=>setAdminPlayerTab(b.dataset.playerTab));$('#openMedicalFromPlayer').onclick=()=>{const id=selectedRemotePlayerId;if(!id)return;$('#adminPlayerModal').close();openRemoteMedical(id)};$('#saveClubberIds').onclick=saveClubberIds;$('#registerEconomicPayment').onclick=registerEconomicPayment;$('#validateClubberInstallments').onclick=()=>setClubberInstallments(true);$('#revokeClubberInstallments').onclick=()=>setClubberInstallments(false);$('#closeEconomicConfigModal').onclick=$('#cancelEconomicConfig').onclick=()=>$('#economicConfigModal').close();$('#economicConfigForm').onsubmit=e=>{e.preventDefault();saveEconomicConfig(e.currentTarget)};
$('#medicalSearch').oninput=renderMedical;$('#medicalFilter').onchange=renderMedical;$$('[data-medical-quick]').forEach(el=>{const go=()=>{const v=el.dataset.medicalQuick;medicalQuickFilter=(medicalQuickFilter===v&&v!=='all')?'all':v;renderMedical()};el.onclick=go;el.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();go()}}});$('#medicalForm [name="medicalDate"]').onchange=e=>{const f=$('#medicalForm');if(currentUser?.source==='supabase'&&e.target.value&&!f.elements.medicalExpiry.value)f.elements.medicalExpiry.value=addMonths(e.target.value,18)};$('#closeMedicalModal').onclick=$('#cancelMedical').onclick=()=>$('#medicalModal').close();$('#saveMedicalAppointment').onclick=saveRemoteMedicalAppointment;$('#editMedicalAppointment').onclick=()=>{const v=remoteClubPlayers.find(x=>x.id===selectedMedicalPlayerId);if(v)setMedicalAppointmentEditor(v,true)};$('#cancelMedicalAppointmentEdit').onclick=()=>{const v=remoteClubPlayers.find(x=>x.id===selectedMedicalPlayerId);if(v)setMedicalAppointmentEditor(v,false)};$('#cancelMedicalAppointment').onclick=cancelRemoteMedicalAppointment;$('#medicalForm').onsubmit=e=>{e.preventDefault();const form=e.currentTarget;if(currentUser?.source==='supabase')return saveRemoteMedical(form);const fd=new FormData(form);medicals.push({id:uid('m'),playerId:selectedMedicalPlayerId,date:fd.get('medicalDate')||'',expiry:fd.get('medicalExpiry')||'',validatedAt:isoToday()});saveMedicals();recordAudit('Reconocimiento médico registrado',selectedMedicalPlayerId,`${fmt(fd.get('medicalDate'))} → ${fmt(fd.get('medicalExpiry'))}`);$('#medicalModal').close();renderMedical();renderClub()};

$$('#accountProfileModal [data-account-tab]').forEach(b=>b.onclick=()=>setSimpleTabs('#accountProfileModal',b.dataset.accountTab));$$('#medicalModal [data-medical-tab]').forEach(b=>b.onclick=()=>setMedicalTab(b.dataset.medicalTab));$$('#medicalModal .medical-close').forEach(b=>b.onclick=()=>$('#medicalModal').close());$('#openCoachModal').onclick=()=>openCoachForNew();if($('#coachPersonSelect'))$('#coachPersonSelect').onchange=e=>{const id=e.currentTarget.value;if(id)applyCoachPersonToForm(id)};$('#closeCoachModal').onclick=$('#cancelCoach').onclick=()=>$('#coachModal').close();['coachCategoryFilter','coachTeamFilter','coachRoleFilter','coachMedicalFilter','coachLicenseFilter','coachDelegateFilter','coachBenchFilter','coachPlayerFilter','coachStatusFilter'].forEach(id=>{const el=$('#'+id);if(el)el.onchange=renderCoaches});if($('#coachSearch'))$('#coachSearch').oninput=renderCoaches;$('#coachForm').onsubmit=async e=>{e.preventDefault();if(currentUser?.source==='supabase')return saveRemoteCoach(e.currentTarget);if(!['admin','club'].includes(currentRole))return;const fd=new FormData(e.currentTarget),old=coaches.find(c=>c.id===editingCoachId),fullName=[fd.get('firstName'),fd.get('lastName1'),fd.get('lastName2')].filter(Boolean).join(' '),item={id:editingCoachId||uid('c'),userId:old?.userId||null,name:fullName,firstName:fd.get('firstName'),lastName1:fd.get('lastName1'),lastName2:fd.get('lastName2'),email:fd.get('email')||'',phone:fd.get('phone')||'',assignments:pendingCoachAssignments.map(a=>({...a})),hasLicense:old?.hasLicense||false,licenseType:old?.licenseType||'',licenseNumber:old?.licenseNumber||'',delegateCourse:old?.delegateCourse||false,notes:old?.notes||'',active:fd.get('active')==='yes'};if(editingCoachId)coaches=coaches.map(c=>c.id===editingCoachId?item:c);else coaches.push(item);saveCoaches();recordAudit('Entrenador actualizado','',item.name);editingCoachId=null;pendingCoachAssignments=[];e.currentTarget.reset();$('#coachModal').close();renderCoaches();renderStructure()};
$('#addCoachAssignment').onclick=async()=>{try{const old=coaches.find(c=>c.id===editingCoachId),personId=old?.personId||selectedCoachPersonId||$('#coachPersonSelect')?.value;if(currentUser?.source==='supabase'&&personId){const ok=await ensureMinorCoachAssignmentAllowed(personId);if(!ok){setCoachAssignmentGuard('No se puede añadir esta asignación. El entrenador es menor y todavía no consta la autorización expresa de su tutor.');return}}setCoachAssignmentGuard('');const team=$('#coachAssignmentTeam').value,role=$('#coachAssignmentRole').value,start=$('#coachAssignmentStart').value,endValue=$('#coachAssignmentEnd').value,end=endValue||'9999-12-31';if(!team||!start){alert('Selecciona equipo y completa la fecha de inicio.');return}if(endValue&&endValue<start){alert('La fecha de fin no puede ser anterior al inicio.');return}let replacePrincipal=false;if(role==='first'){const conflicts=coaches.filter(c=>c.id!==editingCoachId).flatMap(c=>(c.assignments||[]).filter(a=>a.teamId===team&&a.coachRole==='first'&&!a.cancelledAt&&!(end<(a.startDate||'0000-01-01')||start>(a.endDate||'9999-12-31'))).map(a=>({coach:c,assignment:a})));if(conflicts.length){const names=[...new Set(conflicts.map(x=>x.coach.name))].join(', ');if(!confirm(`${coachTeamName(team)} ya tiene como entrenador principal a ${names}. ¿Quieres finalizar esa etapa y asignar a este entrenador como nuevo principal desde ${fmt(start)}?`)){setCoachAssignmentGuard('La asignación no se ha añadido porque el equipo ya tiene entrenador principal en ese periodo.');return}replacePrincipal=true}}const ownIndex=pendingCoachAssignments.findIndex(a=>{const aEnd=a.endDate||'9999-12-31';return a.teamId===team&&!(end<(a.startDate||'0000-01-01')||start>aEnd)});if(ownIndex>=0){const previous=pendingCoachAssignments[ownIndex];if(previous.coachRole===role){alert('Ya existe una asignación solapada para ese equipo.');return}if(!confirm(`Este entrenador ya figura como ${coachRoleLabel(previous.coachRole)} de ${coachTeamName(team)} en ese periodo. ¿Quieres cambiar su función a ${coachRoleLabel(role)} desde ${fmt(start)}?`))return;const previousStart=previous.startDate||start;if(start<=previousStart){pendingCoachAssignments.splice(ownIndex,1,{teamId:team,coachRole:role,startDate:start,endDate:endValue||'',replacePrincipal});}else{const d=new Date(`${start}T12:00:00`);d.setDate(d.getDate()-1);const previousDay=`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;pendingCoachAssignments[ownIndex]={...previous,endDate:previousDay};pendingCoachAssignments.push({teamId:team,coachRole:role,startDate:start,endDate:endValue||'',replacePrincipal});}renderCoachAssignments();setCoachAssignmentGuard(replacePrincipal?'Al guardar, se cambiará la función de este entrenador y se finalizará la etapa del entrenador principal anterior, conservando el histórico.':'Al guardar, se cambiará la función del entrenador conservando el histórico anterior cuando corresponda.','ok');return}const added=addAssignmentFrom('coachAssignment',pendingCoachAssignments,renderCoachAssignments);if(added&&replacePrincipal){pendingCoachAssignments[pendingCoachAssignments.length-1].replacePrincipal=true;renderCoachAssignments();setCoachAssignmentGuard('Al guardar, se finalizará la asignación del entrenador principal anterior y se conservará en el histórico.','ok')}}catch(err){setCoachAssignmentGuard(`No se ha podido comprobar la asignación: ${err.message||err}`)}};
if($('#minorCoachConsentConfirm'))$('#minorCoachConsentConfirm').onclick=submitMinorCoachConsent;
if($('#closeMinorCoachConsent'))$('#closeMinorCoachConsent').onclick=()=>{$('#minorCoachConsentModal').close();pendingMinorConsentAction=null};
if($('#cancelMinorCoachConsent'))$('#cancelMinorCoachConsent').onclick=()=>{$('#minorCoachConsentModal').close();pendingMinorConsentAction=null};

{
  const openClubUser=$('#openClubUserModal'),clubUserForm=$('#clubUserForm'),clubUserModal=$('#clubUserModal'),closeClubUser=$('#closeClubUserModal'),cancelClubUser=$('#cancelClubUser'),clubUserRole=$('#clubUserRole'),addClubUserAssignment=$('#addClubUserAssignment');
  if(openClubUser&&clubUserForm&&clubUserModal)openClubUser.onclick=()=>{pendingUserAssignments=[];clubUserForm.reset();syncCoachUserFields();clubUserModal.showModal()};
  if(closeClubUser&&clubUserModal)closeClubUser.onclick=()=>clubUserModal.close();
  if(cancelClubUser&&clubUserModal)cancelClubUser.onclick=()=>clubUserModal.close();
  if(clubUserRole)clubUserRole.onchange=syncCoachUserFields;
  if(addClubUserAssignment)addClubUserAssignment.onclick=()=>addAssignmentFrom('clubUserAssignment',pendingUserAssignments,renderUserAssignments);
  if(clubUserForm)clubUserForm.onsubmit=e=>{e.preventDefault();if(currentRole!=='admin')return;const fd=new FormData(e.currentTarget),email=String(fd.get('email')).toLowerCase(),role=fd.get('role');let u=users.find(x=>x.email.toLowerCase()===email);if(role==='coach'&&!pendingUserAssignments.length){alert('Añade al menos una asignación de equipo.');return}if(u){u=normalizeUser(u);if(hasRole(u,role)){alert('Esa persona ya tiene ese perfil.');return}u.roles.push(role);u.name=fd.get('name')||u.name;u.active=true;if(role==='coach'){let c=coaches.find(x=>x.userId===u.id);const data={name:u.name,assignments:pendingUserAssignments.map(a=>({...a})),hasLicense:fd.get('hasLicense')==='yes',licenseType:fd.get('licenseType')||'',delegateCourse:fd.get('delegateCourse')==='yes',active:true};if(c)Object.assign(c,data);else coaches.push({id:uid('c'),userId:u.id,...data})}recordAudit('Perfil añadido a persona','',`${u.name} · ${roleLabel(role)}`)}else{const password=fd.get('password');if(!password||String(password).length<6){alert('Para una cuenta nueva indica una contraseña inicial de al menos 6 caracteres.');return}const person={id:uid('person'),name:fd.get('name'),email,dni:'',createdAt:isoToday(),mergedFrom:[]};persons.push(person);u={id:uid('u-person'),personId:person.id,name:fd.get('name'),email,phone:'',password,roles:[role],active:true};users.push(u);if(role==='coach')coaches.push({id:uid('c'),userId:u.id,name:u.name,assignments:pendingUserAssignments.map(a=>({...a})),hasLicense:fd.get('hasLicense')==='yes',licenseType:fd.get('licenseType')||'',delegateCourse:fd.get('delegateCourse')==='yes',active:true});recordAudit('Persona interna creada','',`${u.name} · ${roleLabel(role)}`)}saveUsers();saveCoaches();writeJSON(K.persons,persons);pendingUserAssignments=[];clubUserModal?.close();renderClubUsers();renderCoaches()};
}

if($('#openPersonModal'))$('#openPersonModal').onclick=()=>{if(currentRole!=='admin')return;$('#personForm').reset();$('#personModal').showModal()};if($('#closePersonModal'))$('#closePersonModal').onclick=$('#cancelPerson').onclick=()=>$('#personModal').close();if($('#personForm'))$('#personForm').onsubmit=e=>{e.preventDefault();createRemotePerson(e.currentTarget)};if($('#closePersonAdminModal'))$('#closePersonAdminModal').onclick=()=>$('#personAdminModal').close();if($('#personAdminIdentityForm'))$('#personAdminIdentityForm').onsubmit=e=>{e.preventDefault();savePersonAdminIdentity(e.currentTarget)};if($('#savePersonRoles'))$('#savePersonRoles').onclick=savePersonAdminRoles;if($('#linkPersonAuth'))$('#linkPersonAuth').onclick=linkPersonAuth;if($('#createTemporaryAccess'))$('#createTemporaryAccess').onclick=createTemporaryAccessForSelectedPerson;if($('#resendInternalInvitation'))$('#resendInternalInvitation').onclick=resendInternalInvitationForSelectedPerson;$$('#personAdminTabs [data-person-tab]').forEach(b=>b.onclick=()=>setPersonAdminTab(b.dataset.personTab));
$('#openTeamModal').onclick=()=>{if(currentRole!=='admin'||dbStructureLoaded)return;editingTeamId=null;$('#teamForm').reset();fillTeamCategorySelect();$('#teamModalTitle').textContent='Nuevo equipo';$('#teamModalSeason').textContent=`Temporada ${seasonName(currentSeasonId)}`;$('#teamModal').showModal()};$('#closeTeamModal').onclick=$('#cancelTeam').onclick=()=>$('#teamModal').close();$('#teamForm').onsubmit=e=>{e.preventDefault();saveUnifiedTeam(e.currentTarget)};
$('#openSeasonModal').onclick=()=>{if(currentRole!=='admin')return;$('#seasonForm').reset();$('#seasonModal').showModal()};$('#closeSeasonModal').onclick=$('#cancelSeason').onclick=()=>$('#seasonModal').close();$('#seasonForm').onsubmit=e=>{e.preventDefault();if(currentRole!=='admin')return;const fd=new FormData(e.currentTarget);if(fd.get('endDate')<fd.get('startDate')){alert('La fecha fin no puede ser anterior.');return}seasons.push({id:uid('s'),name:fd.get('name'),startDate:fd.get('startDate'),endDate:fd.get('endDate'),active:true});saveSeasons();recordAudit('Temporada creada','',fd.get('name'));$('#seasonModal').close();renderStructure()};

window.addEventListener('storage',()=>{reload();applyAgeTransitions();if(currentUser)showApp()});
initData();reload();(async()=>{await loadVisualTheme();if(await handlePasswordRecovery())return;await restoreSupabaseSession()})();

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

$('#closeDocumentModal')?.addEventListener('click',()=>$('#documentModal').close());

blockPasteOnEmailConfirm(document);bindSpanishIdentityValidation(document);
