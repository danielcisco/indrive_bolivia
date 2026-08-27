# Resolución de pendientes técnicos (post Sprint 5.1)

## Contexto

Con Fases 1-5 cerradas, quedaban 6 pendientes anotados en sprints anteriores. Se investigó el pendiente de "migración Firebase" y resultó ser mucho más grande de lo anotado (Riverpod 2→3 rompe la API de los 6 controllers existentes, más 8 paquetes Firebase un major detrás) — el usuario decidió explícitamente sacarlo de este lote y tratarlo como su propio sprint aislado más adelante.

Este plan cubre los **4 pendientes restantes**, hechos juntos porque comparten una causa raíz: el `applicationId` compartido bloquea literalmente poder tener Cliente y Repartidor instalados a la vez en un dispositivo, que es requisito para probar tanto el tracking en vivo como el Foreground Service.

1. `applicationId` compartido (bloquea instalar Cliente+Repartidor juntos) + renombrar desde `com.example.indrive_app`
2. Robustez del Foreground Service (recuperación tras muerte del proceso, auto-stop si el envío deja de estar `en_curso`)
3. `FullScreenIntent` en notificaciones críticas de ofertas
4. Verificación manual del tracking en vivo en la app Cliente (desbloqueada por el punto 1)

## Diseño

### 1. Product flavors + applicationId real (resuelve pendientes #1 y #6 originales)

Hoy `android/app/build.gradle.kts` tiene un solo `applicationId = "com.example.indrive_app"` para las 3 apps. Solo Cliente y Repartidor generan APK real (Admin es Flutter Web puro, nunca se instala) — por eso solo hacen falta **2 flavors**, no 3.

- **IDs nuevos**: `bo.villazon.indriveentregas.cliente` / `bo.villazon.indriveentregas.repartidor`. `namespace` (paquete interno Kotlin) se deja como está — es un detalle de compilación sin visibilidad externa, cambiarlo no es parte de lo pedido.
- **`android/app/build.gradle.kts`**: agrega `flavorDimensions("app")` + bloque `productFlavors { cliente {...}; repartidor {...} }`, cada uno fijando su propio `applicationId`. Se corre con `flutter run --flavor cliente -t lib/main_cliente.dart` / `--flavor repartidor -t lib/main_repartidor.dart`.
- **Firebase**: se registran 2 apps Android nuevas en el proyecto `indrive-entregas-villazon` vía Firebase CLI (`firebase apps:create ANDROID -a <packageName> ...` — comando no interactivo, lo corro yo con confirmación tuya antes, mismo criterio que el deploy de la función). El `google-services.json` en `android/app/` pasa a tener 2 bloques `client` (uno por `package_name`) — el plugin de Google Services elige el correcto según qué flavor se esté compilando, un solo archivo alcanza.
- **`lib/firebase_options.dart`**: el `android` único se reemplaza por `androidCliente` y `androidRepartidor` (cada uno con su propio `appId`/`apiKey` reales de Firebase). El caso `TargetPlatform.android` de `currentPlatform` pasa a lanzar un error explícito ("usar androidCliente/androidRepartidor explícitamente") en vez de apuntar a un default ambiguo.
- **`lib/core/observability/app_bootstrap.dart`**: `bootstrapApp()` gana un parámetro `FirebaseOptions? options` (default `null` → sigue usando `currentPlatform`, así Admin/Web no cambia). `main_cliente.dart`/`main_repartidor.dart` pasan explícitamente `DefaultFirebaseOptions.androidCliente`/`.androidRepartidor`.
- **`lib/core/tracking/background_location_service.dart`**: el `Firebase.initializeApp()` del isolate de background (hoy usa `currentPlatform`) pasa a usar `DefaultFirebaseOptions.androidRepartidor` explícito — este archivo es inherentemente solo-Repartidor, no hay ambigüedad.
- La app Firebase vieja (`com.example.indrive_app`) queda huérfana en el proyecto — Firebase CLI no tiene comando de borrado; se puede eliminar a mano desde Console si se quiere, no bloquea nada.

### 2. Robustez del Foreground Service (`lib/core/tracking/background_location_service.dart`)

Dos gaps concretos sobre `onStartTracking`:

- **Recuperación tras muerte del proceso**: si Android mata y reinicia el servicio (`autoStart`/`START_STICKY` del plugin), el isolate nuevo no tiene `envioId` porque nadie volvió a invocar `setEnvioId` desde la UI. Al arrancar, si no llega `setEnvioId` en un plazo corto, se consulta `EnviosRepository.listarEntregasDeRepartidor` del usuario autenticado (ya existe, Sprint 4.1b) filtrando `status == enCurso` para recuperar el envío activo y retomar el tracking solo.
- **Auto-stop si el envío deja de estar `en_curso`**: hoy el único freno es que el repartidor toque "Marcar como entregado" en la UI. Se agrega una suscripción a `EnviosRepository.streamEnvio(envioId)` (ya existe, Sprint 4.1b) dentro del propio isolate — si el status deja de ser `enCurso` por cualquier vía, se cancela la suscripción de posición y se detiene el servicio solo.

### 3. FullScreenIntent (`lib/core/notifications/fcm_service.dart` + manifest)

- `android/app/src/main/AndroidManifest.xml`: agrega `<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />`.
- `_mostrarNotificacionLocal` en `fcm_service.dart`: agrega `fullScreenIntent: true` y `category: AndroidNotificationCategory.call` a `AndroidNotificationDetails` del canal `ofertas_alta_prioridad`, y un `onDidReceiveNotificationResponse` que navega a `RadarScreen` (ya existe) al tocar la notificación.
- **Caveat real, no resoluble en código**: desde Android 14, `USE_FULL_SCREEN_INTENT` requiere que el usuario otorgue el permiso manualmente en Ajustes (no es un runtime prompt estándar) — esto se documenta en el propio commit/comentario, no se puede automatizar ni verificar por este medio (necesita dispositivo/emulador real).

### 4. Verificación tracking en vivo (Cliente) — manual, sin código nuevo

Una vez que Cliente y Repartidor tengan `applicationId` distintos, se pueden instalar ambos a la vez en el mismo emulador/dispositivo. Verificación guiada al final: crear envío en Cliente → aceptarlo y arrancar viaje en Repartidor → confirmar que el marcador se mueve solo en `EnvioDetalleScreen` (Cliente) sin refrescar manualmente.

## Archivos afectados

| Archivo | Cambio |
|---|---|
| `android/app/build.gradle.kts` | `flavorDimensions` + `productFlavors` (cliente/repartidor) |
| `android/app/google-services.json` | 2 bloques `client` (uno por flavor) |
| `lib/firebase_options.dart` | `android` → `androidCliente` + `androidRepartidor` |
| `lib/core/observability/app_bootstrap.dart` | `bootstrapApp({FirebaseOptions? options})` |
| `lib/main_cliente.dart`, `lib/main_repartidor.dart` | pasan sus `FirebaseOptions` explícitos |
| `lib/core/tracking/background_location_service.dart` | recuperación de estado + auto-stop + options explícitos |
| `lib/core/notifications/fcm_service.dart` | `fullScreenIntent`, `category`, tap-to-navigate |
| `android/app/src/main/AndroidManifest.xml` | permiso `USE_FULL_SCREEN_INTENT` |

Sin cambios en `firestore.rules` ni `pubspec.yaml` (no hay dependencias nuevas — se descartó la migración de versiones para este lote).

## Verificación

1. `flutter analyze` limpio.
2. Registrar los 2 apps Android en Firebase (con tu confirmación antes de correr el comando).
3. `flutter run --flavor cliente -t lib/main_cliente.dart -d <device>` y `--flavor repartidor -t lib/main_repartidor.dart -d <otro-device-o-emulador>` — confirmar que ambos instalan y arrancan sin colisión de `applicationId`.
4. Con ambos corriendo: flujo completo Cliente crea envío → Repartidor acepta e inicia viaje → confirmar marcador en vivo en Cliente (pendiente #2 del backlog original, cerrado acá).
5. Forzar (vía ADB `am force-stop` o similar) la muerte del proceso Repartidor mientras el viaje está en curso, reabrir la app, confirmar que el tracking se recupera solo.
6. Notificación de oferta nueva con la app Repartidor en background/pantalla bloqueada — confirmar que intenta full-screen (con la salvedad del permiso especial de Android 14 ya documentada).
7. Commits separados por concern (flavors/Firebase, robustez Foreground Service, FullScreenIntent) para que cada uno sea bisectable si algo falla — no un commit único.
