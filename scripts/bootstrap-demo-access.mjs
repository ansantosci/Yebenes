process.env.SUPABASE_ACCESS_URL = process.env.SUPABASE_DEMO_URL;
process.env.SUPABASE_ACCESS_SERVICE_ROLE_KEY = process.env.SUPABASE_DEMO_SERVICE_ROLE_KEY;
process.env.APP_USER_PASSWORD = process.env.DEMO_APP_USER_PASSWORD;
process.env.ACCESS_ACCOUNT_ORIGIN = 'demo_access';
process.env.ACCESS_LABEL = 'DEMO-ACCESS';
process.env.ACCESS_IDENTITIES_JSON = JSON.stringify([
  { email: 'club.demo@yebenes.demo.invalid', personaId: '20000000-0000-4000-8000-000000000001', displayName: 'Club DEMO' },
  { email: 'coach.demo@yebenes.demo.invalid', personaId: '20000000-0000-4000-8000-000000000002', displayName: 'Entrenador DEMO Acceso' },
  { email: 'coach-player.demo@yebenes.demo.invalid', personaId: '20000000-0000-4000-8000-000000000003', displayName: 'Entrenador Jugador DEMO' },
  { email: 'tutor.demo@yebenes.demo.invalid', personaId: '20000000-0000-4000-8000-000000000004', displayName: 'Tutor DEMO Acceso' },
  { email: 'player-adult.demo@yebenes.demo.invalid', personaId: '20000000-0000-4000-8000-000000000005', displayName: 'Jugador Adulto DEMO' },
  { email: 'multiprofile.demo@yebenes.demo.invalid', personaId: '20000000-0000-4000-8000-000000000007', displayName: 'Multiperfil DEMO' },
]);
process.env.RETIRED_ACCESS_IDENTITIES_JSON = JSON.stringify([
  { email: 'player-minor.demo@yebenes.demo.invalid', personaId: '20000000-0000-4000-8000-000000000006' },
]);

await import('./bootstrap-synthetic-access.mjs');
