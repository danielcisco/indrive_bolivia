import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/domain/entities/envio.dart';
import '../../../../shared/theme/colores_semanticos.dart';
import '../../../../shared/widgets/envio_historial_card.dart' show formatearFechaCorta;
import '../../../../shared/widgets/red_network_image.dart';
import '../../../../shared/widgets/soporte_whatsapp.dart';
import '../providers/pagos_pendientes_controller.dart';

/// Pagos QR de Admin (sprint extra: historial) — 2 pestañas sobre el
/// mismo stream (`pagosQrProvider`): "Pendientes" (sin verificar, como
/// antes) e "Historial" (ya verificados, con fecha) — separados en
/// memoria por `pagoVerificado`, ver el doc de `streamPagosQr`.
class PagosPendientesScreen extends ConsumerStatefulWidget {
  const PagosPendientesScreen({super.key});

  @override
  ConsumerState<PagosPendientesScreen> createState() =>
      _PagosPendientesScreenState();
}

class _PagosPendientesScreenState extends ConsumerState<PagosPendientesScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 2, vsync: this);
  final _verificando = <String>{};

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _verificar(String envioId) async {
    if (_verificando.contains(envioId)) return;
    setState(() => _verificando.add(envioId));
    try {
      await ref.read(enviosRepositoryProvider).verificarPago(envioId);
    } catch (_) {
      if (mounted) {
        mostrarErrorConSoporte(
          context,
          ref,
          mensaje: 'No pudimos verificar el pago. Probá de nuevo.',
          app: 'Admin',
          motivo: 'no puedo verificar un pago QR',
        );
      }
    } finally {
      if (mounted) setState(() => _verificando.remove(envioId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(pagosQrProvider);

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
          child: estado.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => const SupportErrorView(
              mensaje: 'No pudimos cargar los pagos QR. Revisá tu '
                  'conexión y volvé a intentar.',
              app: 'Admin',
              motivo: 'no puedo ver la lista de pagos QR',
            ),
            data: (envios) {
              final pendientes = envios
                  .where((envio) => !envio.pagoVerificado)
                  .toList();
              final historial = envios
                  .where((envio) => envio.pagoVerificado)
                  .toList();
              return TabBarView(
                controller: _tabController,
                children: [
                  _ListaPendientes(
                    envios: pendientes,
                    verificando: _verificando,
                    onVerificar: _verificar,
                  ),
                  _ListaHistorial(envios: historial),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ListaPendientes extends StatelessWidget {
  const _ListaPendientes({
    required this.envios,
    required this.verificando,
    required this.onVerificar,
  });

  final List<Envio> envios;
  final Set<String> verificando;
  final ValueChanged<String> onVerificar;

  @override
  Widget build(BuildContext context) {
    if (envios.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_outlined, size: 48),
              SizedBox(height: 8),
              Text('No hay pagos QR pendientes de verificar.'),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: envios.length,
      itemBuilder: (context, index) {
        final envio = envios[index];
        final estaVerificando = verificando.contains(envio.id);
        final comprobanteUrl = envio.comprobanteUrl;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  envio.descripcion,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(envio.montoOfertadoInicial.format()),
                const SizedBox(height: 8),
                if (comprobanteUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: RedNetworkImage(
                      comprobanteUrl,
                      height: 220,
                      fit: BoxFit.contain,
                    ),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: estaVerificando
                        ? null
                        : () => onVerificar(envio.id),
                    icon: estaVerificando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_outlined),
                    label: Text(
                      estaVerificando ? 'Verificando...' : 'Marcar como verificado',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ListaHistorial extends StatelessWidget {
  const _ListaHistorial({required this.envios});

  final List<Envio> envios;

  @override
  Widget build(BuildContext context) {
    if (envios.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, size: 48),
              SizedBox(height: 8),
              Text('Todavía no hay pagos QR verificados.'),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: envios.length,
      itemBuilder: (context, index) {
        final envio = envios[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: Icon(
              Icons.check_circle_outline,
              color: ColoresSemanticos.exito(context).$1,
            ),
            title: Text(envio.descripcion),
            subtitle: Text(envio.montoOfertadoInicial.format()),
            trailing: Text(
              envio.fechaVerificacionPago != null
                  ? 'Verificado ${formatearFechaCorta(envio.fechaVerificacionPago)}'
                  : 'Fecha no disponible',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        );
      },
    );
  }
}
