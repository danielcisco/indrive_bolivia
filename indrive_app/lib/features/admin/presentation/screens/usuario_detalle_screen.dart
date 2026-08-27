import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/widgets/soporte_whatsapp.dart';
import '../../domain/usuario_admin.dart';
import '../providers/gestion_usuarios_controller.dart';

/// Detalle de un usuario + suspender/reactivar (sprint extra, Grupo C).
/// No hay edición de datos de identidad ni borrado — se descartó un CRUD
/// literal (ver artifact de referencia): crear cuentas sin SMS real
/// rompería la verificación, y borrar dejaría huérfanas las referencias
/// en envíos/calificaciones.
class UsuarioDetalleScreen extends ConsumerStatefulWidget {
  const UsuarioDetalleScreen({super.key, required this.usuario});

  final UsuarioAdmin usuario;

  @override
  ConsumerState<UsuarioDetalleScreen> createState() =>
      _UsuarioDetalleScreenState();
}

class _UsuarioDetalleScreenState extends ConsumerState<UsuarioDetalleScreen> {
  late bool _isActive = widget.usuario.isActive;
  bool _procesando = false;

  Future<void> _cambiarEstado() async {
    final activar = !_isActive;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(activar ? '¿Reactivar cuenta?' : '¿Suspender cuenta?'),
        content: Text(
          activar
              ? 'La cuenta va a poder volver a iniciar sesión normalmente.'
              : 'La cuenta deja de poder iniciar sesión de inmediato, '
                    'incluso si ya tiene una sesión abierta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(activar ? 'Sí, reactivar' : 'Sí, suspender'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _procesando = true);
    try {
      await ref
          .read(usersRepositoryProvider)
          .establecerEstadoCuenta(widget.usuario.uid, activar: activar);
      ref.invalidate(gestionUsuariosControllerProvider);
      if (mounted) setState(() => _isActive = activar);
    } catch (_) {
      if (mounted) {
        mostrarErrorConSoporte(
          context,
          ref,
          mensaje: activar
              ? 'No pudimos reactivar la cuenta. Probá de nuevo.'
              : 'No pudimos suspender la cuenta. Probá de nuevo.',
          app: 'Admin',
          motivo: 'no puedo cambiar el estado de una cuenta (${widget.usuario.uid})',
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = widget.usuario;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de usuario')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              usuario.phoneNumber ?? usuario.uid,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Rol: ${usuario.role ?? 'sin asignar'}'),
            Text('Verificado (KYC): ${usuario.isVerified ? 'Sí' : 'No'}'),
            Text('Estado: ${_isActive ? 'Activo' : 'Suspendido'}'),
            Text(
              usuario.totalCalificaciones == 0
                  ? 'Sin calificaciones todavía'
                  : '⭐ ${usuario.ratingPromedio.toStringAsFixed(1)} · '
                        '${usuario.totalCalificaciones} calificaciones',
            ),
            if (usuario.createdAt != null)
              Text('Registrado: ${usuario.createdAt!.toDate()}'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _procesando ? null : _cambiarEstado,
                style: _isActive
                    ? FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      )
                    : null,
                icon: Icon(
                  _isActive ? Icons.block_outlined : Icons.check_circle_outline,
                ),
                label: Text(
                  _procesando
                      ? 'Procesando...'
                      : _isActive
                      ? 'Suspender cuenta'
                      : 'Reactivar cuenta',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
