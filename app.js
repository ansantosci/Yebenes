const USERS_KEY='yebenes-users-v6';
const SESSION_KEY='yebenes-session-v6';
const PLAYERS_KEY='yebenes-players-v6';
const COACHES_KEY='yebenes-coaches-v8';
const TEAMS_KEY='yebenes-teams-v8';
const LEGACY_PLAYER_KEYS=['yebenes-family-players-v4','yebenes-family-players-v3'];

const seedUsers=[
  {id:'u-admin',name:'Administrador del Club',email:'admin@yebenes.demo',phone:'',password:'demo123',role:'admin',active:true,teamIds:[]},
  {id:'u-club',name:'Usuario del Club',email:'club@yebenes.demo',phone:'',password:'demo123',role:'club',active:true,teamIds:[]},
  {id:'u-coach',name:'Carlos Martín López',email:'entrenador@yebenes.demo',phone:'',password:'demo123',role:'coach',active:true,teamIds:['t-pb-a']},
  {id:'u-family',name:'Familia Santos',email:'familia@yebenes.demo',phone:'600000000',password:'demo123',role:'family',active:true,teamIds:[]}
];

const seedPlayers=[
  {id:'demo-daniel',ownerUserId:'u-family',familyName:'Familia Santos',name:'Daniel Santos García',category:'Prebenjamín',status:'complete',docs:'Completa',federation:'Listo para federar',workflow:'ready',data:true,familyActionRequired:false,returnMessage:'',medicalDate:'2026-06-15',medicalExpiry:'2027-06-15',teamId:'t-pb-a'},
  {id:'demo-alvaro',ownerUserId:'u-family',familyName:'Familia Santos',name:'Álvaro Santos García',category:'Benjamín',status:'pending',docs:'Falta fotografía',federation:'Pendiente',workflow:'review',data:true,familyActionRequired:false,returnMessage:'',medicalDate:'2025-12-10',medicalExpiry:'2026-11-20',teamId:''},
  {id:'demo-hugo',ownerUserId:null,familyName:'Demo club',name:'Hugo Pérez Martín',category:'Alevín',status:'pending',docs:'Falta DNI/NIE',federation:'Pendiente',workflow:'review',data:true,medicalDate:'',medicalExpiry:'',teamId:''},
  {id:'demo-lucia',ownerUserId:null,familyName:'Demo club',name:'Lucía Moreno Díaz',category:'Infantil',status:'complete',docs:'Completa',federation:'Ficha tramitada',workflow:'federated',data:true,medicalDate:'2025-09-01',medicalExpiry:'2026-09-01',teamId:'t-inf-a'}
];



const seedTeams=[
  {id:'t-pb-a',name:'Prebenjamín A',category:'Prebenjamín',active:true},
  {id:'t-pb-b',name:'Prebenjamín B',category:'Prebenjamín',active:true},
  {id:'t-ben-a',name:'Benjamín A',category:'Benjamín',active:true},
  {id:'t-ale-a',name:'Alevín A',category:'Alevín',active:true},
  {id:'t-inf-a',name:'Infantil A',category:'Infantil',active:true}
];

const seedCoaches=[
  {id:'c1',userId:'u-coach',name:'Carlos Martín López',category:'Prebenjamín',teamIds:['t-pb-a'],coachRole:'first',hasLicense:true,licenseType:'UEFA C',delegateCourse:true,active:true},
  {id:'c2',userId:null,name:'Javier Ruiz Gómez',category:'Prebenjamín',teamIds:['t-pb-b'],coachRole:'second',hasLicense:false,licenseType:'',delegateCourse:true,active:true},
  {id:'c3',userId:null,name:'Marta Sánchez Gil',category:'Alevín',teamIds:['t-ale-a'],coachRole:'first',hasLicense:true,licenseType:'UEFA B',delegateCourse:false,active:true},
  {id:'c4',userId:null,name:'Luis Moreno Pérez',category:'Infantil',teamIds:['t-inf-a'],coachRole:'second',hasLicense:true,licenseType:'UEFA C',delegateCourse:true,active:true}
];

const WORKFLOW=[
  {key:'review',label:'Pendiente de revisión inicial',federation:'Pendiente de revisión'},
  {key:'initial_ok',label:'Inscripción inicial validada',federation:'Inscripción validada'},
  {key:'medical',label:'Pendiente de reconocimiento médico',federation:'Pendiente de RRMM'},
  {key:'ready',label:'Listo para federar',federation:'Listo para federar'},
  {key:'federated',label:'Ficha tramitada',federation:'Ficha tramitada'}
];

const $=s=>document.querySelector(s);
const $$=s=>[...document.querySelectorAll(s)];
const esc=(s='')=>String(s).replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
const roleLabel=r=>r==='admin'?'Administrador':r==='club'?'Usuario del club':r==='coach'?'Entrenador':'Familia';
const workflowLabel=k=>WORKFLOW.find(x=>x.key===k)?.label||'Pendiente de revisión';

function readJSON(key,fallback){try{const v=JSON.parse(localStorage.getItem(key));return v??fallback;}catch{return fallback;}}
function writeJSON(key,val){localStorage.setItem(key,JSON.stringify(val));}

function initData(){
  if(!localStorage.getItem(USERS_KEY)) writeJSON(USERS_KEY,seedUsers);
  else {const existing=readJSON(USERS_KEY,[]);for(const u of seedUsers){if(!existing.some(x=>x.id===u.id))existing.push(u);}writeJSON(USERS_KEY,existing.map(u=>({...u,teamIds:u.teamIds||[]})));}
  if(!localStorage.getItem(COACHES_KEY)) writeJSON(COACHES_KEY,seedCoaches);
  if(!localStorage.getItem(TEAMS_KEY)) writeJSON(TEAMS_KEY,seedTeams);
  if(!localStorage.getItem(PLAYERS_KEY)){
    let migrated=null;
    for(const key of LEGACY_PLAYER_KEYS){const v=readJSON(key,null);if(Array.isArray(v)){migrated=v;break;}}
    const migratedPlayers=(migrated||[]).map(p=>({...p,ownerUserId:'u-family',familyName:'Familia Santos',teamId:p.teamId||''}));
    const base=migratedPlayers.length? [...migratedPlayers,...seedPlayers.filter(x=>!x.ownerUserId)] : seedPlayers;
    writeJSON(PLAYERS_KEY,base);
  } else {
    const existing=readJSON(PLAYERS_KEY,[]).map(p=>({...p,teamId:p.teamId||'',workflow:p.workflow==='data_ok'||p.workflow==='docs_ok'?'initial_ok':p.workflow}));
    writeJSON(PLAYERS_KEY,existing);
  }
}

let users=[];let players=[];let coaches=[];let teams=[];let currentUser=null;let selectedPlayerId=null;let editingPlayerId=null;let selectedMedicalPlayerId=null;let editingCoachId=null;
function reload(){users=readJSON(USERS_KEY,seedUsers);players=readJSON(PLAYERS_KEY,seedPlayers);coaches=readJSON(COACHES_KEY,seedCoaches);teams=readJSON(TEAMS_KEY,seedTeams);const sid=localStorage.getItem(SESSION_KEY);currentUser=users.find(u=>u.id===sid&&u.active)||null;}
function saveUsers(){writeJSON(USERS_KEY,users);}
function savePlayers(){writeJSON(PLAYERS_KEY,players);}
function saveCoaches(){writeJSON(COACHES_KEY,coaches);}
function saveTeams(){writeJSON(TEAMS_KEY,teams);}
function teamName(id){return teams.find(t=>t.id===id)?.name||'Sin equipo';}
function visiblePlayers(){return currentUser?.role==='coach'?players.filter(p=>(currentUser.teamIds||[]).includes(p.teamId)):players;}

function showAuth(mode='login'){
  $('#authScreen').classList.remove('hidden');$('#appShell').classList.add('hidden');
  const login=mode==='login';$('#loginForm').classList.toggle('hidden',!login);$('#familySignupForm').classList.toggle('hidden',login);$('#showLogin').classList.toggle('active',login);$('#showFamilySignup').classList.toggle('active',!login);
}
function showApp(){
  $('#authScreen').classList.add('hidden');$('#appShell').classList.remove('hidden');$('#currentRoleLabel').textContent=roleLabel(currentUser.role);
  if(currentUser.role==='family'){
    $('#familyView').classList.add('active');$('#clubView').classList.remove('active');$('#medicalView').classList.remove('active');$('#coachesView').classList.remove('active');$('#usersView').classList.remove('active');$('#familyNav').classList.remove('hidden');$('#clubNav').classList.add('hidden');
    $('#familyTitle').textContent=currentUser.name;renderFamily();
  } else {
    $('#familyView').classList.remove('active');$('#clubView').classList.add('active');$('#medicalView').classList.remove('active');$('#coachesView').classList.remove('active');$('#usersView').classList.remove('active');$('#familyNav').classList.add('hidden');$('#clubNav').classList.remove('hidden');
    const isCoach=currentUser.role==='coach';
    $('#medicalNavButton').style.display=isCoach?'none':'flex';$('#coachesNavButton').style.display=isCoach?'none':'flex';$('#usersNavButton').style.display=currentUser.role==='admin'?'flex':'none';
    $('#clubNav').style.gridTemplateColumns=isCoach?'repeat(2,1fr)':(currentUser.role==='admin'?'repeat(5,1fr)':'repeat(4,1fr)');
    $('#clubHeroTitle').textContent=isCoach?'Jugadores de mis equipos':'Control de fichas federativas';$('#clubHeroText').textContent=isCoach?'Consulta los jugadores que el club ha asignado a tus equipos.':'Revisa documentación, asigna equipos y prepara los datos para la RFFM.';
    renderClub();if(!isCoach){renderMedical();renderCoaches();}if(currentUser.role==='admin')renderClubUsers();
  }
}

function familyPlayers(){return players.filter(p=>p.ownerUserId===currentUser?.id);}
function renderFamily(){
  const mine=familyPlayers();$('#playersList').innerHTML=mine.length?mine.map(p=>`<article class="player-card ${p.familyActionRequired?'needs-action':''}"><div class="row"><div><h3>${esc(p.name)}</h3><div class="meta">${esc(p.category)}</div></div><span class="status ${p.familyActionRequired?'returned':p.status}">${p.familyActionRequired?'↩ Revisar':p.status==='complete'?'✓ Completa':'⚠ Pendiente'}</span></div>${p.familyActionRequired?`<div class="family-alert"><strong>El club solicita cambios</strong><p>${esc(p.returnMessage||'Revisa la información de la ficha.')}</p><button class="primary small edit-family" data-id="${esc(p.id)}">Revisar y modificar</button></div>`:''}<div class="checklist"><div class="check"><span>Datos personales</span><strong>${p.data?'✓':'!'}</strong></div><div class="check"><span>Documentación</span><strong>${esc(p.docs)}</strong></div><div class="check"><span>Federación</span><strong>${esc(p.federation)}</strong></div></div></article>`).join(''):'<div class="empty-card">Todavía no has dado de alta ningún jugador.</div>';
  $$('.edit-family').forEach(b=>b.onclick=()=>openPlayerForEdit(b.dataset.id));$('#familyPlayerCount').textContent=`${mine.length} ${mine.length===1?'jugador registrado':'jugadores registrados'}`;
}

function renderClub(){
  const source=visiblePlayers();const q=$('#searchInput').value.trim().toLowerCase();const f=$('#statusFilter').value;
  const rows=source.filter(p=>(f==='all'||p.status===f)&&p.name.toLowerCase().includes(q));
  $('#adminTable').innerHTML=rows.length?rows.map(p=>`<tr class="admin-row" data-id="${esc(p.id)}" tabindex="0"><td><strong>${esc(p.name)}</strong>${p.familyActionRequired?'<div class="meta return-note">Devuelto a familia</div>':''}</td><td>${esc(p.familyName||'Sin familia')}</td><td>${esc(p.category)}</td><td><strong>${esc(teamName(p.teamId))}</strong></td><td><span class="dot ${p.data?'ok':'warn'}">${p.data?'✓ Completo':'⚠ Revisar'}</span></td><td>${esc(p.docs)}</td><td><span class="workflow-pill ${esc(p.workflow)}">${esc(workflowLabel(p.workflow))}</span></td></tr>`).join(''):'<tr><td colspan="7">No hay jugadores que coincidan con el filtro.</td></tr>';
  $$('.admin-row').forEach(r=>{r.onclick=()=>openAdminPlayer(r.dataset.id);r.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();openAdminPlayer(r.dataset.id)}}});
  $('#statPlayers').textContent=source.length;$('#statComplete').textContent=source.filter(p=>p.status==='complete').length;$('#statDocs').textContent=source.filter(p=>p.docs!=='Completa').length;$('#statReview').textContent=source.filter(p=>p.workflow==='review'||p.familyActionRequired).length;if(currentUser.role!=='coach')renderMedical();
}



function parseDateOnly(v){if(!v)return null;const [y,m,d]=v.split('-').map(Number);return new Date(y,m-1,d);}
function formatDate(v){const d=parseDateOnly(v);return d?new Intl.DateTimeFormat('es-ES').format(d):'—';}
function medicalState(p){
  if(!p.medicalExpiry)return {key:'missing',label:'Sin fecha',days:null};
  const today=new Date();today.setHours(0,0,0,0);const exp=parseDateOnly(p.medicalExpiry);const days=Math.ceil((exp-today)/86400000);
  if(days<0)return {key:'expired',label:'Vencido',days};
  if(days<=90)return {key:'soon',label:`Vence en ${days} días`,days};
  return {key:'ok',label:'En vigor',days};
}

function renderMedical(){
  if(!$('#medicalTable'))return;
  const q=($('#medicalSearch')?.value||'').trim().toLowerCase();const f=$('#medicalFilter')?.value||'all';
  const enriched=players.map(p=>({p,state:medicalState(p)}));
  const rows=enriched.filter(({p,state})=>(!q||p.name.toLowerCase().includes(q))&&(f==='all'||state.key===f));
  $('#medicalTable').innerHTML=rows.length?rows.map(({p,state})=>`<tr class="medical-row" data-id="${esc(p.id)}" tabindex="0"><td><strong>${esc(p.name)}</strong></td><td>${esc(p.category)}</td><td>${formatDate(p.medicalDate)}</td><td>${formatDate(p.medicalExpiry)}</td><td><span class="medical-badge ${state.key}">${esc(state.label)}</span></td></tr>`).join(''):'<tr><td colspan="5">No hay jugadores que coincidan con el filtro.</td></tr>';
  $$('.medical-row').forEach(r=>{r.onclick=()=>openMedical(r.dataset.id);r.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();openMedical(r.dataset.id)}}});
  const states=enriched.map(x=>x.state.key);$('#medicalTotal').textContent=players.length;$('#medicalOk').textContent=states.filter(x=>x==='ok').length;$('#medicalSoon').textContent=states.filter(x=>x==='soon').length;$('#medicalExpired').textContent=states.filter(x=>x==='expired'||x==='missing').length;
  if($('#statMedical90'))$('#statMedical90').textContent=states.filter(x=>x==='soon').length;
}
function openMedical(id){selectedMedicalPlayerId=id;const p=players.find(x=>x.id===id);if(!p)return;$('#medicalPlayerName').textContent=p.name;$('#medicalPlayerMeta').textContent=p.category;const f=$('#medicalForm');f.elements.medicalDate.value=p.medicalDate||'';f.elements.medicalExpiry.value=p.medicalExpiry||'';$('#medicalModal').showModal();}

function coachRoleLabel(v){return v==='first'?'Primer entrenador':'Segundo entrenador';}
function renderCoaches(){
  if(!$('#coachesTable'))return;const teamFilter=$('#coachTeamFilter');if(teamFilter&&teamFilter.options.length===1)teams.filter(t=>t.active).forEach(t=>teamFilter.add(new Option(t.name,t.id)));
  const cats=[...new Set(teams.map(t=>t.category))].sort();const sel=$('#coachCategoryFilter');if(sel&&sel.options.length===1)cats.forEach(c=>sel.add(new Option(c,c)));
  const cf=sel?.value||'all',tf=teamFilter?.value||'all',rf=$('#coachRoleFilter')?.value||'all',lf=$('#coachLicenseFilter')?.value||'all',df=$('#coachDelegateFilter')?.value||'all';
  const rows=coaches.filter(c=>(cf==='all'||c.category===cf)&&(tf==='all'||(c.teamIds||[]).includes(tf))&&(rf==='all'||c.coachRole===rf)&&(lf==='all'||(lf==='yes')===!!c.hasLicense)&&(df==='all'||(df==='yes')===!!c.delegateCourse));
  $('#coachesTable').innerHTML=rows.length?rows.map(c=>`<tr><td><strong>${esc(c.name)}</strong>${c.userId?'<div class="meta">Usuario de entrenador</div>':''}${!c.active?'<div class="meta">Inactivo</div>':''}</td><td>${esc(c.category)}</td><td>${(c.teamIds||[]).map(id=>`<span class="team-chip">${esc(teamName(id))}</span>`).join(' ')||'—'}</td><td>${coachRoleLabel(c.coachRole)}</td><td><span class="dot ${c.hasLicense?'ok':'warn'}">${c.hasLicense?'✓ '+esc(c.licenseType||'Sí'):'⚠ No'}</span></td><td><span class="dot ${c.delegateCourse?'ok':'warn'}">${c.delegateCourse?'✓ Hecho':'⚠ Pendiente'}</span></td><td><button class="secondary tiny edit-coach" data-id="${esc(c.id)}">Editar</button></td></tr>`).join(''):'<tr><td colspan="7">No hay entrenadores que coincidan con los filtros.</td></tr>';
  $$('.edit-coach').forEach(b=>b.onclick=()=>openCoachForEdit(b.dataset.id));renderTeams();
}
function fillTeamMulti(select,selected=[]){select.innerHTML=teams.filter(t=>t.active).map(t=>`<option value="${esc(t.id)}" ${selected.includes(t.id)?'selected':''}>${esc(t.name)} · ${esc(t.category)}</option>`).join('');}
function openCoachForNew(){editingCoachId=null;$('#coachForm').reset();fillTeamMulti($('#coachTeamIds'));$('#coachModalTitle').textContent='Nuevo entrenador';$('#coachModal').showModal();}
function openCoachForEdit(id){const c=coaches.find(x=>x.id===id);if(!c)return;editingCoachId=id;const f=$('#coachForm');f.elements.name.value=c.name;f.elements.category.value=c.category;fillTeamMulti($('#coachTeamIds'),c.teamIds||[]);f.elements.coachRole.value=c.coachRole;f.elements.hasLicense.value=c.hasLicense?'yes':'no';f.elements.licenseType.value=c.licenseType||'';f.elements.delegateCourse.value=c.delegateCourse?'yes':'no';f.elements.active.value=c.active?'yes':'no';$('#coachModalTitle').textContent='Editar entrenador';$('#coachModal').showModal();}
function renderTeams(){if(!$('#teamsTable'))return;$('#teamsTable').innerHTML=teams.map(t=>`<tr><td><strong>${esc(t.name)}</strong></td><td>${esc(t.category)}</td><td>${players.filter(p=>p.teamId===t.id).length}</td><td>${coaches.filter(c=>(c.teamIds||[]).includes(t.id)).length}</td><td><span class="status ${t.active?'complete':'returned'}">${t.active?'Activo':'Inactivo'}</span></td></tr>`).join('');}

function renderClubUsers(){
  const staff=users.filter(u=>['admin','club','coach'].includes(u.role));
  $('#clubUsersTable').innerHTML=staff.map(u=>`<tr><td><strong>${esc(u.name)}</strong></td><td>${esc(u.email)}</td><td>${esc(roleLabel(u.role))}</td><td>${u.role==='coach'?(u.teamIds||[]).map(id=>teamName(id)).join(', ')||'Sin equipos':'—'}</td><td><span class="status ${u.active?'complete':'returned'}">${u.active?'Activo':'Desactivado'}</span></td><td><button class="secondary tiny toggle-user" data-id="${u.id}" ${u.id===currentUser.id?'disabled':''}>${u.active?'Desactivar':'Activar'}</button></td></tr>`).join('');
  $$('.toggle-user').forEach(b=>b.onclick=()=>{const id=b.dataset.id;users=users.map(u=>u.id===id?{...u,active:!u.active}:u);saveUsers();renderClubUsers();});
}

function refreshAdminTeamSelect(p){const sel=$('#adminTeam');sel.innerHTML='<option value="">Sin equipo asignado</option>'+teams.filter(t=>t.active&&t.category===p.category).map(t=>`<option value="${esc(t.id)}">${esc(t.name)}</option>`).join('');sel.value=p.teamId||'';const canAssign=currentUser.role!=='coach'&&p.workflow!=='review';sel.disabled=!canAssign;$('#saveTeamAssignment').disabled=!canAssign;$('#teamAssignHint').textContent=currentUser.role==='coach'?'Solo consulta. El club asigna los equipos.':p.workflow==='review'?'Primero valida la inscripción inicial para poder asignar equipo.':'Asigna al jugador a un equipo de su categoría.';}
function openAdminPlayer(id){selectedPlayerId=id;const p=visiblePlayers().find(x=>x.id===id);if(!p)return;$('#adminPlayerName').textContent=p.name;$('#adminPlayerCategory').textContent=`${p.category} · ${p.familyName||'Sin familia'}`;$('#adminPlayerSource').textContent=p.ownerUserId?'Alta realizada por una familia registrada':'Registro de demostración del club';$('#adminPlayerData').textContent=p.data?'Completos':'Revisar';$('#adminPlayerDocs').textContent=p.docs;$('#adminPlayerFed').textContent=p.federation;$('#adminWorkflow').value=p.workflow||'review';$('#returnMessage').value=p.returnMessage||'';refreshAdminTeamSelect(p);const readonly=currentUser.role==='coach';const linked=!!p.ownerUserId&&!readonly;$('#adminWorkflow').disabled=readonly;$('#saveWorkflow').disabled=readonly;$('#advanceStatus').disabled=readonly;$('#returnMessage').disabled=!linked;$('#returnToFamily').disabled=!linked;$('#returnHint').textContent=readonly?'Perfil de entrenador: acceso de consulta a los jugadores de tus equipos.':linked?'La familia verá el motivo al iniciar sesión.':'Este registro no está vinculado a una cuenta familiar.';$('#adminPlayerModal').showModal();}

function updateSelected(mut){players=players.map(p=>p.id===selectedPlayerId?mut({...p}):p);savePlayers();renderClub();}
function saveTeamAssignment(){if(currentUser.role==='coach')return;const p=players.find(x=>x.id===selectedPlayerId);if(!p||p.workflow==='review')return;const teamId=$('#adminTeam').value;updateSelected(x=>({...x,teamId}));openAdminPlayer(selectedPlayerId);renderCoaches();}
function advanceSelected(){if(currentUser.role==='coach')return;const p=players.find(x=>x.id===selectedPlayerId);if(!p)return;const i=Math.max(0,WORKFLOW.findIndex(x=>x.key===p.workflow));const n=WORKFLOW[Math.min(i+1,WORKFLOW.length-1)];updateSelected(x=>({...x,workflow:n.key,federation:n.federation,status:['ready','federated'].includes(n.key)?'complete':'pending',familyActionRequired:false,returnMessage:''}));openAdminPlayer(selectedPlayerId);}
function setWorkflowSelected(){if(currentUser.role==='coach')return;const wf=WORKFLOW.find(x=>x.key===$('#adminWorkflow').value);if(!wf)return;updateSelected(x=>({...x,workflow:wf.key,federation:wf.federation,status:['ready','federated'].includes(wf.key)?'complete':'pending',familyActionRequired:false,returnMessage:''}));openAdminPlayer(selectedPlayerId);}
function returnSelected(){if(currentUser.role==='coach')return;const p=players.find(x=>x.id===selectedPlayerId);if(!p?.ownerUserId)return;const m=$('#returnMessage').value.trim();if(!m){alert('Indica qué debe revisar o modificar la familia.');return;}updateSelected(x=>({...x,workflow:'review',federation:'Devuelto a familia',status:'pending',familyActionRequired:true,returnMessage:m}));$('#adminPlayerModal').close();}

function openPlayerForNew(){editingPlayerId=null;$('#playerForm').reset();$('#playerModalTitle').textContent='Datos del jugador';$('#savePlayer').textContent='Guardar jugador';$('#playerModal').showModal();}
function openPlayerForEdit(id){const p=familyPlayers().find(x=>x.id===id);if(!p)return;editingPlayerId=id;const f=$('#playerForm');const parts=p.name.split(' ');f.elements.name.value=parts[0]||'';f.elements.surname1.value=parts[1]||'';f.elements.surname2.value=parts.slice(2).join(' ');f.elements.birth.value=p.birth||'';f.elements.dni.value=p.dni||'';f.elements.category.value=p.category||'';f.elements.email.value=p.email||currentUser.email||'';f.elements.phone.value=p.phone||currentUser.phone||'';$('#playerModalTitle').textContent='Revisar datos del jugador';$('#savePlayer').textContent='Guardar cambios';$('#playerModal').showModal();}

$('#showLogin').onclick=()=>showAuth('login');$('#showFamilySignup').onclick=()=>showAuth('signup');
$('#loginForm').onsubmit=e=>{e.preventDefault();reload();const fd=new FormData(e.currentTarget);const u=users.find(x=>x.email.toLowerCase()===String(fd.get('email')).toLowerCase()&&x.password===fd.get('password')&&x.active);if(!u){alert('Correo, contraseña o estado de usuario no válidos.');return;}localStorage.setItem(SESSION_KEY,u.id);currentUser=u;showApp();e.currentTarget.reset();};
$('#familySignupForm').onsubmit=e=>{e.preventDefault();reload();const fd=new FormData(e.currentTarget);if(fd.get('password')!==fd.get('password2')){alert('Las contraseñas no coinciden.');return;}const email=String(fd.get('email')).toLowerCase();if(users.some(u=>u.email.toLowerCase()===email)){alert('Ya existe un usuario con ese correo.');return;}const u={id:`u-family-${Date.now()}`,name:fd.get('name'),email,phone:fd.get('phone'),password:fd.get('password'),role:'family',active:true};users.push(u);saveUsers();localStorage.setItem(SESSION_KEY,u.id);currentUser=u;e.currentTarget.reset();showApp();};
$('#logoutButton').onclick=()=>{localStorage.removeItem(SESSION_KEY);currentUser=null;showAuth('login');};

$('[data-open="playerModal"]').onclick=openPlayerForNew;$('#playerForm').onsubmit=e=>{e.preventDefault();if(!e.currentTarget.reportValidity())return;const fd=new FormData(e.currentTarget);const full=[fd.get('name'),fd.get('surname1'),fd.get('surname2')].filter(Boolean).join(' ');if(editingPlayerId){players=players.map(p=>p.id===editingPlayerId&&p.ownerUserId===currentUser.id?{...p,name:full,category:fd.get('category'),birth:fd.get('birth')||'',dni:fd.get('dni')||'',email:fd.get('email')||'',phone:fd.get('phone')||'',data:true,familyActionRequired:false,returnMessage:'',workflow:'review',federation:'Modificado por familia · pendiente de revisión',status:'pending'}:p);}else{players.push({id:`p-${Date.now()}`,ownerUserId:currentUser.id,familyName:currentUser.name,name:full,category:fd.get('category'),birth:fd.get('birth')||'',dni:fd.get('dni')||'',email:fd.get('email')||'',phone:fd.get('phone')||'',status:'pending',docs:'Pendiente de documentos',federation:'Pendiente de revisión',workflow:'review',data:true,familyActionRequired:false,returnMessage:'',medicalDate:'',medicalExpiry:'',teamId:''});}savePlayers();renderFamily();e.currentTarget.reset();editingPlayerId=null;$('#playerModal').close();};
$$('#playerForm [value="cancel"]').forEach(b=>b.onclick=()=>{$('#playerForm').reset();editingPlayerId=null;$('#playerModal').close();});

$('#searchInput').oninput=renderClub;$('#saveTeamAssignment').onclick=saveTeamAssignment;$('#statusFilter').onchange=renderClub;$('#advanceStatus').onclick=advanceSelected;$('#saveWorkflow').onclick=setWorkflowSelected;$('#returnToFamily').onclick=returnSelected;$('#closeAdminModal').onclick=()=>$('#adminPlayerModal').close();

$$('[data-club-view]').forEach(b=>b.onclick=()=>{if(currentUser.role==='coach'&&b.dataset.clubView!=='clubView')return;if(b.dataset.clubView==='usersView'&&currentUser.role!=='admin')return;$$('.club-nav .nav-item').forEach(x=>x.classList.remove('active'));b.classList.add('active');['clubView','medicalView','coachesView','usersView'].forEach(id=>$('#'+id).classList.toggle('active',b.dataset.clubView===id));if(b.dataset.clubView==='clubView')renderClub();if(b.dataset.clubView==='medicalView')renderMedical();if(b.dataset.clubView==='coachesView')renderCoaches();if(b.dataset.clubView==='usersView')renderClubUsers();});
$$('[data-family-tab]').forEach(b=>b.onclick=()=>{$$('[data-family-tab]').forEach(x=>x.classList.remove('active'));b.classList.add('active');if(b.dataset.familyTab==='players')$('.section').scrollIntoView({behavior:'smooth'});});

$('#openClubUserModal').onclick=()=>$('#clubUserModal').showModal();$('#closeClubUserModal').onclick=$('#cancelClubUser').onclick=()=>$('#clubUserModal').close();$('#clubUserForm').onsubmit=e=>{e.preventDefault();if(currentUser.role!=='admin')return;reload();const fd=new FormData(e.currentTarget);const email=String(fd.get('email')).toLowerCase();if(users.some(u=>u.email.toLowerCase()===email)){alert('Ya existe un usuario con ese correo.');return;}const role=fd.get('role');const uid=`u-staff-${Date.now()}`;const teamIds=role==='coach'?fd.getAll('teamIds'):[];if(role==='coach'&&!teamIds.length){alert('Selecciona al menos un equipo para el entrenador.');return;}users.push({id:uid,name:fd.get('name'),email,phone:'',password:fd.get('password'),role,active:true,teamIds});saveUsers();if(role==='coach'){const firstTeam=teams.find(t=>t.id===teamIds[0]);coaches.push({id:`c-${Date.now()}`,userId:uid,name:fd.get('name'),category:firstTeam?.category||'',teamIds,coachRole:fd.get('coachRole')||'second',hasLicense:fd.get('hasLicense')==='yes',licenseType:fd.get('licenseType')||'',delegateCourse:fd.get('delegateCourse')==='yes',active:true});saveCoaches();}e.currentTarget.reset();$('#clubUserModal').close();renderClubUsers();renderCoaches();};


$('#medicalSearch').oninput=renderMedical;$('#medicalFilter').onchange=renderMedical;$('#closeMedicalModal').onclick=$('#cancelMedical').onclick=()=>$('#medicalModal').close();$('#medicalForm').onsubmit=e=>{e.preventDefault();const fd=new FormData(e.currentTarget);players=players.map(p=>p.id===selectedMedicalPlayerId?{...p,medicalDate:fd.get('medicalDate')||'',medicalExpiry:fd.get('medicalExpiry')||''}:p);savePlayers();$('#medicalModal').close();renderMedical();renderClub();};

$('#openCoachModal').onclick=openCoachForNew;$('#closeCoachModal').onclick=$('#cancelCoach').onclick=()=>$('#coachModal').close();['coachCategoryFilter','coachTeamFilter','coachRoleFilter','coachLicenseFilter','coachDelegateFilter'].forEach(id=>$('#'+id).onchange=renderCoaches);$('#coachForm').onsubmit=e=>{e.preventDefault();const fd=new FormData(e.currentTarget);const teamIds=fd.getAll('teamIds');const item={id:editingCoachId||`c-${Date.now()}`,userId:coaches.find(c=>c.id===editingCoachId)?.userId||null,name:fd.get('name'),category:fd.get('category'),teamIds,coachRole:fd.get('coachRole'),hasLicense:fd.get('hasLicense')==='yes',licenseType:fd.get('licenseType')||'',delegateCourse:fd.get('delegateCourse')==='yes',active:fd.get('active')==='yes'};if(editingCoachId)coaches=coaches.map(c=>c.id===editingCoachId?item:c);else coaches.push(item);saveCoaches();editingCoachId=null;e.currentTarget.reset();$('#coachModal').close();renderCoaches();};

window.addEventListener('storage',()=>{reload();if(currentUser?.role==='family')renderFamily();else if(currentUser){renderClub();if(currentUser.role!=='coach'){renderMedical();renderCoaches();}if(currentUser.role==='admin')renderClubUsers();}});


function syncCoachUserFields(){const isCoach=$('#clubUserRole').value==='coach';$('#coachUserFields').classList.toggle('hidden',!isCoach);if(isCoach)fillTeamMulti($('#clubUserTeamIds'));}
$('#clubUserRole').onchange=syncCoachUserFields;
const oldOpenUser=$('#openClubUserModal').onclick;$('#openClubUserModal').onclick=()=>{syncCoachUserFields();$('#clubUserModal').showModal();};

initData();reload();if(currentUser)showApp();else showAuth('login');
if('serviceWorker' in navigator)navigator.serviceWorker.register('./sw.js?v=8').catch(()=>{});
