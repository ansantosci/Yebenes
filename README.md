## V66 — Corrección visual del perfil Tutor/Familia (29/09/2026)

- Corrige el directorio de Personas para mostrar el perfil `tutor` dentro de **Perfiles de acceso**.
- La etiqueta visible se presenta como **Tutor/Familia**.
- No modifica Supabase, la migración 021 ni las Edge Functions de V65.

## V65 — Identidad multirrol, invitaciones, mayoría de edad y entrenador menor (29/09/2026)

- El Administrador crea únicamente perfiles internos: Administrador, Club y Entrenador.
- Las cuentas internas se crean/vinculan mediante invitación por correo; el usuario establece su propia contraseña.
- Tutor/Familia y Jugador se adquieren por autoregistro y reutilizan la Persona existente cuando coincide el correo.
- La mayoría de edad finaliza la representación ordinaria, activa el perfil Jugador y genera avisos al jugador y al tutor.
- El alta/edición del menor permite guardar un correo propio para preparar esa transición.
- Un Entrenador menor necesita representación activa como jugador y una autorización específica de su tutor antes de recibir asignaciones de equipo.
- Se añade la gestión de esa autorización desde el área Tutor/Familia.
- Migración asociada: `021_v65_identidad_mayoria_y_entrenadores_menores.sql`.
- Edge Function asociada: `gestionar-acceso` V2 (`gestionar-acceso-v2-index.ts`).

## V64 — Corrección de versionado visible (29/09/2026)

- Corrige la etiqueta de la pantalla de inicio, que seguía mostrando V62.
- Alinea `index.html`, `app.js` y `version.json` en V64.

## V63 — Alta de cuentas internas desde Administrador (29/09/2026)

### Objetivo
La aplicación ya puede crear cuentas de Supabase Auth para Personas internas sin entrar manualmente en el Dashboard de Supabase. El flujo queda centrado en **Persona → perfiles → cuenta de acceso**.

### Flujo de alta
1. Administrador crea o abre una Persona.
2. Asigna al menos un perfil de acceso (por ejemplo, **Club**).
3. En **Acceso y roles → Cuenta de acceso** pulsa **Crear cuenta con contraseña temporal**.
4. La Edge Function `gestionar-acceso` crea el usuario Auth, confirma el correo internamente, vincula `personas.auth_user_id` y devuelve una contraseña aleatoria de 14 caracteres que solo se muestra una vez al administrador.
5. En el primer login, `app_metadata.must_change_password=true` obliga a cambiar la contraseña antes de cargar cualquier perfil de la aplicación.
6. Después, cualquier usuario puede volver a cambiar su contraseña desde **Perfil**.

### Seguridad
- La creación de usuarios se ejecuta exclusivamente en una **Supabase Edge Function**; la clave secreta/service-role nunca se expone en el navegador.
- La función valida que quien solicita el alta tenga un rol `administrador` activo.
- La obligación de cambio se guarda en `app_metadata`, que no puede modificar directamente el usuario desde el cliente.
- La función también gestiona el cambio de contraseña propio y elimina `must_change_password` una vez realizado.
- No se almacena la contraseña temporal en tablas ni en localStorage.

### Edge Function nueva
Desplegar `supabase/functions/gestionar-acceso/index.ts` con nombre **gestionar-acceso**. No necesita secretos personalizados: utiliza las variables de Supabase disponibles en Edge Functions (`SUPABASE_URL`, `SUPABASE_SECRET_KEYS`/`SUPABASE_SERVICE_ROLE_KEY` y `SUPABASE_PUBLISHABLE_KEYS`/`SUPABASE_ANON_KEY`).

### Base de datos
- No requiere migración SQL nueva.
- Se apoya en el modelo de Personas y roles de la migración 021.

## V61 — Administración integral de Personas (29/09/2026)

## V62 — Corrección de carga de perfil tras consolidar Usuarios en Personas

- Corrige una regresión de V61 que impedía iniciar sesión con `Cannot read properties of null (reading 'style')`.
- La causa era una referencia JavaScript residual a `usersNavButton`, eliminado del HTML al consolidar la gestión de Usuarios dentro de Personas.
- La inicialización de navegación y perfil ahora trata los controles opcionales de forma defensiva para que la ausencia de una vista no bloquee el login.
- Ajusta la rejilla de navegación de Administrador a las 6 opciones realmente visibles: Fichas, RRMM, Entrenadores, Estructura, Personas y Perfil.
- No requiere cambios de base de datos; mantiene íntegramente el modelo de Personas/roles introducido en V61 y la migración 021.


### Correcciones funcionales
- El perfil **Entrenador** carga únicamente jugadores con una asignación deportiva activa a alguno de sus equipos activos. Una asignación a Chupetines ya no arrastra jugadores de otras categorías/equipos.
- La vista Entrenador oculta por completo información económica: KPI de pago pendiente, columna Pago, pestaña Economía y requisito económico del progreso de ficha.
- Para Entrenador, el progreso operativo se calcula con 4 requisitos visibles: datos, equipo, documentación RFFM y RRMM. El pago continúa existiendo y bloqueando la tramitación para Club/Administrador, pero no se expone al técnico.
- Documentación y RRMM quedan en modo de **consulta operativa** para Entrenador. Se oculta la entrada de gestión RRMM desde la ficha y las acciones de validación documental siguen reservadas a Club/Administrador.
- Se ocultan al Entrenador los bloques de tramitación/devolución a familia y las acciones de activación/inactivación de jugador.
- La columna **Datos** del listado usa ahora el mismo criterio que la ficha del jugador (`remoteDataValidated`), eliminando discrepancias como “Pendiente” en tabla y “Completo” en detalle.
- Al entrar en la vista **Entrenadores** como Administrador/Club se recarga el listado directamente desde Supabase antes de renderizar, evitando información obsoleta tras cambios de roles/asignaciones.

### Modelo y base de datos
- No requiere migración SQL nueva.
- Se apoya en el saneamiento Persona/Entrenador de las migraciones 018–020.
- La asignación real del entrenador se toma exclusivamente de `asignaciones_entrenador_equipo`; no se infieren equipos por categoría ni por datos de la interfaz.

## V59 - 2026-09-28

### Entrenadores reales en Supabase
- La pantalla **Entrenadores** deja de depender del inventario local/demo cuando la sesión procede de Supabase.
- Alta y edición de entrenador vinculada a una `Persona` real: nombre, apellidos, email y teléfono.
- Datos federativos/operativos: tipo y número de licencia, curso de delegado, observaciones y activo/inactivo.
- Un entrenador puede tener una o varias asignaciones a equipos con **Primer entrenador / Segundo entrenador / Delegado**, fecha de inicio y fecha fin.
- Las reasignaciones conservan histórico en `asignaciones_entrenador_equipo`; las ediciones del mismo día no generan duplicados innecesarios.
- Si la Persona ya dispone de cuenta Supabase Auth, la migración garantiza el rol `entrenador`, permitiendo que el control de acceso existente limite su vista a jugadores de sus equipos.
- Los contadores de entrenadores de **Estructura** pasan a calcularse con las asignaciones reales cargadas de PostgreSQL.
- La cola de citas RRMM ya existente utiliza estas asignaciones reales, por lo que los técnicos con email reciben las notificaciones de jugadores de sus equipos.
- Modal de entrenador revisado para móvil: campos y asignaciones se apilan y los botones mantienen tamaño táctil.

### Base de datos
- Requiere **migración 017 — Entrenadores reales**.
- Añade metadatos federativos a `entrenadores`, función a `asignaciones_entrenador_equipo` y RPC seguras `guardar_entrenador` / `guardar_asignaciones_entrenador`.

## V57 - 2026-09-28

### Corrección crítica de sustitución documental
- Corrige el error `subtipo is not defined` al sustituir una fotografía o documento desde la vista Familia.
- La causa era una referencia incorrecta en la actualización optimista del documento activo: se usaba `subtipo` en lugar de la variable real `subtype`.
- Tras una sustitución correcta, la nueva versión se muestra inmediatamente, se cierra el modo de sustitución y **Ver documento** apunta al archivo activo más reciente.
- La versión anterior se conserva como sustituida/histórica.
- Sin cambios de base de datos ni migraciones.

## V56 - 2026-09-28

### Sincronización tras sustituir documentación
- Tras subir una nueva versión, la ficha documental se refresca con el documento activo más reciente.
- Se limpia el selector de archivo y se cierra automáticamente el modo **Sustituir documento**.
- **Ver documento** queda asociado a la versión activa, manteniendo las anteriores en histórico.
- Se evita reabrir con `showModal()` un diálogo documental ya abierto durante el refresco.
- Sin cambios de base de datos ni migraciones.

## V55 - 2026-09-28

### Documentación familiar responsive y navegación simplificada
- Corrige los formularios de subida de documentación para impedir solapamientos entre selector de archivo, nombre del fichero y botón **Subir**.
- En móvil/tablet, `Tipo de documento`, selector de archivo y botón se apilan en una sola columna; en escritorio solo comparten fila cuando hay ancho suficiente.
- Los botones **Ya he realizado la autorización en RFFM** y **Ya he realizado la firma en RFFM** pasan a ancho disponible, permiten salto de línea y mantienen tamaño táctil cómodo.
- Los nombres de archivo largos ya no invaden botones ni otras columnas.
- Se elimina **Jugadores** del menú inferior de Familia porque actualmente duplicaba exactamente el contenido de **Inicio**. El menú queda en **Inicio | Perfil**.
- La ficha de cada jugador sigue siendo accesible desde Inicio y conserva sus pestañas internas `Resumen | Datos | Documentos | RRMM | Inscripción`.
- Sin cambios de base de datos ni migraciones.

## V53 - 2026-09-28

### Simplificación de navegación en Familia
- Se elimina **Documentos** del menú inferior de Familia para evitar una navegación redundante.
- El menú inferior queda en **Inicio | Jugadores | Perfil**, más limpio y usable en móvil.
- La documentación se gestiona únicamente desde **Jugadores → ficha del jugador → Documentos**, manteniendo el contexto del jugador.
- Se retira de la interfaz la antigua vista global de documentación familiar; el gestor documental de la ficha permanece operativo.
- La barra inferior se adapta a tres opciones y conserva el comportamiento responsive.
- Versionado visible e interno alineado a V53.
- Sin cambios de base de datos ni migraciones.


## V52 - 2026-09-28

### Corrección crítica: acceso a documentación de Familia
- Restaurado en `index.html` el diálogo `documentModal`, que se había eliminado accidentalmente durante el rediseño por pestañas de V43.
- Esta era la causa raíz por la que **Gestionar documentación** y **Abrir documentación** no hacían nada en Chrome ni Safari: el JavaScript intentaba escribir en elementos del gestor documental que ya no existían en el DOM.
- Se mantiene una única vista documental compartida desde la ficha del jugador y desde el menú global **Documentos**.
- Añadidas comprobaciones defensivas: si el panel documental faltase en una versión futura, se mostrará un error explícito en lugar de fallar silenciosamente.
- Sin cambios de base de datos.

# V51 — Corrección de acceso a documentación de Familia

## Cambios V51
- Corrige los botones **Gestionar documentación** y **Abrir documentación** de la vista Familia.
- El acceso al gestor documental se enlaza mediante delegación global temprana, por lo que ya no depende de que terminen de inicializarse otros controles de la aplicación.
- Se añade una salvaguarda directa en ambos botones para soportar rerenders dinámicos de la ficha y del listado global de Documentos.
- Se mantiene la simplificación introducida en V50: la vista global **Documentos** no duplica la ficha completa del jugador.
- Sin cambios de esquema ni migraciones SQL.

# C.D. Los Yébenes San Bruno — Gestión de inscripciones y fichas
## V49 - 2026-09-28

- La pestaña **Economía mantiene una alerta mientras la inscripción no esté abonada al 100 %**, aunque exista fraccionamiento Cluber validado.
- La alerta económica es **roja** cuando la situación económica bloquea la tramitación de la ficha.
- La alerta económica es **ámbar** cuando todavía queda saldo pendiente pero el fraccionamiento/domiciliación Cluber ha sido validado y, por tanto, la ficha está habilitada para tramitarse.
- La alerta desaparece únicamente cuando el pago está completado al 100 % o el equipo está configurado como pago no requerido.
- Se elimina de la ficha individual del jugador el bloque **Conciliación Cluber**. La conciliación/importación será un proceso masivo de backoffice para Club/Administrador y se implementará más adelante como opción independiente de menú.
- Se mantiene en la ficha individual la información necesaria para cada jugador: IDs Cluber, estado económico, validación/revocación de fraccionamiento y histórico de pagos.
- El registro manual continúa limitado a **Efectivo**. El modelo de datos conserva otros métodos para futuras activaciones sin migraciones destructivas.
- Sin cambios de base de datos.

## V44 — Corrección de maquetación de la ficha por pestañas

- Corrige el desbordamiento horizontal de la ficha de jugador en Club/Administrador introducido en V43.
- El diálogo de la ficha puede crecer hasta 980 px en escritorio y se adapta al ancho útil de la ventana.
- El contenido interno usa el ancho real del diálogo, evitando que paneles, cabecera y pestañas queden desplazados o recortados.
- Las pestañas mantienen desplazamiento horizontal propio cuando no caben, sin desplazar el contenido completo de la ficha.
- Mejora adicional de comportamiento responsive en pantallas estrechas.
- Sin cambios de base de datos ni migraciones.


Prototipo web de gestión del club para la temporada 2026/2027. Frontend estático publicado en GitHub Pages y backend en Supabase (Auth, PostgreSQL, RLS, Storage y Edge Functions).

**Versión actual: V61 — 29/09/2026**

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

### V49 — 28/09/2026

- Corrige la ficha de **Estructura → Equipo**: vuelven a funcionar **Guardar equipo**, **Cancelar** y la **X** de cierre.
- Causa raíz: el JavaScript se detenía al intentar enlazar controles legacy de alta de usuarios de club que ya no existen en el HTML actual, antes de registrar los eventos del modal de equipo.
- Los listeners legacy pasan a inicializarse de forma defensiva y el propio `openTeamEdit()` registra además los controles críticos del modal de equipo como salvaguarda.
- Sin cambios de base de datos ni migraciones.


| Versión | Fecha | BD / backend | Cambios principales |
|---|---|---|---|
| V60 | 29/09/2026 | Sin migración | Perfil Entrenador restringido a sus equipos, sin Economía, consultas operativas y coherencia Datos/listado. |
| V61 | 29/09/2026 | 021 | Administración integral de Personas, perfiles de acceso, baja lógica, vínculo Auth y relaciones derivadas. |
| V59 | 28/09/2026 | Migración 017 | Entrenadores reales, asignaciones por equipo, licencia/curso delegado, contadores y notificaciones RRMM. |
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
| **V35** | **25/09/2026** | Migración 014 | Bloqueo de documentos validados, solicitud de nueva versión por Club/Admin, retorno automático a pendiente al aportar corrección y nuevo histórico documental. |
| **V36** | **25/09/2026** | Migración 015 | Progreso documental real y declaración por Familia/Jugador de autorización/firma RFFM realizada, pendiente de verificación por el club. |
| **V37** | **25/09/2026** | Sin migración | KPIs clicables como filtros rápidos en Fichas y RRMM. |
| **V38** | **28/09/2026** | Sin migración | El RRMM vigente pasa a formar parte explícita de la ficha y del cálculo de preparación; nuevo progreso integral de requisitos y bloqueo de Listo para federar. |
| **V39** | **28/09/2026** | Migración 016 | Módulo económico por equipo/temporada, pagos, Cluber, fraccionamiento validado y pago como quinto requisito bloqueante de la ficha. |
| **V40** | **28/09/2026** | Sin migración | Estructura unificada por equipo: datos deportivos y económicos en un único listado/ficha. |
| **V41** | **28/09/2026** | Sin migración | Ordenación de Estructura por categoría de menor a mayor edad: Chupetín, Prebenjamín, Benjamín, Alevín, Infantil, Cadete, Juvenil y Senior; dentro de cada categoría, orden natural por nombre de equipo. |
| **V42** | **28/09/2026** | Sin migración | Corrige la apertura de Gestión de pago/Cluber desde la ficha del jugador: evita diálogos modales anidados, permite registrar cobros parciales/totales y vuelve a la ficha al cerrar Economía. |
| **V43** | **28/09/2026** | Sin migración | Ficha de jugador por pestañas con alertas contextuales; Economía integrada en la ficha. |
| **V44** | **28/09/2026** | Sin migración | Corrige maquetación y desbordamientos de la ficha por pestañas. |
| **V45** | **28/09/2026** | Sin migración | Consolidación responsive/mobile-first de fichas y controles táctiles. |
| **V46** | **28/09/2026** | Sin migración | Corrige alertas de pestañas; Datos alerta solo si faltan datos validados o equipo. |
| **V47** | **28/09/2026** | Sin migración | Cobro manual solo en efectivo; Cluber reservado a conciliación/importación futura; parametrización de medios de pago. |
| **V48** | **28/09/2026** | Sin migración | Alerta económica persiste hasta pago 100 %; ámbar si el fraccionamiento Cluber habilita la ficha con saldo pendiente; conciliación Cluber retirada de la ficha individual y reservada a backoffice masivo futuro. |

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
- 014: bloqueo de documentos validados, solicitud de nueva versión e histórico de requisitos.
- 015: declaración de autorización/firma RFFM por familia/jugador y progreso documental.
- 016: configuración económica por equipo/temporada, pagos, situación económica e IDs Cluber.

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
- Investigar/acordar con Cluber API/webhook para automatizar IDs de deportista/tutor, historial de pagos, estado de cargos y validación de fraccionamientos. La V39 deja preparado el modelo para sustituir la validación manual por integración automática.

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

---

## V35 — 25/09/2026 — Migración 014

### Documentación federativa: bloqueo tras validación
- Un documento **validado por Club/Administrador queda bloqueado para Familia/Jugador**.
- La familia puede consultar el archivo validado, pero ya no puede sustituirlo unilateralmente.
- Club/Administrador dispone de **Solicitar nueva versión**, con motivo obligatorio.
- Mientras existe una solicitud de nueva versión, el documento validado anterior se conserva y sigue siendo consultable como última versión aceptada.
- Cuando la familia aporta la nueva versión, el requisito pasa automáticamente a **Aportado · pendiente de revisión**.
- Un documento rechazado que se corrige también vuelve automáticamente a **Aportado · pendiente de revisión**; el rechazo anterior deja de ser el estado vigente.
- Los documentos pendientes de revisión pueden sustituirse por la familia antes de que el club los valide.
- Un requisito rechazado no puede ser validado de nuevo sin que exista una nueva versión aportada.

### Trazabilidad
- Se crea `historial_requisitos_federativos` para conservar las transiciones principales: aportación, corrección, validación, rechazo y solicitud/aportación de nueva versión.
- La versión validada anterior no se marca como sustituida hasta que se aporta realmente un nuevo archivo.

### UX
- Familia: documento validado muestra solo `Ver documento` y la indicación de que está bloqueado.
- Familia: solicitud de nueva versión muestra el motivo del club, permite ver la versión validada anterior y aportar el nuevo archivo.
- Administrador/Club: documentos validados con archivo muestran `Solicitar nueva versión`; los rechazados quedan a la espera de corrección.

### Base de datos
- **Migración 014:** `014_documentos_validados_bloqueados.sql`.

---

## V36 — 25/09/2026 — Migración 015

### Progreso documental RFFM
- Se incorpora un indicador gráfico de porcentaje de documentación completada.
- El porcentaje se calcula **solo con requisitos obligatorios validados por el club**; un documento meramente aportado o un paso comunicado por la familia todavía no suma como completado.
- Se muestra el porcentaje junto con el detalle `X de Y requisitos validados` en:
  - resumen de Documentos de Familia/Jugador;
  - modal de gestión documental;
  - ficha del Club/Administrador;
  - listado de Fichas.
- La documentación se considera completa únicamente al alcanzar el 100% de requisitos obligatorios validados.

### Autorización del tutor y firma online RFFM
- Se mantiene el criterio de no duplicar en la aplicación procesos de firma que se realizan en el circuito oficial de la RFFM.
- Para los requisitos sin archivo (`autorizacion_tutor` y `firma_rffm`), Familia/Jugador puede comunicar: **“Ya lo he realizado en RFFM”**.
- Esa comunicación cambia el requisito a **Comunicado · pendiente de verificación**; no equivale a una validación automática.
- Club/Administrador dispone entonces de:
  - **Verificar y validar**;
  - **No verificado**, con motivo obligatorio.
- Si el club no puede verificarlo, Familia/Jugador ve el motivo y puede comunicar de nuevo que el paso ha sido subsanado/realizado.
- Los requisitos ya validados permanecen bloqueados para Familia/Jugador y solo Club/Administrador puede cambiar su validación.

### Seguridad y trazabilidad
- La transición de “realizado en RFFM” se ejecuta mediante RPC `declarar_requisito_rffm_realizado` con `SECURITY DEFINER` y comprobación de representación activa o autorrepresentación.
- El backend impide que Club/Administrador valide un requisito externo si Familia/Jugador no lo ha comunicado previamente como realizado.
- Cada comunicación queda registrada en `historial_requisitos_federativos` con usuario y fecha.

### Base de datos
- **Migración 015:** `015_declaracion_familia_rffm_y_progreso.sql`.
- Nuevo estado de requisito: `declarado_realizado`.
- Nuevos campos:
  - `declarado_realizado_at`;
  - `declarado_realizado_por`.
- Nueva función:
  - `declarar_requisito_rffm_realizado(uuid)`.

### Pendiente relacionado
- Si la RFFM habilita en el futuro una API/webhook para consultar autorización/firma de licencia, sustituir la verificación manual por consulta automática manteniendo el mismo modelo de estados.


---

## V37 — 25/09/2026 — Sin migración

### Filtros rápidos desde indicadores KPI
- Las tarjetas numéricas de **Fichas** pasan a ser filtros rápidos clicables: Jugadores, Completos, Documentos pendientes, Por revisar, RRMM ≤90 días y Mayoría de edad ≤30 días.
- Las tarjetas de **RRMM** también filtran el listado: Jugadores, Vigente >90 días, Vence ≤90 días y Vencidos/sin RRMM.
- El filtro rápido se combina con búsqueda, categoría, activo/inactivo y estado existentes.
- La tarjeta activa queda resaltada y se muestra una etiqueta de filtro sobre la tabla.
- Pulsar de nuevo la tarjeta activa, la tarjeta `Jugadores` o la `×` de la etiqueta elimina el filtro rápido.
- Se añade soporte de teclado (Enter/Espacio) para las tarjetas KPI.

### Base de datos
- V37 no requiere migración.


---

## V38 — 28/09/2026 — Sin migración

### Reconocimiento médico integrado en la ficha
- La ficha del Club/Administrador muestra de forma explícita el estado del RRMM y su fecha de validez.
- Un RRMM `Vigente >90 días` se muestra en verde.
- Un RRMM que `Vence <=90 días` se muestra en ámbar pero sigue siendo válido para tramitar.
- `Vencido` o `Sin RRMM` se muestran en rojo y bloquean `Listo para federar`.
- Familia/Jugador ve también el estado RRMM dentro del checklist de su ficha.

### Preparación integral de la ficha
Se incorpora un bloque **Preparación para tramitar ficha** con porcentaje y cuatro requisitos actualmente implantados:
1. Datos personales validados por el club.
2. Equipo asignado.
3. Documentación RFFM al 100 %.
4. Reconocimiento médico vigente.

- El indicador muestra `X de 4 requisitos cumplidos` y una barra de progreso.
- El contador superior **Completos** pasa a contar jugadores que cumplen realmente los cuatro requisitos, no solo un estado manual del workflow.
- El filtro rápido `Completos` utiliza el mismo criterio.
- `Listo para federar` y `Ficha tramitada` quedan bloqueados si falta cualquiera de esos requisitos.
- El pago de inscripción queda señalado como futuro quinto requisito cuando se implemente el módulo económico/Cluber.

### Base de datos
- V38 no requiere migración. Usa los datos ya existentes de inscripciones, asignaciones, requisitos documentales y reconocimientos médicos.


---

## V39 — 28/09/2026 — Migración 016

### Configuración económica por equipo y temporada
- Club y Administrador pueden definir el **importe total de inscripción** para cada equipo de la temporada.
- Se configura si el equipo admite **fraccionamiento mediante Cluber** y si el pago es requisito para tramitar la ficha.
- La configuración queda ligada a `equipo + temporada`, de modo que puede cambiar en temporadas posteriores sin alterar el modelo histórico.
- Por defecto no se activa todavía ninguna excepción: Senior A se trata igual que el resto hasta que se decida lo contrario.

### Situación económica de cada inscripción
- Cada inscripción mantiene importe total, importe cobrado, estado económico y condición **Apto para ficha**.
- Estados operativos: `pendiente`, `parcial`, `pagado` y movimientos anulados/devueltos en histórico.
- El modelo admite históricamente `efectivo`, `clubber` y `otro`; desde V47 la interfaz solo permite registrar manualmente **efectivo**. Los pagos Cluber se reservan a conciliación/importación.
- Un pago solo figura como **Pagado** cuando la suma cobrada alcanza el 100 % del importe de inscripción.

### Fraccionamiento Cluber
- El club puede marcar que ha verificado en Cluber la domiciliación/fraccionamiento de las cuotas.
- Una inscripción con cobro parcial puede quedar **habilitada para tramitar ficha** cuando el fraccionamiento Cluber está validado y el equipo lo admite.
- Se diferencia expresamente `pagado al 100 %` de `habilitado para ficha por fraccionamiento validado`.
- La validación queda fechada y asociada al usuario Club/Administrador que la realizó.

### IDs Cluber
- Se pueden registrar el **ID Cluber de deportista** y el **ID Cluber del tutor**.
- Los IDs se almacenan en una entidad separada para mantenerlos fuera del acceso del perfil Entrenador.
- El modelo queda preparado para una futura API/webhook de Cluber sin necesidad de rediseñar la ficha.

### Motor de preparación federativa
El cálculo de **Preparación para tramitar ficha** pasa de 4 a 5 requisitos:
1. Datos personales validados.
2. Equipo asignado.
3. Documentación RFFM al 100 %.
4. Reconocimiento médico vigente.
5. Inscripción económicamente habilitada.

- `Listo para federar` y `Ficha tramitada` quedan bloqueados si el quinto requisito no está cumplido.
- El contador **Completos** y su filtro rápido utilizan también el nuevo requisito económico.
- Se añade el KPI/filtro rápido **Pago pendiente** en Fichas.

### UX
- La ficha de Club/Administrador incorpora un bloque **Situación económica**.
- Desde la ficha se pueden registrar cobros **en efectivo**, guardar IDs Cluber y validar/revocar el fraccionamiento. Los pagos Cluber no se introducen manualmente desde V47.
- Estructura incorpora una tabla específica para configurar importes y reglas económicas por equipo.
- Familia/Jugador ve el estado económico dentro del checklist de su inscripción.

### Base de datos
- **Migración 016:** `016_economia_inscripcion_clubber.sql`.
- Nuevas tablas:
  - `configuracion_economica_equipo`;
  - `situacion_economica_inscripcion`;
  - `pagos_inscripcion`;
  - `vinculos_clubber`.
- Nuevas RPC principales:
  - `configurar_economia_equipo`;
  - `registrar_pago_inscripcion`;
  - `anular_pago_inscripcion`;
  - `validar_fraccionamiento_clubber`;
  - `actualizar_vinculos_clubber`.

---

## V40 — 28/09/2026 — Sin migración

### Estructura unificada por equipo
- Se elimina de **Estructura** el segundo listado independiente de configuración económica.
- La tabla de equipos pasa a mostrar en una única vista los datos deportivos y económicos de cada equipo.
- Nuevas columnas visibles: importe de inscripción, fraccionamiento Cluber y requisito de pago para ficha, junto con categoría, modalidad, jugadores, entrenadores y estado.
- Cada fila de equipo es navegable/clicable y abre una única ficha de edición.

### Ficha única de equipo
- La ficha reúne **Datos deportivos** y **Configuración económica**.
- Datos deportivos editables por Administrador: nombre, categoría, código, modalidad, género y estado activo/inactivo.
- Datos económicos editables por Club y Administrador: importe de inscripción, admisión de fraccionamiento Cluber, requisito de pago para tramitar ficha y observaciones.
- El perfil Club puede consultar los datos deportivos pero no modificarlos; sí puede gestionar la configuración económica.
- La configuración sigue perteneciendo a `equipo + temporada`, conservando el modelo histórico ya establecido.

### UX
- Se elimina la duplicidad conceptual `Equipos / Economía` dentro de Estructura.
- La fila muestra `Economía pendiente` cuando el equipo está activo pero su configuración económica requerida aún no está completa.
- La edición se realiza desde un único punto, reduciendo navegación y riesgo de inconsistencias.

### Base de datos
- V40 no requiere migración.
- Reutiliza `equipos`, `configuracion_economica_equipo` y la RPC `configurar_economia_equipo` de la migración 016.


---

## V41 — 28/09/2026 — Sin migración

### Ordenación deportiva de Estructura
- El listado único de equipos se ordena por la edad de la categoría, de menor a mayor: **Chupetín → Prebenjamín → Benjamín → Alevín → Infantil → Cadete → Juvenil → Senior**.
- El orden se apoya en el campo maestro `categorias.orden` de PostgreSQL, por lo que no depende del nombre textual de la categoría.
- Dentro de una misma categoría se aplica orden natural por nombre de equipo (`A`, `B`, `C`, etc.).
- El mismo criterio se conserva como fallback en el modo local del prototipo.

### Base de datos
- V41 no requiere migración.
- Reutiliza `categorias.orden`, ya cargado en el Modelo de Datos V1.

## V42 — 28/09/2026 — Sin migración

### Corrección de gestión económica desde la ficha
- Corrige el botón **Gestionar pago / Cluber** de la ficha de Club/Administrador, que podía no abrir el formulario económico.
- La causa era la apertura de un segundo `dialog.showModal()` mientras la ficha del jugador seguía abierta como diálogo modal; el comportamiento no es consistente entre navegadores.
- Al entrar en Economía, V42 cierra temporalmente la ficha del jugador y abre la gestión económica como único modal activo.
- Al cerrar Economía (botón X o tecla Escape) se reabre automáticamente la ficha del mismo jugador.
- Se mantiene el formulario económico; desde V47 el alta manual de cobros queda limitada a efectivo. Se conservan IDs Cluber, referencias, histórico y validación/revocación de fraccionamiento Cluber.
- Si por cualquier motivo el diálogo económico no pudiera abrirse, ahora se informa al usuario en lugar de fallar silenciosamente.

### Versionado
- Se corrige también `window.YEBENES_APP_VERSION`, que había quedado rezagado respecto al número visible de release.
- `index.html`, `app.js`, `version.json`, CSS y JS quedan alineados en **V42**.

### Base de datos
- V42 no requiere nueva migración. Continúa utilizando la **migración 016** para configuración económica, pagos y Cluber.



## V43 · 28/09/2026 · Fichas por pestañas y alertas contextuales

- La ficha de jugador para Club/Administrador se reorganiza en **Resumen, Datos, Documentación, RRMM, Economía e Histórico**.
- Las pestañas muestran alerta roja cuando existe un bloqueo que requiere atención y alerta ámbar para RRMM vigente que vence en <=90 días.
- El resumen de preparación es navegable: pulsar Datos/Equipo, Documentación, RRMM o Pago abre directamente la pestaña correspondiente.
- **Economía queda integrada dentro de la propia ficha**, eliminando el diálogo secundario que provocaba el fallo de `Gestionar pago / Cluber`.
- La ficha de Familia/Jugador adopta el mismo lenguaje visual, simplificado a **Resumen, Datos, Documentos, RRMM e Inscripción**. Las alertas de Familia se reservan a tareas que puede resolver o debe conocer el tutor/jugador; la falta de equipo no se presenta como tarea familiar.
- Se mantiene el patrón global de diseño: **listados = KPIs + filtros + tabla; fichas = pestañas + resumen + alertas contextuales**.
- Sin cambios de base de datos. Se mantiene migración 016 como última migración funcional.


## V45 — 28/09/2026 — Responsive mobile-first y alertas de pestaña corregidas

### Corrección funcional
- La alerta roja de la pestaña **Datos** ya no depende de que exista una asignación de equipo.
- **Datos** solo muestra alerta cuando los datos personales todavía no han sido validados por el club, reutilizando la misma regla que el requisito `Datos personales validados` del motor de preparación federativa.
- La falta de equipo queda representada únicamente en el requisito de equipo correspondiente y no contamina la pestaña Datos.

### Consolidación responsive
- La ficha de jugador de Club/Administrador pasa a comportamiento **mobile-first**.
- En <=720 px ocupa el viewport útil completo, sin scroll horizontal global y con scroll vertical interno.
- Cabecera y botón cerrar permanecen accesibles; la barra de pestañas queda sticky y es desplazable horizontalmente.
- Pestañas y controles tienen altura táctil mínima aproximada de 44 px.
- Resúmenes, requisitos, formularios, acciones y economía se apilan a una sola columna en móvil.
- Botones principales pasan a ancho completo cuando el espacio es reducido.
- Textos largos, históricos y estados pueden envolver sin ensanchar la ficha.
- El mismo criterio de controles táctiles, formularios apilados y ausencia de scroll horizontal se extiende a fichas de Familia y al resto de diálogos.

### Base de datos
- V45 no requiere migración. La última migración funcional sigue siendo la **016**.

## V47 — 28/09/2026 — Política de cobros y Cluber

### Operativa actual
- **Registro manual:** únicamente efectivo.
- **Cluber:** los cobros no se registran manualmente; se incorporarán mediante conciliación de fichero exportado o API cuando esté disponible.
- **Fraccionamiento Cluber:** el Club/Administrador puede seguir validando manualmente que la domiciliación de cuotas está correctamente configurada. Esa validación puede habilitar la ficha aunque el importe total aún no esté cobrado.
- Los pagos Cluber previamente registrados durante pruebas permanecen en el histórico; V47 no altera ni elimina datos existentes.

### Parametrización
`PAYMENT_FEATURES` mantiene separada la política operativa de la estructura de datos:
- `efectivo`: habilitado;
- otros medios manuales: deshabilitados;
- tarjeta: deshabilitada;
- importación Cluber: todavía deshabilitada.

Esto permite activar nuevas formas de cobro en el futuro sin eliminar la estructura económica existente. Si una futura forma de pago requiere un código específico nuevo en PostgreSQL, se realizará entonces la migración correspondiente.

### Compatibilidad técnica
La marca visible se escribe **Cluber**. Los nombres técnicos históricos de la migración 016 (`vinculos_clubber`, `validar_fraccionamiento_clubber`, etc.) no se renombran en V47 para evitar una migración destructiva o innecesaria.

## V50 — Navegación Familia y documentación sin redundancias (28/09/2026)

### Cambios funcionales
- Se corrige el acceso a documentación desde Familia: tanto **Gestionar documentación** en la ficha del jugador como **Abrir documentación** en la vista global abren el mismo gestor documental.
- Se centraliza el evento mediante delegación sobre la vista Familia para evitar botones sin respuesta tras rerenders dinámicos.
- La opción inferior **Documentos** pasa a ser una vista específica: oculta temporalmente el bloque completo de fichas de jugadores y el resumen familiar para evitar mostrar dos veces la misma información.
- En la vista Documentos solo se muestra el listado documental por jugador con progreso y acceso al gestor.
- Al volver a **Inicio** o **Jugadores** se restaura la ficha completa con sus pestañas.
- El hero de Familia adapta título y descripción cuando se entra en Documentos.
- Se mantiene una única fuente de detalle documental (`openDocumentManager`) independientemente del punto de entrada.

### Cambios técnicos
- `APP_VERSION` y `YEBENES_APP_VERSION` pasan a 50.
- Cache-busting de `styles.css` y `app.js` actualizado a `?v=50`.
- `version.json` actualizado a 50.
- No requiere migración SQL.


## V55 — Estado visible de documentos aportados
- La vista Familia distingue de forma robusta entre documento pendiente sin archivo y documento ya aportado pendiente de revisión.
- Tras una subida correcta, se muestra nombre de archivo, estado **Aportado · pendiente de revisión**, botón **Ver documento** y **Sustituir documento**.
- Mientras el club no valide, la familia puede reemplazar el archivo.
- Los documentos validados continúan bloqueados salvo solicitud de nueva versión por el club.
- Se añade una salvaguarda de render: si existe un documento activo para el requisito, la interfaz lo trata como aportado aunque el estado del requisito llegue momentáneamente desfasado.
- Sin cambios de base de datos.


## V56 — Sustitución documental sincronizada (28/09/2026)

### Correcciones funcionales
- Tras sustituir un documento desde Familia, la tarjeta se actualiza inmediatamente con la **nueva versión activa**.
- El modo **Sustituir documento** se cierra automáticamente después de una subida correcta; desaparecen el selector y el botón `Subir`.
- El nombre, tipo y enlace de **Ver documento** pasan a apuntar a la última versión aportada.
- La versión anterior queda únicamente como histórico/sustituida conforme a la función de base de datos existente.
- La subida se refresca primero de forma optimista en pantalla y después se reconcilia con Supabase, evitando estados visuales obsoletos por latencia.
- Se evita volver a ejecutar `showModal()` sobre un diálogo documental que ya está abierto, eliminando una posible interrupción del refresco.
- Los selectores de archivo y subtipo se resuelven dentro del formulario concreto que disparó la acción, evitando tomar controles de otra versión del mismo requisito.

### Base de datos
- V56 no requiere migración SQL. Continúa utilizando la lógica de versionado documental introducida en las migraciones 013 y 014.

## V59 — Persona como origen de Entrenadores

- El alta de entrenadores deja de crear identidades independientes: **Persona → rol Entrenador → datos técnicos → asignaciones**.
- `Entrenadores` queda como vista exclusivamente operativa de técnicos; se elimina el listado duplicado de equipos.
- El número de entrenadores por equipo se consulta en `Estructura`, dentro del listado único de equipos.
- `Personas` usa datos reales de Supabase para Administrador, permite crear una identidad base y asignar/revisar el rol Entrenador.
- Si una Persona ya tiene otros roles o usuario Auth, se reutilizan sin crear duplicados.
- El formulario de Entrenador selecciona una Persona existente y usa la RPC `asignar_rol_entrenador`; los datos de identidad quedan de solo lectura en esta vista.
- Se conservan función por equipo, vigencia, licencia, curso de delegado, estado e histórico de asignaciones.
- No requiere nueva migración: depende de las migraciones 018–020 ya aplicadas.

## V61 - Administración integral de Personas (2026-09-29)

V61 consolida **Persona** como identidad maestra y mueve la administración de usuarios y perfiles a la vista Personas.

### Cambios funcionales
- La tabla Personas muestra identidad, correo, perfiles de acceso, relaciones, cuenta Auth y estado.
- Cada Persona se abre en una ficha con pestañas **Identidad / Acceso y roles / Relaciones**.
- El administrador puede modificar los datos de identidad y realizar una baja lógica (Activo/Inactivo) conservando el histórico.
- Los perfiles **Administrador, Club y Entrenador** se administran con checks.
- **Jugador · acceso propio** solo puede concederse a una Persona adulta. Al activarlo se reutiliza/crea su extensión `jugadores`; no necesita representación ordinaria para gestionarse a sí misma.
- **Tutor/Familia** no se concede manualmente: se muestra como perfil derivado de una representación activa.
- La condición de **Jugador federado** se muestra como relación derivada de la extensión `jugadores`, diferenciándola del perfil de acceso propio.
- Si existe una cuenta de Supabase Auth con el mismo correo, el administrador puede vincularla a la Persona desde la ficha.
- Se elimina del menú la vista separada **Usuarios**, al quedar su función consolidada en Personas.
- Entrenador sigue siendo una extensión de Persona; si se retira el perfil Entrenador con asignaciones activas, la operación se bloquea hasta finalizar dichas asignaciones.

### Migración 021
`021_administracion_personas_roles.sql` añade RPC seguras para:
- `guardar_persona_admin(...)`
- `actualizar_perfiles_persona_admin(...)`
- `vincular_auth_persona_por_email_admin(...)`

La baja es lógica. No se eliminan identidades con histórico operativo.


## V67 - corrección del flujo de invitación

- Evita forzar `refreshSession()` después de cambiar la contraseña desde una invitación, corrigiendo `Invalid Refresh Token: Refresh Token Not Found`.
- Actualiza el texto del primer acceso para indicar que el usuario está creando su contraseña tras aceptar la invitación, no sustituyendo una contraseña temporal.
- El alta administrativa espera a que el listado remoto de Personas se refresque antes de mostrar la confirmación.
- Sin cambios en migraciones SQL ni Edge Functions respecto a V65/V66.


## V69 - estado y reenvío de activación de cuentas internas

- La ficha de Persona distingue entre cuenta vinculada pendiente de activación y cuenta ya activada.
- El Administrador puede reenviar un enlace de activación a cuentas internas pendientes.
- Para cuentas ya creadas en Supabase Auth se utiliza un enlace de recuperación/establecimiento de contraseña, evitando duplicar usuarios y el problema de re-invitar un correo ya registrado.
- No modifica la migración 021 ni el modelo de datos.


## V69
- Recuperación de contraseña desde la pantalla de acceso.
- Flujo específico para enlaces de recuperación con establecimiento de nueva contraseña.
- Diferenciación entre confirmación de autoregistro y recuperación de contraseña.
- Mensajes de autenticación revisados.


## V70
- Mejora el circuito de entrenadores menores: la autorización del tutor se comprueba ya al pulsar **Añadir asignación**, manteniendo además el bloqueo de backend al guardar.
- Tras un rechazo de backend se restaura la lista persistida y no queda una asignación ficticia marcada como activa.
- La autorización del tutor usa un diálogo integrado con texto explícito e independiente de la representación como jugador.
- El listado de entrenadores muestra el estado de autorización del tutor para técnicos menores.
- La ficha de perfiles del Administrador muestra feedback claro cuando un entrenador menor queda pendiente de autorización.
- Los datos maestros de Persona en la ficha de Entrenador permanecen en solo lectura; el estado mostrado se etiqueta expresamente como estado del entrenador.
- Se mantiene la separación entre Jugador deportivo (`jugadores.activo`) y perfil de acceso Jugador: los menores son representados por su tutor y no necesitan perfil de acceso Jugador activo hasta la mayoría de edad.


## V71

- Tutor/Familia puede consultar autorizaciones vigentes e histórico de entrenador menor.
- Se añade revocación expresa por el mismo tutor que concedió la autorización.
- Revocar finaliza inmediatamente las asignaciones activas del entrenador menor y cancela las futuras, conservando trazabilidad en auditoría.
- El perfil Entrenador no se elimina al revocar: simplemente vuelve a quedar bloqueado para asignaciones mientras sea menor.
- Se mantiene la validación backend de autorización antes de guardar asignaciones.

## V72

- Las autorizaciones de entrenador menor dejan de ocupar un bloque general en la portada de Familia.
- Autorizar, rechazar y revocar se gestionan dentro de la ficha del menor afectado, en la pestaña **Datos**.
- Una autorización vigente muestra su fecha y el botón **Revocar autorización** dentro de la ficha del niño.
- Las solicitudes pendientes aparecen también dentro de la ficha correspondiente con **Autorizar / Rechazar**.
- El histórico del consentimiento queda asociado visualmente al menor, evitando ocupar espacio en familias con varios jugadores.
- Sin cambios de backend respecto a V71; la migración 023 sigue siendo la vigente.



## V74

- Corrige el error `Invalid time value` al mostrar autorizaciones revocadas o históricas: el formateador de fechas admite tanto fechas SQL (`YYYY-MM-DD`) como timestamps de Supabase.
- Las asignaciones de entrenador canceladas por revocación del tutor dejan de eliminarse físicamente: se conservan en `asignaciones_entrenador_equipo` con marca de cancelación y motivo.
- Las vistas operativas excluyen las asignaciones canceladas, manteniéndolas disponibles para histórico y auditoría.
- La revocación continúa bloqueando nuevas asignaciones mientras el entrenador siga siendo menor y no exista una nueva autorización vigente.


## V74
- El perfil Club puede solicitar o relanzar la autorización del tutor para un entrenador menor desde la propia ficha del entrenador.
- Si la autorización está pendiente se informa del estado y se mantiene bloqueada la creación de asignaciones.
- Si está revocada, rechazada o no existe, Club/Admin pueden solicitar una nueva autorización sin modificar el perfil Entrenador.
