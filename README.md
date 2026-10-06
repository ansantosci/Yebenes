## V85 — Correcciones RRMM y asignaciones de entrenadores (06/10/2026)

Cambios principales:
- Corrige el cálculo estimado del RRMM a +18 meses sin perder un día por conversión UTC.
- Elimina de la interfaz de Entrenadores los campos legacy y Observaciones.
- Corrige la validación del correo en edición: usa el correo de Persona ya cargado en el entrenador.
- Mejora el filtro Jugador/Entrenador: Perfil jugador / También es jugador / No es jugador.
- Detecta en frontend un entrenador principal existente y ofrece sustitución controlada.
- Envía al backend la decisión de sustitución para cerrar la etapa anterior con histórico.
- Mantiene los datos legacy internamente solo para compatibilidad durante la transición.

Migración asociada: `033_v85_principal_unico_y_correcciones.sql`.
