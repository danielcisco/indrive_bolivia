import 'package:flutter/material.dart';

class ClienteHomeScreen extends StatelessWidget {
  const ClienteHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('inDrive Entregas — Cliente')),
      body: const Center(
        child: Text('App Cliente — Villazón, Potosí'),
      ),
    );
  }
}
