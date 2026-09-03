import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/cerrar_sesion.dart';
import '../data/providers.dart';
import '../theme/colores_semanticos.dart';
import 'pantalla_instrucciones_foto.dart';
import 'soporte_whatsapp.dart';

/// Se muestra en vez de Home mientras la cuenta (Cliente o Repartidor,
/// Sprint 10) no está verificada — antes, un repartidor sin aprobar
/// entraba igual al Radar y recién se enteraba de que no podía
/// aceptar/ofertar con un `permission-denied` confuso al intentarlo; con
/// el Sprint 10, lo mismo aplica al Cliente para evitar que cualquiera
/// entre a publicar envíos sin haber sido revisado. Cubre 2 estados:
/// - Sin foto de Cédula todavía (cuentas creadas antes del registro en 4
///   pasos, que nunca pasaron por esa captura): la pide acá mismo.
/// - Con foto ya subida: espera la aprobación del Admin en tiempo real
///   (stream de `users/{uid}`) y habilita "Continuar" apenas se aprueba.
class EsperandoVerificacionScreen extends ConsumerStatefulWidget {
  const EsperandoVerificacionScreen({
    super.key,
    required this.onVerificado,
    required this.appLabel,
    required this.descripcionDesbloqueo,
  });

  final VoidCallback onVerificado;

  /// 'Cliente' o 'Repartidor' — identifica la app en el mensaje de
  /// soporte por WhatsApp.
  final String appLabel;

  /// Qué se desbloquea al aprobar el KYC, ej. "veas envíos disponibles"
  /// (Repartidor) o "publiques envíos" (Cliente) — completa la frase "Un
  /// administrador va a verificar tu Cédula antes de que ...".
  final String descripcionDesbloqueo;

  @override
  ConsumerState<EsperandoVerificacionScreen> createState() =>
      _EsperandoVerificacionScreenState();
}

class _EsperandoVerificacionScreenState
    extends ConsumerState<EsperandoVerificacionScreen> {
  XFile? _foto;
  bool _procesando = false;

  Future<void> _tomarFoto() async {
    final foto = await mostrarInstruccionesYTomarFoto(
      context,
      titulo: 'Cédula de Identidad',
      icono: Icons.badge_outlined,
      recomendaciones: const [
        'Foto clara, sin capturas de pantalla ni fotocopias.',
        'Sin filtros, todos los datos deben verse bien.',
        'El documento completo dentro del cuadro.',
      ],
    );
    if (foto != null && mounted) setState(() => _foto = foto);
  }

  Future<void> _subirFoto() async {
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
    } catch (_) {
      if (mounted) {
        mostrarErrorConSoporte(
          context,
          ref,
          mensaje: 'No pudimos subir la foto de tu Cédula. Probá de nuevo '
              'o contactanos si sigue fallando.',
          app: widget.appLabel,
          motivo: 'no puedo subir la foto de mi Cédula para verificarme',
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _continuar() async {
    await FirebaseAuth.instance.currentUser!.getIdTokenResult(true);
    widget.onVerificado();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Verificación pendiente')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          final datos = snapshot.data?.data();
          final isVerified = datos?['isVerified'] as bool? ?? false;
          final cedulaUrl = datos?['cedulaUrl'] as String?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isVerified) ...[
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: ColoresSemanticos.exito(context).$1,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '¡Ya fuiste verificado! Bienvenido.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _continuar,
                    child: const Text('Continuar'),
                  ),
                ] else if (cedulaUrl == null) ...[
                  const Icon(Icons.badge_outlined, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Todavía falta un paso: sacá una foto clara del '
                    'frente de tu Cédula de Identidad para que un '
                    'administrador la revise.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (_foto != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(_foto!.path), height: 200),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _tomarFoto,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(_foto == null ? 'Tomar foto' : 'Repetir foto'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: (_procesando || _foto == null)
                        ? null
                        : _subirFoto,
                    child: Text(_procesando ? 'Subiendo...' : 'Subir'),
                  ),
                ] else ...[
                  const Icon(Icons.hourglass_empty, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Tu cuenta está en revisión. Un administrador va a '
                    'verificar tu Cédula antes de que ${widget.descripcionDesbloqueo} '
                    '— esta pantalla se actualiza sola apenas te aprueben.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  const FilledButton(
                    onPressed: null,
                    child: Text('Continuar'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '¿La revisión está tardando mucho?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => abrirSoporteWhatsapp(
                      ref: ref,
                      app: widget.appLabel,
                      motivo: 'mi cuenta sigue sin verificarse',
                    ),
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('Contactar soporte por WhatsApp'),
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: cerrarSesionYBorrarBloqueo,
                  child: const Text('Cerrar sesión'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
