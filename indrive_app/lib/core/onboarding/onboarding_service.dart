import 'package:shared_preferences/shared_preferences.dart';

/// Si ya se mostró la pantalla de onboarding de permisos + acuerdos —
/// mismo patrón que `AppLockService.yaSeOfrecioSetup()`, pero con
/// `SharedPreferences` en vez de `flutter_secure_storage`: esto es una
/// preferencia de "ya lo vio", no un secreto.
class OnboardingService {
  static const _claveCompletado = 'onboarding_completado';

  Future<bool> completado() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_claveCompletado) ?? false;
  }

  Future<void> marcarCompletado() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_claveCompletado, true);
  }
}
