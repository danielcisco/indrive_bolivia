import 'package:flutter/material.dart';

/// Tema visual compartido por las tres apps (Cliente, Repartidor, Admin).
///
/// Centralizado aquí para que un cambio de marca no requiera tocar cada
/// entry point por separado.
///
/// Pulido de UI (sprint de rediseño): identidad inspirada en Starbucks —
/// un verde profundo (confianza, movimiento) + un dorado cálido como
/// acento, con Manrope como tipografía única en todos los pesos
/// (bundleada localmente como fuente variable: depender de
/// fonts.gstatic.com en tiempo de ejecución sería mala idea para la
/// conectividad real de la frontera). `ColorScheme.fromSeed` con
/// `secondaryKey` deriva un sistema tonal completo (ambos brillos, buen
/// contraste) a partir de esos dos colores en vez de fijar cada rol a
/// mano. `surface`/`surfaceContainerHigh` se pisan a mano con la crema
/// cálida de la maqueta — el algoritmo de Material, dejado solo, deriva
/// un gris con tinte verdoso en vez de esa crema, porque no conoce la
/// intención "fondo cálido tipo papel" detrás del seed.
abstract final class AppTheme {
  static const Color _brandTeal = Color(0xFF00704A);
  static const Color _brandAmber = Color(0xFFC6A664);
  static const String _fontFamily = 'Manrope';

  static const Color _cremaClara = Color(0xFFF2EEE4);
  static const Color _cremaClaraSuave = Color(0xFFFBFAF6);
  static const Color _cremaOscura = Color(0xFF17211D);
  static const Color _cremaOscuraSuave = Color(0xFF1E2A25);

  static ThemeData get light => _construir(Brightness.light);

  static ThemeData get dark => _construir(Brightness.dark);

  static ThemeData _construir(Brightness brightness) {
    // Dos paletas tonales independientes (una por seed) fusionadas en una
    // sola: `ColorScheme.fromSeed` en esta versión de Flutter no expone un
    // segundo seed para "secondary" directo, así que se deriva el ámbar
    // aparte y se toman sus tonos ya calculados (con buen contraste
    // garantizado en ambos brillos) para los roles secondary*.
    final baseTeal = ColorScheme.fromSeed(
      seedColor: _brandTeal,
      brightness: brightness,
    );
    final baseAmbar = ColorScheme.fromSeed(
      seedColor: _brandAmber,
      brightness: brightness,
    );
    final esOscuro = brightness == Brightness.dark;
    final colorScheme = baseTeal.copyWith(
      secondary: baseAmbar.primary,
      onSecondary: baseAmbar.onPrimary,
      secondaryContainer: baseAmbar.primaryContainer,
      onSecondaryContainer: baseAmbar.onPrimaryContainer,
      surface: esOscuro ? _cremaOscura : _cremaClara,
      surfaceContainerHigh: esOscuro ? _cremaOscuraSuave : _cremaClaraSuave,
    );
    final textTheme = _construirTextTheme(colorScheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      fontFamily: _fontFamily,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: colorScheme.surfaceTint,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),

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
          minimumSize: const Size(64, 52),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          side: BorderSide(color: colorScheme.outlineVariant, width: 1.4),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onSurfaceVariant,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.secondary,
        foregroundColor: colorScheme.onSecondary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error, width: 1.4),
        ),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        iconColor: colorScheme.onSurfaceVariant,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.secondaryContainer,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurfaceVariant,
        ),
        secondaryLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSecondaryContainer,
        ),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        thickness: 1,
        space: 32,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        actionTextColor: colorScheme.secondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        circularTrackColor: colorScheme.surfaceContainerHighest,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.secondary
              : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.secondaryContainer
              : null,
        ),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : null,
        ),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        selectedLabelTextStyle: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
        ),
        indicatorColor: colorScheme.secondaryContainer,
      ),
    );
  }

  static TextTheme _construirTextTheme(ColorScheme colorScheme) {
    const base = TextTheme();
    return base
        .copyWith(
          displayLarge: base.displayLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
          displayMedium: base.displayMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          headlineLarge: base.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          titleSmall: base.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          bodyLarge: base.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
          bodyMedium: base.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
          labelLarge: base.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          labelSmall: base.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        )
        .apply(fontFamily: _fontFamily);
  }
}
