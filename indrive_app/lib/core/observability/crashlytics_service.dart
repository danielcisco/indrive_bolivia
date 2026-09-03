import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Envuelve el reporte de errores a Firebase Crashlytics.
///
/// Crashlytics no soporta Flutter Web: en esa plataforma [initialize] es
/// un no-op, para que el panel de Admin (que compila a Web) no intente
/// registrar handlers que no tienen efecto ahí.
abstract final class CrashlyticsService {
  static Future<void> initialize() async {
    if (kIsWeb) return;

    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  /// Deja constancia de una transición de estado de negocio (sprint de
  /// observabilidad) — [envioId] y [extra] quedan como custom keys, así
  /// que no solo aparecen en el breadcrumb de este evento sino pegados a
  /// CUALQUIER crash posterior en la misma sesión, sin tener que
  /// reconstruir el contexto a mano.
  static void logEvento(
    String evento, {
    String? envioId,
    Map<String, String> extra = const {},
  }) {
    if (kIsWeb) return;
    if (envioId != null) {
      FirebaseCrashlytics.instance.setCustomKey('envio_id', envioId);
    }
    for (final entrada in extra.entries) {
      FirebaseCrashlytics.instance.setCustomKey(entrada.key, entrada.value);
    }
    final detalle = extra.entries.map((e) => '${e.key}=${e.value}').join(' ');
    FirebaseCrashlytics.instance.log(
      detalle.isEmpty ? evento : '$evento $detalle',
    );
  }
}
