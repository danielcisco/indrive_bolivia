import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Muestra rol/verificación leídos del ID token y un botón de cerrar
/// sesión. Compartido por las 3 pantallas Home para no triplicar el mismo
/// FutureBuilder de lectura de claims.
class SessionStatusView extends StatelessWidget {
  const SessionStatusView({super.key, required this.appLabel});

  final String appLabel;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return FutureBuilder<IdTokenResult>(
      future: user.getIdTokenResult(true),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }
        final claims = snapshot.data!.claims ?? const <String, dynamic>{};
        final role = claims['role'] as String? ?? 'sin rol asignado';
        final isVerified = claims['isVerified'] as bool? ?? false;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(appLabel),
            const SizedBox(height: 8),
            Text('Rol: $role'),
            Text('Verificado: $isVerified'),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: FirebaseAuth.instance.signOut,
              child: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );
  }
}
