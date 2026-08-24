import 'package:flutter/material.dart';

import '../../../../shared/widgets/session_status_view.dart';

class RepartidorHomeScreen extends StatelessWidget {
  const RepartidorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('inDrive Entregas — Repartidor')),
      body: const Center(
        child: SessionStatusView(
          appLabel: 'App Repartidor — Villazón, Potosí',
        ),
      ),
    );
  }
}
