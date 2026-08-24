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

  /// Se llama una sola vez, justo después del primer login exitoso.
  /// La Cloud Function rechaza la llamada si el usuario ya tiene un rol.
  Future<void> assignInitialRole(String role) async {
    final callable = _functions.httpsCallable('assignInitialRole');
    await callable.call<Map<String, dynamic>>({'role': role});
    await _auth.currentUser?.getIdTokenResult(true);
  }
}
