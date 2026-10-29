process.env.SUPABASE_ACCESS_URL = process.env.SUPABASE_TEST_URL;
process.env.SUPABASE_ACCESS_SERVICE_ROLE_KEY = process.env.SUPABASE_TEST_SERVICE_ROLE_KEY;
process.env.APP_USER_PASSWORD = process.env.TEST_APP_USER_PASSWORD;
process.env.ACCESS_ACCOUNT_ORIGIN = 'test_access';
process.env.ACCESS_LABEL = 'TEST-ACCESS';
process.env.ACCESS_IDENTITIES_JSON = JSON.stringify([
  { email: 'club.test@yebenes.test', personaId: '10000000-0000-4000-8000-000000000001', displayName: 'Club TEST' },
  { email: 'coach.test@yebenes.test', personaId: '10000000-0000-4000-8000-000000000002', displayName: 'Entrenador TEST Acceso' },
  { email: 'coach-player.test@yebenes.test', personaId: '10000000-0000-4000-8000-000000000003', displayName: 'Entrenador Jugador TEST' },
  { email: 'tutor.test@yebenes.test', personaId: '10000000-0000-4000-8000-000000000004', displayName: 'Tutor TEST Acceso' },
  { email: 'player-adult.test@yebenes.test', personaId: '10000000-0000-4000-8000-000000000005', displayName: 'Jugador Adulto TEST' },
  { email: 'player-minor.test@yebenes.test', personaId: '10000000-0000-4000-8000-000000000006', displayName: 'Jugador Menor TEST' },
  { email: 'multiprofile.test@yebenes.test', personaId: '10000000-0000-4000-8000-000000000007', displayName: 'Multiperfil TEST' },
]);

await import('./bootstrap-synthetic-access.mjs');
