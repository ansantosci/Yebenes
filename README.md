# Los Yébenes San Bruno — Prototipo web app · V18

Versión de pruebas del área de familias y gestión del C.D. Los Yébenes San Bruno.

## Novedades V18

- El alta de una cuenta **Tutor/Familia exige DNI/NIE propio del tutor**.
- El DNI/NIE se guarda en la persona del tutor y se reutiliza automáticamente al dar de alta menores.
- En el alta de jugador se muestra el **DNI/NIE del tutor** recuperado de la cuenta.
- El **DNI/NIE del menor es opcional**.
- Si el menor no tiene documento propio, la inscripción conserva una referencia y una instantánea del documento del tutor utilizado.
- El DNI del tutor **no interviene en la deduplicación de jugadores**, por lo que varios hermanos pueden compartir legítimamente el mismo documento de representante.
- Si una cuenta antigua de tutor no tiene DNI/NIE, se solicita una sola vez al realizar la siguiente alta y queda guardado para futuras inscripciones.
- Se mantiene desactivado el Service Worker durante la fase de desarrollo para evitar versiones obsoletas en caché.

## Publicación

GitHub Pages debe desplegar la rama `main` desde `/(root)`.
