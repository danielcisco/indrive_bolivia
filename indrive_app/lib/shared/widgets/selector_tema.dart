import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_mode_provider.dart';

void mostrarSelectorTema(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final actual = ref.watch(themeModeProvider);
        return AlertDialog(
          title: const Text('Tema'),
          content: RadioGroup<ThemeMode>(
            groupValue: actual,
            onChanged: (modo) =>
                ref.read(themeModeProvider.notifier).cambiar(modo!),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<ThemeMode>(
                  title: Text('Claro'),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('Oscuro'),
                  value: ThemeMode.dark,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('Según el sistema'),
                  value: ThemeMode.system,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    ),
  );
}
