import 'package:flutter/material.dart';

import '../../../../shared/widgets/phone_login_view.dart';

class ClienteLoginScreen extends StatelessWidget {
  const ClienteLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ingresar como Cliente')),
      body: const PhoneLoginView(role: 'cliente'),
    );
  }
}
