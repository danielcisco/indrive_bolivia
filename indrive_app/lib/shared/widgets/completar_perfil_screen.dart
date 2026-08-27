import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';

/// Red de seguridad de `AuthGate`: se muestra en vez de Home mientras
/// `nombre`/`nick` no existan en `users/{uid}`. En el camino feliz nunca
/// llega a verse — `PhoneLoginView` ya los pide en la misma pantalla de
/// login para cuentas nuevas — pero cubre 2 casos reales: cuentas creadas
/// antes de que existiera ese paso, y la ventana de carrera donde
/// `authStateChanges()` navega a Home antes de que ese paso termine.
class CompletarPerfilScreen extends ConsumerStatefulWidget {
  const CompletarPerfilScreen({super.key, required this.onCompletado});

  final VoidCallback onCompletado;

  @override
  ConsumerState<CompletarPerfilScreen> createState() =>
      _CompletarPerfilScreenState();
}

class _CompletarPerfilScreenState
    extends ConsumerState<CompletarPerfilScreen> {
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _nickController = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _nickController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombreController.text.trim();
    final apellido = _apellidoController.text.trim();
    final nick = _nickController.text.trim();
    if (nombre.isEmpty || apellido.isEmpty || nick.isEmpty) {
      setState(() => _error = 'Completa tu nombre, apellido y nick.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await ref
          .read(usersRepositoryProvider)
          .actualizarPerfil(uid, nombre: nombre, apellido: apellido, nick: nick);
      widget.onCompletado();
    } catch (error) {
      if (mounted) setState(() => _error = 'No se pudo guardar: $error');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Completa tu perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Antes de continuar, contanos cómo te llamás — así el '
              'Cliente y el Repartidor pueden identificarse entre sí.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apellidoController,
              decoration: const InputDecoration(labelText: 'Apellido'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nickController,
              decoration: const InputDecoration(labelText: 'Nick'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: Text(_guardando ? 'Guardando...' : 'Guardar'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
