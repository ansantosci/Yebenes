## V86 — Hotfix guardado de entrenador existente (06/10/2026)

V86 es una release frontend-only y deliberadamente pequena.

Corrige el error detectado en V85 al guardar un entrenador existente desde perfil Club:
`Cannot read properties of undefined (reading 'auth_user_id')`.

Causa: `saveRemoteCoach()` asumía que la Persona estaba cargada en `dbPersons`. En perfil Club esa colección no siempre está disponible aunque la ficha del entrenador ya contenga la identidad y el `auth_user_id`.

Corrección: para decidir si es necesario invitar al entrenador se reutiliza primero `person?.auth_user_id` y, como respaldo, el `userId` ya cargado en el entrenador (`old?.userId`). De este modo editar un entrenador existente no intenta leer una Persona inexistente ni dispara una invitación innecesaria.

No cambia SQL, Edge Functions ni modelo de datos. Se mantiene íntegramente V85.
