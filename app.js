const STORAGE_KEY = 'yebenes-family-players-v4';
const LEGACY_KEYS = ['yebenes-family-players-v3'];

const defaultFamilyPlayers = [
  {id:'demo-daniel', name:'Daniel Santos García', category:'Prebenjamín', status:'complete', docs:'Completa', federation:'Listo para federar', workflow:'ready', data:true},
  {id:'demo-alvaro', name:'Álvaro Santos García', category:'Benjamín', status:'pending', docs:'Falta fotografía', federation:'Pendiente', workflow:'review', data:true}
];

const clubOnlyDemoPlayers = [
  {id:'demo-hugo', name:'Hugo Pérez Martín', category:'Alevín', status:'pending', docs:'Falta DNI/NIE', federation:'Pendiente', workflow:'review', data:true},
  {id:'demo-lucia', name:'Lucía Moreno Díaz', category:'Infantil', status:'complete', docs:'Completa', federation:'Ficha tramitada', workflow:'federated', data:true},
  {id:'demo-mario', name:'Mario López Serrano', category:'Cadete', status:'pending', docs:'Completa', federation:'Revisar datos', workflow:'review', data:false},
  {id:'demo-sara', name:'Sara Gómez Prieto', category:'Juvenil', status:'complete', docs:'Completa', federation:'Listo para federar', workflow:'ready', data:true}
];

const WORKFLOW = [
  {key:'review', label:'Pendiente de revisión', federation:'Pendiente'},
  {key:'data_ok', label:'Datos validados', federation:'Datos validados'},
  {key:'docs_ok', label:'Documentación validada', federation:'Documentación validada'},
  {key:'ready', label:'Listo para federar', federation:'Listo para federar'},
  {key:'federated', label:'Ficha tramitada', federation:'Ficha tramitada'}
];

function readStoredPlayers(){
  for(const key of [STORAGE_KEY, ...LEGACY_KEYS]){
    try {
      const saved = JSON.parse(localStorage.getItem(key));
      if(Array.isArray(saved)){
        return saved.map(normalizePlayer);
      }
    } catch {}
  }
  return null;
}

function normalizePlayer(p){
  const workflow = p.workflow || inferWorkflow(p.federation);
  return {
    ...p,
    workflow,
    familyActionRequired: !!p.familyActionRequired,
    returnMessage: p.returnMessage || '',
    updatedAt: p.updatedAt || null
  };
}

function inferWorkflow(federation=''){
  const f=String(federation).toLowerCase();
  if(f.includes('tramitada')) return 'federated';
  if(f.includes('listo')) return 'ready';
  if(f.includes('documentación validada')) return 'docs_ok';
  if(f.includes('datos validados')) return 'data_ok';
  return 'review';
}

let players = readStoredPlayers() || [...defaultFamilyPlayers];
let selectedPlayerId = null;
let editingPlayerId = null;

function saveFamilyPlayers(){
  localStorage.setItem(STORAGE_KEY, JSON.stringify(players));
}

function syncPlayersFromStorage(){
  const saved = readStoredPlayers();
  if(saved) players = saved;
}

function getAdminPlayers(){
  syncPlayersFromStorage();
  return [...players, ...clubOnlyDemoPlayers];
}

function isFamilyPlayer(id){ return players.some(p=>p.id===id); }

function esc(s=''){
  return String(s).replace(/[&<>'"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;","'":"&#39;",'"':'&quot;'}[c]));
}

function workflowLabel(key){ return WORKFLOW.find(x=>x.key===key)?.label || 'Pendiente de revisión'; }

function renderPlayers(){
  syncPlayersFromStorage();
  const root=document.querySelector('#playersList');
  root.innerHTML=players.map(p=>`<article class="player-card ${p.familyActionRequired?'needs-action':''}" data-family-player="${esc(p.id)}">
    <div class="row"><div><h3>${esc(p.name)}</h3><div class="meta">${esc(p.category)}</div></div><span class="status ${p.familyActionRequired?'returned':p.status}">${p.familyActionRequired?'↩ Revisar':p.status==='complete'?'✓ Completa':'⚠ Pendiente'}</span></div>
    ${p.familyActionRequired?`<div class="family-alert"><strong>El club solicita cambios</strong><p>${esc(p.returnMessage || 'Revisa la información de la ficha.')}</p><button class="primary small edit-family" data-id="${esc(p.id)}">Revisar y modificar</button></div>`:''}
    <div class="checklist"><div class="check"><span>Datos personales</span><strong>${p.data?'✓':'!'}</strong></div><div class="check"><span>Documentación</span><strong>${esc(p.docs)}</strong></div><div class="check"><span>Federación</span><strong>${esc(p.federation)}</strong></div></div>
  </article>`).join('');

  document.querySelectorAll('.edit-family').forEach(btn=>btn.addEventListener('click',()=>openPlayerFormForEdit(btn.dataset.id)));

  const familyCount=document.querySelector('#familyPlayerCount');
  if(familyCount) familyCount.textContent=`${players.length} ${players.length===1?'jugador registrado':'jugadores registrados'}`;
}

function renderAdmin({resetFilters=false}={}){
  const adminPlayers=getAdminPlayers();
  const search=document.querySelector('#searchInput');
  const filter=document.querySelector('#statusFilter');
  if(resetFilters){ search.value=''; filter.value='all'; }
  const q=search.value.trim().toLowerCase();
  const f=filter.value;
  const rows=adminPlayers.filter(p=>(f==='all'||p.status===f)&&p.name.toLowerCase().includes(q));

  document.querySelector('#adminTable').innerHTML=rows.length ? rows.map(p=>`<tr class="admin-row" data-id="${esc(p.id)}" tabindex="0">
      <td><strong>${esc(p.name)}</strong>${p.id?.startsWith('local-')?'<div class="meta">Alta desde familias</div>':''}${p.familyActionRequired?'<div class="meta return-note">Devuelto a familia</div>':''}</td>
      <td>${esc(p.category)}</td>
      <td><span class="dot ${p.data?'ok':'warn'}">${p.data?'✓ Completo':'⚠ Revisar'}</span></td>
      <td>${esc(p.docs)}</td>
      <td><span class="workflow-pill ${esc(p.workflow)}">${esc(workflowLabel(p.workflow))}</span></td>
    </tr>`).join('') : '<tr><td colspan="5">No hay jugadores que coincidan con el filtro.</td></tr>';

  document.querySelectorAll('.admin-row').forEach(row=>{
    row.addEventListener('click',()=>openAdminPlayer(row.dataset.id));
    row.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();openAdminPlayer(row.dataset.id);}});
  });

  const complete=adminPlayers.filter(p=>p.status==='complete').length;
  const pendingDocs=adminPlayers.filter(p=>p.docs!=='Completa').length;
  const review=adminPlayers.filter(p=>p.workflow==='review'||p.familyActionRequired).length;
  const set=(id,value)=>{const el=document.querySelector(id); if(el) el.textContent=value;};
  set('#statPlayers',adminPlayers.length);
  set('#statComplete',complete);
  set('#statDocs',pendingDocs);
  set('#statReview',review);
}

function renderAll(){ renderPlayers(); renderAdmin(); }

function openAdminPlayer(id){
  selectedPlayerId=id;
  const p=getAdminPlayers().find(x=>x.id===id);
  if(!p) return;
  const family=isFamilyPlayer(id);
  document.querySelector('#adminPlayerName').textContent=p.name;
  document.querySelector('#adminPlayerCategory').textContent=p.category;
  document.querySelector('#adminPlayerSource').textContent=family?'Alta realizada por la familia':'Registro de demostración del club';
  document.querySelector('#adminPlayerData').textContent=p.data?'Completos':'Revisar';
  document.querySelector('#adminPlayerDocs').textContent=p.docs;
  document.querySelector('#adminPlayerFed').textContent=p.federation;
  document.querySelector('#adminWorkflow').value=p.workflow || 'review';
  const msg=document.querySelector('#returnMessage');
  msg.value=p.returnMessage || '';
  msg.disabled=!family;
  document.querySelector('#returnToFamily').disabled=!family;
  document.querySelector('#returnHint').textContent=family?'La familia verá el motivo y podrá modificar la ficha.':'Solo disponible para altas vinculadas a una familia.';
  document.querySelector('#adminPlayerModal').showModal();
}

function updateSelected(mutator){
  if(!selectedPlayerId || !isFamilyPlayer(selectedPlayerId)) return false;
  players=players.map(p=>p.id===selectedPlayerId?normalizePlayer(mutator({...p})):p);
  saveFamilyPlayers();
  renderAll();
  return true;
}

function advanceSelected(){
  const p=getAdminPlayers().find(x=>x.id===selectedPlayerId);
  if(!p) return;
  if(!isFamilyPlayer(selectedPlayerId)){
    alert('Este registro es de demostración. La edición completa se habilitará al conectar la base de datos.');
    return;
  }
  const current=Math.max(0,WORKFLOW.findIndex(x=>x.key===p.workflow));
  const next=WORKFLOW[Math.min(current+1,WORKFLOW.length-1)];
  updateSelected(x=>({
    ...x,
    workflow:next.key,
    federation:next.federation,
    status: next.key==='ready'||next.key==='federated' ? 'complete':'pending',
    familyActionRequired:false,
    returnMessage:'',
    updatedAt:new Date().toISOString()
  }));
  document.querySelector('#adminWorkflow').value=next.key;
  openAdminPlayer(selectedPlayerId);
}

function setWorkflowSelected(){
  const value=document.querySelector('#adminWorkflow').value;
  const wf=WORKFLOW.find(x=>x.key===value);
  if(!wf) return;
  if(!isFamilyPlayer(selectedPlayerId)){
    alert('Este registro es de demostración. La edición completa se habilitará al conectar la base de datos.');
    return;
  }
  updateSelected(x=>({
    ...x,
    workflow:wf.key,
    federation:wf.federation,
    status:wf.key==='ready'||wf.key==='federated'?'complete':'pending',
    familyActionRequired:false,
    returnMessage:'',
    updatedAt:new Date().toISOString()
  }));
  openAdminPlayer(selectedPlayerId);
}

function returnSelectedToFamily(){
  const message=document.querySelector('#returnMessage').value.trim();
  if(!isFamilyPlayer(selectedPlayerId)) return;
  if(!message){
    document.querySelector('#returnMessage').focus();
    alert('Indica qué debe revisar o modificar la familia.');
    return;
  }
  updateSelected(x=>({
    ...x,
    workflow:'review',
    federation:'Devuelto a familia',
    status:'pending',
    familyActionRequired:true,
    returnMessage:message,
    updatedAt:new Date().toISOString()
  }));
  document.querySelector('#adminPlayerModal').close();
}

function openPlayerFormForEdit(id){
  const p=players.find(x=>x.id===id);
  if(!p) return;
  editingPlayerId=id;
  const form=document.querySelector('#playerForm');
  const parts=p.name.split(' ');
  form.elements.name.value=parts[0]||'';
  form.elements.surname1.value=parts[1]||'';
  form.elements.surname2.value=parts.slice(2).join(' ');
  form.elements.birth.value=p.birth||'';
  form.elements.dni.value=p.dni||'';
  form.elements.category.value=p.category||'';
  form.elements.email.value=p.email||'';
  form.elements.phone.value=p.phone||'';
  document.querySelector('#playerModalTitle').textContent='Revisar datos del jugador';
  document.querySelector('#savePlayer').textContent='Guardar cambios';
  document.querySelector('#playerModal').showModal();
}

function openPlayerFormForNew(){
  editingPlayerId=null;
  document.querySelector('#playerForm').reset();
  document.querySelector('#playerModalTitle').textContent='Datos del jugador';
  document.querySelector('#savePlayer').textContent='Guardar jugador';
  document.querySelector('#playerModal').showModal();
}

renderAll();

document.querySelector('#searchInput').addEventListener('input',()=>renderAdmin());
document.querySelector('#statusFilter').addEventListener('change',()=>renderAdmin());
document.querySelectorAll('[data-open="playerModal"]').forEach(b=>b.addEventListener('click',openPlayerFormForNew));

document.querySelector('#advanceStatus').addEventListener('click',advanceSelected);
document.querySelector('#saveWorkflow').addEventListener('click',setWorkflowSelected);
document.querySelector('#returnToFamily').addEventListener('click',returnSelectedToFamily);
document.querySelector('#closeAdminModal').addEventListener('click',()=>document.querySelector('#adminPlayerModal').close());

const form=document.querySelector('#playerForm');
const saveButton=document.querySelector('#savePlayer');

form.addEventListener('submit',e=>{
  e.preventDefault();
  if(!form.reportValidity()) return;
  const fd=new FormData(form);
  const full=[fd.get('name'),fd.get('surname1'),fd.get('surname2')].filter(Boolean).join(' ');
  if(editingPlayerId){
    players=players.map(p=>p.id===editingPlayerId?{
      ...p,
      name:full,
      category:fd.get('category'),
      data:true,
      birth:fd.get('birth') || '',
      dni:fd.get('dni') || '',
      email:fd.get('email') || '',
      phone:fd.get('phone') || '',
      familyActionRequired:false,
      returnMessage:'',
      workflow:'review',
      federation:'Modificado por familia · pendiente de revisión',
      status:'pending',
      updatedAt:new Date().toISOString()
    }:p);
  } else {
    const player={
      id:`local-${Date.now()}`,
      name:full,
      category:fd.get('category'),
      status:'pending',
      docs:'Pendiente de documentos',
      federation:'Pendiente de revisión',
      workflow:'review',
      data:true,
      birth:fd.get('birth') || '',
      dni:fd.get('dni') || '',
      email:fd.get('email') || '',
      phone:fd.get('phone') || '',
      familyActionRequired:false,
      returnMessage:'',
      updatedAt:new Date().toISOString()
    };
    players=[...players, player];
  }
  saveFamilyPlayers();
  renderPlayers();
  renderAdmin({resetFilters:true});
  form.reset();
  editingPlayerId=null;
  document.querySelector('#playerModal').close();
});

saveButton.addEventListener('click',e=>{e.preventDefault();form.requestSubmit();});

document.querySelectorAll('#playerForm [value="cancel"]').forEach(btn=>btn.addEventListener('click',e=>{
  e.preventDefault();
  form.reset();
  editingPlayerId=null;
  document.querySelector('#playerModal').close();
}));

let admin=false;
document.querySelector('#roleSwitch').addEventListener('click',()=>{
  admin=!admin;
  if(admin){ syncPlayersFromStorage(); renderAdmin({resetFilters:true}); }
  else renderPlayers();
  document.querySelector('#familyView').classList.toggle('active',!admin);
  document.querySelector('#adminView').classList.toggle('active',admin);
  document.querySelector('#bottomNav').style.display=admin?'none':'grid';
  document.querySelector('#roleSwitch').textContent=admin?'👪':'↔';
});

document.querySelectorAll('.nav-item').forEach(b=>b.addEventListener('click',()=>{
  document.querySelectorAll('.nav-item').forEach(x=>x.classList.remove('active'));
  b.classList.add('active');
  if(b.dataset.tab==='players') document.querySelector('.section').scrollIntoView({behavior:'smooth'});
}));

window.addEventListener('storage',e=>{
  if([STORAGE_KEY,...LEGACY_KEYS].includes(e.key)){
    syncPlayersFromStorage();
    renderAll();
  }
});

if('serviceWorker' in navigator){navigator.serviceWorker.register('./sw.js?v=4').catch(()=>{});}
