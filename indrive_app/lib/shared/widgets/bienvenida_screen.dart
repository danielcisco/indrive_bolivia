import 'package:flutter/material.dart';

/// Primera pantalla que ve un usuario sin sesión — identifica claramente
/// en qué app está (Cliente/Repartidor) antes de pedir nada. "Registrarme"
/// y "Ya tengo cuenta" llevan al mismo flujo de teléfono+código (el propio
/// login ya distingue cuenta nueva vs existente vía `isNewUser`); estos
/// botones son solo de expectativa/copy, no cambian el comportamiento.
class BienvenidaScreen extends StatelessWidget {
  const BienvenidaScreen({
    super.key,
    required this.appLabel,
    required this.destino,
  });

  final String appLabel;
  final WidgetBuilder destino;

  void _continuar(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: destino));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_shipping_outlined, size: 64),
              const SizedBox(height: 16),
              Text(
                'App $appLabel',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              const Text('Villazón, Potosí'),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _continuar(context),
                  child: const Text('Registrarme'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _continuar(context),
                  child: const Text('Ya tengo cuenta'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
