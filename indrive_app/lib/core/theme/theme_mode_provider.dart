import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _clavePreferenciaTema = 'tema_preferido';

/// Tema elegido a mano por el usuario (Claro/Oscuro/Sistema), persistido
/// localmente — arranca en `ThemeMode.system` mientras carga la
/// preferencia guardada, así que el primer frame nunca parpadea a un
/// tema distinto del que ya se ve.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _cargar();
    return ThemeMode.system;
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_clavePreferenciaTema);
    final modo = ThemeMode.values.firstWhere(
      (m) => m.name == guardado,
      orElse: () => ThemeMode.system,
    );
    state = modo;
  }

  Future<void> cambiar(ThemeMode modo) async {
    state = modo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clavePreferenciaTema, modo.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
