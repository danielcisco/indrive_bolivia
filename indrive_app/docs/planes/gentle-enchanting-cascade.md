# Nombre/nick, identidad de la contraparte y fix de navegación al aceptar

## Contexto

Tras probar el header de usuario y el envío en curso, el usuario pidió 4 mejoras relacionadas:

1. El Cliente no tiene forma de saber **quién** (nombre) es el repartidor que aceptó su envío, ni el Repartidor quién es el Cliente al que le va a entregar — hoy `Envio` solo guarda `clienteId`/`repartidorAsignadoId` (IDs puros), y ninguna pantalla de detalle muestra algo legible de la contraparte.
2. Al tocar "Aceptar directo" en Repartidor, tras el éxito solo se hace `Navigator.pop()` ([envio_repartidor_detalle_screen.dart:70](indrive_app/lib/features/repartidor/presentation/screens/envio_repartidor_detalle_screen.dart:70)) — vuelve al Radar en vez de llevar al repartidor a ver su nueva entrega en "Mis entregas".
3. Cliente y Repartidor quieren registrar un **nombre y un nick** ("para usar más adelante") — hoy no existe ningún campo de nombre (decisión previa de esta sesión fue mostrar solo teléfono/email; el usuario ahora pide explícitamente agregar esto).

Estas 3 piden coordinarse: el nombre/nick que se registre es justamente lo que hace falta para resolver el punto 1 (mostrar identidad de la contraparte) y para completar el header ya construido.

**Decisión de diseño clave (privacidad):** `users/{uid}` hoy tiene `cedulaUrl` (foto de la Cédula) y `phoneNumber` — campos sensibles. Su regla de lectura es `isOwner(uid) || isAdmin()` — su propio dueño únicamente. Para que la contraparte (Cliente↔Repartidor) pueda ver nombre/nick/avatar sin exponer esos campos sensibles, **se crea una colección nueva `perfiles_publicos/{uid}`** con solo `nombre`, `nick`, `avatarId` — de lectura abierta a cualquier usuario autenticado, escritura solo por el dueño. Se escribe en batch junto con `users/{uid}` para que ambos queden sincronizados atómicamente. (El ⭐ rating queda fuera de este perfil público por ahora — mostrarlo ahí exigiría que la Cloud Function `actualizarRatingPromedio` también escriba en esta colección nueva; se puede sumar después si hace falta, no es parte de lo pedido hoy.)

## 1. Registro de nombre y nick (onboarding obligatorio, Cliente/Repartidor)

- **Firestore Rules** ([firestore.rules](indrive_app/firestore.rules), justo después del bloque `users/{uid}` en la línea 36): nueva colección
  ```
  match /perfiles_publicos/{uid} {
    allow read: if isSignedIn();
    allow write: if isOwner(uid) &&
      request.resource.data.keys().hasOnly(['nombre', 'nick', 'avatarId']);
    allow delete: if false;
  }
  ```
- [users_repository.dart](indrive_app/lib/shared/data/users_repository.dart): nuevo helper privado `_guardarPerfil(uid, campos)` que hace un `WriteBatch` con `set(..., merge:true)` sobre `users/{uid}` Y `perfiles_publicos/{uid}` a la vez. `actualizarAvatar` pasa a usarlo (así el avatar también queda sincronizado en el perfil público). Nuevo `actualizarPerfil(uid, {required nombre, required nick})` que también lo usa. Nuevo `obtenerMiPerfil(uid)` (lee de `users/{uid}`, igual que `obtenerMiRating`) y `obtenerPerfilPublico(uid)` (lee de `perfiles_publicos/{uid}`, para ver a un tercero).
- Nueva entidad chica `lib/shared/domain/entities/perfil_publico.dart`: `PerfilPublico(nombre, nick, avatarId)` + `fromMap`.
- [providers.dart](indrive_app/lib/shared/data/providers.dart): `miPerfilProvider` (`FutureProvider<PerfilPublico?>`, propio) y `perfilPublicoProvider` (`FutureProvider.family<PerfilPublico?, String>`, de un uid ajeno).
- Nueva pantalla `lib/shared/widgets/completar_perfil_screen.dart`: formulario simple (2 `TextField`, nombre y nick, no vacíos), botón "Guardar" que llama `actualizarPerfil` y luego un callback `onCompletado`.
- [auth_gate.dart](indrive_app/lib/shared/widgets/auth_gate.dart): nuevo parámetro `bool requierePerfilCompleto = false`. Justo antes de `return homeBuilder(context)` (línea 54), si `requierePerfilCompleto` es true, se envuelve en un `FutureBuilder` que consulta `obtenerMiPerfil(uid)`; si `nombre`/`nick` están vacíos, muestra `CompletarPerfilScreen` en vez de Home (mismo patrón que ya usa para `_RoleMismatchScreen`). `AuthGate` pasa a `StatefulWidget` para poder refrescar ese `Future` (`setState`) cuando `CompletarPerfilScreen` llama `onCompletado`.
- [main_cliente.dart](indrive_app/lib/main_cliente.dart) y [main_repartidor.dart](indrive_app/lib/main_repartidor.dart): agregan `requierePerfilCompleto: true` al `AuthGate`. Admin no se toca (no lo pidió el usuario, y no tiene sentido — usa email, no hay "nick" de por medio).

## 2. Mostrar nombre/nick en el header (reemplaza teléfono/email)

- [user_profile_header.dart](indrive_app/lib/shared/widgets/user_profile_header.dart): en vez de leer `FirebaseAuth.currentUser.phoneNumber/email` directo, usa `ref.watch(miPerfilProvider)`; si hay perfil, muestra `'${perfil.nombre} (@${perfil.nick})'`; si no (caso Admin, que nunca completa este perfil), cae al teléfono/email como hasta ahora. Se agrega que tocar el texto del nombre (solo cuando `mostrarRating` es true, ya que en la práctica distingue Cliente/Repartidor de Admin en los 3 usos actuales) abra un diálogo simple para editar nombre/nick reutilizando `actualizarPerfil` — sin esto, un error de tipeo en el onboarding quedaría fijo para siempre.

## 3. Identidad de la contraparte en el detalle del envío

- [envio_detalle_screen.dart](indrive_app/lib/features/cliente/presentation/screens/envio_detalle_screen.dart) (Cliente): cuando `envio.repartidorAsignadoId != null` (asignado/en_curso/entregado), una tarjeta chica arriba del mapa con `ref.watch(perfilPublicoProvider(repartidorAsignadoId))`: avatar + "Tu repartidor: nombre (@nick)".
- [envio_repartidor_detalle_screen.dart](indrive_app/lib/features/repartidor/presentation/screens/envio_repartidor_detalle_screen.dart) (Repartidor): mismo patrón con `perfilPublicoProvider(envio.clienteId)`, siempre visible (el cliente existe desde que se crea el envío) — "Cliente: nombre (@nick)".
- Reutilizan el mismo widget chico `AvatarCirculo(avatarId)` (extraído de la parte visual de `UserProfileHeader` a `lib/shared/widgets/avatar_circulo.dart` para no duplicar el `CircleAvatar` + `Icon`).

## 4. Fix: redirigir a "Mis entregas" tras aceptar directo

[envio_repartidor_detalle_screen.dart](indrive_app/lib/features/repartidor/presentation/screens/envio_repartidor_detalle_screen.dart), método `_aceptarDirecto` (línea 70): en vez de `Navigator.of(context).pop()`, hace `Navigator.of(context).popUntil((r) => r.isFirst)` (vuelve hasta `RepartidorHomeScreen`, saltándose Radar y este detalle) y luego `Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MisEntregasScreen()))` — el repartidor cae directo en la lista con su nueva entrega ya asignada.

## Verificación

1. `flutter analyze` limpio.
2. `firebase deploy --only firestore:rules`.
3. Abrir Cliente o Repartidor con una cuenta que ya tenía sesión (sin nombre/nick todavía): debe aparecer `CompletarPerfilScreen` antes del Home. Completar y confirmar que entra normalmente. Cerrar y volver a abrir: ya no debe pedirlo de nuevo.
4. El header ahora muestra "Nombre (@nick)" en vez del teléfono/email.
5. Cliente crea un envío, Repartidor lo acepta directo: (a) Repartidor cae en "Mis entregas" automáticamente; (b) el detalle del Repartidor muestra el nombre/nick del Cliente; (c) el detalle del Cliente (una vez asignado) muestra el nombre/nick del Repartidor.
6. Commit.
