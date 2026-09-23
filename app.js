const STORAGE_KEY = 'yebenes-family-players-v3';

const defaultFamilyPlayers = [
  {id:'demo-daniel', name:'Daniel Santos García', category:'Prebenjamín', status:'complete', docs:'Completa', federation:'Listo para federar', data:true},
  {id:'demo-alvaro', name:'Álvaro Santos García', category:'Benjamín', status:'pending', docs:'Falta fotografía', federation:'Pendiente', data:true}
];

const clubOnlyDemoPlayers = [
  {id:'demo-hugo', name:'Hugo Pérez Martín', category:'Alevín', status:'pending', docs:'Falta DNI/NIE', federation:'Pendiente', data:true},
  {id:'demo-lucia', name:'Lucía Moreno Díaz', category:'Infantil', status:'complete', docs:'Completa', federation:'Ficha tramitada', data:true},
  {id:'demo-mario', name:'Mario López Serrano', category:'Cadete', status:'pending', docs:'Completa', federation:'Revisar datos', data:false},
  {id:'demo-sara', name:'Sara Gómez Prieto', category:'Juvenil', status:'complete', docs:'Completa', federation:'Listo para federar', data:true}
];

function readStoredPlayers(){
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY));
    return Array.isArray(saved) ? saved : null;
  } catch {
    return null;
  }
}

let players = readStoredPlayers() || [...defaultFamilyPlayers];

function saveFamilyPlayers(){
  localStorage.setItem(STORAGE_KEY, JSON.stringify(players));
}

function syncPlayersFromStorage(){
  const saved = readStoredPlayers();
  if (saved) players = saved;
}

function getAdminPlayers(){
  syncPlayersFromStorage();
  return [...players, ...clubOnlyDemoPlayers];
}

function renderPlayers(){
  syncPlayersFromStorage();
  const root=document.querySelector('#playersList');
  root.innerHTML=players.map(p=>`<article class="player-card">
    <div class="row"><div><h3>${p.name}</h3><div class="meta">${p.category}</div></div><span class="status ${p.status}">${p.status==='complete'?'✓ Completa':'⚠ Pendiente'}</span></div>
    <div class="checklist"><div class="check"><span>Datos personales</span><strong>${p.data?'✓':'!'}</strong></div><div class="check"><span>Documentación</span><strong>${p.docs}</strong></div><div class="check"><span>Federación</span><strong>${p.federation}</strong></div></div>
  </article>`).join('');

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
  const rows=adminPlayers
    .filter(p=>(f==='all'||p.status===f)&&p.name.toLowerCase().includes(q));

  document.querySelector('#adminTable').innerHTML=rows.length ? rows.map(p=>`<tr>
      <td><strong>${p.name}</strong>${p.id?.startsWith('local-')?'<div class="meta">Alta desde familias</div>':''}</td><td>${p.category}</td><td><span class="dot ${p.data?'ok':'warn'}">${p.data?'✓ Completo':'⚠ Revisar'}</span></td><td>${p.docs}</td><td>${p.federation}</td>
    </tr>`).join('') : '<tr><td colspan="5">No hay jugadores que coincidan con el filtro.</td></tr>';

  const complete=adminPlayers.filter(p=>p.status==='complete').length;
  const pendingDocs=adminPlayers.filter(p=>p.docs!=='Completa').length;
  const review=adminPlayers.filter(p=>p.status==='pending').length;
  const set=(id,value)=>{const el=document.querySelector(id); if(el) el.textContent=value;};
  set('#statPlayers',adminPlayers.length);
  set('#statComplete',complete);
  set('#statDocs',pendingDocs);
  set('#statReview',review);
}

function renderAll(){
  renderPlayers();
  renderAdmin();
}

renderAll();

document.querySelector('#searchInput').addEventListener('input',()=>renderAdmin());
document.querySelector('#statusFilter').addEventListener('change',()=>renderAdmin());

document.querySelectorAll('[data-open="playerModal"]').forEach(b=>b.addEventListener('click',()=>document.querySelector('#playerModal').showModal()));

const form=document.querySelector('#playerForm');
const saveButton=document.querySelector('#savePlayer');

form.addEventListener('submit',e=>{
  e.preventDefault();
  if(!form.reportValidity()) return;
  const fd=new FormData(form);
  const full=[fd.get('name'),fd.get('surname1'),fd.get('surname2')].filter(Boolean).join(' ');
  const player={
    id:`local-${Date.now()}`,
    name:full,
    category:fd.get('category'),
    status:'pending',
    docs:'Pendiente de documentos',
    federation:'Pendiente',
    data:true,
    birth:fd.get('birth') || '',
    dni:fd.get('dni') || '',
    email:fd.get('email') || '',
    phone:fd.get('phone') || ''
  };
  players=[...players, player];
  saveFamilyPlayers();
  renderPlayers();
  renderAdmin({resetFilters:true});
  form.reset();
  document.querySelector('#playerModal').close();
});

// Fuerza un submit estándar en Safari/iOS, evitando depender de method="dialog" o SubmitEvent.submitter.
saveButton.addEventListener('click',e=>{
  e.preventDefault();
  form.requestSubmit();
});

document.querySelectorAll('#playerForm [value="cancel"]').forEach(btn=>btn.addEventListener('click',e=>{
  e.preventDefault();
  form.reset();
  document.querySelector('#playerModal').close();
}));

let admin=false;
document.querySelector('#roleSwitch').addEventListener('click',()=>{
  admin=!admin;
  if(admin){
    syncPlayersFromStorage();
    renderAdmin({resetFilters:true});
  } else {
    renderPlayers();
  }
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

// Sincroniza cambios si la app está abierta en otra pestaña del mismo navegador.
window.addEventListener('storage',e=>{
  if(e.key===STORAGE_KEY){
    syncPlayersFromStorage();
    renderAll();
  }
});

if('serviceWorker' in navigator){navigator.serviceWorker.register('./sw.js?v=3').catch(()=>{});} 
