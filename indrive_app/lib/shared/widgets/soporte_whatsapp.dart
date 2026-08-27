import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/providers.dart';

/// Número de contacto directo de soporte (Villazón, Potosí) — atención
/// personal, no un call center, así que un solo número fijo alcanza.
const _numeroSoporte = '59179320919';

/// Abre WhatsApp con un mensaje precargado: quién es (nombre/nick si ya
/// completó su perfil, o solo el teléfono si el problema ocurrió antes de
/// llegar a esa parte, ej. durante el login) y en qué pantalla/app quedó
/// trabado — así quien atiende no tiene que volver a pedirle los mismos
/// datos.
///
/// [identidadFallback] cubre el caso donde todavía no hay sesión iniciada
/// (ej. falló el login mismo, no hay `currentUser`) pero sí un dato suelto
/// útil para identificar a quien escribe — ej. el email que tipeó en el
/// panel Admin.
Future<void> abrirSoporteWhatsapp({
  required WidgetRef ref,
  required String app,
  required String motivo,
  String? identidadFallback,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  final telefono = user?.phoneNumber ?? 'sin número registrado';
  final perfil = user != null
      ? await ref.read(usersRepositoryProvider).obtenerMiPerfil(user.uid)
      : null;
  final identidad = (perfil != null && perfil.nombre.isNotEmpty)
      ? '${perfil.nombre} ${perfil.apellido} (@${perfil.nick})'
      : (identidadFallback ?? 'todavía sin perfil completo');

  final mensaje =
      'Hola, soy $identidad, tel $telefono. '
      'Tengo un problema en la app $app: $motivo.';

  final uri = Uri.parse(
    'https://wa.me/$_numeroSoporte?text=${Uri.encodeComponent(mensaje)}',
  );
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Reemplazo del texto de error crudo (`Text('Error: $error')`) por un
/// bloque entendible + botón de contacto directo (Sprint 9) — para cuando
/// el error ocupa toda la pantalla (ej. una lista que no cargó, una
/// pantalla de estado bloqueante).
class SupportErrorView extends ConsumerWidget {
  const SupportErrorView({
    super.key,
    required this.mensaje,
    required this.app,
    required this.motivo,
  });

  /// Texto amigable que ve el usuario — nunca la excepción técnica.
  final String mensaje;
  final String app;
  final String motivo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () =>
                  abrirSoporteWhatsapp(ref: ref, app: app, motivo: motivo),
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Contactar soporte por WhatsApp'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mismo reemplazo que [SupportErrorView] pero para feedback puntual de
/// una acción que falló (crear envío, aceptar oferta, confirmar entrega)
/// — un `SnackBar` con el mensaje amigable y un botón de acción directo a
/// WhatsApp, en vez de interrumpir con una pantalla completa.
void mostrarErrorConSoporte(
  BuildContext context,
  WidgetRef ref, {
  required String mensaje,
  required String app,
  required String motivo,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensaje),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'WhatsApp',
        onPressed: () =>
            abrirSoporteWhatsapp(ref: ref, app: app, motivo: motivo),
      ),
    ),
  );
}
