# Los Yébenes San Bruno - Prototipo web app V15

Versión de pruebas de la aplicación responsive del C.D. Los Yébenes San Bruno.

## Cambio principal de V15

Se refuerza la actualización de la PWA para evitar que Chrome mantenga versiones antiguas:

- Service Worker con estrategia **network first** y `cache: no-store` para los recursos del mismo origen.
- Registro con `updateViaCache: 'none'`.
- Comprobación de actualizaciones al arrancar, recuperar el foco y volver a una pestaña visible.
- Eliminación automática de cachés antiguas.
- Migración automática desde la estrategia de caché de V14 y anteriores.
- Aviso discreto **Nueva versión disponible** con botón **Actualizar ahora** para las siguientes actualizaciones.
- Recarga con parámetro de cache-busting al aplicar una actualización.

La lógica funcional de negocio de V14 se mantiene sin cambios.
