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
}
