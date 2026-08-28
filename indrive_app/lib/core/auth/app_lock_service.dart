import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Bloqueo local (huella + PIN de respaldo, sprint extra) — encima de la
/// sesión de Firebase Auth ya persistida, no en reemplazo del SMS: el
/// SMS sigue siendo la única verificación de identidad la primera vez
/// que un teléfono inicia sesión; esto es solo la llave para volver a
/// entrar rápido sin repetirlo.
///
/// El PIN se guarda como hash+salt en `flutter_secure_storage`
/// (Keystore/Keychain — un secreto, no una preferencia, por eso no usa
/// `SharedPreferences` como el resto de los flags simples de la app). La
/// huella nunca pasa por acá: `local_auth` delega la verificación
/// biométrica al sistema operativo, la app nunca ve ni guarda datos
/// biométricos.
class AppLockService {
  AppLockService({FlutterSecureStorage? storage, LocalAuthentication? localAuth})
    : _storage = storage ?? const FlutterSecureStorage(),
      _localAuth = localAuth ?? LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  static const _keyPinHash = 'app_lock_pin_hash';
  static const _keySalt = 'app_lock_pin_salt';
  static const _keyBiometriaHabilitada = 'app_lock_biometria_habilitada';
  static const _keySetupOfrecido = 'app_lock_setup_ofrecido';

  /// Si hay un PIN configurado, el bloqueo está activo — no hay un flag
  /// "activado" aparte que pueda desincronizarse del PIN mismo.
  Future<bool> tienePinConfigurado() async {
    return await _storage.read(key: _keyPinHash) != null;
  }

  /// Si ya se le ofreció configurar el bloqueo alguna vez — para no
  /// insistir con el mismo diálogo en cada apertura si lo saltó.
  Future<bool> yaSeOfrecioSetup() async {
    return await _storage.read(key: _keySetupOfrecido) == 'true';
  }

  Future<void> marcarSetupOfrecido() {
    return _storage.write(key: _keySetupOfrecido, value: 'true');
  }

  Future<void> configurarPin(String pin) async {
    final salt = _generarSalt();
    await _storage.write(key: _keySalt, value: salt);
    await _storage.write(key: _keyPinHash, value: _hashear(pin, salt));
  }

  Future<bool> verificarPin(String pin) async {
    final salt = await _storage.read(key: _keySalt);
    final hashGuardado = await _storage.read(key: _keyPinHash);
    if (salt == null || hashGuardado == null) return false;
    return _hashear(pin, salt) == hashGuardado;
  }

  /// Se llama al cerrar sesión — un PIN es un secreto local de ESTA
  /// cuenta en ESTE dispositivo, no debería sobrevivir a un cambio de
  /// cuenta (ej. el celular se presta a otra persona con otro número).
  Future<void> borrarTodo() async {
    await _storage.delete(key: _keyPinHash);
    await _storage.delete(key: _keySalt);
    await _storage.delete(key: _keyBiometriaHabilitada);
    await _storage.delete(key: _keySetupOfrecido);
  }

  Future<bool> biometriaHabilitada() async {
    return await _storage.read(key: _keyBiometriaHabilitada) == 'true';
  }

  Future<void> habilitarBiometria(bool habilitar) {
    return _storage.write(
      key: _keyBiometriaHabilitada,
      value: habilitar.toString(),
    );
  }

  Future<bool> biometriaDisponibleEnDispositivo() async {
    try {
      final soportado = await _localAuth.isDeviceSupported();
      final puedeChequear = await _localAuth.canCheckBiometrics;
      return soportado && puedeChequear;
    } catch (_) {
      return false;
    }
  }

  /// `stickyAuth: true` — si el usuario cambia de app a mitad del
  /// diálogo del sistema (ej. a mirar un SMS) y vuelve, retoma el mismo
  /// diálogo en vez de cancelar la autenticación sola.
  Future<bool> autenticarConBiometria() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Confirmá tu identidad para entrar',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  String _generarSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashear(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }
}
