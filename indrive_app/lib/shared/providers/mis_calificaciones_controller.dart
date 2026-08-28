import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../domain/entities/calificacion.dart';

/// Calificaciones recibidas por el usuario autenticado, en tiempo real
/// (Sprint 13) — compartido por Cliente y Repartidor.
final misCalificacionesControllerProvider =
    StreamProvider<List<Calificacion>>((ref) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return Stream.value(const []);
      return ref
          .watch(usersRepositoryProvider)
          .streamMisCalificaciones(uid)
          .map(
            (snapshot) => snapshot.docs
                .map(
                  (doc) => Calificacion.fromFirestore(
                    doc,
                    // Collection group: el envío dueño de esta calificación
                    // es el padre del padre
                    // (envios/{envioId}/calificaciones/{autorId}).
                    envioId: doc.reference.parent.parent!.id,
                  ),
                )
                .toList(),
          );
    });
