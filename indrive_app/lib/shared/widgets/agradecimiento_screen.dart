import 'dart:async';

import 'package:flutter/material.dart';

/// Pantalla de cierre de cualquier registro (Sprint 18) — se muestra 5
/// segundos (o hasta que el usuario toque el botón) antes de entrar al
/// Home, en vez de que el registro simplemente "desaparezca" al guardar.
class AgradecimientoScreen extends StatefulWidget {
  const AgradecimientoScreen({super.key, required this.mensaje});

  final String mensaje;

  @override
  State<AgradecimientoScreen> createState() => _AgradecimientoScreenState();
}

class _AgradecimientoScreenState extends State<AgradecimientoScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 5), _cerrar);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _cerrar() {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E7D32),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '¡Gracias!',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.mensaje,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _cerrar,
                    child: const Text('Continuar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
