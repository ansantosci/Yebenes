const url = process.env.SUPABASE_ACCESS_URL;
const service = process.env.SUPABASE_ACCESS_SERVICE_ROLE_KEY;
const password = process.env.APP_USER_PASSWORD;
const accountOrigin = process.env.ACCESS_ACCOUNT_ORIGIN;
const label = process.env.ACCESS_LABEL;
const identities = JSON.parse(process.env.ACCESS_IDENTITIES_JSON ?? '[]');
const retiredIdentities = JSON.parse(process.env.RETIRED_ACCESS_IDENTITIES_JSON ?? '[]');

if (!url || !service || !password || !accountOrigin || !label || identities.length === 0) {
  throw new Error('Missing synthetic-access bootstrap configuration.');
}
if (password.length < 10) throw new Error('The synthetic-access password must have at least 10 characters.');

const headers = { apikey: service, Authorization: `Bearer ${service}`, 'Content-Type': 'application/json' };

async function request(path, options = {}) {
  const response = await fetch(url + path, { ...options, headers: { ...headers, ...options.headers } });
  const text = await response.text();
  let data;
  try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  if (!response.ok) throw new Error(`${options.method ?? 'GET'} ${path}: ${response.status} ${text}`);
  return data;
}

const users = [];
for (let page = 1; ; page += 1) {
  const batch = (await request(`/auth/v1/admin/users?page=${page}&per_page=100`))?.users ?? [];
  users.push(...batch);
  if (batch.length < 100) break;
}

for (const { email } of retiredIdentities) {
  const user = users.find((candidate) => String(candidate.email ?? '').toLowerCase() === email.toLowerCase());
  if (!user) continue;
  const existingOrigin = user.app_metadata?.account_origin;
  if (existingOrigin !== accountOrigin) {
    throw new Error(`Refusing to remove ${email}: it belongs to account origin ${existingOrigin ?? 'unknown'}.`);
  }
  await request(`/auth/v1/admin/users/${user.id}`, { method: 'DELETE' });
  console.log(`removed retired ${email}`);
}

for (const { email, personaId, displayName } of identities) {
  let user = users.find((candidate) => String(candidate.email ?? '').toLowerCase() === email.toLowerCase());
  if (user) {
    const existingOrigin = user.app_metadata?.account_origin;
    if (existingOrigin && existingOrigin !== accountOrigin) {
      throw new Error(`Refusing to change ${email}: it belongs to account origin ${existingOrigin}.`);
    }
    user = await request(`/auth/v1/admin/users/${user.id}`, {
      method: 'PUT',
      body: JSON.stringify({
        password,
        email_confirm: true,
        user_metadata: { ...(user.user_metadata ?? {}), display_name: displayName, person_id: personaId, account_origin: accountOrigin },
        app_metadata: { ...(user.app_metadata ?? {}), account_origin: accountOrigin },
      }),
    });
  } else {
    user = await request('/auth/v1/admin/users', {
      method: 'POST',
      body: JSON.stringify({
        email,
        password,
        email_confirm: true,
        user_metadata: { display_name: displayName, person_id: personaId, account_origin: accountOrigin },
        app_metadata: { account_origin: accountOrigin },
      }),
    });
  }

  const linked = await request(`/rest/v1/personas?id=eq.${personaId}`, {
    method: 'PATCH',
    headers: { Prefer: 'return=representation' },
    body: JSON.stringify({ auth_user_id: user.id, email_contacto: email, activo: true }),
  });
  if (!Array.isArray(linked) || linked.length !== 1) throw new Error(`Could not link one Persona for ${email}.`);
  console.log(`linked ${email} -> ${personaId}`);
}

console.log(`${label} ready: ${identities.length} users`);
