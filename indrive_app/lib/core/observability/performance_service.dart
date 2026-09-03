import 'package:firebase_performance/firebase_performance.dart';

/// Traza custom de Firebase Performance alrededor de una operación async
/// (sprint de observabilidad) — un solo helper para los 3 flujos medidos
/// (crear envío, aceptar oferta, actualizar radar) en vez de repetir el
/// mismo start/stop try/finally en cada uno.
abstract final class PerformanceService {
  static Future<T> medir<T>(String nombre, Future<T> Function() trabajo) async {
    final trace = FirebasePerformance.instance.newTrace(nombre);
    await trace.start();
    try {
      final resultado = await trabajo();
      trace.putAttribute('resultado', 'ok');
      return resultado;
    } catch (e) {
      trace.putAttribute('resultado', 'error');
      rethrow;
    } finally {
      await trace.stop();
    }
  }
}
