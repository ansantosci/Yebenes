# Los Yébenes San Bruno - Prototipo web app V17

Versión de pruebas de la aplicación responsive del C.D. Los Yébenes San Bruno.

## Cambio técnico principal de V17

Durante la fase de desarrollo se desactiva temporalmente el Service Worker para evitar que Chrome mantenga versiones antiguas de la aplicación.

- La aplicación ya no registra un Service Worker nuevo.
- Al arrancar intenta desregistrar Service Workers anteriores del sitio.
- Se eliminan las cachés PWA antiguas sin borrar los datos de prueba almacenados en `localStorage`.
- `styles.css` y `app.js` se cargan con parámetro de versión (`?v=17`) para forzar la actualización de recursos.
- Se mantiene intacta la funcionalidad de negocio de V16.
- La pantalla de acceso muestra discretamente `v17`.

## Funcionalidad heredada de V16

- Entidad lógica Persona vinculada a usuarios y jugadores.
- Detección de posibles duplicados por correo, DNI/NIE y nombre + fecha de nacimiento.
- Bloqueo preventivo de altas duplicadas de jugadores.
- Pantalla Administrador > Personas con directorio maestro y posibles duplicados.
- Fusión administrativa que conserva perfiles e histórico cuando no existen conflictos de inscripción en una misma temporada.

## Nota sobre versiones internas

La versión visible de la aplicación es **V17**. El esquema de claves de datos locales sigue siendo **13** para conservar los datos de prueba existentes entre versiones.

## Service Worker

Se reactivará cuando la aplicación alcance una versión más estable, con una estrategia de actualización controlada.
