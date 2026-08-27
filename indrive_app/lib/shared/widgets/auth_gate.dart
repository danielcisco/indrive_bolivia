import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import 'completar_perfil_screen.dart';

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
/// En el camino feliz `PhoneLoginView` ya los pide en la misma pantalla de
/// login para cuentas nuevas y este gate ni se nota — pero es la única
/// red de seguridad real contra la carrera entre `authStateChanges()`
/// (dispara apenas se confirma el código SMS) y el paso de nombre/nick
/// (que corre después, en la misma función async): sin este gate, esa
/// carrera podía mandar a Home sin haber guardado nombre/nick ni haber
/// terminado de asignar el rol.
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
  Future<bool>? _perfilCompletoFuture;
  String? _uidDelPerfilVerificado;

  Future<bool> _perfilEstaCompleto(String uid) async {
    final perfil = await ref.read(usersRepositoryProvider).obtenerMiPerfil(uid);
    return perfil != null &&
        perfil.nombre.isNotEmpty &&
        perfil.apellido.isNotEmpty &&
        perfil.nick.isNotEmpty;
  }

  void _refrescarPerfil(String uid) {
    // Body en bloque (no flecha): `setState` exige un callback que
    // devuelva void. `() => _x = _perfilEstaCompleto(uid)` es una
    // asignación que "devuelve" el Future asignado, así que Flutter
    // rechazaba ese closure en runtime — este fue el bug real reportado.
    setState(() {
      _perfilCompletoFuture = _perfilEstaCompleto(uid);
    });
  }

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
            if (_uidDelPerfilVerificado != user.uid) {
              _uidDelPerfilVerificado = user.uid;
              _perfilCompletoFuture = _perfilEstaCompleto(user.uid);
            }
            return FutureBuilder<bool>(
              future: _perfilCompletoFuture,
              builder: (context, perfilSnapshot) {
                if (!perfilSnapshot.hasData) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (perfilSnapshot.data == false) {
                  return CompletarPerfilScreen(
                    onCompletado: () => _refrescarPerfil(user.uid),
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
                return widget.homeBuilder(context);
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
                onPressed: FirebaseAuth.instance.signOut,
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
