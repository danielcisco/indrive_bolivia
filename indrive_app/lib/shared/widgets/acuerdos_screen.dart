import 'package:flutter/material.dart';

import '../../core/onboarding/onboarding_service.dart';

/// Segundo y último paso del onboarding (sprint de rediseño). Texto
/// genérico a propósito: el proyecto todavía no tiene Términos de Uso ni
/// Política de Privacidad reales redactados — cuando existan, este
/// texto (y un link al documento real) los reemplaza. No se inventa un
/// documento que no existe.
class AcuerdosScreen extends StatefulWidget {
  const AcuerdosScreen({super.key, required this.onCompletado});

  final VoidCallback onCompletado;

  @override
  State<AcuerdosScreen> createState() => _AcuerdosScreenState();
}

class _AcuerdosScreenState extends State<AcuerdosScreen> {
  bool _aceptado = false;
  bool _procesando = false;

  Future<void> _confirmar() async {
    setState(() => _procesando = true);
    await OnboardingService().marcarCompletado();
    if (!mounted) return;
    widget.onCompletado();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Acuerdos', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(
                'Antes de continuar, necesitamos tu conformidad con las '
                'condiciones de uso del servicio.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _aceptado,
                onChanged: (valor) => setState(() => _aceptado = valor ?? false),
                title: const Text(
                  'Acepto los Términos de Uso y la Política de '
                  'Privacidad de inDrive Entregas.',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_aceptado && !_procesando) ? _confirmar : null,
                  child: Text(_procesando ? 'Un momento...' : 'Aceptar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
