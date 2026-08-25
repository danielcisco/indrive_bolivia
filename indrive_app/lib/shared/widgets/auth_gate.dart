import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Decide entre pantalla de login y pantalla principal según el estado de
/// sesión de Firebase Auth, y valida que el rol de la cuenta coincida con
/// [expectedRole] — sin esto, una cuenta de un rol podía iniciar sesión en
/// la app de otro rol (ej. Repartidor entrando a la app Cliente) y ver su
/// UI, aunque las Firestore Rules ya bloqueen las escrituras indebidas.
/// Compartido por las 3 apps para no triplicar el mismo `StreamBuilder`.
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.loginBuilder,
    required this.homeBuilder,
    required this.expectedRole,
  });

  final WidgetBuilder loginBuilder;
  final WidgetBuilder homeBuilder;
  final String expectedRole;

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
          return loginBuilder(context);
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
            if (role != null && role != expectedRole) {
              return _RoleMismatchScreen(
                expectedRole: expectedRole,
                actualRole: role,
              );
            }
            return homeBuilder(context);
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
