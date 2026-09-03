import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/tracking/battery_optimization.dart';
import 'acuerdos_screen.dart';

/// Primer paso del onboarding de permisos (sprint de rediseño) — una
/// sola pantalla que explica TODOS los permisos antes de pedirlos, en
/// vez de que cada uno aparezca sin aviso en momentos distintos de uso
/// (como pasaba antes: batería al abrir Home, ubicación recién al
/// aceptar el primer viaje). Los diálogos reactivos que ya existían
/// (`entrega_en_curso_screen.dart`, `battery_optimization_prompt.dart`)
/// se dejan tal cual, como red de seguridad si el permiso se pierde
/// después de este onboarding — no se duplican acá, solo se anticipan.
class PermisosAccesoScreen extends StatefulWidget {
  const PermisosAccesoScreen({
    super.key,
    required this.role,
    required this.onCompletado,
  });

  /// 'cliente' o 'repartidor' — determina qué permisos se explican.
  final String role;
  final VoidCallback onCompletado;

  @override
  State<PermisosAccesoScreen> createState() => _PermisosAccesoScreenState();
}

class _PermisosAccesoScreenState extends State<PermisosAccesoScreen> {
  bool _procesando = false;

  bool get _esRepartidor => widget.role == 'repartidor';

  Future<void> _siguiente() async {
    setState(() => _procesando = true);
    // Mejor esfuerzo: si el usuario deniega alguno, no se bloquea el
    // flujo — los diálogos reactivos existentes lo vuelven a ofrecer más
    // adelante cuando de verdad haga falta (ej. al aceptar un viaje).
    try {
      await Geolocator.checkPermission().then((permiso) async {
        if (permiso == LocationPermission.denied) {
          await Geolocator.requestPermission();
        }
      });
    } catch (_) {}
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {}
    if (_esRepartidor) {
      try {
        await BatteryOptimization.solicitarExclusion();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _procesando = false);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AcuerdosScreen(onCompletado: widget.onCompletado),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Permisos de acceso',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Te vamos a pedir estos permisos para que la app '
                    'funcione bien — podés cambiarlos después desde '
                    'Ajustes.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  const SizedBox(height: 12),
                  _FilaPermiso(
                    icono: Icons.location_on_outlined,
                    titulo: 'Ubicación',
                    descripcion: _esRepartidor
                        ? 'Para el radar de envíos cercanos y la navegación.'
                        : 'Para calcular rutas y mostrar tu posición en '
                              'el mapa.',
                  ),
                  if (_esRepartidor)
                    const _FilaPermiso(
                      icono: Icons.map_outlined,
                      titulo: 'Ubicación en segundo plano',
                      descripcion:
                          'Para que el cliente te vea en el mapa mientras '
                          'vas en camino con una entrega.',
                    ),
                  _FilaPermiso(
                    icono: Icons.notifications_outlined,
                    titulo: 'Notificaciones',
                    descripcion: _esRepartidor
                        ? 'Para avisarte de nuevas ofertas apenas aparecen.'
                        : 'Para avisarte de ofertas y cambios de estado '
                              'de tus envíos.',
                  ),
                  if (_esRepartidor)
                    const _FilaPermiso(
                      icono: Icons.battery_charging_full_outlined,
                      titulo: 'Batería',
                      descripcion:
                          'Para que el rastreo y las notificaciones no se '
                          'corten en segundo plano.',
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: _procesando ? null : _siguiente,
                  child: Text(_procesando ? 'Un momento...' : 'Siguiente'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaPermiso extends StatelessWidget {
  const _FilaPermiso({
    required this.icono,
    required this.titulo,
    required this.descripcion,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icono, color: colorScheme.onSecondaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  descripcion,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
