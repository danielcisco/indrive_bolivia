# Pulido de UI — tema + botones (post sprint extra)

## Contexto

Sprint extra cerrado (Grupo E, OCR de documentos, queda pendiente para más adelante). Ahora: consistencia visual y pulido en las 3 apps — Material 3 de siempre, sin identidad de marca nueva, con soporte de tema oscuro (decisiones ya tomadas con el usuario). Hoy `AppTheme` solo tiene `light`, sin ningún `ComponentTheme` (botones/inputs/cards quedan con el default de Flutter, inconsistentes entre pantallas), y 44 botones en 22 archivos, la mayoría sin ícono.

## Diseño

### 1. `AppTheme` — el cambio de mayor impacto, cero toques por pantalla

`lib/core/theme/app_theme.dart` gana:
- `dark` (mismo seed, `ColorScheme.fromSeed(..., brightness: Brightness.dark)`).
- `FilledButtonThemeData`/`OutlinedButtonThemeData`: alto mínimo consistente (48) y ancho completo por defecto — hoy cada botón tiene el ancho que le da su texto, se ve desprolijo en pantallas con varios apilados.
- `InputDecorationTheme`: `filled: true` + `OutlineInputBorder` redondeado — hoy los `TextField` son solo una línea (default de Material), se ven muy crudos.
- `CardTheme`: bordes redondeados y elevación consistente (ya se usa `Card` en Pagos/KYC del Admin con estilos ad-hoc).

Esto solo, sin tocar ninguna pantalla, ya mejora los 44 botones + todos los inputs + todas las cards de las 3 apps.

### 2. Los 3 `main_*.dart` — activar tema oscuro

Cada uno pasa de `theme: AppTheme.light` a `theme: AppTheme.light, darkTheme: AppTheme.dark, themeMode: ThemeMode.system` — respeta el tema del sistema del teléfono.

### 3. Pase de íconos en los botones principales (no los 44, los que importan)

Se agregan íconos (`FilledButton.icon`/`OutlinedButton.icon`) a los botones de **acción primaria** de cada pantalla — no a botones de diálogo tipo "Sí"/"No"/"Cancelar", que no lo necesitan. Patrón mecánico, mismo cambio repetido con un ícono distinto según la acción:

| Pantalla | Botón | Ícono |
|---|---|---|
| `cliente_home_screen.dart` | Mis envíos | `Icons.local_shipping_outlined` |
| `crear_envio_screen.dart` | Publicar envío | `Icons.send_outlined` |
| `envio_detalle_screen.dart` | Cancelar envío / Calificar | `Icons.cancel_outlined` / `Icons.star_outline` |
| `mis_envios_screen.dart` | FAB "+" | ya es ícono, sin cambio |
| `repartidor_home_screen.dart` | Radar / Mis entregas / Mis calificaciones / Subir Cédula | `Icons.radar` / `Icons.local_shipping_outlined` / `Icons.star_outline` / `Icons.badge_outlined` |
| `envio_repartidor_detalle_screen.dart` | Aceptar directo / Enviar contraoferta | `Icons.check_circle_outline` / `Icons.reply_outlined` |
| `entrega_en_curso_screen.dart` | Iniciar viaje / Marcar como entregado | `Icons.play_arrow_outlined` / `Icons.check_circle_outline` |
| `confirmar_entrega_screen.dart` | Confirmar entrega | `Icons.check_circle_outline` |
| `subir_cedula_screen.dart` | Subir | `Icons.cloud_upload_outlined` |
| `kyc_pending_screen.dart` | Aprobar | `Icons.check_outlined` |
| `pagos_pendientes_screen.dart` | Marcar como verificado | `Icons.verified_outlined` |
| `usuario_detalle_screen.dart` | Suspender/Reactivar | `Icons.block_outlined` / `Icons.check_circle_outline` |
| `admin_login_screen.dart`, `cliente/repartidor_login` (vía `phone_login_view.dart`) | Ingresar/Enviar código/Confirmar | `Icons.login`/`Icons.sms_outlined`/`Icons.check_outlined` |

### 4. Estados vacíos con ícono

Las pantallas de lista que hoy muestran solo texto centrado ("Todavía no tienes envíos.", "No hay pagos QR pendientes...", etc. — `mis_envios_screen.dart`, `mis_entregas_screen.dart`, `kyc_pending_screen.dart`, `pagos_pendientes_screen.dart`, `gestion_usuarios_screen.dart`, `mis_calificaciones_screen.dart`) ganan un ícono grande arriba del texto (`Icons.inbox_outlined` o uno específico por pantalla) — mismo patrón repetido, un `Column` con `Icon` + `SizedBox` + `Text` en vez de solo `Text`.

## Archivos afectados

Los 2 de mayor impacto (`app_theme.dart`, 3× `main_*.dart`) + los ~15 de la tabla de íconos + ~6 de estados vacíos — todos con el mismo tipo de cambio mecánico descrito arriba, sin lógica nueva. No se listan línea por línea.

## Verificación

1. `flutter analyze` limpio.
2. Correr cada app (`--flavor cliente`, `--flavor repartidor`, panel Admin web) y mirar: botones consistentes, inputs con borde, tema oscuro si el teléfono/navegador está en modo oscuro.
3. Commit único (es un cambio puramente visual, no hace falta separarlo en varios).

---

# Sprint extra — Grupo D: notificaciones de ciclo de vida del envío

## Contexto

Cuarto de 5 grupos, el más grande de los "razonables". Hoy el Cliente no tiene FCM configurado para nada (solo Repartidor, para ofertas cercanas) — tiene que tener la pantalla abierta para enterarse de que aceptaron su envío, le mandaron una contraoferta, o se venció el tiempo sin que nadie lo tomara. Dos piezas: (1) armar FCM en la app Cliente por primera vez, (2) un barrido programado (primer uso de `onSchedule` en el proyecto) que cierra los envíos vencidos.

## Diseño

### 1. Nuevo estado `EnvioStatus.expirado`, no reusar `cancelado`

Un envío que se vence solo (nadie lo tomó a tiempo) no es lo mismo que uno que el Cliente canceló a propósito — mostrar "cancelado" en el historial cuando en realidad se venció es engañoso. Se agrega `expirado` al enum (mismo patrón `fromFirestore`/`toFirestore` que los demás valores) en `lib/shared/domain/entities/envio.dart`. El Radar del Repartidor no necesita ningún cambio: ya filtra por `status == 'pendiente_ofertas'`, así que un envío que pasa a `expirado` desaparece solo.

### 2. Barrido de expiración — primer `onSchedule` del proyecto

`expirarEnviosVencidos` (`onSchedule`, cada 5 minutos — la ventana de subasta son 10, así que el peor caso es ~5 min de demora): consulta `envios` con `status == 'pendiente_ofertas' && expiraEn < now()`, paginado con `.limit()` (nunca sin cota, ni siquiera en un cron), pasa cada uno a `expirado` y dispara la notificación al Cliente.

### 3. Notificaciones nuevas — reutilizan el envío de FCM que ya existe

- `notificarAceptacionDirecta` (`onDocumentUpdated` sobre `envios/{envioId}`): si pasa de `pendiente_ofertas` a `asignado` **con** `ofertaAceptadaId == null` (esa combinación específica es "aceptación directa", distinta de que el propio Cliente haya elegido una oferta) → notifica al `clienteId`.
- `notificarNuevaContraoferta` (`onDocumentCreated` sobre `envios/{envioId}/ofertas/{ofertaId}`): notifica al `clienteId` del envío padre.
- `expirarEnviosVencidos` también notifica, como parte del mismo barrido.

Las tres comparten un helper interno (`enviarNotificacionAUsuario(uid, title, body)`) que lee `users/{uid}.fcmToken` y llama `admin.messaging().send()` — evita triplicar esa lectura.

### 4. `FcmService` gana un segundo canal, no una clase nueva

Hoy `FcmService` crea un solo canal (`ofertas_alta_prioridad`, con `fullScreenIntent` estilo "llamada entrante" — correcto para el Repartidor, pero exagerado para un aviso informativo al Cliente). Se agrega `kActualizacionesEnvioChannelId` (`Importance.high` pero sin `fullScreenIntent`/`category: call`), y `_mostrarNotificacionLocal` elige el canal según cuál venga en el mensaje (`message.notification?.android?.channelId`) en vez de tener el canal de ofertas hardcodeado — así el mismo `FcmService`, sin cambios de arquitectura, sirve para ambos roles.

### 5. Activar FCM en Cliente por primera vez

`ClienteApp` (`main_cliente.dart`) pasa a `ConsumerWidget` y hace `ref.watch(fcmServiceProvider)` en el `build()` — exactamente el mismo patrón de una línea que ya usa `RepartidorApp`.

## Archivos afectados

| Archivo | Cambio |
|---|---|
| `lib/shared/domain/entities/envio.dart` | + `EnvioStatus.expirado` |
| `functions/src/index.ts` | + `expirarEnviosVencidos`, `notificarAceptacionDirecta`, `notificarNuevaContraoferta`, helper de envío |
| `lib/core/notifications/fcm_service.dart` | + canal `actualizaciones_envio`, selección dinámica de canal |
| `lib/main_cliente.dart` | `ClienteApp` → `ConsumerWidget` + `fcmServiceProvider` |

Sin cambios en `firestore.rules` (el barrido escribe vía Admin SDK, que bypassea Rules) ni en `firestore.indexes.json` (la query del barrido es un solo `where` compuesto por igualdad+rango sobre 2 campos ya indexados por Firestore automáticamente — status y expiraEn con un solo rango no necesitan índice compuesto explícito).

## Verificación

1. `flutter analyze` + `tsc` limpios.
2. Crear un envío, aceptarlo directo desde Repartidor → confirmar que llega el push al Cliente.
3. Mandar una contraoferta → confirmar push al Cliente.
4. Crear un envío y esperar a que venza (o probar con una ventana corta manualmente) → confirmar que pasa a `expirado`, desaparece del Radar, y llega el push.
5. Deploy de las 3 funciones — pido confirmación antes.
6. Commit.

---

# Sprint extra — Grupo C: gestión de usuarios (Admin)

## Contexto

Tercero de 5 grupos. Pantalla de gestión de cuentas para el panel Admin: lista de todos los usuarios (Cliente + Repartidor), detalle, y suspender/reactivar. Ya se había descartado un CRUD literal (ver artifact de referencia): sin crear cuentas (rompería la verificación por SMS) ni borrar de verdad (dejaría huérfanas las referencias en envíos/calificaciones) — "suspender" es la operación correcta, reversible.

## Diseño

### 1. "Suspender" = deshabilitar el login real, no un flag cosmético

Una cuenta suspendida tiene que dejar de poder loguearse de verdad, no solo mostrar un cartel. Nueva Cloud Function `establecerEstadoCuenta` (mismo patrón admin-only que `approveKyc`): usa el Admin SDK para `auth().updateUser(uid, {disabled})` — el mecanismo real de Firebase Auth para esto — y además `revokeRefreshTokens(uid)` al suspender, para que no seguir con la sesión ya abierta hasta que expire sola. En espejo, guarda `users/{uid}.isActive` (vía Admin SDK, bypassea Rules) solo para que el panel pueda mostrar el estado sin tener que llamar al Admin SDK en cada lectura.

`firestore.rules`: se agrega `isActive` a los campos que el dueño no puede tocar en `users/{uid}` (mismo criterio que `role`/`isVerified`) — si no, cualquiera podría reactivarse a sí mismo escribiendo directo a Firestore. Usa `.get('isActive', true)` (no acceso directo) porque el campo puede no existir todavía en cuentas nunca suspendidas, y un acceso directo a una clave ausente rompe la regla para *todas* las demás escrituras del dueño (ubicación, fcmToken, cédula).

*Limitación conocida, fuera de alcance*: si el usuario ya tiene la app abierta en el momento de la suspensión, no lo saca de la pantalla actual al instante — recién lo nota en el próximo refresh de su token (las Rules igual le bloquean cualquier escritura nueva mientras tanto vía `isVerifiedRepartidor()`/`isCliente()`, que dependen del token).

### 2. Datos — extender `UsersRepository`

- `listarUsuarios({limit, startAfter})`: `users` ordenado por `createdAt` desc, paginado, sin filtro de rol (Cliente y Repartidor mezclados, cada fila muestra su rol).
- `establecerEstadoCuenta(uid, {required bool activar})`: llama a la Cloud Function.

### 3. Entidad `UsuarioAdmin` (`lib/features/admin/domain/`)

uid, phoneNumber, role, isVerified, isActive, ratingPromedio, totalCalificaciones, createdAt — todo lo que ya vive en `users/{uid}` a esta altura del proyecto.

### 4. Pantallas Admin

- `GestionUsuariosScreen`: lista paginada (mismo esqueleto que `KycPendingScreen`), cada fila con teléfono + rol + estado (Activo/Suspendido) + verificado.
- `UsuarioDetalleScreen`: todos los campos de `UsuarioAdmin` + botón "Suspender"/"Reactivar" según `isActive`.
- 4ta pestaña "Usuarios" en el `NavigationRail` de `AdminHomeScreen`.

## Archivos afectados

| Archivo | Cambio |
|---|---|
| `functions/src/index.ts` | + `establecerEstadoCuenta` |
| `firestore.rules` | `isActive` inmutable para el dueño en `users/{uid}` |
| `lib/shared/data/users_repository.dart` | + `listarUsuarios`, `establecerEstadoCuenta` |
| `lib/features/admin/domain/usuario_admin.dart` | nuevo |
| `lib/features/admin/presentation/providers/gestion_usuarios_controller.dart` | nuevo |
| `lib/features/admin/presentation/screens/gestion_usuarios_screen.dart` | nuevo |
| `lib/features/admin/presentation/screens/usuario_detalle_screen.dart` | nuevo |
| `lib/features/admin/presentation/screens/admin_home_screen.dart` | 4ta pestaña "Usuarios" |

Sin índice nuevo (la query de `listarUsuarios` es un solo `orderBy`, no necesita compuesto). Sin cambios en `storage.rules`.

## Verificación

1. `flutter analyze` + `tsc` limpios.
2. Panel Admin → Usuarios → ver la lista, abrir un detalle.
3. Suspender una cuenta de prueba → confirmar que esa cuenta ya no puede loguearse (o se desconecta) en su app.
4. Reactivarla → confirmar que puede volver a entrar.
5. Deploy de la función + reglas — pido confirmación antes.
6. Commit.

---

# Sprint extra — Grupo B: reputación (calificaciones recibidas + promedio)

## Contexto

Segundo de 5 grupos acordados. Hoy se puede calificar pero nadie ve las calificaciones que recibió, ni existe un promedio — justo la señal de confianza que un mercado de este tipo necesita mostrar. Dos partes: (1) un listado paginado de "mis calificaciones recibidas" para Cliente y Repartidor, (2) un promedio 0-5 (`0` = todavía sin calificaciones, "nuevo") mantenido automáticamente por una Cloud Function cada vez que entra una calificación nueva.

## Diseño

### 1. Por qué un promedio mantenido por Cloud Function, no calculado al vuelo

Recorrer todas las calificaciones de un usuario cada vez que hay que mostrar su promedio no escala (regla no negociable: nunca queries sin cota, y acá "todas las calificaciones de siempre" es exactamente eso). En cambio, `users/{uid}` gana dos campos —`totalCalificaciones` (int) y `sumaEstrellas` (int)— que una Cloud Function nueva (`actualizarRatingPromedio`, trigger `onDocumentCreated` sobre `envios/{envioId}/calificaciones/{autorId}`) actualiza dentro de una transacción cada vez que se crea una calificación, y de ahí deriva `ratingPromedio` (`sumaEstrellas / totalCalificaciones`, `0` si `totalCalificaciones == 0`). Mismo patrón de "Cloud Function como única vía de escritura de un campo derivado" que ya usan `setEnvioExpiration` y `approveKyc`.

### 2. Listado de calificaciones recibidas — collection group query

Las calificaciones viven en `envios/{envioId}/calificaciones/{autorId}` (subcolección por envío). Para listar "todas las que recibió el uid X" sin importar de qué envío vinieron, hace falta una **collection group query** (`FirebaseFirestore.collectionGroup('calificaciones').where('paraId', isEqualTo: uid)`) — la regla de Firestore que ya existe (`allow read: if isSignedIn()` sobre `calificaciones`) ya cubre este tipo de query sin cambios, porque las Rules evalúan por path del documento, no por la forma de la query. Sí hace falta un índice nuevo de tipo `COLLECTION_GROUP` en `firestore.indexes.json`.

### 3. Pantalla compartida `MisCalificacionesScreen`

Vive en `lib/shared/widgets/` — mismo criterio que `MapPickerScreen`, que ya es una pantalla completa (no un widget chico) compartida entre roles ahí mismo. Lista paginada (mismo esqueleto que `KycPendingController`/`PagosPendientesController`): estrellas, comentario si tiene, fecha. El controller nuevo (`MisCalificacionesController`) vive en `lib/shared/providers/` (carpeta nueva, paralela a `features/<rol>/presentation/providers/`, porque esta lógica no es de un rol específico).

### 4. Mostrar el promedio en cada Home

`ClienteHomeScreen` y `RepartidorHomeScreen` ganan una línea "⭐ 4.5 · 12 calificaciones" (o "Sin calificaciones todavía" si `total == 0`) + un botón "Mis calificaciones" que abre la pantalla compartida. Nuevo `UsersRepository.obtenerMiRating(uid)` + provider `miRatingProvider`.

## Archivos afectados

| Archivo | Cambio |
|---|---|
| `functions/src/index.ts` | + `actualizarRatingPromedio` |
| `firestore.indexes.json` | + índice `COLLECTION_GROUP` para `calificaciones` |
| `lib/shared/data/users_repository.dart` | + `obtenerMisCalificaciones`, `obtenerMiRating` |
| `lib/shared/data/providers.dart` | + `miRatingProvider` |
| `lib/shared/providers/mis_calificaciones_controller.dart` | nuevo |
| `lib/shared/widgets/mis_calificaciones_screen.dart` | nuevo |
| `lib/features/cliente/presentation/screens/cliente_home_screen.dart` | resumen + botón |
| `lib/features/repartidor/presentation/screens/repartidor_home_screen.dart` | resumen + botón |

Sin cambios en `firestore.rules` (la lectura de `calificaciones` ya está cubierta) ni en `storage.rules`.

## Verificación

1. `flutter analyze` + `tsc` (functions) limpios.
2. Calificar un envío desde ambos lados → confirmar en Firestore Console que `users/{uid}.totalCalificaciones`/`sumaEstrellas`/`ratingPromedio` se actualizaron.
3. Abrir "Mis calificaciones" en Cliente y Repartidor → ver la calificación recién creada en la lista.
4. Deploy de la función nueva + el índice — pido confirmación antes de correrlo.
5. Commit.

---

# Sprint extra — Grupo A: cancelar, confirmar, timer

## Contexto

Primero de 5 grupos acordados con el usuario para el sprint extra de mejoras de UX. Este grupo no necesita infraestructura nueva — todo usa datos y Rules que ya existen (la regla de cancelación del Cliente ya estaba en `firestore.rules` sin ninguna pantalla que la use; `expiraEn` ya existe en cada envío).

1. **Cancelar envío (Cliente)**: la regla `firestore.data.clienteId == request.auth.uid && resource.data.status == 'pendiente_ofertas' && request.resource.data.status == 'cancelado'` ya existe en `firestore.rules` — nunca se conectó a ninguna pantalla.
2. **Confirmación antes de "Aceptar directo" (Repartidor)**: evita comprometerse a una entrega real por un toque accidental.
3. **Timer visible (ambos)**: cuánto tiempo queda antes de que se cierre la ventana de ofertas de un envío (`expiraEn`, fijado server-side por la Cloud Function `setEnvioExpiration`).

## Diseño

### 1. `EnviosRepository.cancelarEnvio(envioId)`

Un `update({'status': 'cancelado'})` — mismo nivel que `marcarEntregado`/`iniciarViaje`, sin transacción (no hay condición de carrera que prevenir aquí, a diferencia de aceptar un envío).

### 2. Widget compartido `CountdownTimer` (`lib/shared/widgets/countdown_timer.dart`)

Recibe `Timestamp? expiraEn`, se re-renderiza cada segundo (`Timer.periodic`, cancelado en `dispose()`) mostrando "Tiempo restante: MM:SS" o "Vencido" si ya pasó. Usa `DateTime.now()` del dispositivo **solo para animar el conteo visual** contra el `expiraEn` que ya vino del servidor — no es una regla de negocio ni se escribe a ningún lado, así que no choca con la regla no negociable de CLAUDE.md sobre vencimientos (esa regla es sobre qué define el vencimiento real, no sobre cómo se anima en pantalla).

### 3. `EnvioDetalleScreen` (Cliente)

- Muestra `CountdownTimer` cuando `status == pendienteOfertas`.
- Botón "Cancelar envío" (mismo estado), con diálogo de confirmación antes de llamar `cancelarEnvio`.

### 4. `EnvioRepartidorDetalleScreen` (Repartidor)

- Muestra `CountdownTimer` (mismo envío, mismo campo).
- "Aceptar directo" pasa por un `AlertDialog` de confirmación antes de ejecutar `_aceptarDirecto` — mismo criterio ya usado en otros diálogos del proyecto (`AlertDialog` con dos acciones).

## Archivos afectados

| Archivo | Cambio |
|---|---|
| `lib/shared/data/envios_repository.dart` | + `cancelarEnvio` |
| `lib/shared/widgets/countdown_timer.dart` | nuevo |
| `lib/features/cliente/presentation/screens/envio_detalle_screen.dart` | timer + botón cancelar |
| `lib/features/repartidor/presentation/screens/envio_repartidor_detalle_screen.dart` | timer + confirmación al aceptar |

Sin cambios en `firestore.rules` (la regla de cancelar ya existe), sin Cloud Functions nuevas, sin dependencias nuevas.

## Verificación

1. `flutter analyze` limpio.
2. Cliente: crear un envío, ver el timer contando, cancelarlo con confirmación, confirmar que desaparece de "Mis envíos" activos.
3. Repartidor: en Radar, abrir un envío, ver el timer, tocar "Aceptar directo" → aparece el diálogo → confirmar → recién ahí se asigna.
4. Commit.
