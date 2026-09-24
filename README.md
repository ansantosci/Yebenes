# Los Yébenes San Bruno – Prototipo web app V7

Versión de pruebas para la temporada 2026/2027.

## Novedades V7
- Control de reconocimientos médicos por jugador.
- Fecha del último reconocimiento y fecha de validez/próxima renovación.
- Aviso automático de reconocimientos que vencen en los próximos 90 días.
- Filtros por en vigor, próximos a vencer, vencidos y sin datos.
- Inventario de entrenadores por categoría.
- Rol de primer o segundo entrenador.
- Control de licencia de entrenador y nivel/tipo.
- Control de curso de delegado.
- Filtros por categoría, rol, licencia y curso de delegado.
- Alta y edición de entrenadores desde el área del club.

## Importante
Este entorno sigue usando almacenamiento local del navegador (localStorage). No debe utilizarse todavía con datos reales ni contraseñas reales. En la versión de producción se conectará a autenticación, base de datos y almacenamiento seguro.

## Reconocimientos médicos
La app almacena explícitamente la fecha de validez/próxima renovación que figure en el control federativo del jugador y calcula sobre esa fecha el aviso de 90 días. Esto evita asumir una periodicidad fija mientras se valida la regla exacta aplicable en RFFM para cada supuesto.
