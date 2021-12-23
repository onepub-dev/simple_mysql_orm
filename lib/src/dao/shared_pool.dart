import 'dart:async';

import 'package:logging/logging.dart';

import '../util/counted_set.dart';

/// Creates a [Pool] whose members can be shared. The pool keeps a record of
/// between [minSize] and [maxSize] open items.
///
/// The [manager] contains the logic to open and close connections.
///
/// Example:
///     final pool = SharedPool(PostgresManager('exampleDB'), minSize: 5,
///                    maxSize: 10);
///     createTable() async {
///       Connection<PostgreSQLConnection> conn = await pool.get();
///       PostgreSQLConnection db = conn.connection;
///       await db.execute(
///           "CREATE TABLE posts (id SERIAL PRIMARY KEY, name VARCHAR(255),
///              age INT);");
///       await conn.release();
///     }
class SharedPool<T> implements Pool<T> {
  SharedPool(this.manager, {this.minSize = 10, this.maxSize = 10})
      : _d = maxSize - minSize;
  @override
  final ConnectionManager<T> manager;

  late final logger = Logger('SharedPool');

  final int minSize;
  final int maxSize;
  final _pool = CountedSet<ConnectionWrapper<T>>();

  Future<ConnectionWrapper<T>> _createNew() async {
    final n = await manager.open();
    final conn = ConnectionWrapper._(this, n);
    _pool.add(1, conn);
    return conn;
  }

  /// Returns a connection
  @override
  Future<ConnectionWrapper<T>> get() async {
    if (_pool.numAt(0) > 0 || _pool.length >= maxSize) {
      final conn = _pool.leastUsed!;
      _pool.inc(conn);
      return conn;
    }
    return _createNew();
  }

  final int _d;

  /// Releases [connection] back to the pool
  @override
  Future<void> release(ConnectionWrapper<T> connection) async {
    if (_d <= 0) {
      return;
    }
    if (!connection.isReleased) {
      _pool.dec(connection);
    }
    if (_pool.length != maxSize) {
      return;
    }
    if (_pool.numAt(0) < _d) {
      return;
    }
    final removes = _pool.removeAllAt(0);
    for (final r in removes) {
      try {
        if (r.isReleased) {
          continue;
        }
        r.isReleased = true;
        manager.close(r.wrapped);
        // ignore: avoid_catches_without_on_clauses
      } catch (e, st) {
        logger.severe(() => 'Failed closing connection', e, st);
      }
    }
  }
}

/// A connection
class ConnectionWrapper<T> {
  ConnectionWrapper._(this.pool, this._wrapped);

  /// Releases the connection
  Future<void> release() => pool.release(this);

  /// The connection [Pool] this connection belongs to.
  final Pool<T> pool;

  /// The underlying connection
  final T _wrapped;

  /// Is this connection released to the pool?
  bool isReleased = false;

  T get wrapped => _wrapped;
}

/// Interface to open and close the connection [C]
abstract class ConnectionManager<C> {
  /// Establishes and returns a new connection
  FutureOr<C> open();

  /// Closes provided[connection]
  FutureOr<void> close(C connection);
}

/// Interface for pool
abstract class Pool<T> {
  /// Contains logic to open and close connections.
  ConnectionManager<T> get manager;

  /// Returns a new connection
  Future<ConnectionWrapper<T>> get();

  /// Releases [connection] back to the pool.
  Future<void> release(ConnectionWrapper<T> connection);
}
