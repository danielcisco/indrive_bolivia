import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/location/current_location.dart';
import '../data/providers.dart';
import 'soporte_whatsapp.dart';

/// Número de emergencia con su nombre público, para el listado de marcado
/// rápido — mismos 3 servicios que existen en toda Bolivia, no varían por
/// ciudad.
const _numerosEmergencia = [
  (nombre: 'Policía Boliviana', numero: '110'),
  (nombre: 'Bomberos', numero: '119'),
  (nombre: 'Cruz Roja (ambulancia)', numero: '118'),
];

/// Pantalla de seguridad (sprint extra, pedido explícito del usuario):
/// compartir ubicación actual por WhatsApp a un contacto de confianza
/// configurado de antemano, + marcado rápido a los 3 números de
/// emergencia de Bolivia. Compartida por Cliente y Repartidor — nada acá
/// depende del rol.
///
/// Aclaración importante de alcance: "ubicación en vivo" de WhatsApp (el
/// marcador que se actualiza solo por un tiempo) solo se puede iniciar
/// DESDE la propia app de WhatsApp, ninguna app de terceros puede
/// activarlo por su cuenta. Lo que sí se puede hacer, y es lo que hace
/// esta pantalla, es abrir WhatsApp con un mensaje ya escrito que incluye
/// un link a la ubicación actual (una foto puntual, no un seguimiento
/// continuo) — el texto del botón y el mensaje son honestos sobre esto.
class SeguridadScreen extends ConsumerStatefulWidget {
  const SeguridadScreen({super.key});

  @override
  ConsumerState<SeguridadScreen> createState() => _SeguridadScreenState();
}

class _SeguridadScreenState extends ConsumerState<SeguridadScreen> {
  String? _contactoNombre;
  String? _contactoTelefono;
  bool _cargando = true;
  bool _enviandoUbicacion = false;

  @override
  void initState() {
    super.initState();
    _cargarContacto();
  }

  Future<void> _cargarContacto() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final contacto = await ref
        .read(usersRepositoryProvider)
        .obtenerContactoEmergencia(uid);
    if (!mounted) return;
    setState(() {
      _contactoNombre = contacto.nombre;
      _contactoTelefono = contacto.telefono;
      _cargando = false;
    });
  }

  Future<void> _editarContacto() async {
    final nombreController = TextEditingController(text: _contactoNombre);
    final telefonoController = TextEditingController(text: _contactoTelefono);
    final guardar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contacto de confianza'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreController,
              decoration: const InputDecoration(labelText: 'Nombre'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: telefonoController,
              decoration: const InputDecoration(
                labelText: 'Teléfono (con +591)',
                hintText: '+59170000000',
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (guardar != true) return;
    final nombre = nombreController.text.trim();
    final telefono = telefonoController.text.trim();
    if (nombre.isEmpty || telefono.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await ref
        .read(usersRepositoryProvider)
        .guardarContactoEmergencia(uid, nombre: nombre, telefono: telefono);
    if (mounted) {
      setState(() {
        _contactoNombre = nombre;
        _contactoTelefono = telefono;
      });
    }
  }

  Future<void> _enviarUbicacion() async {
    final telefono = _contactoTelefono;
    if (telefono == null) return;
    setState(() => _enviandoUbicacion = true);
    try {
      final posicion = await obtenerUbicacionActual();
      final link =
          'https://www.google.com/maps?q=${posicion.latitude},${posicion.longitude}';
      final mensaje = Uri.encodeComponent(
        'Necesito ayuda, esta es mi ubicación actual: $link',
      );
      final numeroLimpio = telefono.replaceAll(RegExp(r'[^0-9]'), '');
      final uri = Uri.parse('https://wa.me/$numeroLimpio?text=$mensaje');
      final abierto = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!abierto && mounted) {
        mostrarErrorConSoporte(
          context,
          ref,
          mensaje: 'No pudimos abrir WhatsApp. ¿Lo tenés instalado?',
          app: 'Cliente/Repartidor',
          motivo: 'no puedo compartir mi ubicación de emergencia',
        );
      }
    } catch (_) {
      if (mounted) {
        mostrarErrorConSoporte(
          context,
          ref,
          mensaje:
              'No pudimos obtener tu ubicación. Revisá que el GPS '
              'esté activado.',
          app: 'Cliente/Repartidor',
          motivo: 'no puedo compartir mi ubicación de emergencia',
        );
      }
    } finally {
      if (mounted) setState(() => _enviandoUbicacion = false);
    }
  }

  Future<void> _llamar(String numero) async {
    await launchUrl(Uri(scheme: 'tel', path: numero));
  }

  @override
  Widget build(BuildContext context) {
    final tieneContacto = _contactoTelefono != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Seguridad')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.emergency_share_outlined,
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Compartir ubicación',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onErrorContainer,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tieneContacto
                              ? 'Le manda tu ubicación actual por WhatsApp '
                                    'a $_contactoNombre.'
                              : 'Configurá un contacto de confianza para '
                                    'poder avisarle tu ubicación en caso de '
                                    'emergencia.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onErrorContainer,
                              ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onError,
                            ),
                            onPressed: _enviandoUbicacion
                                ? null
                                : (tieneContacto
                                      ? _enviarUbicacion
                                      : _editarContacto),
                            icon: _enviandoUbicacion
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    tieneContacto
                                        ? Icons.share_location_outlined
                                        : Icons.person_add_alt_outlined,
                                  ),
                            label: Text(
                              _enviandoUbicacion
                                  ? 'Enviando...'
                                  : (tieneContacto
                                        ? 'Enviar mi ubicación por WhatsApp'
                                        : 'Configurar contacto'),
                            ),
                          ),
                        ),
                        if (tieneContacto) ...[
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: _editarContacto,
                            child: const Text('Cambiar contacto'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Números de emergencia',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final servicio in _numerosEmergencia)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.call_outlined),
                      title: Text(servicio.nombre),
                      subtitle: Text(servicio.numero),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _llamar(servicio.numero),
                    ),
                  ),
              ],
            ),
    );
  }
}
