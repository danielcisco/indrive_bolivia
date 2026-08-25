import 'package:flutter/material.dart';

import '../../../../shared/widgets/session_status_view.dart';
import 'mis_envios_screen.dart';

class ClienteHomeScreen extends StatelessWidget {
  const ClienteHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('inDrive Entregas — Cliente')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SessionStatusView(
              appLabel: 'App Cliente — Villazón, Potosí',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MisEnviosScreen()),
              ),
              child: const Text('Mis envíos'),
            ),
          ],
        ),
      ),
    );
  }
}
