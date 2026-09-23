const players = [
  {name:'Daniel Santos García', category:'Prebenjamín', status:'complete', docs:'Completa', federation:'Listo para federar', data:true},
  {name:'Álvaro Santos García', category:'Benjamín', status:'pending', docs:'Falta fotografía', federation:'Pendiente', data:true}
];
const adminPlayers = [
  ...players,
  {name:'Hugo Pérez Martín', category:'Alevín', status:'pending', docs:'Falta DNI/NIE', federation:'Pendiente', data:true},
  {name:'Lucía Moreno Díaz', category:'Infantil', status:'complete', docs:'Completa', federation:'Ficha tramitada', data:true},
  {name:'Mario López Serrano', category:'Cadete', status:'pending', docs:'Completa', federation:'Revisar datos', data:false},
  {name:'Sara Gómez Prieto', category:'Juvenil', status:'complete', docs:'Completa', federation:'Listo para federar', data:true}
];

function renderPlayers(){
  const root=document.querySelector('#playersList');
  root.innerHTML=players.map(p=>`<article class="player-card">
    <div class="row"><div><h3>${p.name}</h3><div class="meta">${p.category}</div></div><span class="status ${p.status}">${p.status==='complete'?'✓ Completa':'⚠ Pendiente'}</span></div>
    <div class="checklist"><div class="check"><span>Datos personales</span><strong>${p.data?'✓':'!'}</strong></div><div class="check"><span>Documentación</span><strong>${p.docs}</strong></div><div class="check"><span>Federación</span><strong>${p.federation}</strong></div></div>
  </article>`).join('');
}
function renderAdmin(){
  const q=document.querySelector('#searchInput').value.toLowerCase(); const f=document.querySelector('#statusFilter').value;
  document.querySelector('#adminTable').innerHTML=adminPlayers.filter(p=>(f==='all'||p.status===f)&&p.name.toLowerCase().includes(q)).map(p=>`<tr>
    <td><strong>${p.name}</strong></td><td>${p.category}</td><td><span class="dot ${p.data?'ok':'warn'}">${p.data?'✓ Completo':'⚠ Revisar'}</span></td><td>${p.docs}</td><td>${p.federation}</td>
  </tr>`).join('');
}
renderPlayers(); renderAdmin();

document.querySelector('#searchInput').addEventListener('input',renderAdmin);
document.querySelector('#statusFilter').addEventListener('change',renderAdmin);

document.querySelectorAll('[data-open="playerModal"]').forEach(b=>b.addEventListener('click',()=>document.querySelector('#playerModal').showModal()));

document.querySelector('#playerForm').addEventListener('submit',e=>{
  const submitter=e.submitter; if(!submitter || submitter.value!=='default') return;
  e.preventDefault();
  const fd=new FormData(e.currentTarget);
  const full=[fd.get('name'),fd.get('surname1'),fd.get('surname2')].join(' ');
  players.push({name:full,category:fd.get('category'),status:'pending',docs:'Pendiente de documentos',federation:'Pendiente',data:true});
  renderPlayers(); e.currentTarget.reset(); document.querySelector('#playerModal').close();
});

let admin=false;
document.querySelector('#roleSwitch').addEventListener('click',()=>{
  admin=!admin;
  document.querySelector('#familyView').classList.toggle('active',!admin);
  document.querySelector('#adminView').classList.toggle('active',admin);
  document.querySelector('#bottomNav').style.display=admin?'none':'grid';
  document.querySelector('#roleSwitch').textContent=admin?'👪':'↔';
});

document.querySelectorAll('.nav-item').forEach(b=>b.addEventListener('click',()=>{
  document.querySelectorAll('.nav-item').forEach(x=>x.classList.remove('active')); b.classList.add('active');
  if(b.dataset.tab==='players') document.querySelector('.section').scrollIntoView({behavior:'smooth'});
}));

if('serviceWorker' in navigator){navigator.serviceWorker.register('./sw.js').catch(()=>{});}
