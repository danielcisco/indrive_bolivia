import 'package:flutter/material.dart';

/// Colores semánticos fijos (no roles del `ColorScheme`, que ya están
/// tomados por la marca) con variante clara/oscura explícita — un solo
/// lugar de verdad para "verde de éxito", "ámbar de alerta", etc, en vez
/// de que cada pantalla defina su propio tono a mano (y se olvide del
/// modo oscuro).
abstract final class ColoresSemanticos {
  static (Color, Color) exito(BuildContext context) => _par(
    context,
    claro: const Color(0xFF2E7D32),
    claroFondo: const Color(0xFFE3F2E5),
    oscuro: const Color(0xFF8FD9A8),
    oscuroFondo: const Color(0xFF1E3B26),
  );

  static (Color, Color) advertencia(BuildContext context) => _par(
    context,
    claro: const Color(0xFF8A5A00),
    claroFondo: const Color(0xFFFCEACB),
    oscuro: const Color(0xFFE8C066),
    oscuroFondo: const Color(0xFF3A2C10),
  );

  static (Color, Color) info(BuildContext context) => _par(
    context,
    claro: const Color(0xFF0B5FFF),
    claroFondo: const Color(0xFFE3ECFF),
    oscuro: const Color(0xFF9AB8FF),
    oscuroFondo: const Color(0xFF1B2C4D),
  );

  static (Color, Color) neutro(BuildContext context) => _par(
    context,
    claro: const Color(0xFF5F6368),
    claroFondo: const Color(0xFFE8E9EA),
    oscuro: const Color(0xFFC2C6CB),
    oscuroFondo: const Color(0xFF3A3C3F),
  );

  static (Color, Color) _par(
    BuildContext context, {
    required Color claro,
    required Color claroFondo,
    required Color oscuro,
    required Color oscuroFondo,
  }) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    return esOscuro ? (oscuro, oscuroFondo) : (claro, claroFondo);
  }
}
