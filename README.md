# CD Los Yébenes San Bruno - Prototipo web app V20

## Novedad principal

V20 conecta por primera vez la aplicación de pruebas con **Supabase Auth + PostgreSQL + RLS**.

- Inicio de sesión real mediante email/contraseña de Supabase Auth.
- La identidad se resuelve desde `public.personas`.
- Los perfiles activos se obtienen desde `public.persona_roles` + `public.roles`.
- Una persona puede seguir teniendo varios perfiles y cambiar entre ellos.
- El logout cierra la sesión real de Supabase.
- La operación deportiva (jugadores, equipos, fichas, etc.) continúa temporalmente en `localStorage`; se migrará por fases a PostgreSQL.
- El autorregistro real de nuevas familias/jugadores se deja temporalmente deshabilitado hasta implementar el flujo seguro de alta.

## Seguridad

El frontend utiliza únicamente la **Publishable key** de Supabase. No contiene `service_role`, secret keys ni contraseña PostgreSQL. Las tablas están protegidas mediante RLS.

## Desarrollo

El Service Worker continúa desactivado durante la fase de desarrollo rápido. `version.json` mantiene la comprobación de versiones desplegadas.
