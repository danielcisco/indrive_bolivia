import 'package:flutter/material.dart';

class RepartidorHomeScreen extends StatelessWidget {
  const RepartidorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('inDrive Entregas — Repartidor')),
      body: const Center(
        child: Text('App Repartidor — Villazón, Potosí'),
      ),
    );
  }
}
