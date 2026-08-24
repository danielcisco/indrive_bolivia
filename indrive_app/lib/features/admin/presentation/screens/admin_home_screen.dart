import 'package:flutter/material.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('inDrive Entregas — Panel Admin')),
      body: const Center(
        child: Text('Panel de Administración — Villazón, Potosí'),
      ),
    );
  }
}
