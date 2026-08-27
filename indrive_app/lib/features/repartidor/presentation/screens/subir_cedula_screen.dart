import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/widgets/soporte_whatsapp.dart';

/// Diferido de KYC (seguimiento del Sprint 5.1): el repartidor sube una
/// foto de su Cédula de Identidad para que el Admin la revise antes de
/// aprobar. Mismo patrón que `ConfirmarEntregaScreen` (Sprint 6.1) sin el
/// selector de método de pago.
class SubirCedulaScreen extends ConsumerStatefulWidget {
  const SubirCedulaScreen({super.key});

  @override
  ConsumerState<SubirCedulaScreen> createState() => _SubirCedulaScreenState();
}

class _SubirCedulaScreenState extends ConsumerState<SubirCedulaScreen> {
  XFile? _foto;
  bool _procesando = false;

  Future<void> _tomarFoto() async {
    // imageQuality/maxWidth más altos que una foto de paquete: acá lo que
    // importa es que el Admin pueda leer el número de Cédula ampliando la
    // imagen, no solo confirmar que algo llegó entero (Sprint 9).
    final foto = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      maxWidth: 1920,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (foto != null && mounted) setState(() => _foto = foto);
  }

  Future<void> _confirmar() async {
    final foto = _foto;
    if (foto == null) return;
    setState(() => _procesando = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final repository = ref.read(usersRepositoryProvider);
      final url = await repository.subirFotoCedula(
        uid: uid,
        archivo: File(foto.path),
      );
      await repository.guardarCedulaUrl(uid, url);
      ref.invalidate(miEstadoKycProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        mostrarErrorConSoporte(
          context,
          ref,
          mensaje: 'No pudimos subir la foto de tu Cédula. Probá de nuevo.',
          app: 'Repartidor',
          motivo: 'no puedo subir la foto de mi Cédula',
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subir foto de Cédula')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sacá una foto clara del frente de tu Cédula de Identidad. '
              'Un administrador la va a revisar antes de aprobar tu cuenta.',
            ),
            const SizedBox(height: 16),
            if (_foto != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(_foto!.path), height: 220),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _tomarFoto,
              icon: const Icon(Icons.camera_alt),
              label: Text(_foto == null ? 'Tomar foto' : 'Repetir foto'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_procesando || _foto == null) ? null : _confirmar,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(_procesando ? 'Subiendo...' : 'Subir'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
