import 'package:flutter_test/flutter_test.dart';
import 'package:indrive_app/core/offline/offline_action.dart';
import 'package:indrive_app/core/offline/offline_action_queue.dart';
import 'package:indrive_app/core/offline/queue_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late OfflineActionQueue queue;

  setUp(() {
    queue = OfflineActionQueue(
      database: QueueDatabase(path: inMemoryDatabasePath),
    );
  });

  tearDown(() async {
    await queue.dispose();
  });

  test('enqueue + processPending ejecuta el handler y limpia la cola', () async {
    final processed = <OfflineAction>[];
    queue.registerHandler('test_action', (action) async {
      processed.add(action);
    });

    final id = await queue.enqueue(
      type: 'test_action',
      payload: {'foo': 'bar'},
    );
    await queue.processPending();

    expect(processed, hasLength(1));
    expect(processed.single.id, id);
    expect(processed.single.payload, {'foo': 'bar'});
    expect(await queue.pendingCount(), 0);
  });

  test('reintenta con backoff exponencial si el handler falla', () async {
    var attempts = 0;
    queue.registerHandler('fallible', (action) async {
      attempts++;
      throw Exception('fallo simulado');
    });

    await queue.enqueue(type: 'fallible', payload: {});
    await queue.processPending();

    expect(attempts, 1);
    expect(await queue.pendingCount(), 1);

    // El próximo intento queda agendado en el futuro (backoff): un segundo
    // processPending() inmediato no debería re-ejecutar el handler todavía.
    await queue.processPending();
    expect(attempts, 1);
  });

  test('sin handler registrado, la acción queda pendiente sin lanzar', () async {
    await queue.enqueue(type: 'sin_handler', payload: {});
    await queue.processPending();
    expect(await queue.pendingCount(), 1);
  });
}
