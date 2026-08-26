import 'package:flutter/material.dart';

/// Tema visual compartido por las tres apps (Cliente, Repartidor, Admin).
///
/// Centralizado aquí para que un cambio de marca no requiera tocar cada
/// entry point por separado. Pulido de UI (post sprint extra): agrega
/// `dark` y `ComponentTheme`s consistentes (botones, inputs, cards) — sin
/// esto cada pantalla heredaba el default crudo de Material, con botones
/// de ancho variable e inputs de una sola línea.
abstract final class AppTheme {
  static const Color _seedColor = Color(0xFF0B5FFF);

  static ThemeData get light => _construir(Brightness.light);

  static ThemeData get dark => _construir(Brightness.dark);

  static ThemeData _construir(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      // Solo el alto se fuerza a un mínimo consistente (48 = tap target
      // recomendado) — el ancho NO se fuerza a infinito acá: muchos
      // botones del proyecto son chicos a propósito (acciones dentro de
      // una Card, botones de diálogo "Sí"/"No"), y minWidth: infinity los
      // rompería sin importar dónde estén. Los botones que sí deben
      // ocupar todo el ancho (las acciones principales de cada pantalla)
      // lo hacen explícitamente con SizedBox(width: double.infinity, ...)
      // en su propio lugar.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
