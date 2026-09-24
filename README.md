# Los Yébenes San Bruno - Prototipo web app V12

Versión funcional de demostración para la temporada 2026/2027.

## Novedades V12

- Una misma cuenta/persona puede acumular varios perfiles: **Tutor/Familia, Jugador, Entrenador, Club y Administrador**.
- Selector de perfil al iniciar sesión cuando una persona tiene más de un perfil, y cambio posterior sin cerrar sesión.
- Autorregistro diferenciado:
  - un adulto puede registrarse como **Jugador** para inscribirse a sí mismo;
  - un menor no puede autorregistrarse y debe ser inscrito por un **Tutor/Familia**.
- Los perfiles internos **Entrenador, Club y Administrador** solo los concede un Administrador.
- Si un correo ya existe, el Administrador añade el nuevo perfil a la misma cuenta en lugar de crear una cuenta duplicada.
- Un Tutor o Jugador puede pasar a ser Entrenador o miembro del Club conservando la misma cuenta.
- Se mantiene la representación legal, transición a autorrepresentación a los 18 años, equipos, RRMM, temporadas, auditoría e históricos de V11.
- Migración automática de los datos locales de V11 al modelo V12 para conservar las pruebas realizadas en el mismo navegador.

### Usuarios demo

- Administrador: `admin@yebenes.demo` / `demo123`
- Club: `club@yebenes.demo` / `demo123`
- Entrenador: `entrenador@yebenes.demo` / `demo123`
- Tutor/Familia: `familia@yebenes.demo` / `demo123`
- Jugador: `jugador@yebenes.demo` / `demo123`
- Multirol: `multi@yebenes.demo` / `demo123`

> Este entorno usa `localStorage` y credenciales de demostración. No debe utilizarse con datos personales reales.
