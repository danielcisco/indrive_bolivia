# Mover nombre/nick al login + fix del bug de setState

## Contexto

Dos problemas de la última entrega:

1. **Bug confirmado por captura**: al guardar en `CompletarPerfilScreen`, `AuthGate` truena con *"setState() callback argument returned a Future"*. Causa exacta en [auth_gate.dart](indrive_app/lib/shared/widgets/auth_gate.dart): `setState(() => _perfilCompletoFuture = _perfilEstaCompleto(user.uid))` — el cuerpo de esa flecha es una asignación cuyo valor es el `Future` devuelto por `_perfilEstaCompleto`, así que el closure completo tiene tipo de retorno `Future<bool>` en vez de `void`, y Flutter lo rechaza en runtime. El dato SÍ se guardó antes del crash (el `await actualizarPerfil(...)` corre antes de llamar `onCompletado`), así que "Daniel Gutierrez Montaño / kekes" y "Jose Antonio Flores / Zorro" ya están en Firestore.
2. **Pedido explícito del usuario**: nombre/nick deben pedirse "al momento de registrar" un Cliente/Repartidor nuevo, no en una pantalla aparte después. Confirmado con AskUserQuestion: mover los campos a la misma pantalla de login (paso del código SMS), en vez de la pantalla separada `CompletarPerfilScreen`.

Esto también resuelve gratis la queja de "no se identifica en qué app estamos": `ClienteLoginScreen`/`RepartidorLoginScreen` ya tienen `AppBar(title: Text('Ingresar como Cliente'/'Repartidor'))` — el problema era exclusivo de `CompletarPerfilScreen`, que no tenía ningún título de app. Al eliminar esa pantalla, el problema desaparece con ella.

**Señal para saber si es un registro nuevo**: `FirebaseAuth.signInWithCredential(...)` (usado tanto en `sendVerificationCode`'s `verificationCompleted` como en `confirmCode`) devuelve un `UserCredential` con `additionalUserInfo?.isNewUser` — `true` solo la primerísima vez que ese número de teléfono se autentica. `confirmCode` en [phone_auth_repository.dart](indrive_app/lib/core/auth/phone_auth_repository.dart:36-45) YA devuelve ese `UserCredential` (no se usa hoy) — no hace falta tocar el repositorio, solo leer ese campo en `PhoneLoginView`.

## Cambios

### 1. [phone_login_view.dart](indrive_app/lib/shared/widgets/phone_login_view.dart) — nuevo paso 3 condicional
Pasa a `ConsumerStatefulWidget` (para poder llamar `ref.read(usersRepositoryProvider).actualizarPerfil(...)`, mismo patrón que `CompletarPerfilScreen`).

- `_confirmCode()`: en vez de llamar `assignInitialRole` incondicionalmente tras confirmar el código, guarda el `UserCredential` y revisa `additionalUserInfo?.isNewUser`:
  - `false` (login de cuenta existente): comportamiento actual sin cambios — llama `assignInitialRole(widget.role)` y listo (`AuthGate` reacciona solo).
  - `true` (registro nuevo): en vez de `assignInitialRole`, pasa a un tercer estado (`_esRegistroNuevo = true`) que muestra dos `TextField` nuevos (Nombre, Nick) en la misma pantalla.
- Nuevo método `_completarRegistro()`: valida que ambos campos no estén vacíos, llama `ref.read(usersRepositoryProvider).actualizarPerfil(uid, nombre:, nick:)` y DESPUÉS `_repository.assignInitialRole(widget.role)` (mismo orden que ya usa `CompletarPerfilScreen` hoy, solo movido de archivo).

### 2. [auth_gate.dart](indrive_app/lib/shared/widgets/auth_gate.dart) — revertir al diseño simple
Vuelve a ser `StatelessWidget` (como antes de la entrega anterior): se quita `requierePerfilCompleto`, el `FutureBuilder` de perfil, `_perfilCompletoFuture`/`_uidDelPerfilVerificado` y el import de `CompletarPerfilScreen` — ya no hace falta ningún gate post-login, el nombre/nick se resuelven durante el registro mismo. Esto elimina el bug de raíz en vez de parchearlo.

### 3. Eliminar `lib/shared/widgets/completar_perfil_screen.dart`
Ya no lo referencia nadie tras el paso 2.

### 4. [main_cliente.dart](indrive_app/lib/main_cliente.dart) y [main_repartidor.dart](indrive_app/lib/main_repartidor.dart)
Quitar la línea `requierePerfilCompleto: true,` del `AuthGate(...)` (vuelve a la firma original de 3 parámetros).

### Cuentas viejas sin nombre/nick
Las que ya existían antes de esta función (y las que se crearon antes del fix, si alguna quedó sin completar por el bug) simplemente no tienen `nombre`/`nick` — el header ya cae al teléfono/email como fallback (`user_profile_header.dart`, sin cambios) y el usuario puede tocarlo para completarlo manualmente con el diálogo de edición que ya existe ahí. No hace falta backfill ni gate adicional para este caso.

Sin cambios en Firestore Rules (la regla de `perfiles_publicos/{uid}` ya desplegada sigue sirviendo igual) ni en `users_repository.dart`/`providers.dart` (los métodos `actualizarPerfil`/`obtenerMiPerfil`/`obtenerPerfilPublico` de la entrega anterior se reusan tal cual).

## Verificación

1. `flutter analyze` limpio.
2. Repartidor o Cliente con un número de teléfono **nuevo**: tras el código SMS, deben aparecer los campos Nombre/Nick en la misma pantalla (con "Ingresar como Cliente/Repartidor" visible arriba); al guardar, entra a Home sin error.
3. Con una cuenta **ya existente** (ej. las de este sprint): el login sigue funcionando igual que siempre, sin pedir nombre/nick de nuevo.
4. El header sigue mostrando "Nombre (@nick)" para las cuentas que ya lo tienen.
5. Commit.
