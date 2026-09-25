# CD Los Yébenes San Bruno - Prototipo web app V23

## Novedad principal

V23 conecta por primera vez la aplicación de pruebas con **Supabase Auth + PostgreSQL + RLS**.

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


## Correccion V23
- Corrige el login asíncrono en Chrome: el formulario se conserva antes del `await`, evitando `Cannot read properties of null (reading reset)`.


## V23
- La pestaña Estructura lee temporadas, categorías y equipos reales desde Supabase/PostgreSQL.
- Se muestran los 23 equipos de la temporada 2026/2027 cargados en la migración 005.
- La edición de estructura queda temporalmente deshabilitada en la UI mientras se completa el CRUD remoto.
- El resto de datos deportivos continúa temporalmente en localStorage.


## Corrección V23

Restaura las funciones de gestión de **Usuarios** y **Personas** que faltaban en V22 y provocaban el error `renderClubUsers is not defined` al iniciar sesión como Administrador. No cambia el modelo de datos ni la integración con Supabase.
