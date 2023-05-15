/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';

import '../exceptions.dart';
import '../util/my_sql_exception.dart';
import 'db.dart';

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
class SharedPool<T extends Transactionable> implements Pool<T> {
  /// The [excessDuration] sets the duration after which we check
  /// for any excess connections and disconnect from them.
  SharedPool(
    this.manager, {
    required this.excessDuration,
    this.minSize = 10,
    this.maxSize = 10,
  }) {
    if (minSize < 0) {
      throw ConfigurationException(
          'The DBPool must have a minSize > 0, found $minSize');
    }
    if (maxSize < minSize) {
      throw ConfigurationException('The DBPool maxSize must be >= minSize. '
          'Found minSize: $minSize maxSize: $maxSize');
    }

    // we start in a state where we have connections available.
    available.complete(true);

    // start timer future to release excess connections.
    _releaseTimer = Timer(excessDuration, _releaseExcess);
  }
  @override
  final ConnectionManager<T> manager;

  late final logger = Logger('SharedPool');

  final int minSize;
  final int maxSize;
  final Duration excessDuration;

  late Timer _releaseTimer;

  /// Used to track the set of connections and whether
  /// they are in use.
  final _pool = <ConnectionWrapper<T>, bool>{};

  int get size => _pool.length;

  Future<ConnectionWrapper<T>> _createNew() async {
    final n = await manager.open();
    final conn = ConnectionWrapper._(this, n);
    _pool[conn] = false;
    logger.finer(() => 'Created new connection: ${conn.wrapped.id}');

    return conn;
  }

  Completer<bool> available = Completer<bool>();

  /// Returns a connection
  @override
  Future<ConnectionWrapper<T>> obtain() async {
    final conn = _findUnusedConnection();

    if (conn != null) {
      return _allocate(conn);
    }

    /// we have no unused connections.
    if (_pool.length >= maxSize) {
      /// we need to wait for a connection to become available
      available = Completer<bool>();
      // wait for a connection to become available
      logger.finer(() => 'awaiting connection');
      await available.future;
      return _allocate(_findUnusedConnection()!);
    }

    return _allocate(await _validConnection(null));
  }

  ConnectionWrapper<T>? _findUnusedConnection() {
    for (final connection in _pool.keys) {
      if (_pool[connection] == false) {
        return connection;
      }
    }
    return null;
  }

  /// Over time we want to release connections that
  /// have not been used and are in excess of [minSize]
  /// We release one connection every minute provided
  /// it hasn't been used for at least a minute;
  Future<void> _releaseExcess() async {
    logger.finer(() => 'releaseExcess called');
    if (_pool.length > minSize) {
      logger.finer(() => 'Found potentional connections to release');
      final oneMinuteAgo = DateTime.now().subtract(excessDuration);
      for (final conn in _pool.keys) {
        if (_pool[conn] ?? true == true) {
          logger.finer(() => 'connection ${conn.wrapped.id} in use');

          /// connection is in use.
          continue;
        }
        if (conn.lastUsed.isBefore(oneMinuteAgo)) {
          _pool.remove(conn);

          try {
            await manager.close(conn.wrapped);
            logger.finer(() =>
                'removed from pool unused connection: ${conn.wrapped.id}');
            // ignore: avoid_catches_without_on_clauses
          } catch (e, st) {
            logger.severe(() => 'Failed closing connection', e, st);
          }

          /// we release no more than one per minute.
          break;
        }
      }
    }

    // restart the timer.
    _releaseTimer = Timer(excessDuration, _releaseExcess);
  }

  /// Releases [connection] back to the pool
  @override
  Future<void> release(ConnectionWrapper<T> connection) async {
    _deallocate(connection);

    /// tell anyone trying to obtain a connection
    /// that we now have some available.
    if (!available.isCompleted) {
      logger.finer(() => 'flagged connections available');
      available.complete(true);
    }
  }

  Future<ConnectionWrapper<T>> _allocate(ConnectionWrapper<T> conn) async {
    logger.finer(() => 'obtained connection ${conn.wrapped.id}');

    /// mark conn as in use before we call await so
    /// that another async method can't obtain it.
    _pool[conn] = true;

    final _conn = await _validConnection(conn);

    // Mark the returned connection as in use as it
    // may be different from the one we passed in.
    _pool[_conn] = true;

    return _conn;
  }

  void _deallocate(ConnectionWrapper<T> conn) {
    logger.finer(() => 'released connection ${conn.wrapped.id}');

    if (conn.wrapped.inTransaction) {
      throw StateError('Attempted to release a connection ${conn.wrapped.id} '
          'whilst a transaction was pending.');
    }
    _pool[conn] = false;
  }

  /// Checks that the passed [conn] is still valid
  /// and if not replaces it with a valid connection.
  /// If a replacement connection can't be obtained
  /// then an exception will be thrown.
  Future<ConnectionWrapper<T>> _validConnection(
      ConnectionWrapper<T>? conn) async {
    var _conn = conn;
    var retries = 30;
    var success = false;

    String? lastError;
    while (!success && retries > 0) {
      try {
        if (_conn != null && await _conn.wrapped.test()) {
          success = true;
          if (lastError != null) {
            logger.warning('Connection to MySQL succeeded.');
          }
          break;
        } else {
          if (_conn != null) {
            _removeBadConnection(_conn);
            _conn = null;
          }
          retries--;
          _conn = await _createNew();
          success = true;
          break;
        }
        // ignore: avoid_catches_without_on_clauses
      } catch (e) {
        // remove the bad connection
        _removeBadConnection(_conn);
        _conn = null;
        lastError = e.toString();
        if (e is MySqlException) {
          /// no point retrying if its access denied.
          if (e.message.contains('Access denied for user')) {
            break;
          } else {
            await _logAndWait(lastError);
          }
        }
        if (e is StateError || e is MySqlException || e is SocketException) {
          await _logAndWait(lastError);
        } else {
          rethrow;
        }
      }
    }
    if (!success) {
      logger.severe('Unable to connect to db. $lastError');
      throw MySqlORMException('Unable to connect to db. $lastError');
    }

    return _conn!;
  }

  /// Throws a MySQLException if we find a connection
  /// that hasn't been released or is still in a transaction.
  Future<void> close() async {
    final inTransaction = <int>[];
    final notReleased = <int>[];
    for (final conn in _pool.keys) {
      if (_pool[conn] ?? false == true) {
        notReleased.add(conn.id);
      } else if (conn.inTransaction) {
        inTransaction.add(conn.id);
      } else {
        await conn.close();
      }
    }
    var error = '';

    if (inTransaction.isNotEmpty) {
      error += 'Found one or more connections still in a transation: '
          '${inTransaction.join(',')}';
    }
    if (notReleased.isNotEmpty) {
      error += 'Found one or more connections not released: '
          '${notReleased.join(',')}';
    }

    if (error.isNotEmpty) {
      throw MySQLException(error);
    }

    _releaseTimer.cancel();
  }

  Future<void> _logAndWait(String message) async {
    logger.warning('Connection attempt failed: $message. '
        'Retrying in 10 seconds');
    // sleep 10 secondss
    await Future.delayed(const Duration(seconds: 10), () => null);
  }

  void _removeBadConnection(ConnectionWrapper<T>? conn) {
    if (conn != null) {
      logger.warning(() => 'Found bad connection: ${conn.id}. Replacing it.');
      // remove the invalid connection
      _pool.remove(conn);
    }
  }
}

/// A connection
class ConnectionWrapper<T extends Transactionable> {
  ConnectionWrapper._(this.pool, this._wrapped);

  /// Releases the connection
  Future<void> release() => pool.release(this);

  /// The connection [Pool] this connection belongs to.
  final Pool<T> pool;

  /// The underlying connection
  final T _wrapped;

  bool get inTransaction => _wrapped.inTransaction;

  int get id => _wrapped.id;

  /// Is this connection released to the pool?
  bool isReleased = false;

  T get wrapped => _wrapped;

  /// when this connection was last used.
  DateTime lastUsed = DateTime.now();

  Future<void> close() async => _wrapped.close();
}

/// Interface to open and close the connection [C]
abstract class ConnectionManager<C> {
  /// Establishes and returns a new connection
  FutureOr<C> open();

  /// Closes provided[connection]
  FutureOr<void> close(C connection);
}

/// Interface for pool
abstract class Pool<T extends Transactionable> {
  /// Contains logic to open and close connections.
  ConnectionManager<T> get manager;

  /// Returns a new connection
  Future<ConnectionWrapper<T>> obtain();

  /// Releases [connection] back to the pool.
  Future<void> release(ConnectionWrapper<T> connection);
}
