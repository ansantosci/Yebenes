# Los Yébenes San Bruno - Prototipo web app V8

Versión de demostración para pruebas internas. No usar datos personales reales.

## Novedades V8
- Equipos concretos por categoría (por ejemplo, Prebenjamín A / B).
- Nuevo rol interno **Entrenador**, creado exclusivamente por un administrador.
- Al crear un entrenador se asigna uno o varios equipos y se registran función, licencia y curso de delegado.
- El entrenador solo puede consultar los jugadores asignados a sus equipos.
- Los jugadores nacen desde el alta realizada por la familia sin equipo asignado.
- El club valida primero la inscripción inicial y, a partir de ese estado, puede asignar al jugador a un equipo.
- Flujo: inscripción familiar -> revisión inicial -> asignación de equipo -> reconocimiento médico -> listo para federar -> ficha tramitada.

### Usuarios demo
- Administrador: `admin@yebenes.demo` / `demo123`
- Club: `club@yebenes.demo` / `demo123`
- Entrenador: `entrenador@yebenes.demo` / `demo123`
- Familia: `familia@yebenes.demo` / `demo123`

El prototipo usa `localStorage`; todavía no existe sincronización real entre dispositivos.
