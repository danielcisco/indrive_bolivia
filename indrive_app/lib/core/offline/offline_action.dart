/// Una acción crítica pendiente de sincronizar. El [id] (UUIDv4) es la
/// clave de idempotencia: quien la ejecuta debe usarlo como ID del
/// documento remoto que escribe, para que reintentar tras un fallo de red
/// sobreescriba en vez de duplicar.
class OfflineAction {
  const OfflineAction({
    required this.id,
    required this.type,
    required this.payload,
    required this.attemptCount,
    required this.nextAttemptAt,
    required this.createdAt,
  });

  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final int attemptCount;
  final DateTime nextAttemptAt;
  final DateTime createdAt;
}
