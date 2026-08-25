import 'package:flutter/material.dart';

import '../../../../shared/widgets/session_status_view.dart';
import 'radar_screen.dart';

class RepartidorHomeScreen extends StatelessWidget {
  const RepartidorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('inDrive Entregas — Repartidor')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SessionStatusView(
              appLabel: 'App Repartidor — Villazón, Potosí',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RadarScreen()),
              ),
              child: const Text('Radar de ofertas'),
            ),
          ],
        ),
      ),
    );
  }
}
