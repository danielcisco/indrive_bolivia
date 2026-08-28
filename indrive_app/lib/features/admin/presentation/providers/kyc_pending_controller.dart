import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/providers.dart';
import '../../domain/usuario_kyc_pendiente.dart';

/// Lista en tiempo real de usuarios con KYC pendiente (sprint extra) —
/// antes era un fetch puntual (`AsyncNotifier` de una sola pasada, mismo
/// esqueleto que `MisEnviosController`/`RadarController`) que nunca se
/// refrescaba solo: una cuenta recién registrada no aparecía en el panel
/// Admin hasta recargar la pantalla a mano (bug real reportado). Un
/// `StreamProvider` sobre la misma query acotada por `.limit()` se
/// autoactualiza apenas se crea o aprueba una cuenta.
final kycPendingControllerProvider =
    StreamProvider<List<UsuarioKycPendiente>>((ref) {
      return ref
          .watch(usersRepositoryProvider)
          .streamUsuariosPendientesKyc()
          .map(
            (snapshot) =>
                snapshot.docs.map(UsuarioKycPendiente.fromFirestore).toList(),
          );
    });
