import 'dart:async';
import 'dart:io';

import 'package:simple_mysql_orm/simple_mysql_orm.dart';
import 'package:simple_mysql_orm/src/dao/shared_pool.dart';
import 'package:test/test.dart';

void main() {
  test('stops opening connections after five attempts', () async {
    final manager = _FailingManager();
    final pool = SharedPool<_FakeConnection>(
      manager,
      minSize: 0,
      maxSize: 1,
      excessDuration: const Duration(days: 1),
      retryDelay: Duration.zero,
    );

    await expectLater(pool.obtain(), throwsA(isA<Exception>()));

    expect(manager.openCalls, 5);
    await pool.close();
  });

  test('closes a connection that opens after the attempt timeout', () async {
    final manager = _DelayedManager();
    final pool = SharedPool<_FakeConnection>(
      manager,
      minSize: 0,
      maxSize: 1,
      excessDuration: const Duration(days: 1),
      maxConnectionAttempts: 1,
      connectionAttemptTimeout: const Duration(milliseconds: 10),
      retryDelay: Duration.zero,
    );

    await expectLater(
      pool.obtain(),
      throwsA(
        isA<MySqlORMException>().having(
          (error) => error.toString(),
          'message',
          contains('TimeoutException'),
        ),
      ),
    );
    manager.completeOpen();
    await manager.closed.future.timeout(const Duration(seconds: 1));

    expect(manager.closeCalls, 1);
    expect(pool.size, 0);
    await pool.close();
  });
}

class _FailingManager implements ConnectionManager<_FakeConnection> {
  var openCalls = 0;

  @override
  Future<_FakeConnection> open() {
    openCalls++;
    return Future.error(const SocketException('unavailable'));
  }

  @override
  Future<void> close(_FakeConnection connection) => Future.value();
}

class _DelayedManager implements ConnectionManager<_FakeConnection> {
  final _open = Completer<_FakeConnection>();
  final closed = Completer<void>();
  var closeCalls = 0;

  void completeOpen() => _open.complete(_FakeConnection(1));

  @override
  Future<_FakeConnection> open() => _open.future;

  @override
  Future<void> close(_FakeConnection connection) async {
    closeCalls++;
    closed.complete();
  }
}

class _FakeConnection implements Transactionable {
  @override
  final int id;

  _FakeConnection(this.id);

  @override
  bool get inTransaction => false;

  @override
  Future<void> close() async {}

  @override
  Future<bool> test() async => true;
}
