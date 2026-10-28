// C.D. Los Yebenes San Bruno
// Configuracion publica de entornos del frontend.
//
// IMPORTANTE:
// Este fichero solo puede contener informacion publica del cliente.
// NUNCA incluir:
// - service_role / secret keys
// - contrasena PostgreSQL
// - CRON_SECRET
// - tokens Mailtrap
// - tokens GitHub
// - cualquier otro secreto backend

window.YEBENES_ENVIRONMENTS = Object.freeze({

  demo: Object.freeze({
    name: 'DEMO',
    supabaseUrl: 'https://ypyzochuqtetddffohpv.supabase.co',
    supabasePublishableKey: 'sb_publishable_AZkaUtTojw0Xrxu3dwgkhg_2QFNU1q3',
    authRedirectUrl: 'https://ansantosci.github.io/Yebenes/'
  }),

  test: Object.freeze({
    name: 'TEST',
    supabaseUrl: 'https://eenzhtnwnimpqurjpaok.supabase.co',
    supabasePublishableKey: 'sb_publishable_esdB658Kge6lCUh4qjgG0g_D1obbWz9',
    authRedirectUrl: 'https://ansantosci.github.io/Yebenes/test/'
  }),

  develop: Object.freeze({
    name: 'DEVELOP',
    supabaseUrl: 'https://eenzhtnwnimpqurjpaok.supabase.co',
    supabasePublishableKey: 'sb_publishable_esdB658Kge6lCUh4qjgG0g_D1obbWz9',
    authRedirectUrl: 'https://ansantosci.github.io/Yebenes/develop/'
  })

});

// El workflow de despliegue establecera window.YEBENES_ENVIRONMENT
// antes de cargar este fichero:
//
//   main    -> demo
//   test    -> test
//   develop -> develop
//
// Mientras construimos la nueva infraestructura, mantenemos DEMO como
// fallback seguro para conservar el comportamiento actual de V93.8.

const requestedEnvironment =
  String(window.YEBENES_ENVIRONMENT || 'demo')
    .trim()
    .toLowerCase();

const selectedConfig =
  window.YEBENES_ENVIRONMENTS[requestedEnvironment];

if (!selectedConfig) {
  throw new Error(
    `Entorno Yebenes no valido: ${requestedEnvironment}`
  );
}

window.YEBENES_ENVIRONMENT = requestedEnvironment;
window.YEBENES_CONFIG = selectedConfig;

console.info(
  `[Yebenes] Entorno frontend: ${selectedConfig.name}`
);
