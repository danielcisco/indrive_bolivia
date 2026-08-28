import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/widgets/envio_activo_card.dart';
import '../../../../shared/widgets/estado_verificacion_screen.dart';
import '../../../../shared/widgets/mis_calificaciones_screen.dart';
import '../../../../shared/widgets/session_status_view.dart';
import '../../../../shared/widgets/user_profile_header.dart';
import 'envio_detalle_screen.dart';
import 'mis_envios_screen.dart';

class ClienteHomeScreen extends ConsumerWidget {
  const ClienteHomeScreen({super.key});

  // Mismo patrón que AdminHomeScreen._abrirSesion (Sprint 9): rol/estado
  // de verificación detrás de un ícono de cuenta, no suelto en el body —
  // un cliente común no necesita ver "Rol: cliente" impreso todo el
  // tiempo en su pantalla principal (Sprint 16).
  void _abrirSesion(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        content: const SessionStatusView(
          appLabel: 'App Cliente — Villazón, Potosí',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final envioActivo = ref.watch(miEnvioActivoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('inDrive Entregas — Cliente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Cuenta',
            onPressed: () => _abrirSesion(context),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: UserProfileHeader(mostrarRating: true),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            envioActivo.when(
              loading: () => const SizedBox.shrink(),
              error: (error, _) => const SizedBox.shrink(),
              data: (envio) {
                if (envio == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: EnvioActivoCard(
                    envio: envio,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EnvioDetalleScreen(envioId: envio.id),
                      ),
                    ),
                  ),
                );
              },
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MisCalificacionesScreen(),
                ),
              ),
              icon: const Icon(Icons.star_outline),
              label: const Text('Mis calificaciones'),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const EstadoVerificacionScreen(role: 'cliente'),
                ),
              ),
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Mi verificación'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MisEnviosScreen()),
                ),
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Mis envíos'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
