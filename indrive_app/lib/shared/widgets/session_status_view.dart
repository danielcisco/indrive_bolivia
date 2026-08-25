import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Muestra rol/verificación leídos del ID token y un botón de cerrar
/// sesión. Compartido por las 3 pantallas Home.
///
/// Justo después del login, la Cloud Function que asigna el rol puede no
/// haber terminado todavía cuando esta pantalla se monta (el cambio de
/// estado de Auth dispara la navegación a Home antes de que termine esa
/// llamada) — por eso reintenta unas pocas veces automáticamente antes de
/// rendirse y mostrar un botón manual.
class SessionStatusView extends StatefulWidget {
  const SessionStatusView({super.key, required this.appLabel});

  final String appLabel;

  @override
  State<SessionStatusView> createState() => _SessionStatusViewState();
}

class _SessionStatusViewState extends State<SessionStatusView> {
  static const _maxIntentosAutomaticos = 3;
  static const _esperaEntreIntentos = Duration(seconds: 2);

  late Future<IdTokenResult> _future;
  int _intentos = 0;

  @override
  void initState() {
    super.initState();
    _future = _obtenerClaims();
  }

  Future<IdTokenResult> _obtenerClaims() async {
    final user = FirebaseAuth.instance.currentUser!;
    final resultado = await user.getIdTokenResult(true);
    final tieneRol = resultado.claims?['role'] != null;
    if (!tieneRol && _intentos < _maxIntentosAutomaticos) {
      _intentos++;
      await Future.delayed(_esperaEntreIntentos);
      return _obtenerClaims();
    }
    return resultado;
  }

  void _reintentarManual() {
    setState(() {
      _intentos = 0;
      _future = _obtenerClaims();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<IdTokenResult>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }
        final claims = snapshot.data!.claims ?? const <String, dynamic>{};
        final role = claims['role'] as String?;
        final isVerified = claims['isVerified'] as bool? ?? false;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.appLabel),
            const SizedBox(height: 8),
            Text('Rol: ${role ?? 'asignando...'}'),
            Text('Verificado: $isVerified'),
            const SizedBox(height: 16),
            if (role == null)
              TextButton(
                onPressed: _reintentarManual,
                child: const Text('Reintentar'),
              ),
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
