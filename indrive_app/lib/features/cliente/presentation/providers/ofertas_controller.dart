import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../../../shared/domain/entities/oferta.dart';

/// Propuestas de un envío en tiempo real (Sprint 13). Reemplaza el fetch
/// puntual anterior — ver `EnviosRepository.streamOfertas` para el porqué.
final ofertasControllerProvider = StreamProvider.family<List<Oferta>, String>((
  ref,
  envioId,
) {
  return ref
      .watch(enviosRepositoryProvider)
      .streamOfertas(envioId)
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => Oferta.fromFirestore(doc, envioId: envioId))
            .toList(),
      );
});
