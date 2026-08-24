import 'package:flutter/material.dart';

import '../../../../shared/widgets/session_status_view.dart';

class ClienteHomeScreen extends StatelessWidget {
  const ClienteHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('inDrive Entregas — Cliente')),
      body: const Center(
        child: SessionStatusView(appLabel: 'App Cliente — Villazón, Potosí'),
      ),
    );
  }
}
