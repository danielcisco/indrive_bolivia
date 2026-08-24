import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Envuelve la base SQLite de la cola offline. Solo Android (Cliente y
/// Repartidor) la usa — el panel Admin es un dashboard siempre-online y no
/// la importa.
class QueueDatabase {
  // ignore: prefer_initializing_formals
  QueueDatabase({String? path}) : _path = path;

  final String? _path;
  Database? _db;

  Future<Database> open() async {
    final existing = _db;
    if (existing != null) return existing;

    final dbPath = _path ?? p.join(await getDatabasesPath(), 'offline_queue.db');
    final db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE offline_actions (
          id TEXT PRIMARY KEY,
          type TEXT NOT NULL,
          payload TEXT NOT NULL,
          attempt_count INTEGER NOT NULL,
          next_attempt_at INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        )
      '''),
    );
    _db = db;
    return db;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
