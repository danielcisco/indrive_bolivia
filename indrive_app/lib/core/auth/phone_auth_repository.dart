import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef VerificationCodeSent = void Function(String verificationId);
typedef PhoneAuthFailed = void Function(FirebaseAuthException error);

/// Envuelve el flujo de Firebase Phone Auth (teléfono + OTP) y la asignación
/// de rol post-login vía la Cloud Function `assignInitialRole`.
class PhoneAuthRepository {
  PhoneAuthRepository({FirebaseAuth? auth, FirebaseFunctions? functions})
    : _auth = auth ?? FirebaseAuth.instance,
      _functions =
          functions ??
          FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  Future<void> sendVerificationCode({
    required String phoneNumber,
    required VerificationCodeSent onCodeSent,
    required PhoneAuthFailed onFailed,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: onFailed,
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<UserCredential> confirmCode({
    required String verificationId,
    required String smsCode,
  }) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  /// Se llama justo después del primer login exitoso — tolerante a
  /// reintentos: la Cloud Function rechaza la llamada si el uid ya tiene
  /// un rol asignado (`already-exists`), lo cual pasa si el usuario
  /// alcanzó a completar este paso dos veces (la primera ya había
  /// funcionado) o si `AuthGate` reintenta el registro tras una falla a
  /// mitad de camino. En ese caso el resultado final es el que queríamos
  /// de todas formas (rol asignado), así que no es un error real.
  Future<void> assignInitialRole(String role) async {
    final callable = _functions.httpsCallable('assignInitialRole');
    try {
      await callable.call<Map<String, dynamic>>({'role': role});
    } on FirebaseFunctionsException catch (error) {
      if (error.code != 'already-exists') rethrow;
    }
    await _auth.currentUser?.getIdTokenResult(true);
  }
}
