# CD Los Yébenes San Bruno - Prototipo web app V26

## Novedad principal

V26 mejora el flujo de confirmación de correo de Supabase Auth.

- Añade **Reenviar correo de confirmación** en la pantalla de acceso.
- El reenvío usa explícitamente `https://ansantosci.github.io/Yebenes/` como destino.
- El alta inicial usa también esa URL de redirección.
- Si existe un alta pendiente, el correo se reutiliza automáticamente para facilitar el reenvío.
- Si Supabase devuelve un enlace caducado/inválido, la app muestra una indicación específica para solicitar uno nuevo.
- Mantiene todas las funciones de V25: Auth real, perfiles desde PostgreSQL, altas controladas de Tutor/Jugador adulto y alta de menores mediante RPC.

## Seguridad

El frontend usa únicamente la Publishable key de Supabase. RLS sigue protegiendo las tablas. No se incluyen claves `service_role`, secretos JWT ni contraseña de PostgreSQL.

## Desarrollo

El Service Worker continúa desactivado durante la fase de desarrollo rápido. `version.json` se usa para comprobar la versión publicada.
