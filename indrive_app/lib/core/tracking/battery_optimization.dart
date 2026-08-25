import 'package:permission_handler/permission_handler.dart';

/// Onboarding obligatorio de CLAUDE.md: sin excluir la app de la
/// optimización de batería (Doze mode), fabricantes como Xiaomi/Samsung
/// pueden matar el Foreground Service de tracking en segundo plano.
abstract final class BatteryOptimization {
  static Future<bool> estaExcluida() async {
    return Permission.ignoreBatteryOptimizations.isGranted;
  }

  /// Dispara el diálogo del sistema para excluir la app. Devuelve true si
  /// quedó concedido (el usuario puede rechazarlo — no se fuerza).
  static Future<bool> solicitarExclusion() async {
    final estado = await Permission.ignoreBatteryOptimizations.request();
    return estado.isGranted;
  }
}
