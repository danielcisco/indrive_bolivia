# Pantalla de Bienvenida + registro en 4 pasos (nombres, apellidos, nick, carnet)

## Contexto

Rediseño explícito del flujo de entrada, pedido por el usuario en 4 pasos:
1. Bienvenida (identifica la app: Cliente/Repartidor) con botones "Registrarme" / "Ya tengo cuenta".
2. Teléfono + "Enviar código" (ya existe, con el prefijo `+591` fijo agregado en la entrega anterior).
3. Código SMS.
4. Nombres, apellidos, nick y foto de carnet — recién ahí entra a su Home.

Decisiones ya confirmadas con el usuario (AskUserQuestion):
- La foto de carnet en el paso 4 aplica a **ambos roles** (Cliente también), no solo Repartidor.
- Cliente **no** espera aprobación del Admin — entra directo a su Home apenas termina el paso 4; la foto queda archivada para revisión futura si hace falta, sin bloquear nada. Repartidor sigue esperando aprobación del Admin como hasta ahora (maneja entregas y dinero de terceros).
- "Registrarme" y "Ya tengo cuenta" llevan al mismo flujo teléfono+código — la diferencia es solo de expectativa/copy, sin mensajes de error por "botón equivocado". Si resulta que el número ya tenía cuenta, el paso 4 se salta automáticamente (mismo criterio `isNewUser` que ya existe).

## Qué se reusa tal cual

- `PhoneAuthRepository.confirmCode` ya devuelve el `UserCredential` con `additionalUserInfo?.isNewUser` — el mismo criterio ya implementado para decidir si se pide el paso 4.
- `UsersRepository.subirFotoCedula`/`guardarCedulaUrl` ([users_repository.dart](indrive_app/lib/shared/data/users_repository.dart)) — mismo patrón de captura que ya usa `SubirCedulaScreen` (`ImagePicker(source: camera, imageQuality:70, maxWidth:1280)`), reusado tal cual para el paso 4 de ambos roles (la ruta de Storage `kyc/{uid}/` y su regla ya no distinguen rol, sirven igual para Cliente).
- `AuthGate` con `requierePerfilCompleto` y `CompletarPerfilScreen` (red de seguridad para la carrera `authStateChanges`/cuentas viejas) — se actualizan para incluir `apellido`, sin cambiar su mecánica.
- `RepartidorHomeScreen`'s aviso "Subir foto de tu Cédula" + `SubirCedulaScreen` — se dejan intactos, como red de seguridad para cuentas creadas antes de este cambio que nunca subieron la foto.

## Cambios

### 1. Campo `apellido` nuevo, en paralelo a `nombre`/`nick`
- [firestore.rules](indrive_app/firestore.rules): la regla de `perfiles_publicos/{uid}` pasa a `hasOnly(['nombre', 'apellido', 'nick', 'avatarId'])`.
- [perfil_publico.dart](indrive_app/lib/shared/domain/entities/perfil_publico.dart): agrega `apellido`.
- [users_repository.dart](indrive_app/lib/shared/data/users_repository.dart): `actualizarPerfil` gana el parámetro `required String apellido`.
- En todos los lugares que hoy muestran `perfil.nombre` como nombre completo ([user_profile_header.dart](indrive_app/lib/shared/widgets/user_profile_header.dart), la tarjeta de contraparte en [envio_detalle_screen.dart](indrive_app/lib/features/cliente/presentation/screens/envio_detalle_screen.dart) y en [envio_repartidor_detalle_screen.dart](indrive_app/lib/features/repartidor/presentation/screens/envio_repartidor_detalle_screen.dart)) pasan a mostrar `'${perfil.nombre} ${perfil.apellido} (@${perfil.nick})'`.
- [completar_perfil_screen.dart](indrive_app/lib/shared/widgets/completar_perfil_screen.dart): agrega el campo Apellido (texto, igual que nombre/nick) — se mantiene sin captura de foto, es la red de seguridad para un caso raro, no la vía principal.

### 2. Pantalla de Bienvenida nueva
`lib/shared/widgets/bienvenida_screen.dart` — compartida por Cliente/Repartidor (mismo criterio que `PhoneLoginView`): título de la app bien visible ("App Cliente — Villazón, Potosí" / "App Repartidor — ..."), dos botones ("Registrarme", "Ya tengo cuenta") que hacen exactamente lo mismo: `Navigator.push` a la pantalla de login existente (`ClienteLoginScreen`/`RepartidorLoginScreen`, sin cambios).

[main_cliente.dart](indrive_app/lib/main_cliente.dart) y [main_repartidor.dart](indrive_app/lib/main_repartidor.dart): `AuthGate.loginBuilder` pasa de `(_) => const ClienteLoginScreen()` a `(_) => BienvenidaScreen(appLabel: 'Cliente', destino: (_) => const ClienteLoginScreen())` (mismo patrón para Repartidor).

### 3. Paso 4 en `PhoneLoginView`: agrega apellido + foto de carnet, para ambos roles
[phone_login_view.dart](indrive_app/lib/shared/widgets/phone_login_view.dart) — el bloque `if (_esRegistroNuevo)` (líneas 133-157 hoy) gana:
- `_apellidoController` (nuevo `TextField`, junto a nombre).
- Captura de foto: mismo patrón que `SubirCedulaScreen` (`XFile? _fotoCarnet`, botón "Tomar foto"/"Repetir foto", preview con `Image.file`).
- El botón "Continuar" queda deshabilitado hasta que `_fotoCarnet != null` (igual que `SubirCedulaScreen` deshabilita "Subir" sin foto).
- `_completarRegistro()` pasa a: validar nombre+apellido+nick no vacíos y foto tomada → `subirFotoCedula` → `actualizarPerfil(nombre:, apellido:, nick:)` → `guardarCedulaUrl` → `assignInitialRole(widget.role)`. Mismo manejo de errores ya existente (try/catch con `_errorMessage`).

Sin cambios de alcance para Repartidor más allá de esto: sigue sin poder operar hasta que Admin apruebe (`KycPendingScreen` no cambia, sigue filtrando solo por `role == 'repartidor'`). Para Cliente, la foto sube a `kyc/{uid}/` igual, pero nada la bloquea — entra a Home apenas `assignInitialRole` resuelve, mismo comportamiento reactivo de `AuthGate` que ya existe hoy.

## Verificación

1. `flutter analyze` limpio.
2. `firebase deploy --only firestore:rules` (por el campo `apellido` en `perfiles_publicos`).
3. Abrir Cliente con un número de prueba nuevo: ve la Bienvenida con "App Cliente" bien visible → teléfono → código → nombres/apellidos/nick/foto → entra directo a su Home (sin esperar nada).
4. Abrir Repartidor con un número de prueba nuevo: mismo flujo, pero al terminar el paso 4 entra a Home mostrando "Rol: repartidor" pero sin verificar — el Admin lo ve en "Verificación KYC" con su foto ya cargada (la misma que subió en el registro) y puede aprobarlo.
5. El header y las tarjetas de "Tu repartidor"/"Cliente" muestran nombre + apellido + nick correctamente.
6. Commit.
