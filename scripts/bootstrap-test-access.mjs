const url = process.env.SUPABASE_TEST_URL;
const service = process.env.SUPABASE_TEST_SERVICE_ROLE_KEY;
const password = process.env.TEST_APP_USER_PASSWORD;
if (!url || !service || !password) throw new Error('Missing SUPABASE_TEST_URL, SUPABASE_TEST_SERVICE_ROLE_KEY or TEST_APP_USER_PASSWORD');
if (password.length < 10) throw new Error('TEST_APP_USER_PASSWORD must have at least 10 characters');
const headers = { apikey: service, Authorization: `Bearer ${service}`, 'Content-Type': 'application/json' };
const identities = [
 ['club.test@yebenes.test','10000000-0000-4000-8000-000000000001','Club TEST'],
 ['coach.test@yebenes.test','10000000-0000-4000-8000-000000000002','Entrenador TEST Acceso'],
 ['coach-player.test@yebenes.test','10000000-0000-4000-8000-000000000003','Entrenador Jugador TEST'],
 ['tutor.test@yebenes.test','10000000-0000-4000-8000-000000000004','Tutor TEST Acceso'],
 ['player-adult.test@yebenes.test','10000000-0000-4000-8000-000000000005','Jugador Adulto TEST'],
 ['player-minor.test@yebenes.test','10000000-0000-4000-8000-000000000006','Jugador Menor TEST'],
 ['multiprofile.test@yebenes.test','10000000-0000-4000-8000-000000000007','Multiperfil TEST'],
];
async function req(path, opts={}) { const r=await fetch(url+path,{...opts,headers:{...headers,...opts.headers}}); const text=await r.text(); let data; try{data=text?JSON.parse(text):null}catch{data=text} if(!r.ok) throw new Error(`${opts.method||'GET'} ${path}: ${r.status} ${text}`); return data; }
let users=[]; for(let page=1;;page++){ const d=await req(`/auth/v1/admin/users?page=${page}&per_page=100`); const batch=d?.users||[]; users.push(...batch); if(batch.length<100) break; }
for (const [email,personaId,displayName] of identities) {
  let user=users.find(u=>String(u.email||'').toLowerCase()===email);
  if(!user){ user=await req('/auth/v1/admin/users',{method:'POST',body:JSON.stringify({email,password,email_confirm:true,user_metadata:{display_name:displayName,person_id:personaId,account_origin:'test_access'},app_metadata:{account_origin:'test_access'}})}); }
  else { user=await req(`/auth/v1/admin/users/${user.id}`,{method:'PUT',body:JSON.stringify({password,email_confirm:true,user_metadata:{...(user.user_metadata||{}),display_name:displayName,person_id:personaId,account_origin:'test_access'},app_metadata:{...(user.app_metadata||{}),account_origin:'test_access'}})}); }
  await req(`/rest/v1/personas?id=eq.${personaId}`,{method:'PATCH',headers:{Prefer:'return=minimal'},body:JSON.stringify({auth_user_id:user.id,email_contacto:email,activo:true})});
  console.log(`linked ${email} -> ${personaId}`);
}
console.log(`TEST-ACCESS ready: ${identities.length} users`);
