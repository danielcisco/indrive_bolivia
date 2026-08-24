import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'offline_action.dart';
import 'queue_database.dart';

typedef OfflineActionHandler = Future<void> Function(OfflineAction action);

const Duration _maxBackoff = Duration(minutes: 5);

/// Cola de acciones críticas persistida en SQLite, con reintentos por
/// backoff exponencial. Sin handlers concretos todavía: Sprint 3.x
/// registrará acciones reales ("crear envío", "enviar oferta") vía
/// [registerHandler]; por ahora esto es solo la infraestructura.
class OfflineActionQueue {
  OfflineActionQueue({QueueDatabase? database, Uuid? uuid})
    : _database = database ?? QueueDatabase(),
      _uuid = uuid ?? const Uuid();

  final QueueDatabase _database;
  final Uuid _uuid;
  final Map<String, OfflineActionHandler> _handlers = {};
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  void registerHandler(String type, OfflineActionHandler handler) {
    _handlers[type] = handler;
  }

  /// Encola una acción y devuelve su id (UUIDv4). Quien la crea debe usar
  /// ese mismo id como ID del documento remoto que escribe.
  Future<String> enqueue({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    final id = _uuid.v4();
    final db = await _database.open();
    final now = DateTime.now();
    await db.insert('offline_actions', {
      'id': id,
      'type': type,
      'payload': jsonEncode(payload),
      'attempt_count': 0,
      'next_attempt_at': now.millisecondsSinceEpoch,
      'created_at': now.millisecondsSinceEpoch,
    });
    return id;
  }

  /// Procesa las acciones cuyo `nextAttemptAt` ya venció. Se llama al
  /// arrancar la app y al recuperar conectividad (ver [startListening]).
  Future<void> processPending() async {
    final db = await _database.open();
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'offline_actions',
      where: 'next_attempt_at <= ?',
      whereArgs: [now],
      orderBy: 'created_at ASC',
    );

    for (final row in rows) {
      final action = OfflineAction(
        id: row['id']! as String,
        type: row['type']! as String,
        payload:
            jsonDecode(row['payload']! as String) as Map<String, dynamic>,
        attemptCount: row['attempt_count']! as int,
        nextAttemptAt: DateTime.fromMillisecondsSinceEpoch(
          row['next_attempt_at']! as int,
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['created_at']! as int,
        ),
      );
      await _processOne(db, action);
    }
  }

  Future<void> _processOne(Database db, OfflineAction action) async {
    final handler = _handlers[action.type];
    if (handler == null) return;

    try {
      await handler(action);
      await db.delete(
        'offline_actions',
        where: 'id = ?',
        whereArgs: [action.id],
      );
    } catch (_) {
      final nextAttempt = action.attemptCount + 1;
      final backoffSeconds = min(
        pow(2, nextAttempt).toInt(),
        _maxBackoff.inSeconds,
      );
      final nextAttemptAt = DateTime.now().add(
        Duration(seconds: backoffSeconds),
      );
      await db.update(
        'offline_actions',
        {
          'attempt_count': nextAttempt,
          'next_attempt_at': nextAttemptAt.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [action.id],
      );
    }
  }

  Future<int> pendingCount() async {
    final db = await _database.open();
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM offline_actions',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Dispara [processPending] cada vez que el dispositivo recupera
  /// conectividad.
  void startListening() {
    _connectivitySubscription ??= Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        processPending();
      }
    });
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    await _database.close();
  }
}
