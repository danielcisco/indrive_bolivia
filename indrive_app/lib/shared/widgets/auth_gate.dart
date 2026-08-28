import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/cerrar_sesion.dart';
import '../../core/auth/phone_auth_repository.dart';
import 'app_lock_gate.dart';
import 'registro_wizard_screen.dart';

/// Builder de la pantalla de "verificación pendiente" — recibe
/// [onVerificado] para que esa pantalla le avise a `AuthGate` que vuelva a
/// leer el claim `isVerified` (typedef aparte, no `WidgetBuilder`, porque
/// `AuthGate` vive en `shared/` y no puede importar una pantalla de
/// `features/repartidor/` directamente — mantiene la separación de Clean
/// Architecture del proyecto).
typedef VerificacionPendienteBuilder =
    Widget Function(BuildContext context, VoidCallback onVerificado);

/// Decide entre pantalla de login y pantalla principal según el estado de
/// sesión de Firebase Auth, y valida que el rol de la cuenta coincida con
/// [expectedRole] — sin esto, una cuenta de un rol podía iniciar sesión en
/// la app de otro rol (ej. Repartidor entrando a la app Cliente) y ver su
/// UI, aunque las Firestore Rules ya bloqueen las escrituras indebidas.
/// Compartido por las 3 apps para no triplicar el mismo `StreamBuilder`.
///
/// Si [requierePerfilCompleto] es true (Cliente/Repartidor, no Admin),
/// también exige `nombre`/`nick` en `users/{uid}` antes de mostrar Home.
/// En el camino feliz `PhoneLoginView` ya los pide dentro de
/// `RegistroWizardScreen` para cuentas nuevas y este gate ni se nota —
/// pero es la única red de seguridad real contra dos escenarios: la
/// carrera entre `authStateChanges()` (dispara apenas se confirma el
/// código SMS) y el guardado de nombre/nick (que corre después, en la
/// misma función async); y un wizard interrumpido a mitad de camino (red,
/// app cerrada) que dejó el registro sin terminar. En ambos casos, en vez
/// de mostrar Home a medio registrar, este gate vuelve a mostrar el mismo
/// wizard — no un formulario corto aparte — así el usuario retoma
/// exactamente los mismos pasos (foto, fecha de nacimiento, Cédula y,
/// para Repartidor, licencia/vehículo) en vez de terminar en Home con
/// datos de KYC incompletos.
///
/// [verificacionPendienteBuilder] (solo Repartidor): si el claim
/// `isVerified` es false, se muestra esa pantalla en vez de Home — antes,
/// un repartidor sin aprobar entraba igual al Radar y recién se enteraba
/// de que no podía aceptar/ofertar con un `permission-denied` confuso al
/// intentarlo.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({
    super.key,
    required this.loginBuilder,
    required this.homeBuilder,
    required this.expectedRole,
    this.requierePerfilCompleto = false,
    this.verificacionPendienteBuilder,
  });

  final WidgetBuilder loginBuilder;
  final WidgetBuilder homeBuilder;
  final String expectedRole;
  final bool requierePerfilCompleto;
  final VerificacionPendienteBuilder? verificacionPendienteBuilder;

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return widget.loginBuilder(context);
        }
        return FutureBuilder<IdTokenResult>(
          // Sin forzar refresh: justo después del registro el rol puede
          // tardar en propagarse (ver SessionStatusView) — un role == null
          // se trata como "todavía sin asignar", no como mismatch.
          future: user.getIdTokenResult(),
          builder: (context, tokenSnapshot) {
            if (!tokenSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final role = tokenSnapshot.data!.claims?['role'] as String?;
            if (role != null && role != widget.expectedRole) {
              return _RoleMismatchScreen(
                expectedRole: widget.expectedRole,
                actualRole: role,
              );
            }
            if (!widget.requierePerfilCompleto) {
              return widget.homeBuilder(context);
            }
            // Stream, no Future cacheado: el wizard corre en una ruta
            // aparte (empujada por PhoneLoginView, no por este fallback),
            // así que un Future capturado una sola vez por uid quedaba
            // stale para siempre — al volver acá con popUntil(isFirst)
            // este gate seguía mostrando "incompleto" con los datos de
            // ANTES del registro y volvía a construir el wizard desde
            // cero. Un stream sobre el documento se autoactualiza apenas
            // se escribe cualquier campo, sin depender de que alguien
            // recuerde refrescarlo a mano.
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, perfilSnapshot) {
                if (!perfilSnapshot.hasData) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final datos = perfilSnapshot.data!.data();
                final perfilCompleto =
                    datos != null &&
                    (datos['nombre'] as String?)?.isNotEmpty == true &&
                    (datos['apellido'] as String?)?.isNotEmpty == true &&
                    (datos['nick'] as String?)?.isNotEmpty == true;
                if (!perfilCompleto) {
                  return RegistroWizardScreen(
                    role: widget.expectedRole,
                    onCompletado: () =>
                        PhoneAuthRepository().assignInitialRole(
                          widget.expectedRole,
                        ),
                  );
                }
                final isVerified =
                    tokenSnapshot.data!.claims?['isVerified'] as bool? ??
                    false;
                if (widget.verificacionPendienteBuilder != null &&
                    !isVerified) {
                  return widget.verificacionPendienteBuilder!(
                    context,
                    () => setState(() {}),
                  );
                }
                // Bloqueo local con huella/PIN (sprint extra) — solo acá,
                // no en el bypass de Admin de más arriba: es un gate
                // pensado para el celular, no para el panel web.
                return AppLockGate(child: widget.homeBuilder(context));
              },
            );
          },
        );
      },
    );
  }
}

class _RoleMismatchScreen extends StatelessWidget {
  const _RoleMismatchScreen({
    required this.expectedRole,
    required this.actualRole,
  });

  final String expectedRole;
  final String actualRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Esta cuenta tiene el rol "$actualRole", no "$expectedRole".',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Cierra sesión e ingresa con una cuenta del rol correcto.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: cerrarSesionYBorrarBloqueo,
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
