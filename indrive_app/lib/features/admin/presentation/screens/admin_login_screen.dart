import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/soporte_whatsapp.dart';

/// Login de staff con email/contraseña. No hay auto-registro: las cuentas
/// admin se crean manualmente (ver functions/scripts/setAdminClaim.ts).
class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (error) {
      setState(
        () => _errorMessage = switch (error.code) {
          'invalid-credential' ||
          'wrong-password' ||
          'user-not-found' => 'Email o contraseña incorrectos.',
          _ => 'No pudimos iniciar sesión. Probá de nuevo.',
        },
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel Admin — Ingresar')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _signIn,
                icon: const Icon(Icons.login),
                label: Text(_isSubmitting ? 'Ingresando...' : 'Ingresar'),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => abrirSoporteWhatsapp(
                  ref: ref,
                  app: 'Admin',
                  motivo: 'no puedo iniciar sesión en el panel',
                  identidadFallback: _emailController.text.trim().isEmpty
                      ? null
                      : 'intentando entrar con ${_emailController.text.trim()}',
                ),
                icon: const Icon(Icons.chat_outlined, size: 18),
                label: const Text('¿Sigue fallando? Contactar soporte'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
