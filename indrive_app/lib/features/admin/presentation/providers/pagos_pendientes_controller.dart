import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/domain/entities/envio.dart';

/// Envíos entregados con pago QR, en tiempo real (sprint extra:
/// historial en Admin) — pendientes y verificados juntos; la pantalla
/// los separa por `pagoVerificado` para sus 2 pestañas. Ver el doc de
/// `EnviosRepository.streamPagosQr` para el porqué de un solo stream
/// para ambas.
final pagosQrProvider = StreamProvider<List<Envio>>((ref) {
  return ref
      .watch(enviosRepositoryProvider)
      .streamPagosQr()
      .map((snapshot) => snapshot.docs.map(Envio.fromFirestore).toList());
});
