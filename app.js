const USERS_KEY='yebenes-users-v6';
const SESSION_KEY='yebenes-session-v6';
const PLAYERS_KEY='yebenes-players-v6';
const LEGACY_PLAYER_KEYS=['yebenes-family-players-v4','yebenes-family-players-v3'];

const seedUsers=[
  {id:'u-admin',name:'Administrador del Club',email:'admin@yebenes.demo',phone:'',password:'demo123',role:'admin',active:true},
  {id:'u-club',name:'Usuario del Club',email:'club@yebenes.demo',phone:'',password:'demo123',role:'club',active:true},
  {id:'u-family',name:'Familia Santos',email:'familia@yebenes.demo',phone:'600000000',password:'demo123',role:'family',active:true}
];

const seedPlayers=[
  {id:'demo-daniel',ownerUserId:'u-family',familyName:'Familia Santos',name:'Daniel Santos García',category:'Prebenjamín',status:'complete',docs:'Completa',federation:'Listo para federar',workflow:'ready',data:true,familyActionRequired:false,returnMessage:''},
  {id:'demo-alvaro',ownerUserId:'u-family',familyName:'Familia Santos',name:'Álvaro Santos García',category:'Benjamín',status:'pending',docs:'Falta fotografía',federation:'Pendiente',workflow:'review',data:true,familyActionRequired:false,returnMessage:''},
  {id:'demo-hugo',ownerUserId:null,familyName:'Demo club',name:'Hugo Pérez Martín',category:'Alevín',status:'pending',docs:'Falta DNI/NIE',federation:'Pendiente',workflow:'review',data:true},
  {id:'demo-lucia',ownerUserId:null,familyName:'Demo club',name:'Lucía Moreno Díaz',category:'Infantil',status:'complete',docs:'Completa',federation:'Ficha tramitada',workflow:'federated',data:true}
];

const WORKFLOW=[
  {key:'review',label:'Pendiente de revisión',federation:'Pendiente'},
  {key:'data_ok',label:'Datos validados',federation:'Datos validados'},
  {key:'docs_ok',label:'Documentación validada',federation:'Documentación validada'},
  {key:'ready',label:'Listo para federar',federation:'Listo para federar'},
  {key:'federated',label:'Ficha tramitada',federation:'Ficha tramitada'}
];

const $=s=>document.querySelector(s);
const $$=s=>[...document.querySelectorAll(s)];
const esc=(s='')=>String(s).replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
const roleLabel=r=>r==='admin'?'Administrador':r==='club'?'Usuario del club':'Familia';
const workflowLabel=k=>WORKFLOW.find(x=>x.key===k)?.label||'Pendiente de revisión';

function readJSON(key,fallback){try{const v=JSON.parse(localStorage.getItem(key));return v??fallback;}catch{return fallback;}}
function writeJSON(key,val){localStorage.setItem(key,JSON.stringify(val));}

function initData(){
  if(!localStorage.getItem(USERS_KEY)) writeJSON(USERS_KEY,seedUsers);
  if(!localStorage.getItem(PLAYERS_KEY)){
    let migrated=null;
    for(const key of LEGACY_PLAYER_KEYS){const v=readJSON(key,null);if(Array.isArray(v)){migrated=v;break;}}
    const migratedPlayers=(migrated||[]).map(p=>({...p,ownerUserId:'u-family',familyName:'Familia Santos'}));
    const base=migratedPlayers.length? [...migratedPlayers,...seedPlayers.filter(x=>!x.ownerUserId)] : seedPlayers;
    writeJSON(PLAYERS_KEY,base);
  }
}

let users=[];let players=[];let currentUser=null;let selectedPlayerId=null;let editingPlayerId=null;
function reload(){users=readJSON(USERS_KEY,seedUsers);players=readJSON(PLAYERS_KEY,seedPlayers);const sid=localStorage.getItem(SESSION_KEY);currentUser=users.find(u=>u.id===sid&&u.active)||null;}
function saveUsers(){writeJSON(USERS_KEY,users);}
function savePlayers(){writeJSON(PLAYERS_KEY,players);}

function showAuth(mode='login'){
  $('#authScreen').classList.remove('hidden');$('#appShell').classList.add('hidden');
  const login=mode==='login';$('#loginForm').classList.toggle('hidden',!login);$('#familySignupForm').classList.toggle('hidden',login);$('#showLogin').classList.toggle('active',login);$('#showFamilySignup').classList.toggle('active',!login);
}
function showApp(){
  $('#authScreen').classList.add('hidden');$('#appShell').classList.remove('hidden');$('#currentRoleLabel').textContent=roleLabel(currentUser.role);
  if(currentUser.role==='family'){
    $('#familyView').classList.add('active');$('#clubView').classList.remove('active');$('#usersView').classList.remove('active');$('#familyNav').classList.remove('hidden');$('#clubNav').classList.add('hidden');
    $('#familyTitle').textContent=currentUser.name;renderFamily();
  } else {
    $('#familyView').classList.remove('active');$('#clubView').classList.add('active');$('#usersView').classList.remove('active');$('#familyNav').classList.add('hidden');$('#clubNav').classList.remove('hidden');
    $('#usersNavButton').style.display=currentUser.role==='admin'?'flex':'none';renderClub();if(currentUser.role==='admin')renderClubUsers();
  }
}

function familyPlayers(){return players.filter(p=>p.ownerUserId===currentUser?.id);}
function renderFamily(){
  const mine=familyPlayers();$('#playersList').innerHTML=mine.length?mine.map(p=>`<article class="player-card ${p.familyActionRequired?'needs-action':''}"><div class="row"><div><h3>${esc(p.name)}</h3><div class="meta">${esc(p.category)}</div></div><span class="status ${p.familyActionRequired?'returned':p.status}">${p.familyActionRequired?'↩ Revisar':p.status==='complete'?'✓ Completa':'⚠ Pendiente'}</span></div>${p.familyActionRequired?`<div class="family-alert"><strong>El club solicita cambios</strong><p>${esc(p.returnMessage||'Revisa la información de la ficha.')}</p><button class="primary small edit-family" data-id="${esc(p.id)}">Revisar y modificar</button></div>`:''}<div class="checklist"><div class="check"><span>Datos personales</span><strong>${p.data?'✓':'!'}</strong></div><div class="check"><span>Documentación</span><strong>${esc(p.docs)}</strong></div><div class="check"><span>Federación</span><strong>${esc(p.federation)}</strong></div></div></article>`).join(''):'<div class="empty-card">Todavía no has dado de alta ningún jugador.</div>';
  $$('.edit-family').forEach(b=>b.onclick=()=>openPlayerForEdit(b.dataset.id));$('#familyPlayerCount').textContent=`${mine.length} ${mine.length===1?'jugador registrado':'jugadores registrados'}`;
}

function renderClub(){
  const q=$('#searchInput').value.trim().toLowerCase();const f=$('#statusFilter').value;
  const rows=players.filter(p=>(f==='all'||p.status===f)&&p.name.toLowerCase().includes(q));
  $('#adminTable').innerHTML=rows.length?rows.map(p=>`<tr class="admin-row" data-id="${esc(p.id)}" tabindex="0"><td><strong>${esc(p.name)}</strong>${p.familyActionRequired?'<div class="meta return-note">Devuelto a familia</div>':''}</td><td>${esc(p.familyName||'Sin familia')}</td><td>${esc(p.category)}</td><td><span class="dot ${p.data?'ok':'warn'}">${p.data?'✓ Completo':'⚠ Revisar'}</span></td><td>${esc(p.docs)}</td><td><span class="workflow-pill ${esc(p.workflow)}">${esc(workflowLabel(p.workflow))}</span></td></tr>`).join(''):'<tr><td colspan="6">No hay jugadores que coincidan con el filtro.</td></tr>';
  $$('.admin-row').forEach(r=>{r.onclick=()=>openAdminPlayer(r.dataset.id);r.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();openAdminPlayer(r.dataset.id)}}});
  $('#statPlayers').textContent=players.length;$('#statComplete').textContent=players.filter(p=>p.status==='complete').length;$('#statDocs').textContent=players.filter(p=>p.docs!=='Completa').length;$('#statReview').textContent=players.filter(p=>p.workflow==='review'||p.familyActionRequired).length;
}

function renderClubUsers(){
  const staff=users.filter(u=>u.role==='admin'||u.role==='club');
  $('#clubUsersTable').innerHTML=staff.map(u=>`<tr><td><strong>${esc(u.name)}</strong></td><td>${esc(u.email)}</td><td>${esc(roleLabel(u.role))}</td><td><span class="status ${u.active?'complete':'returned'}">${u.active?'Activo':'Desactivado'}</span></td><td><button class="secondary tiny toggle-user" data-id="${u.id}" ${u.id===currentUser.id?'disabled':''}>${u.active?'Desactivar':'Activar'}</button></td></tr>`).join('');
  $$('.toggle-user').forEach(b=>b.onclick=()=>{const id=b.dataset.id;users=users.map(u=>u.id===id?{...u,active:!u.active}:u);saveUsers();renderClubUsers();});
}

function openAdminPlayer(id){
  selectedPlayerId=id;const p=players.find(x=>x.id===id);if(!p)return;$('#adminPlayerName').textContent=p.name;$('#adminPlayerCategory').textContent=`${p.category} · ${p.familyName||'Sin familia'}`;$('#adminPlayerSource').textContent=p.ownerUserId?'Alta realizada por una familia registrada':'Registro de demostración del club';$('#adminPlayerData').textContent=p.data?'Completos':'Revisar';$('#adminPlayerDocs').textContent=p.docs;$('#adminPlayerFed').textContent=p.federation;$('#adminWorkflow').value=p.workflow||'review';$('#returnMessage').value=p.returnMessage||'';const linked=!!p.ownerUserId;$('#returnMessage').disabled=!linked;$('#returnToFamily').disabled=!linked;$('#returnHint').textContent=linked?'La familia verá el motivo al iniciar sesión.':'Este registro no está vinculado a una cuenta familiar.';$('#adminPlayerModal').showModal();
}
function updateSelected(mut){players=players.map(p=>p.id===selectedPlayerId?mut({...p}):p);savePlayers();renderClub();}
function advanceSelected(){const p=players.find(x=>x.id===selectedPlayerId);if(!p)return;const i=Math.max(0,WORKFLOW.findIndex(x=>x.key===p.workflow));const n=WORKFLOW[Math.min(i+1,WORKFLOW.length-1)];updateSelected(x=>({...x,workflow:n.key,federation:n.federation,status:['ready','federated'].includes(n.key)?'complete':'pending',familyActionRequired:false,returnMessage:''}));openAdminPlayer(selectedPlayerId);}
function setWorkflowSelected(){const wf=WORKFLOW.find(x=>x.key===$('#adminWorkflow').value);if(!wf)return;updateSelected(x=>({...x,workflow:wf.key,federation:wf.federation,status:['ready','federated'].includes(wf.key)?'complete':'pending',familyActionRequired:false,returnMessage:''}));openAdminPlayer(selectedPlayerId);}
function returnSelected(){const p=players.find(x=>x.id===selectedPlayerId);if(!p?.ownerUserId)return;const m=$('#returnMessage').value.trim();if(!m){alert('Indica qué debe revisar o modificar la familia.');return;}updateSelected(x=>({...x,workflow:'review',federation:'Devuelto a familia',status:'pending',familyActionRequired:true,returnMessage:m}));$('#adminPlayerModal').close();}

function openPlayerForNew(){editingPlayerId=null;$('#playerForm').reset();$('#playerModalTitle').textContent='Datos del jugador';$('#savePlayer').textContent='Guardar jugador';$('#playerModal').showModal();}
function openPlayerForEdit(id){const p=familyPlayers().find(x=>x.id===id);if(!p)return;editingPlayerId=id;const f=$('#playerForm');const parts=p.name.split(' ');f.elements.name.value=parts[0]||'';f.elements.surname1.value=parts[1]||'';f.elements.surname2.value=parts.slice(2).join(' ');f.elements.birth.value=p.birth||'';f.elements.dni.value=p.dni||'';f.elements.category.value=p.category||'';f.elements.email.value=p.email||currentUser.email||'';f.elements.phone.value=p.phone||currentUser.phone||'';$('#playerModalTitle').textContent='Revisar datos del jugador';$('#savePlayer').textContent='Guardar cambios';$('#playerModal').showModal();}

$('#showLogin').onclick=()=>showAuth('login');$('#showFamilySignup').onclick=()=>showAuth('signup');
$('#loginForm').onsubmit=e=>{e.preventDefault();reload();const fd=new FormData(e.currentTarget);const u=users.find(x=>x.email.toLowerCase()===String(fd.get('email')).toLowerCase()&&x.password===fd.get('password')&&x.active);if(!u){alert('Correo, contraseña o estado de usuario no válidos.');return;}localStorage.setItem(SESSION_KEY,u.id);currentUser=u;showApp();e.currentTarget.reset();};
$('#familySignupForm').onsubmit=e=>{e.preventDefault();reload();const fd=new FormData(e.currentTarget);if(fd.get('password')!==fd.get('password2')){alert('Las contraseñas no coinciden.');return;}const email=String(fd.get('email')).toLowerCase();if(users.some(u=>u.email.toLowerCase()===email)){alert('Ya existe un usuario con ese correo.');return;}const u={id:`u-family-${Date.now()}`,name:fd.get('name'),email,phone:fd.get('phone'),password:fd.get('password'),role:'family',active:true};users.push(u);saveUsers();localStorage.setItem(SESSION_KEY,u.id);currentUser=u;e.currentTarget.reset();showApp();};
$('#logoutButton').onclick=()=>{localStorage.removeItem(SESSION_KEY);currentUser=null;showAuth('login');};

$('[data-open="playerModal"]').onclick=openPlayerForNew;$('#playerForm').onsubmit=e=>{e.preventDefault();if(!e.currentTarget.reportValidity())return;const fd=new FormData(e.currentTarget);const full=[fd.get('name'),fd.get('surname1'),fd.get('surname2')].filter(Boolean).join(' ');if(editingPlayerId){players=players.map(p=>p.id===editingPlayerId&&p.ownerUserId===currentUser.id?{...p,name:full,category:fd.get('category'),birth:fd.get('birth')||'',dni:fd.get('dni')||'',email:fd.get('email')||'',phone:fd.get('phone')||'',data:true,familyActionRequired:false,returnMessage:'',workflow:'review',federation:'Modificado por familia · pendiente de revisión',status:'pending'}:p);}else{players.push({id:`p-${Date.now()}`,ownerUserId:currentUser.id,familyName:currentUser.name,name:full,category:fd.get('category'),birth:fd.get('birth')||'',dni:fd.get('dni')||'',email:fd.get('email')||'',phone:fd.get('phone')||'',status:'pending',docs:'Pendiente de documentos',federation:'Pendiente de revisión',workflow:'review',data:true,familyActionRequired:false,returnMessage:''});}savePlayers();renderFamily();e.currentTarget.reset();editingPlayerId=null;$('#playerModal').close();};
$$('#playerForm [value="cancel"]').forEach(b=>b.onclick=()=>{$('#playerForm').reset();editingPlayerId=null;$('#playerModal').close();});

$('#searchInput').oninput=renderClub;$('#statusFilter').onchange=renderClub;$('#advanceStatus').onclick=advanceSelected;$('#saveWorkflow').onclick=setWorkflowSelected;$('#returnToFamily').onclick=returnSelected;$('#closeAdminModal').onclick=()=>$('#adminPlayerModal').close();

$$('[data-club-view]').forEach(b=>b.onclick=()=>{if(b.dataset.clubView==='usersView'&&currentUser.role!=='admin')return;$$('.club-nav .nav-item').forEach(x=>x.classList.remove('active'));b.classList.add('active');$('#clubView').classList.toggle('active',b.dataset.clubView==='clubView');$('#usersView').classList.toggle('active',b.dataset.clubView==='usersView');if(b.dataset.clubView==='usersView')renderClubUsers();});
$$('[data-family-tab]').forEach(b=>b.onclick=()=>{$$('[data-family-tab]').forEach(x=>x.classList.remove('active'));b.classList.add('active');if(b.dataset.familyTab==='players')$('.section').scrollIntoView({behavior:'smooth'});});

$('#openClubUserModal').onclick=()=>$('#clubUserModal').showModal();$('#closeClubUserModal').onclick=$('#cancelClubUser').onclick=()=>$('#clubUserModal').close();$('#clubUserForm').onsubmit=e=>{e.preventDefault();if(currentUser.role!=='admin')return;reload();const fd=new FormData(e.currentTarget);const email=String(fd.get('email')).toLowerCase();if(users.some(u=>u.email.toLowerCase()===email)){alert('Ya existe un usuario con ese correo.');return;}users.push({id:`u-staff-${Date.now()}`,name:fd.get('name'),email,phone:'',password:fd.get('password'),role:fd.get('role'),active:true});saveUsers();e.currentTarget.reset();$('#clubUserModal').close();renderClubUsers();};

window.addEventListener('storage',()=>{reload();if(currentUser?.role==='family')renderFamily();else if(currentUser){renderClub();if(currentUser.role==='admin')renderClubUsers();}});

initData();reload();if(currentUser)showApp();else showAuth('login');
if('serviceWorker' in navigator)navigator.serviceWorker.register('./sw.js?v=6').catch(()=>{});
