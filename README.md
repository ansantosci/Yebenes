# CD Los Yébenes San Bruno - Prototipo web app V27

## Novedad principal

V27 mejora el flujo de confirmación de correo de Supabase Auth.

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


## V27
- Fichas del club leídas desde Supabase/PostgreSQL.
- Apertura de ficha real, cambio de estado, devolución a familia y asignación de equipo.
- Activación/inactivación real de jugadores.
- Progreso familiar calculado con datos reales.
- Edición de menores devueltos mediante RPC segura (requiere migración 009).


## V29
- RRMM real contra Supabase.
- Histórico de reconocimientos médicos por jugador.
- Aviso de vencimiento en 90 días.
- Propuesta automática de caducidad a dos años, editable según la fecha oficial RFFM.
- Bloqueo de 'Listo para federar' y 'Ficha tramitada' si no hay equipo o RRMM vigente.
- Pago de inscripción/Cluber queda identificado como requisito P0 futuro antes de producción.


## V29
- Corrige el cache-busting de `app.js` y `styles.css`: V28 seguía solicitando `app.js?v=27`.
- RRMM usa ahora el código real de V28 al cargarse correctamente el JavaScript actualizado.
- No se modifica el modelo de datos ni Supabase.

## V31
- RRMM con contadores excluyentes: Vigente >90 días, Vence <=90 días, Vencido/sin RRMM.
- Gestión de citas RRMM con fecha/hora, lugar, dirección e indicaciones.
- La familia/jugador ve la cita en su ficha.
- Se prepara una cola de notificaciones para tutor/jugador y entrenadores activos del equipo.
- Requiere migración 010. El envío efectivo de emails desde la cola requiere backend/Edge Function; no se exponen secretos SMTP en el navegador.
