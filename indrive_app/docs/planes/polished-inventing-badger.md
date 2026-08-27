# Diferido — KYC: subida real de foto de Cédula

## Contexto

Sprint 5.1 dejó la aprobación de KYC como un simple toggle de `isVerified`, sin evidencia real, porque no existía ningún flujo de captura de foto. Se decidió explícitamente tratarlo como su propio trabajo de seguimiento. Buena noticia encontrada al revisar: la infraestructura de Storage para esto **ya existe desde antes** y nunca se usó — `storage.rules` ya tiene `match /kyc/{uid}/{allPaths=**}` (dueño lee/escribe, admin lee), sin necesitar ningún cambio. El patrón completo (captura con `image_picker`, subida a Storage, mostrar la imagen en el panel Admin) ya está probado end-to-end con el comprobante QR del Sprint 6.1 — esto es la misma receta aplicada a un caso distinto.

## Diseño

### 1. Dónde sube la foto el Repartidor

No se agrega como paso obligatorio del registro (no tocar el login por teléfono). En vez de eso, `RepartidorHomeScreen` muestra un aviso/botón "Subir foto de tu Cédula" cuando la cuenta todavía no está verificada **y** todavía no subió ninguna foto — una vez subida, el aviso desaparece (aunque el admin no la haya aprobado todavía), para no insistir de más.

### 2. Datos — extender `UsersRepository`, no crear un repositorio nuevo

- `subirFotoCedula({required String uid, required File archivo})`: sube a `kyc/$uid/${uuid}.jpg` (mismo patrón que `EnviosRepository.subirComprobante`: `SettableMetadata(contentType: 'image/jpeg')` explícito, aprendido del bug de esta sesión), devuelve la download URL.
- `guardarCedulaUrl(uid, url)`: `users/{uid}.set({cedulaUrl: url}, merge: true)`. Sin cambios de Firestore Rules — la regla de `users/{uid}` ya permite al dueño escribir campos nuevos (solo fija `role`/`isVerified` como inmutables), confirmado leyendo la regla actual.
- `obtenerCedulaUrl(uid)`: fetch puntual, para decidir si `RepartidorHomeScreen` muestra el aviso.

### 3. Entidad Admin — extender `RepartidorKycPendiente`

Agrega `cedulaUrl: String?`. `KycPendingScreen` ya tiene el patrón de tarjeta con imagen (`PagosPendientesScreen` del Sprint 6.1) — se replica: si `cedulaUrl != null`, `Image.network(...)`; si no, texto "Todavía no subió la foto de su Cédula". El botón "Aprobar" sigue funcionando igual sin foto (mismo criterio ya decidido: es información para el admin, no un gate forzado por reglas).

### 4. Pantalla nueva — `SubirCedulaScreen` (Repartidor)

Calco de `ConfirmarEntregaScreen` sin el selector de método de pago: botón "Tomar foto" (`ImagePicker`, `imageQuality: 70`, `maxWidth: 1280` — mismo criterio de compresión), preview, botón "Subir". Al confirmar: sube + guarda la URL + vuelve a Home.

### 5. `RepartidorHomeScreen`

Pasa a `ConsumerWidget`. Nuevo provider compartido `miEstadoKycProvider` (`shared/data/providers.dart`): combina el claim `isVerified` del ID token con `obtenerCedulaUrl` de Firestore. Si `!isVerified && cedulaUrl == null`, muestra el botón; se invalida el provider al volver de `SubirCedulaScreen` para que el aviso desaparezca sin reiniciar la app.

## Archivos afectados

| Archivo | Cambio |
|---|---|
| `lib/shared/data/users_repository.dart` | + `subirFotoCedula`, `guardarCedulaUrl`, `obtenerCedulaUrl` |
| `lib/shared/data/providers.dart` | + `miEstadoKycProvider` |
| `lib/features/admin/domain/repartidor_kyc_pendiente.dart` | + `cedulaUrl` |
| `lib/features/admin/presentation/screens/kyc_pending_screen.dart` | muestra la foto |
| `lib/features/repartidor/presentation/screens/subir_cedula_screen.dart` | nuevo |
| `lib/features/repartidor/presentation/screens/repartidor_home_screen.dart` | aviso condicional |

Sin cambios en `firestore.rules` ni `storage.rules` — ambas ya cubren este caso.

## Verificación

1. `flutter analyze` limpio.
2. Registrar un repartidor nuevo (sin verificar) → confirmar que `RepartidorHomeScreen` muestra el aviso.
3. Subir la foto → confirmar que el aviso desaparece sin reiniciar la app.
4. Panel Admin → KYC → confirmar que se ve la foto → aprobar → confirmar que sigue funcionando igual que antes.
5. Commit.
