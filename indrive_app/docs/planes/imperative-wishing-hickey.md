# Sprint 7.1 — Pruebas y Despliegue en Producción

## Contexto

Última fase del backlog original. Tres entregables: firma de release real (hoy `release` usa las claves de debug — `signingConfig = signingConfigs.getByName("debug")`, con un TODO explícito en el código), compilación `--split-per-abi`, y el panel Admin desplegado en un hosting real (hoy solo corre en `localhost` vía `flutter run -d web-server`). La keystore de producción la generás vos mismo/a (decisión ya tomada) — es una clave irreversible si se pierde/filtra, no algo que deba pasar por este chat.

Las "pruebas de campo simuladas" ya están sustancialmente cubiertas por todo lo que probamos hoy en dispositivo real (envío→radar→viaje→entrega con ambos métodos de pago→calificación, KYC, mapa en vivo) — este sprint no reinventa esos casos, agrega un smoke test final sobre el **APK de release firmado específicamente** (es un build distinto al debug que veníamos usando, vale la pena confirmar que también arranca bien).

## Diseño

### 1. Keystore y firma de release (`android/app/build.gradle.kts`)

Guía para que generes la keystore vos (comando exacto en la sección de Verificación). Se agrega al `build.gradle.kts` el patrón oficial de Flutter para release signing, con el mismo estilo que ya usa el archivo para `MAPS_API_KEY` (`Properties()` + `FileInputStream` sobre un archivo gitignoreado):

- Lee `android/key.properties` (nuevo, ya cubierto por `.gitignore` — confirmé que `key.properties` y `**/*.jks` ya están ahí desde el scaffold inicial).
- `signingConfigs { create("release") { ... } }` poblado desde ese archivo.
- `buildTypes.release.signingConfig` usa `"release"` si `key.properties` existe, si no cae a `"debug"` (igual que hoy) — así el build no se rompe para quien todavía no generó la keystore.
- Una sola keystore/alias compartida por los 2 flavors (cliente/repartidor) — no hace falta una por app.

No se activa minificación/R8 (`minifyEnabled`) — el backlog pide específicamente `--split-per-abi`, no ofuscación; agregarla es una superficie de riesgo nueva (reflection de Firebase, iconos de notificación) no pedida para este sprint.

### 2. Panel Admin → Firebase Hosting

- `firebase.json` gana un bloque `"hosting": { "public": "build/web", "ignore": [...] }`.
- Build: `flutter build web -t lib/main_admin.dart` (genera `build/web`).
- Deploy: `firebase deploy --only hosting` — lo corro yo con tu confirmación antes, mismo criterio que los deploys anteriores.
- **Prerrequisito manual, mismo patrón que la key de Maps Web del Sprint 5.1**: la key de Maps ya está restringida por HTTP referrer a `localhost:*` únicamente — hay que agregarle el dominio real del Hosting (`indrive-entregas-villazon.web.app` y `.firebaseapp.com`) en Google Cloud Console, si no el mapa del panel no va a cargar ahí aunque el resto de la app sí.

### 3. Build de release `--split-per-abi`

Genera APKs separados por arquitectura (arm64-v8a, armeabi-v7a, x86_64) en vez de un único APK gordo — comandos exactos en Verificación. Dado el problema de Gradle/loopback que tengo en este entorno (confirmado varias veces esta sesión: cualquier comando que yo dispare hacia Gradle falla, mientras que corrido a mano en tu propia terminal funciona), **estos builds los tenés que correr vos** — te dejo los comandos exactos.

## Archivos afectados

| Archivo | Cambio |
|---|---|
| `android/app/build.gradle.kts` | `signingConfigs["release"]` leyendo `key.properties` |
| `android/key.properties` | nuevo, lo creás vos (gitignoreado) |
| `firebase.json` | + bloque `hosting` |

Sin cambios en Dart/Firestore/Storage — este sprint es infraestructura de build y despliegue, no funcionalidad nueva.

## Verificación

1. **Generar la keystore** (en tu terminal, desde `D:\indrive_bolivia\indrive_app\android\app`):
   ```
   keytool -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   Va a pedirte una contraseña para la keystore y datos tipo nombre/organización — elegís vos, no me los pases a mí.
2. Crear `android/key.properties` con `storePassword`, `keyPassword`, `keyAlias=upload`, `storeFile=upload-keystore.jks`.
3. `flutter build apk --flavor cliente -t lib/main_cliente.dart --release --split-per-abi` y lo mismo con `repartidor` — confirmar que compilan (antes fallaban con `signingConfig` de debug, ahora deberían usar la keystore real).
4. Instalar uno de los APK de release resultantes en el teléfono y correr un smoke test corto (login, ver Radar/Mis envíos) — confirma que el build de release en sí arranca bien, más allá de que ya probamos toda la lógica en debug.
5. `flutter build web -t lib/main_admin.dart` + `firebase deploy --only hosting` (lo corro yo, con tu confirmación).
6. Actualizar la restricción de la key de Maps Web en Google Cloud Console con el dominio real del Hosting.
7. Commit final del sprint.
