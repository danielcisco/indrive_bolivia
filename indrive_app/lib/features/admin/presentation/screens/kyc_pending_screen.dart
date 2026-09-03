import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/widgets/red_network_image.dart';
import '../../../../shared/widgets/soporte_whatsapp.dart';
import '../../../../shared/widgets/visor_foto_screen.dart';
import '../../domain/usuario_kyc_pendiente.dart';
import '../providers/kyc_pending_controller.dart';

String _formatearFecha(Timestamp? timestamp) {
  if (timestamp == null) return '—';
  final fecha = timestamp.toDate();
  return '${fecha.day.toString().padLeft(2, '0')}/'
      '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
}

/// KYC de Admin (sprint extra: historial) — 2 pestañas: "Pendientes"
/// (como antes, con botón Aprobar) e "Historial" (cuentas ya
/// verificadas, con fecha de verificación, sin botón).
class KycPendingScreen extends ConsumerStatefulWidget {
  const KycPendingScreen({super.key});

  @override
  ConsumerState<KycPendingScreen> createState() => _KycPendingScreenState();
}

class _KycPendingScreenState extends ConsumerState<KycPendingScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 2, vsync: this);
  final _aprobando = <String>{};

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _aprobar(String uid) async {
    if (_aprobando.contains(uid)) return;
    setState(() => _aprobando.add(uid));
    try {
      await ref.read(usersRepositoryProvider).aprobarKyc(uid);
      // Sin actualizar la lista a mano: streamUsuariosPendientesKyc ya
      // deja de incluir a este uid apenas isVerified pasa a true (y
      // streamUsuariosVerificadosRecientes lo empieza a incluir solo).
    } catch (_) {
      if (mounted) {
        mostrarErrorConSoporte(
          context,
          ref,
          mensaje: 'No pudimos aprobar la cuenta. Probá de nuevo.',
          app: 'Admin',
          motivo: 'no puedo aprobar el KYC de una cuenta',
        );
      }
    } finally {
      if (mounted) setState(() => _aprobando.remove(uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = ref.watch(kycPendingControllerProvider);
    final historial = ref.watch(kycHistorialProvider);

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pendientes'),
            Tab(text: 'Historial'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              pendientes.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => const SupportErrorView(
                  mensaje: 'No pudimos cargar las cuentas pendientes de '
                      'KYC. Revisá tu conexión y volvé a intentar.',
                  app: 'Admin',
                  motivo: 'no puedo ver la lista de KYC pendiente',
                ),
                data: (usuarios) => _ListaKyc(
                  usuarios: usuarios,
                  mensajeVacio: 'No hay cuentas con KYC pendiente.',
                  iconoVacio: Icons.verified_user_outlined,
                  aprobando: _aprobando,
                  onAprobar: _aprobar,
                ),
              ),
              historial.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => const SupportErrorView(
                  mensaje: 'No pudimos cargar el historial de KYC. Revisá '
                      'tu conexión y volvé a intentar.',
                  app: 'Admin',
                  motivo: 'no puedo ver el historial de KYC',
                ),
                data: (usuarios) => _ListaKyc(
                  usuarios: usuarios,
                  mensajeVacio: 'Todavía no hay cuentas verificadas.',
                  iconoVacio: Icons.history,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ListaKyc extends StatelessWidget {
  const _ListaKyc({
    required this.usuarios,
    required this.mensajeVacio,
    required this.iconoVacio,
    this.aprobando,
    this.onAprobar,
  });

  final List<UsuarioKycPendiente> usuarios;
  final String mensajeVacio;
  final IconData iconoVacio;

  /// Si son null, la tarjeta no muestra el botón "Aprobar" — es la
  /// pestaña de historial, de solo lectura.
  final Set<String>? aprobando;
  final ValueChanged<String>? onAprobar;

  @override
  Widget build(BuildContext context) {
    if (usuarios.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconoVacio, size: 48),
              const SizedBox(height: 8),
              Text(mensajeVacio),
            ],
          ),
        ),
      );
    }

    // Scrollbar siempre visible (sprint extra) — cada tarjeta trae
    // bastante texto y varias filas de fotos, así que en una cuenta
    // repartidor la lista completa suele pasar de largo la pantalla; sin
    // esto no había ninguna señal de que hubiera más para revisar más
    // abajo.
    return Scrollbar(
      thumbVisibility: true,
      child: ListView.builder(
        itemCount: usuarios.length,
        itemBuilder: (context, index) {
          final usuario = usuarios[index];
          final estaAprobando = aprobando?.contains(usuario.uid) ?? false;
          final identificador = (usuario.nombre?.isNotEmpty ?? false)
              ? '${usuario.nombre} ${usuario.apellido ?? ''}'
                    '${usuario.nick != null ? ' (@${usuario.nick})' : ''}'
              : (usuario.phoneNumber ?? usuario.uid);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          usuario.role == 'cliente' ? 'Cliente' : 'Repartidor',
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          identificador,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _filaDato(context, 'Teléfono', usuario.phoneNumber ?? '—'),
                  _filaDato(
                    context,
                    'Registrado',
                    _formatearFecha(usuario.createdAt),
                  ),
                  _filaDato(
                    context,
                    'Fecha de nacimiento',
                    _formatearFecha(usuario.fechaNacimiento),
                  ),
                  if (onAprobar == null)
                    _filaDato(
                      context,
                      'Verificado',
                      _formatearFecha(usuario.fechaVerificacion),
                    ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text(
                    'Documento de identidad',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  _filaFotos(context, {
                    'Foto personal': usuario.fotoPersonalUrl,
                    'Cédula': usuario.cedulaUrl,
                  }),
                  if (usuario.role == 'repartidor') ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Text(
                      'Licencia de conducir',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    _filaDato(
                      context,
                      'Número de licencia',
                      usuario.numeroLicencia ?? '—',
                    ),
                    _filaDato(
                      context,
                      'Vencimiento',
                      _formatearFecha(usuario.fechaExpiracionLicencia),
                    ),
                    const SizedBox(height: 8),
                    _filaFotos(context, {
                      'Licencia (frente)': usuario.licenciaFrenteUrl,
                      'Licencia (dorso)': usuario.licenciaDorsoUrl,
                      'Selfie con licencia': usuario.selfieLicenciaUrl,
                    }),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Text(
                      'Vehículo',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    _filaDato(
                      context,
                      'Tipo',
                      usuario.tipoVehiculo == 'auto'
                          ? 'Automóvil'
                          : usuario.tipoVehiculo == 'moto'
                          ? 'Motocicleta'
                          : '—',
                    ),
                    _filaDato(context, 'Marca', usuario.marcaVehiculo ?? '—'),
                    _filaDato(context, 'Modelo', usuario.modeloVehiculo ?? '—'),
                    _filaDato(context, 'Color', usuario.colorVehiculo ?? '—'),
                    _filaDato(context, 'Placa', usuario.placaVehiculo ?? '—'),
                    _filaDato(
                      context,
                      'Año',
                      usuario.anioVehiculo?.toString() ?? '—',
                    ),
                    const SizedBox(height: 8),
                    _filaFotos(context, {
                      'Vehículo': usuario.fotoVehiculoUrl,
                      'Tarjeta de circulación': usuario.tarjetaCirculacionUrl,
                      'SOAT': usuario.soatUrl,
                    }),
                  ],
                  if (onAprobar != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: estaAprobando
                            ? null
                            : () => onAprobar!(usuario.uid),
                        icon: estaAprobando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check_outlined),
                        label: Text(estaAprobando ? 'Aprobando...' : 'Aprobar'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _filaDato(BuildContext context, String etiqueta, String valor) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: [
          TextSpan(
            text: '$etiqueta: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: valor),
        ],
      ),
    ),
  );

  /// Fila de miniaturas — solo las que sí se subieron ([fotos] mapea
  /// título → url, url puede ser null). Tocar una la abre a pantalla
  /// completa con zoom: la miniatura de 88x88 no alcanza para leer una
  /// placa o un número de licencia con detalle.
  Widget _filaFotos(BuildContext context, Map<String, String?> fotos) {
    final disponibles = fotos.entries.where((e) => e.value != null).toList();
    if (disponibles.isEmpty) {
      return const Text('Todavía no subió ninguna foto de esta sección.');
    }
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final entrada in disponibles)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                button: true,
                label: 'Ver foto: ${entrada.key}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => mostrarFotoCompleta(
                    context,
                    entrada.value!,
                    titulo: entrada.key,
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: RedNetworkImage(
                          entrada.value!,
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(
                        width: 88,
                        child: Text(
                          entrada.key,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
