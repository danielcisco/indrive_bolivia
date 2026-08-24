import 'package:flutter/material.dart';

/// Tema visual compartido por las tres apps (Cliente, Repartidor, Admin).
///
/// Centralizado aquí para que un cambio de marca no requiera tocar cada
/// entry point por separado.
abstract final class AppTheme {
  static const Color _seedColor = Color(0xFF0B5FFF);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
      );
}
