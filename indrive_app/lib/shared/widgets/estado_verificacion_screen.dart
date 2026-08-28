import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Perfil → estado de verificación (Sprint 22) — checklist de los pasos
/// que ya se cumplieron, a diferencia de `EsperandoVerificacionScreen`
/// (que BLOQUEA el Home mientras no está verificado): esta es de consulta
/// libre, se puede abrir en cualquier momento desde el perfil.
class EstadoVerificacionScreen extends StatelessWidget {
  const EstadoVerificacionScreen({super.key, required this.role});

  /// 'cliente' o 'repartidor' — Repartidor suma licencia y vehículo a los
  /// documentos requeridos.
  final String role;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Estado de verificación')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          final datos = snapshot.data?.data();
          if (datos == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final isVerified = datos['isVerified'] as bool? ?? false;
          final cedulaUrl = datos['cedulaUrl'] as String?;
          final docsRepartidorCompletos = role != 'repartidor' ||
              (datos['numeroLicencia'] != null &&
                  datos['fotoVehiculoUrl'] != null);
          final documentosCargados = cedulaUrl != null && docsRepartidorCompletos;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _PasoVerificacion(
                icono: Icons.description_outlined,
                titulo: 'Documentos cargados',
                subtitulo: documentosCargados
                    ? 'Gracias por completar tu registro.'
                    : role == 'repartidor'
                          ? 'Faltan documentos: Cédula, licencia o datos del '
                                'vehículo.'
                          : 'Todavía falta tu foto de Cédula.',
                estado: documentosCargados
                    ? _EstadoPaso.completo
                    : _EstadoPaso.incompleto,
              ),
              _PasoVerificacion(
                icono: Icons.hourglass_empty,
                titulo: 'Esperando verificación',
                subtitulo: !documentosCargados
                    ? 'Se activa apenas termines de cargar tus documentos.'
                    : isVerified
                    ? 'Ya pasaste esta etapa.'
                    : 'Un administrador está revisando tus documentos — '
                          'te vamos a avisar en cuanto termine.',
                estado: !documentosCargados
                    ? _EstadoPaso.pendiente
                    : isVerified
                    ? _EstadoPaso.completo
                    : _EstadoPaso.enCurso,
              ),
              _PasoVerificacion(
                icono: Icons.verified_outlined,
                titulo: 'Verificación completa',
                subtitulo: isVerified
                    ? 'Ya podés usar la app sin restricciones.'
                    : 'Última etapa — se completa cuando el administrador '
                          'te aprueba.',
                estado: isVerified
                    ? _EstadoPaso.completo
                    : _EstadoPaso.pendiente,
                esUltimo: true,
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _EstadoPaso { completo, enCurso, incompleto, pendiente }

class _PasoVerificacion extends StatelessWidget {
  const _PasoVerificacion({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.estado,
    this.esUltimo = false,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;
  final _EstadoPaso estado;
  final bool esUltimo;

  static const _verde = Color(0xFF2E7D32);
  static const _ambar = Color(0xFF8A5A00);

  @override
  Widget build(BuildContext context) {
    final Color color = switch (estado) {
      _EstadoPaso.completo => _verde,
      _EstadoPaso.enCurso => _ambar,
      _EstadoPaso.incompleto => Theme.of(context).colorScheme.error,
      _EstadoPaso.pendiente => Theme.of(context).colorScheme.outline,
    };
    final IconData iconoEstado = switch (estado) {
      _EstadoPaso.completo => Icons.check_circle,
      _EstadoPaso.enCurso => Icons.access_time_filled,
      _EstadoPaso.incompleto => Icons.error,
      _EstadoPaso.pendiente => Icons.radio_button_unchecked,
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(iconoEstado, color: color, size: 28),
              if (!esUltimo)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Theme.of(context).colorScheme.outlineVariant,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
