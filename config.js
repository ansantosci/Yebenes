// C.D. Los Yebenes San Bruno - configuracion de entornos
// Solo contiene configuracion publica del frontend.
// NUNCA incluir aqui service_role, CRON_SECRET, tokens de Mailtrap,
// contrasenas de PostgreSQL ni otros secretos backend.

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
    authRedirectUrl: ''
  })

});

// La seleccion definitiva del entorno se realizara desde el despliegue.
// Mientras no exista esa configuracion, DEMO es el valor por defecto
// para no modificar accidentalmente el comportamiento de V93.8.

window.YEBENES_ENVIRONMENT =
  window.YEBENES_ENVIRONMENT || 'demo';

window.YEBENES_CONFIG =
  window.YEBENES_ENVIRONMENTS[window.YEBENES_ENVIRONMENT];

if (!window.YEBENES_CONFIG) {
  throw new Error(
    `Entorno Yebenes no valido: ${window.YEBENES_ENVIRONMENT}`
  );
}
