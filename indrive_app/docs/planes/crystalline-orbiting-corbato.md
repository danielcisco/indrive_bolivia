# Sprint 4.1b — Foreground Service GPS, tracking en vivo y batería

## Contexto

Segunda mitad de Fase 4 (la primera, selector de mapa, cerró en 4.1a). Reglas no negociables de `CLAUDE.md` que se implementan aquí por primera vez: throttling de GPS por distancia (~15 m) con filtro de precisión, Foreground Service con notificación persistente mientras hay un viaje en curso, y onboarding obligatorio de exclusión de optimización de batería.

Decisión ya acordada: **`flutter_background_service`** para el Foreground Service (en vez de escribir Kotlin nativo a medida) — se verifica empíricamente en dispositivo como cualquier otro plugin nuevo de este proyecto.

## Lo que falta para que esto sea probable: una pantalla de "viaje en curso"

Hoy, después de aceptar un envío o que el cliente acepte una oferta, el repartidor no tiene ninguna pantalla que muestre sus entregas activas — este Sprint la agrega, porque sin ella no hay dónde disparar "Iniciar viaje" (lo que arranca el tracking).

## Flujo de estados

`asignado` (ya existe) → **"Iniciar viaje"** → `en_curso` (arranca el Foreground Service) → **"Marcar como entregado"** → `entregado` (detiene el servicio). Dos métodos nuevos en `EnviosRepository`: `iniciarViaje` y `marcarEntregado`, cada uno una actualización simple validada por una regla de Firestore (no hace falta transacción: no hay condición de carrera entre múltiples repartidores aquí, solo uno ya está asignado).

## Foreground Service: throttling y filtro de precisión

`lib/core/tracking/background_location_service.dart`: usa `Geolocator.getPositionStream` con `distanceFilter: 15` (metros) — el throttling por distancia lo hace el propio proveedor de ubicación del sistema operativo, no un `Timer` ni cálculo manual, tal como pide CLAUDE.md ("no streams crudos"). Cada lectura se filtra con una función pura `esPosicionValida(position, maxAccuracyMetros: 50)` (testeada sin dispositivo) antes de escribirse a `envios/{id}.repartidorPosicionActual` vía `EnviosRepository.actualizarPosicionRepartidor`. La notificación persistente ("Entrega en curso — [descripción]") la gestiona el propio plugin mientras el servicio está activo.

El servicio arranca al tocar "Iniciar viaje" y se detiene al tocar "Marcar como entregado" — nunca corre sin una entrega activa.

## Onboarding de batería (obligatorio, no opcional)

Usa `permission_handler` (`Permission.ignoreBatteryOptimizations`) — antes de permitir "Iniciar viaje" por primera vez, si el permiso no está concedido se muestra una pantalla explicando por qué hace falta (Doze mode puede matar el tracking en Xiaomi/Samsung) con un botón que dispara el diálogo del sistema. No bloquea de forma permanente si el usuario decide no concederlo (algunos fabricantes lo gestionan distinto), pero se vuelve a mostrar cada vez que no esté concedido.

## Tiempo real para el Cliente

`EnvioDetalleScreen` (Cliente) pasa de `envioProvider` (fetch puntual, Sprint 3.1) a un nuevo `envioStreamProvider` (`snapshots()` de ese único documento) mientras el envío está `en_curso` — un listener en tiempo real sobre un solo documento es exactamente el caso de uso correcto para streams (distinto de "streams masivos" sobre colecciones enteras, que CLAUDE.md sí prohíbe). `EnvioMapPreview` se extiende para dibujar un tercer marcador (repartidor) cuando `repartidorPosicionActual` está presente.

## Cambios al esquema y reglas

`Envio` agrega `repartidorPosicionActual: GeoPoint?` y `repartidorPosicionActualizada: Timestamp?`.

`firestore.rules` — 2 reglas nuevas en `envios/{envioId}`:
- El repartidor asignado avanza el estado (`asignado→en_curso` o `en_curso→entregado`), sin tocar ningún otro campo.
- El repartidor asignado actualiza `repartidorPosicionActual`/`repartidorPosicionActualizada` mientras `status == 'en_curso'`, sin cambiar nada más.

`firestore.indexes.json` — índice compuesto `repartidorAsignadoId ASC, createdAt DESC` para listar las entregas del repartidor.

## Permisos Android nuevos

`ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION` — se agregan a `AndroidManifest.xml`; la declaración del `<service>` la resuelve `flutter_background_service` según su configuración (se ajusta durante la implementación si el plugin lo requiere explícito).

## Archivos a crear/editar

- `indrive_app/pubspec.yaml` — `flutter_background_service`, `permission_handler`.
- `indrive_app/android/app/src/main/AndroidManifest.xml` — permisos de background location/foreground service.
- `indrive_app/firestore.rules`, `firestore.indexes.json` — descrito arriba.
- `indrive_app/lib/shared/domain/entities/envio.dart` — campos de posición del repartidor.
- `indrive_app/lib/shared/data/envios_repository.dart` — `listarEntregasDeRepartidor`, `iniciarViaje`, `marcarEntregado`, `actualizarPosicionRepartidor`.
- `indrive_app/lib/shared/data/providers.dart` — `envioStreamProvider`.
- `indrive_app/lib/shared/widgets/envio_map_preview.dart` — marcador de repartidor en vivo.
- `indrive_app/lib/core/tracking/background_location_service.dart`, `location_accuracy_filter.dart`, `battery_optimization.dart` (nuevos).
- `indrive_app/lib/features/repartidor/presentation/providers/mis_entregas_controller.dart` (nuevo, mismo patrón de paginación ya usado 3 veces).
- `indrive_app/lib/features/repartidor/presentation/screens/mis_entregas_screen.dart`, `entrega_en_curso_screen.dart` (nuevos).
- `indrive_app/lib/features/repartidor/presentation/screens/repartidor_home_screen.dart` — navegación a "Mis entregas".
- `indrive_app/lib/features/cliente/presentation/screens/envio_detalle_screen.dart` — usa `envioStreamProvider` en vez de `envioProvider`.
- `indrive_app/test/location_accuracy_filter_test.dart` (nuevo).

Fuera de alcance (anotado, no descuidado): manejo de la app muriendo/reiniciando el proceso mientras el servicio corre (recuperación de estado), y detener el servicio automáticamente si el envío se cancela por otra vía — ambos son refinamientos de robustez para un Sprint de pulido posterior, no bloquean la funcionalidad central.

## Verificación

1. `flutter pub get`, `flutter analyze`, `flutter test` (incluye el filtro de precisión).
2. `firebase deploy --only firestore`.
3. En el Samsung: como Repartidor, aceptar/que te acepten un envío, ir a "Mis entregas", conceder el permiso de batería cuando se pida, tocar "Iniciar viaje" — confirmar que aparece la notificación persistente.
4. Caminar/moverte y confirmar en la consola de Firestore que `repartidorPosicionActual` se actualiza (aprox. cada 15 m de movimiento real, no en un intervalo fijo).
5. Desde la app Cliente, abrir el detalle de ese envío y confirmar que el marcador del repartidor se mueve en el mapa sin necesidad de refrescar manualmente.
6. Tocar "Marcar como entregado" y confirmar que la notificación persistente desaparece y el estado pasa a `entregado`.

Al cerrar, explico las decisiones (por qué `distanceFilter` en vez de throttling manual, por qué un stream de un solo documento no viola la regla de "no streams masivos", y los dos refinamientos que quedan fuera de alcance) y esto completa Fase 4 — espero autorización antes de Fase 5.

---

## Contexto

Fase 4, primera mitad. El usuario aprobó dividir el Sprint 4.1 del backlog en dos: esta parte (**4.1a**) cubre "mapas" — cierra la limitación conocida y documentada desde Sprint 3.1 (destino por lat/lng manual, origen por una sola lectura GPS sin ajuste). La segunda mitad (**4.1b**: Foreground Service de tracking GPS del repartidor + onboarding de batería) queda para un Sprint aparte — es la parte con código nativo Android y más riesgo técnico, merece su propia validación dedicada en vez de mezclarse con el trabajo de UI de mapas.

Decisión ya acordada: **Google Maps** (`google_maps_flutter`) sobre OpenStreetMap — mejor cobertura de calles en Bolivia, a cambio de necesitar una API key de Google Cloud (el proyecto ya está en plan Blaze, así que es solo habilitar una API más).

## Prerrequisito — a cargo del usuario

Generar una API key de Google Maps:
1. https://console.cloud.google.com/google/maps-apis/api-list?project=indrive-entregas-villazon → habilitar **"Maps SDK for Android"**.
2. https://console.cloud.google.com/apis/credentials?project=indrive-entregas-villazon → "Crear credenciales" → "Clave de API".
3. Restringir la clave: tipo "Apps de Android", agregar el paquete `com.example.indrive_app` + el SHA-1 del certificado de debug (`cd android && ./gradlew signingReport`, o te lo consigo yo si prefieres). Sin esta restricción, cualquiera que vea la clave podría usarla desde otra app.
4. Agregar al archivo `android/local.properties` (ya gitignored, igual que `flutter.sdk`) la línea `MAPS_API_KEY=tu_clave_aqui`.

No subo la clave al repo — se inyecta vía manifest placeholder leído desde `local.properties`, mismo patrón que Flutter ya usa para la ruta del SDK.

## Selector de mapa (reutilizado, no dos pantallas)

`MapPickerScreen`: `GoogleMap` de pantalla completa con un pin fijo en el centro (el mapa se mueve debajo, patrón estándar de apps de delivery) + botón "Confirmar ubicación" que devuelve un `GeoPoint` vía `Navigator.pop`. Una sola pantalla genérica, usada dos veces desde `CrearEnvioScreen` (origen y destino) — evita construir dos pickers casi idénticos.

Para origen, el mapa arranca centrado en la ubicación GPS actual (reutiliza `obtenerUbicacionActual()` de `lib/core/location/current_location.dart`, Sprint 3.1/3.2) como punto de partida — pero ahora el usuario puede ajustar la posición del pin antes de confirmar, a diferencia de Sprint 3.1 donde la lectura GPS era la respuesta final sin poder corregirla.

## Preview de mapa en el detalle del envío

`EnvioMapPreview` (widget compartido, usado en `EnvioDetalleScreen` de Cliente y `EnvioRepartidorDetalleScreen` de Repartidor): mapa pequeño no interactivo con dos marcadores (origen "A", destino "B") en vez de mostrar coordenadas crudas. Sin tracking en vivo todavía — eso es 4.1b.

## Archivos a crear/editar

- `indrive_app/pubspec.yaml` — agrega `google_maps_flutter`.
- `indrive_app/android/app/build.gradle.kts` — lee `MAPS_API_KEY` de `local.properties`, lo expone como manifest placeholder.
- `indrive_app/android/app/src/main/AndroidManifest.xml` — `<meta-data android:name="com.google.android.geo.API_KEY" android:value="${MAPS_API_KEY}" />`.
- `indrive_app/lib/shared/widgets/map_picker_screen.dart` (nuevo).
- `indrive_app/lib/shared/widgets/envio_map_preview.dart` (nuevo).
- `indrive_app/lib/features/cliente/presentation/screens/crear_envio_screen.dart` — reemplaza los campos de lat/lng manuales de destino y el flujo de solo-GPS de origen por `MapPickerScreen`.
- `indrive_app/lib/features/cliente/presentation/screens/envio_detalle_screen.dart` — agrega `EnvioMapPreview`.
- `indrive_app/lib/features/repartidor/presentation/screens/envio_repartidor_detalle_screen.dart` — agrega `EnvioMapPreview`.

Sin tests unitarios nuevos — es UI de mapa nativa (vista de plataforma), no hay lógica pura que testear aquí; se verifica manualmente en dispositivo, igual que las demás pantallas.

## Verificación

1. `flutter pub get`, `flutter analyze`.
2. En el Samsung conectado: `main_cliente.dart` → Crear Envío → confirmar que ambos selectores de mapa abren, centran en tu ubicación (origen) y permiten mover el pin antes de confirmar.
3. Crear un envío nuevo y confirmar que el detalle (Cliente y Repartidor) muestra el mapa con los 2 marcadores en la posición correcta.

Al cerrar, explico el manejo de la API key (por qué no se commitea) y dejo anotado el Sprint 4.1b (Foreground Service + batería) como el siguiente antes de esperar autorización.

---

## Contexto

Cierra Fase 3. Dos métodos de `EnviosRepository` quedaron construidos desde Sprint 2.1 sin ninguna pantalla que los usara (`aceptarEnvioDirecto`, `enviarOferta`) — este Sprint les da UI real desde el lado Repartidor, y agrega lo que faltaba: el radar geolocalizado (usando el `origenGeohash` que Sprint 2.1 ya calcula) y notificaciones push de alta prioridad.

Decisiones ya acordadas con el usuario:
1. **Radar por prefijo de geohash + sondeo adaptativo** (no radio real en km): se consulta `origenGeohash` por rango de prefijo (misma técnica que ya usamos para guardar el campo, sin dependencias nuevas). Si hay pocos resultados, se acorta el prefijo (celda más grande) y se reintenta — así es como CLAUDE.md describe literalmente el radar ("geohash + sondeo adaptativo, no streams masivos"). Limitación conocida y aceptada: puede perderse un envío justo al otro lado del borde de una celda.
2. **FCM: núcleo ahora, FullScreenIntent como seguimiento explícito**. Se construye: Cloud Function que notifica a los repartidores cercanos cuando se crea un envío, canal de notificación Android de alta importancia, registro/actualización del token FCM, y manejo de la notificación en foreground/background. La pantalla completa estilo "llamada entrante" (con el permiso especial `USE_FULL_SCREEN_INTENT` de Android 14+) se deja como tarea de seguimiento aparte — es una Activity dedicada, no una extensión trivial de esto.

## Bloqueador de prueba a resolver primero

Las Firestore Rules de Sprint 2.1 ya exigen `role == 'repartidor' && isVerified == true` para crear ofertas o aceptar un envío directo — pero no existe todavía ningún flujo (ni Fase 5/admin) para marcar `isVerified: true`. Sin esto, **no se puede probar nada de este Sprint**. Agrego `functions/scripts/setVerifiedClaim.ts` (mismo patrón que `setAdminClaim.ts` de Sprint 1.2: lee los claims actuales del usuario, preserva `role`, fija `isVerified: true`) para que puedas marcar tu cuenta de prueba de Repartidor como verificada antes de probar.

## Cómo el radar decide "dónde está" el repartidor sin adelantar Fase 4

Fase 4 es la que trae streaming continuo de GPS con throttling y Foreground Service — construir eso ahora sería adelantar trabajo fuera de orden. En su lugar, cada vez que el repartidor abre (o refresca) la pantalla de Radar se toma **una lectura GPS puntual** (se reutiliza el mismo helper de Sprint 3.1, movido a `lib/core/location/current_location.dart` para compartirlo entre Cliente y Repartidor) que sirve para dos cosas a la vez: consultar envíos cercanos, y actualizar `users/{uid}.ultimaGeohash` + `ultimaUbicacionActualizada` (Server Timestamp) — ese campo es lo que la Cloud Function de notificaciones usa para decidir a quién avisar. No hay tracking en segundo plano ni mientras la app está cerrada.

## Radar: sondeo adaptativo

`EnviosRepository.buscarEnviosCercanos(prefix, {limit, startAfter})`: `where('status','==','pendiente_ofertas').where('origenGeohash','>=',prefix).where('origenGeohash','<',prefix+'~')`. `RadarController` empieza con un prefijo de 6 caracteres (~celda de ~1.2 km) y si obtiene menos de 3 resultados y el prefijo tiene más de 3 caracteres, lo acorta un carácter y reintenta (hasta 3 pasos) — la función pura que decide la secuencia de prefijos a probar queda testeada con un unit test (sin Firestore). Se refresca al entrar a la pantalla y con un botón manual — nada de `Timer.periodic` ni streams continuos, tal como pide CLAUDE.md ("no streams masivos").

## Contraofertas y aceptación directa (cerrando UI pendiente de Sprint 2.1)

`EnvioRepartidorDetalleScreen`: muestra el envío + dos acciones que ya existían en el repositorio sin UI:
- **Aceptar directo** → `EnviosRepository.aceptarEnvioDirecto` (transacción atómica, Sprint 2.1).
- **Hacer contraoferta** → formulario de monto (reutiliza `Money.parseBobString`) → `EnviosRepository.enviarOferta` (Sprint 2.1, ya valida la tolerancia de gracia de vencimiento).

## Núcleo FCM

- **Cloud Function `notifyNearbyRepartidores`** (`onDocumentCreated('envios/{envioId}')`, mismo patrón que `setEnvioExpiration`): toma el prefijo del `origenGeohash` del envío nuevo, consulta `users` con `role=='repartidor'` y `ultimaGeohash` en ese rango de prefijo (límite 100), y envía un mensaje FCM de prioridad alta (`android.priority: 'high'`, canal de notificación dedicado) a los tokens encontrados.
- **Cliente Flutter**: `lib/core/notifications/fcm_service.dart` — crea el canal de notificación Android de importancia alta al arrancar (`flutter_local_notifications`), pide permiso de notificaciones (Android 13+), obtiene y guarda el token FCM en `users/{uid}.fcmToken`, escucha `onTokenRefresh` (con su `dispose()` correspondiente), y muestra la notificación local tanto en foreground (`FirebaseMessaging.onMessage`, que si no se maneja no se ve mientras la app está abierta) como confía en el SO para background/terminada.
- Al tocar la notificación: abre la pantalla de Radar (no el envío específico — no hay infraestructura de deep-linking todavía; anotado como detalle menor a futuro, no bloqueante).
- Reglas de Firestore: no requieren cambios — la regla de `users/{uid}` ya permite al dueño escribir campos nuevos (`fcmToken`, `ultimaGeohash`) mientras no toque `role`/`isVerified`.

## Dependencias y permisos nuevos

- `pubspec.yaml`: `firebase_messaging`, `flutter_local_notifications`.
- `AndroidManifest.xml`: permiso `POST_NOTIFICATIONS` (Android 13+).
- `firestore.indexes.json`: índice compuesto `status ASC, origenGeohash ASC` (consulta del radar).

## Archivos a crear/editar

- `indrive_app/functions/scripts/setVerifiedClaim.ts` (nuevo).
- `indrive_app/functions/src/index.ts` — agrega `notifyNearbyRepartidores`.
- `indrive_app/firestore.indexes.json` — índice nuevo.
- `indrive_app/lib/core/location/current_location.dart` (nuevo — `obtenerUbicacionActual()` movido desde el controller de Cliente).
- `indrive_app/lib/core/notifications/fcm_service.dart` (nuevo).
- `indrive_app/lib/shared/data/envios_repository.dart` — `buscarEnviosCercanos`.
- `indrive_app/lib/shared/data/providers.dart` — provider del `FcmService`.
- `indrive_app/lib/features/repartidor/presentation/providers/radar_controller.dart` (nuevo, incluye la función pura de prefijos a testear).
- `indrive_app/lib/features/repartidor/presentation/screens/radar_screen.dart`, `envio_repartidor_detalle_screen.dart` (nuevos).
- `indrive_app/lib/features/repartidor/presentation/screens/repartidor_home_screen.dart` — navegación al Radar.
- `indrive_app/lib/main_repartidor.dart` — `ProviderScope` + inicialización de `FcmService`.
- `indrive_app/lib/features/cliente/presentation/providers/crear_envio_controller.dart` — usa el helper movido en vez de la copia local.
- `indrive_app/test/radar_prefixes_test.dart` (nuevo).

## Verificación

1. `flutter pub get`, `flutter analyze`, `flutter test`.
2. `firebase deploy --only firestore,functions`.
3. Correr `setVerifiedClaim.ts <uid>` sobre tu cuenta de prueba de Repartidor (requisito para que las rules permitan ofertar/aceptar).
4. En el Samsung con `main_repartidor.dart`: abrir Radar, conceder permisos de ubicación y notificaciones, confirmar que aparece el envío que crees desde Cliente. Probar "Aceptar directo" en uno y "Hacer contraoferta" en otro.
5. Confirmar desde la app Cliente que la nueva oferta aparece en el detalle del envío (cierra el ciclo con Sprint 3.1).
6. Con la app Repartidor en segundo plano (tras haber abierto Radar al menos una vez), crear un envío nuevo desde Cliente y confirmar que llega la notificación push de alta prioridad.

Al cerrar, explico las decisiones (por qué geohash-prefijo en vez de radio real, por qué el núcleo FCM se separa del FullScreenIntent, cómo se evita adelantar Fase 4) y dejo anotada la tarea de seguimiento del FullScreenIntent antes de esperar autorización para Sprint 3.2 → Fase 4.

---

## Contexto

Fase 3 del backlog: primeras pantallas de negocio reales, sobre la capa de datos que dejó el Sprint 2.1 (`Envio`, `Oferta`, `EnviosRepository`, reglas, `OfflineActionQueue`). Dos cosas se resuelven aquí que quedaron explícitamente pendientes:

1. **Gestor de estado** (decisión ya tomada con el usuario): **Riverpod**, con providers clásicos (`Provider`/`AsyncNotifier`), sin `riverpod_generator`/`build_runner` todavía — mantiene el código legible para mentoría sin sumar un paso de generación de código en este Sprint. Migrar a la sintaxis con anotaciones más adelante es un cambio mecánico, no arquitectónico, así que no bloquea nada diferirlo.
2. **"Cliente elige una oferta específica"**, que el Sprint 2.1 dejó explícitamente fuera de alcance (solo se construyó `aceptarEnvioDirecto`, el "primero en tomar" del repartidor). Aquí se agrega `aceptarOferta`, donde el cliente elige entre las propuestas recibidas.

También se conecta por primera vez la cola offline (Sprint 2.1) con una acción real: "crear envío".

**Nota de secuencia**: todavía no existe la pantalla de Repartidor para enviar ofertas (eso es Sprint 3.2) — la lógica de "aceptar propuesta" se construye y se prueba con una oferta sembrada manualmente en la consola de Firestore; funcionará end-to-end sin cambios en cuanto el Sprint 3.2 permita enviar ofertas de verdad.

## Decisiones de alcance

- **Origen**: se autocompleta con la ubicación GPS actual del dispositivo (`geolocator`, una sola lectura puntual — el throttling/streaming continuo de GPS es Fase 4, no aplica aquí).
- **Destino**: campos de latitud/longitud manuales, como solución temporal hasta que Fase 4 traiga el selector de mapa. Se documenta como limitación conocida, no un descuido.
- **Paginación**: botón "Cargar más" explícito (no scroll infinito), para no sumar lógica de detección de posición de scroll en este Sprint.
- Fuera de alcance: mapas, notificaciones push (FCM), pagos — todos programados en fases posteriores.

## Cambios al esquema y reglas (extensión, no ruptura)

Se agrega `ofertaAceptadaId: string | null` a `Envio` para soportar la elección específica del cliente (antes solo existía la vía "repartidor toma directo").

`EnviosRepository.aceptarOferta({envioId, ofertaId, repartidorId})`: transacción atómica de 2 documentos (envío + la oferta elegida) — valida `envio.status == 'pendiente_ofertas' && repartidorAsignadoId == null` y `oferta.status == 'pendiente'`, y solo entonces escribe `envio.status = 'asignado'`, `envio.repartidorAsignadoId`, `envio.ofertaAceptadaId`, y `oferta.status = 'aceptada'`. Las demás ofertas pendientes del mismo envío **no se tocan** (evita una transacción de tamaño no acotado) — la UI las trata como cerradas en cuanto `envio.status != 'pendiente_ofertas'`.

`firestore.rules` — dos reglas nuevas:
- En `envios/{envioId}`: permite al cliente dueño pasar de `pendiente_ofertas` a `asignado` fijando `ofertaAceptadaId`, validando con `get()` que `repartidorAsignadoId` coincide con el `repartidorId` de esa oferta (evita que el cliente asigne un repartidor arbitrario).
- En `ofertas/{ofertaId}`: permite marcarla `pendiente → aceptada` solo si quien escribe es el cliente dueño del envío padre (`get()` sobre el envío) y no cambia monto/repartidor.

## Idempotencia real para la cola offline (primer handler conectado)

`EnviosRepository.crearEnvioConId(id, {...})` — variante de `crearEnvio` que escribe en `envios/{id}` (vía `.doc(id).set(...)`) en vez de `.add()` con ID autogenerado. `CrearEnvioScreen`, al enviar: intenta escribir directo; si falla por red, encola vía `OfflineActionQueue.enqueue(type: 'crear_envio', payload: {...})`, y un handler registrado al arrancar la app (`registerHandler('crear_envio', ...)`) usa `crearEnvioConId(action.id, ...)` — así un reintento tras un fallo parcial sobreescribe el mismo documento en vez de duplicar el envío.

## Dinero en el formulario (sin contaminar con `double`)

`Money.parseBobString(String input)`: parseo puramente por texto (separa por el punto decimal, castea cada mitad a `int`, nunca pasa por `double.parse(...) * 100`) — evita el riesgo de imprecisión de punto flotante incluso en la conversión desde el input del usuario.

## Providers (Riverpod) — patrón

- `lib/shared/data/providers.dart`: `enviosRepositoryProvider`, `offlineActionQueueProvider` (crea la cola, registra el handler `crear_envio`, llama `startListening()`, y libera recursos con `ref.onDispose(queue.dispose)`).
- Listas paginadas (`MisEnviosScreen`, ofertas de un envío) usan un `AsyncNotifier` con estado `{items, lastDocument, hasMore}` y un método `cargarMas()` — un solo patrón reutilizado en ambas pantallas, no dos implementaciones distintas.
- `main_cliente.dart` se envuelve en `ProviderScope` (raíz obligatoria de Riverpod).

## Archivos a crear/editar

- `indrive_app/pubspec.yaml` — agrega `flutter_riverpod`, `geolocator`.
- `indrive_app/android/app/src/main/AndroidManifest.xml` — permisos `ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION`.
- `indrive_app/firestore.rules` — reglas nuevas descritas arriba.
- `indrive_app/lib/shared/domain/entities/envio.dart` — campo `ofertaAceptadaId`.
- `indrive_app/lib/shared/domain/value_objects/money.dart` — `Money.parseBobString`.
- `indrive_app/lib/shared/data/envios_repository.dart` — `crearEnvioConId`, `listarEnviosDeCliente`, `aceptarOferta`.
- `indrive_app/lib/shared/data/providers.dart` (nuevo).
- `indrive_app/lib/features/cliente/presentation/providers/mis_envios_controller.dart`, `ofertas_controller.dart`, `crear_envio_controller.dart` (nuevos).
- `indrive_app/lib/features/cliente/presentation/screens/crear_envio_screen.dart`, `mis_envios_screen.dart`, `envio_detalle_screen.dart` (nuevos).
- `indrive_app/lib/features/cliente/presentation/screens/cliente_home_screen.dart` — botones de navegación a las pantallas nuevas.
- `indrive_app/lib/main_cliente.dart` — `ProviderScope`.
- `indrive_app/test/money_test.dart` — casos para `parseBobString`.

## Verificación

1. `flutter pub get`, `flutter analyze`, `flutter test`.
2. `firebase deploy --only firestore:rules`.
3. En el Samsung conectado (`main_cliente.dart`): crear un envío real (usa GPS real para origen), confirmar que aparece en "Mis Envíos" con estado `pendiente_ofertas`.
4. Sembrar manualmente una oferta de prueba en la consola de Firestore bajo `envios/{id}/ofertas/`, confirmar que aparece en el detalle del envío, y que "Aceptar" corre la transacción y deja el envío en `asignado`.
5. Apagar el wifi/datos del celular, crear un envío (debe encolarse offline), reactivar conexión, confirmar que se sincroniza solo (mismo ID, sin duplicados) — valida el primer handler real de `OfflineActionQueue`.

Al cerrar, explico las decisiones (por qué Riverpod sin codegen todavía, cómo la transacción de aceptar oferta se mantiene acotada, y la limitación temporal del destino manual) y espero autorización antes de Sprint 3.2.

## Contexto

Fase 2 del backlog ("Diseño de Modelos de Datos y Resiliencia"). Con Auth/RBAC ya funcionando (Sprint 1.2), este Sprint construye la **capa de datos e infraestructura de resiliencia** que usará toda la lógica de negocio de Fase 3 — sin construir todavía pantallas de negocio (eso es Sprint 3.1/3.2). Cubre, tal como pide el backlog: esquema de Envíos/Subastas en Firestore, manejo de dinero en BOB como enteros en centavos, y la cola offline idempotente con UUIDv4 + backoff exponencial.

De las reglas no negociables de `CLAUDE.md` que aplican directamente aquí:
- Dinero: enteros en centavos, nunca `double`.
- Vencimiento de subastas: **Server Timestamp**, nunca `DateTime.now()` del cliente — con tolerancia de gracia para la cola offline.
- Prevención de doble asignación de envíos: **transacción atómica de Firestore** validando estado previo.
- Cola offline: UUIDv4 por acción (idempotencia) + backoff exponencial.
- Firestore: siempre paginado, nunca sin cota.

## Decisión de diseño: vencimiento por Server Timestamp (detalle no trivial)

El SDK cliente de Firestore solo puede pedir "la hora actual del servidor" (`FieldValue.serverTimestamp()`), no "la hora del servidor + 10 minutos" — sumar un offset requiere el reloj del servidor, no el del cliente. Para cumplir la regla no negociable sin usar `DateTime.now()`, agrego un **trigger de Cloud Function** (`onDocumentCreated` en `envios/{envioId}`, reutilizando el proyecto `functions/` de Sprint 1.2) que calcula `expiraEn = createdAt (server) + 10 minutos` y lo escribe server-side. El cliente nunca fija `expiraEn`.

**Tolerancia de gracia offline**: al validar si aún se puede ofertar, se compara contra `expiraEn + 2 minutos` (constante), para que una oferta encolada offline que sincroniza poco después del cierre nominal no se rechace de inmediato.

## Esquema Firestore

```
/envios/{envioId}
  clienteId: string
  status: 'pendiente_ofertas' | 'asignado' | 'en_curso' | 'entregado' | 'cancelado'
  descripcion: string
  origen: GeoPoint, origenGeohash: string
  destino: GeoPoint
  montoOfertadoInicialCentavos: int
  repartidorAsignadoId: string | null
  createdAt: Timestamp (server)
  expiraEn: Timestamp (server, vía Cloud Function — ver arriba)

/envios/{envioId}/ofertas/{ofertaId}   (subcolección — permite paginar, evita arrays sin cota)
  repartidorId: string
  montoOfertadoCentavos: int
  status: 'pendiente' | 'aceptada' | 'rechazada'
  createdAt: Timestamp (server)
```

`origenGeohash` se calcula en el repositorio al crear el envío (paquete `dart_geohash`) — se guarda desde ya para que Fase 4 (radar geolocalizado) no requiera migración, pero **no** se implementa aún la query por radio/geohash (eso es Sprint 3.2/4.1).

## Prevención de doble asignación (transacción atómica)

`EnviosRepository.aceptarEnvioDirecto(envioId)`: usa `FirebaseFirestore.runTransaction` — lee el envío, verifica `status == 'pendiente_ofertas' && repartidorAsignadoId == null` dentro de la misma transacción, y solo entonces escribe `status: 'asignado'`, `repartidorAsignadoId: uid`. Las Firestore Rules validan la misma precondición sobre los datos leídos en la transacción, así que dos repartidores aceptando el mismo envío en paralelo: solo uno gana, el otro falla la transacción (se reintenta automáticamente y ve el nuevo estado). Esto es exactamente el patrón que exige `CLAUDE.md`, sin necesitar una Cloud Function adicional.

La elección de una oferta específica por parte del cliente (en vez de "primero en aceptar") queda como extensión para Sprint 3.x — fuera de alcance de este Sprint (solo infraestructura).

## Dinero: value object `Money`

`lib/shared/domain/value_objects/money.dart` — envuelve `int centavos`, con `+`, `-`, comparadores y `format()` (`"Bs. 15.00"`). La conversión a `double` solo existe para mostrar en pantalla, nunca se usa en cálculos. Todo el esquema de Envíos/Ofertas usa esta clase (o el `int` crudo en la capa Firestore, convertido a `Money` en el dominio).

## Cola offline idempotente

Infraestructura genérica en `lib/core/offline/` (uso previsto por Cliente/Repartidor; el panel Admin no la necesita, es un dashboard siempre-online — no se importa en `main_admin.dart`):
- `offline_action.dart`: modelo `OfflineAction { id (UUIDv4), type, payloadJson, attemptCount, nextAttemptAt }`.
- `offline_action_queue.dart`: persistida en SQLite (`sqflite`) para sobrevivir cierres de la app. `enqueue()` genera el UUID; `processPending()` recorre acciones vencidas, invoca el handler registrado por `type`, y en caso de fallo aplica backoff exponencial (`2^intentos` segundos, tope 5 min). Se dispara al reconectar (`connectivity_plus`) y al arrancar la app.
- **Idempotencia real**: el UUID de la acción se usa como ID del documento Firestore que la acción crea (ej. `envios/{actionId}` en vez de un ID autogenerado) — si el handler se reintenta tras un fallo de red que en realidad sí escribió, el segundo intento sobreescribe el mismo documento en vez de duplicarlo.
- Sin handlers concretos todavía (no hay pantallas de negocio aún) — se prueba con handlers falsos en tests unitarios. Sprint 3.x conectará acciones reales ("crear envío", "enviar oferta") a esta cola.

## Dependencias nuevas (`indrive_app/pubspec.yaml`)

- `uuid` — UUIDv4.
- `sqflite` + `path` — persistencia local de la cola (solo Android, no se usa en Admin/Web).
- `sqflite_common_ffi` (dev_dependency) — permite testear la cola en el host sin dispositivo.
- `connectivity_plus` — disparar `processPending()` al reconectar.
- `dart_geohash` — cálculo de geohash para `origenGeohash`.

## Archivos a crear/editar

- `indrive_app/functions/src/index.ts` — agrega `setEnvioExpiration` (trigger `onDocumentCreated`).
- `indrive_app/firestore.rules` — agrega reglas para `envios` y `envios/{id}/ofertas` (deny-by-default salvo lo descrito arriba).
- `indrive_app/lib/shared/domain/value_objects/money.dart`
- `indrive_app/lib/shared/domain/entities/envio.dart`, `oferta.dart`
- `indrive_app/lib/shared/data/envios_repository.dart`
- `indrive_app/lib/core/offline/offline_action.dart`, `offline_action_queue.dart`, `queue_database.dart`
- `indrive_app/test/money_test.dart`, `test/offline_action_queue_test.dart` (unitarios, sin necesidad de dispositivo)
- `indrive_app/pubspec.yaml` — nuevas dependencias

## Verificación

1. `flutter pub get`, `flutter analyze`.
2. `flutter test` — cubre `Money` (aritmética/formato) y `OfflineActionQueue` (enqueue, persistencia, backoff, idempotencia con handler falso) vía `sqflite_common_ffi`.
3. `firebase deploy --only firestore:rules,functions` — despliega la nueva regla y el trigger de expiración.
4. Prueba manual mínima (sin UI todavía): desde una consola Dart o un botón temporal, crear un `Envio` vía `EnviosRepository.crearEnvio(...)` y confirmar en la consola de Firestore que `expiraEn` aparece ~10 minutos después de `createdAt`, fijado por la Cloud Function (no por el cliente).

Al cerrar, explico las decisiones (por qué Cloud Function para `expiraEn`, por qué subcolección para ofertas, cómo la transacción previene doble asignación) y espero autorización antes de Sprint 3.1.
