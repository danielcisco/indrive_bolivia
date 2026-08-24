import 'package:flutter/material.dart';

import '../../../../shared/widgets/phone_login_view.dart';

class RepartidorLoginScreen extends StatelessWidget {
  const RepartidorLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ingresar como Repartidor')),
      body: const PhoneLoginView(role: 'repartidor'),
    );
  }
}
