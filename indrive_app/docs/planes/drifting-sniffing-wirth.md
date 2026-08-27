# Tests de Firestore Security Rules

## Contexto

De los 2 puntos de "v1" que elegiste, este es el de tests automatizados. Ya existían 20 tests de Dart (Money, cola offline, geohash del radar, filtro GPS) — corregí mi error de haber dicho que había cero. Lo que genuinamente falta, y donde más valor tiene agregar cobertura, son las **Firestore Security Rules**: esta sesión encontramos ahí bugs reales en producción (el `permission-denied` al subir la foto de Cédula por acceso directo a `role`/`isVerified` ausentes; la regla de `perfiles_publicos` recién agregada) — un test de reglas los habría atrapado antes de que llegaran a tu pantalla. Es la pieza de mayor apalancamiento: `firestore.rules` ya tiene ~10 bloques de reglas con lógica no trivial (prevención de doble asignación, inmutabilidad de campos por rol) y ningún test las cubre hoy.

Entorno verificado: Java 17, Node 22 y Firebase CLI 15.28.1 ya disponibles — el emulador de Firestore (que corre sobre JVM) debería funcionar sin la limitación de Gradle/Android que ya conocemos en este entorno (se confirma en el paso de verificación).

## Alcance

No exhaustivo — cubre las reglas de mayor riesgo/ya-golpeadas-por-bugs-reales, no las ~10 reglas completas de `envios`:
1. `users/{uid}`: create sin role/isVerified permitido, con ellos rechazado; update de campos nuevos (nombre/apellido/nick/avatarId/cedulaUrl) permitido cuando role/isVerified/isActive todavía no existen (el bug real de esta sesión) y cuando ya existen; update que intenta cambiar role/isVerified/isActive rechazado; read solo dueño/admin.
2. `perfiles_publicos/{uid}`: read abierto a cualquier autenticado; write del dueño con solo los 4 campos permitidos; write con un campo extra rechazado; write de otro uid rechazado.
3. `envios/{envioId}`: create válido por el cliente dueño; create con otro clienteId rechazado; un repartidor verificado acepta un envío pendiente (→ asignado); un SEGUNDO repartidor intentando aceptar el mismo envío después de que ya quedó asignado es rechazado (la prevención de doble asignación — la regla de seguridad más crítica del proyecto según CLAUDE.md); un repartidor NO verificado no puede aceptar.

## Dónde vive

Carpeta nueva `firestore-tests/` en la raíz del proyecto (sibling de `functions/`, no adentro — esto no es código de Cloud Functions ni se despliega con ellas):
- `firestore-tests/package.json`: `@firebase/rules-unit-testing` + `vitest` (liviano, sin config extra).
- `firestore-tests/rules.test.ts`: los casos de arriba, usando `initializeTestEnvironment` apuntando a `../firestore.rules`.
- `firestore-tests/vitest.config.ts` mínimo.

[firebase.json](indrive_app/firebase.json): agrega bloque `"emulators": { "firestore": { "port": 8080 } }` (necesario para que `firebase emulators:exec` levante el emulador que los tests usan).

## Cómo se corren

`firebase emulators:exec --only firestore "cd firestore-tests && npm test"` desde la raíz de `indrive_app` — levanta el emulador, corre los tests contra él, lo apaga solo. No requiere tocar el proyecto real de Firebase (los datos de prueba viven solo en el emulador, en memoria).

## Verificación

1. Confirmar que `firebase emulators:exec --only firestore ...` efectivamente levanta el emulador en este entorno (Java ya confirmado disponible) — si falla por alguna razón de sandbox, se documenta como limitación conocida, igual que Gradle.
2. Los ~15-18 casos de arriba en verde.
3. Confirmar que el caso de doble asignación falla en rojo si se comenta la precondición `resource.data.repartidorAsignadoId == null` en `firestore.rules` (prueba de que el test realmente protege esa regla, no solo pasa por casualidad).
4. No se toca ningún test de Dart existente ni `firestore.rules` en sí — esto es puro test nuevo.
