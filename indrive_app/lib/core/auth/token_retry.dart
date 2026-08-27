import 'package:firebase_auth/firebase_auth.dart';

/// Reintenta [accion] una vez, forzando un ID token nuevo, si falla por
/// `permission-denied` (Sprint 9).
///
/// Cubre un caso real: un Custom Claim (`role: admin`, `isVerified`, etc.)
/// se actualiza en el servidor, pero el token que el cliente ya tiene en
/// caché sigue circulando tal cual hasta por ~1 hora — Firebase no invalida
/// tokens existentes cuando cambian los claims. Sin este reintento, una
/// acción administrativa (aprobar KYC, verificar pago, suspender cuenta)
/// fallaba con `permission-denied` hasta que el usuario cerraba sesión y
/// volvía a entrar a mano, sin ninguna pista de por qué.
Future<T> conReintentoDeToken<T>(Future<T> Function() accion) async {
  try {
    return await accion();
  } on FirebaseException catch (error) {
    if (error.code != 'permission-denied') rethrow;
    await FirebaseAuth.instance.currentUser?.getIdToken(true);
    return accion();
  }
}
