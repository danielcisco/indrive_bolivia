import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Pantalla previa con recomendaciones antes de abrir la cámara (Sprint
/// 19) — se antepone a cada punto de captura de documento de la app
/// (foto personal, Cédula, licencia, vehículo, SOAT). Un solo widget
/// parametrizado por título/checklist/ícono, no una pantalla por cada
/// documento.
///
/// Devuelve el `XFile` capturado, o `null` si el usuario vuelve atrás sin
/// sacar la foto.
Future<XFile?> mostrarInstruccionesYTomarFoto(
  BuildContext context, {
  required String titulo,
  required List<String> recomendaciones,
  required IconData icono,
}) {
  return Navigator.of(context).push<XFile?>(
    MaterialPageRoute(
      builder: (_) => _PantallaInstruccionesFoto(
        titulo: titulo,
        recomendaciones: recomendaciones,
        icono: icono,
      ),
    ),
  );
}

class _PantallaInstruccionesFoto extends StatefulWidget {
  const _PantallaInstruccionesFoto({
    required this.titulo,
    required this.recomendaciones,
    required this.icono,
  });

  final String titulo;
  final List<String> recomendaciones;
  final IconData icono;

  @override
  State<_PantallaInstruccionesFoto> createState() =>
      _PantallaInstruccionesFotoState();
}

class _PantallaInstruccionesFotoState
    extends State<_PantallaInstruccionesFoto> {
  bool _procesando = false;

  Future<void> _tomarFoto() async {
    setState(() => _procesando = true);
    // imageQuality/maxWidth altos: documento (no paquete) — necesita
    // leerse con nitidez al ampliar, mismo criterio que ya usaba
    // subir_cedula_screen.dart desde el Sprint 9.
    final foto = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      maxWidth: 1920,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (mounted) {
      setState(() => _procesando = false);
      if (foto != null) Navigator.of(context).pop(foto);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final recomendacion in widget.recomendaciones)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(recomendacion)),
                  ],
                ),
              ),
            const SizedBox(height: 32),
            Center(
              child: Icon(
                widget.icono,
                size: 120,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _procesando ? null : _tomarFoto,
                icon: const Icon(Icons.camera_alt),
                label: Text(_procesando ? 'Abriendo cámara...' : 'Tomar una foto'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Miniatura + botón "repetir foto" para cuando ya se sacó una — mismo
/// bloque visual repetido en cada paso del wizard de registro.
class PreviewFotoTomada extends StatelessWidget {
  const PreviewFotoTomada({
    super.key,
    required this.foto,
    required this.onRepetir,
  });

  final XFile foto;
  final VoidCallback onRepetir;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(File(foto.path), height: 160),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onRepetir,
          icon: const Icon(Icons.camera_alt),
          label: const Text('Repetir foto'),
        ),
      ],
    );
  }
}
