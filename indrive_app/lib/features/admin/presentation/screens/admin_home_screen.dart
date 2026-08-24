import 'package:flutter/material.dart';

import '../../../../shared/widgets/session_status_view.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('inDrive Entregas — Panel Admin')),
      body: const Center(
        child: SessionStatusView(
          appLabel: 'Panel de Administración — Villazón, Potosí',
        ),
      ),
    );
  }
}
