import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Decide entre pantalla de login y pantalla principal según el estado de
/// sesión de Firebase Auth. Compartido por las 3 apps para no triplicar el
/// mismo `StreamBuilder`.
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.loginBuilder,
    required this.homeBuilder,
  });

  final WidgetBuilder loginBuilder;
  final WidgetBuilder homeBuilder;

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
        return snapshot.data == null
            ? loginBuilder(context)
            : homeBuilder(context);
      },
    );
  }
}
