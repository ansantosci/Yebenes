# C.D. Los Yébenes San Bruno — Gestión de inscripciones y fichas

Prototipo web de gestión del club para la temporada 2026/2027. Frontend estático publicado en GitHub Pages y backend en Supabase (Auth, PostgreSQL, RLS, Storage y Edge Functions).

**Versión actual: V34 — 25/09/2026**

## Estado funcional actual

- Autenticación real con Supabase Auth y perfiles/roles acumulables.
- Roles: Administrador, Club, Entrenador, Tutor/Familia y Jugador.
- Alta de Tutor/Familia y de Jugador adulto; alta de menores por su tutor.
- Modelo con UUID, temporadas, categorías, equipos, jugadores, representaciones e inscripciones.
- 23 equipos reales 2026/2027 cargados en PostgreSQL.
- Fichas del club, estados, histórico, devolución a familia, activo/inactivo y asignación a equipo.
- RRMM real: histórico, vigencia, avisos <=90 días, citas, modificación/cancelación y notificaciones.
- Notificaciones de citas mediante cola + Supabase Edge Function + Mailtrap Sandbox en desarrollo.
- Documentación federativa privada en Supabase Storage con checklist por inscripción y revisión Club/Admin.
- Service Worker desactivado durante desarrollo rápido. Debe reactivarse cuando exista una versión estable.

## Trazabilidad de versiones

| Versión | Fecha | BD / backend | Cambios principales |
|---|---|---|---|
| V1 modelo | 24/09/2026 | Modelo de datos V1 | Modelo relacional congelado; adopción de UUID como identificadores. |
| V20 | 24/09/2026 | Supabase Auth/RLS | Primer login real contra Supabase y resolución Persona → Roles. |
| V21 | 25/09/2026 | — | Corrige el error de login por uso de `event.currentTarget` tras un `await`. |
| V22–V24 | 25/09/2026 | Migración 005 | Estructura real desde PostgreSQL; 23 equipos 2026/2027 y modalidad F7/F11. |
| V25–V26 | 25/09/2026 | Migraciones 006–007 | Alta real de Tutor/Jugador adulto y menores. Confirmación y reenvío de email. |
| V27 | 25/09/2026 | Migraciones 008–009 | Fichas reales desde Supabase; revisión, devolución, edición familiar, estados y asignación de equipo. |
| V28–V29 | 25/09/2026 | — | RRMM real; histórico y aviso de vencimiento. V29 corrige cache-busting de recursos. |
| V30 | 25/09/2026 | Migración 010 | Contadores RRMM excluyentes y gestión de citas; cola de notificaciones. |
| V31 | 25/09/2026 | Migración 011 + Edge Function v1 | Modificar/cancelar cita, trazabilidad y primer envío backend a Mailtrap. |
| V32 | 25/09/2026 | Migración 012 + Edge Function v2 | Bloqueo anti-doble clic, notificaciones robustas, cuerpo completo y reintento ante 429. |
| V33 | 25/09/2026 | Migración 013 | Documentación federativa RFFM en Storage privado; checklist y validación/rechazo. |
| **V34** | **25/09/2026** | Sin migración nueva | Mejora UX documental: tarjeta de documento aportado/validado, sustitución bajo demanda, rechazo visible con motivo y acción secundaria para cambiar una validación. README acumulativo reconstruido. |

## V34 — detalle

### Familia / Jugador
- Tras subir un archivo ya no permanece abierto el formulario de carga.
- `Aportado`: tarjeta **Documento aportado · Pendiente de revisión** con `Ver documento` y `Sustituir`.
- `Validado`: tarjeta **Validado por el club**, con acceso al archivo y sustitución deliberada bajo demanda.
- `Rechazado`: el motivo del club se muestra destacado y se ofrece directamente **Aportar documento corregido**.
- El selector de archivo solo aparece cuando realmente es necesario aportar/sustituir un documento.

### Club / Administrador
- El rechazo sigue exigiendo motivo obligatorio.
- Un requisito validado ya no muestra `Rechazar` como acción principal.
- Se muestra `Cambiar validación`; exige motivo y confirmación antes de pasar un requisito validado a rechazado.
- El motivo queda visible en la ficha para facilitar la corrección por la familia.

## Migraciones aplicadas

- 001–004: esquema base, maestros, seguridad/RLS y roles.
- 005: equipos reales 2026/2027 y modalidad.
- 006: altas controladas de perfiles y menores.
- 007: inscripción del jugador adulto.
- 008: corrección de ambigüedad en `registrar_mi_perfil`.
- 009: actualización segura de menor representado.
- 010: citas RRMM y cola de notificaciones.
- 011: edición/cancelación de citas y trazabilidad.
- 012: robustez/idempotencia de notificaciones RRMM.
- 013: requisitos y documentos federativos + Storage privado.

## Edge Functions

### `procesar-notificaciones` — V2
Procesa `notificaciones_salida` desde backend, usa Mailtrap Sandbox durante desarrollo, actualiza `enviado_at`, intentos y errores y trata los 429 como reintentables.

Secrets de desarrollo:
- `MAILTRAP_API_TOKEN`
- `MAILTRAP_INBOX_ID`

No deben almacenarse secretos en GitHub ni en el frontend.

## Requisitos pendientes / backlog

### P0 antes de producción
- Sustituir Mailtrap por proveedor SMTP de producción con `losyebenessanbruno.es` y SPF/DKIM/DMARC.
- Reactivar y estabilizar Service Worker/PWA cuando el ciclo de releases deje de ser tan frecuente.
- Construir módulo económico: importe de inscripción configurable por equipo+temporada; pago efectivo/Cluber; pago total separado de validación de fraccionamiento Cluber; bloqueo de ficha si no está económicamente habilitada.
- Investigar/acordar con Cluber API/webhook para IDs de deportista/tutor e historial/estado de pagos.

### Funcional
- Completar circuito documental RFFM y reglas por categoría/temporada.
- Gestión de entrenadores reales por equipo, primer/segundo entrenador, vigencia, licencia y curso de delegado.
- Notificar citas RRMM también a entrenadores activos del equipo cuando existan asignaciones reales.
- Recordatorio automático de cita RRMM 48 h antes.
- Configuración de importes y reglas económicas desde perfiles Club/Administrador.
- Excepción económica de Senior A: identificada, todavía no activada; por ahora todos los equipos se tratan igual.

## Seguridad

- Frontend: solo Publishable key de Supabase.
- RLS habilitado sobre datos operativos.
- Documentación federativa en bucket privado con URLs firmadas temporales.
- Secretos y envío de correo únicamente en backend/Edge Functions.
- No exponer `service_role`, JWT secret, contraseña PostgreSQL ni tokens de Mailtrap.
