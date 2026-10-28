/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:mysql_client/exception.dart' as mysql_client;

import '../exceptions.dart';
import '../util/my_sql_exception.dart';
import 'db.dart';

/// Creates a [Pool] whose members can be shared. The pool keeps a record of
/// between [minSize] and [maxSize] open items.
///
/// The [manager] contains the logic to open and close connections.
///
/// Example:
/// ```dart
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
/// ```
class SharedPool<T extends Transactionable> implements Pool<T> {
  @override
  final ConnectionManager<T> manager;

  late final logger = Logger('SharedPool');

  final int minSize;

  final int maxSize;

  final Duration excessDuration;

  /// Maximum number of attempts to open a replacement connection.
  final int maxConnectionAttempts;

  /// Maximum time allowed for one connection open or health check.
  final Duration connectionAttemptTimeout;

  /// Delay between failed connection attempts.
  final Duration retryDelay;

  /// Maximum time to wait for an in-use connection to be released.
  final Duration acquireTimeout;

  late Timer _releaseTimer;

  /// Used to track the set of connections and whether
  /// they are in use.
  final _pool = <ConnectionWrapper<T>, bool>{};

  Completer<void>? _available;

  var _pendingOpens = 0;

  var _closed = false;

  /// The [excessDuration] sets the duration after which we check
  /// for any excess connections and disconnect from them.
  SharedPool(
    this.manager, {
    required this.excessDuration,
    this.minSize = 10,
    this.maxSize = 10,
    this.maxConnectionAttempts = 5,
    this.connectionAttemptTimeout = const Duration(seconds: 10),
    this.retryDelay = const Duration(seconds: 10),
    this.acquireTimeout = const Duration(seconds: 30),
  }) {
    if (minSize < 0) {
      throw ConfigurationException(
          'The DBPool must have a minSize > 0, found $minSize');
    }
    if (maxSize < minSize) {
      throw ConfigurationException('The DBPool maxSize must be >= minSize. '
          'Found minSize: $minSize maxSize: $maxSize');
    }
    if (maxSize < 1) {
      throw ConfigurationException('The DBPool maxSize must be at least 1.');
    }
    if (maxConnectionAttempts < 1) {
      throw ConfigurationException(
          'The DBPool must make at least one connection attempt');
    }

    // start timer future to release excess connections.
    _releaseTimer = Timer(excessDuration, _releaseExcess);
  }

  int get size => _pool.length;

  Future<ConnectionWrapper<T>> _createNew() async {
    final open = manager.open();
    late final T n;
    try {
      n = await open.timeout(connectionAttemptTimeout);
    } on TimeoutException {
      unawaited(
        open.then(_closeLateConnection, onError: (Object _, StackTrace __) {}),
      );
      rethrow;
    }
    final conn = ConnectionWrapper._(this, n);
    // The opener owns the new connection until obtain() finishes validation.
    _pool[conn] = true;
    logger.finer(() => 'Created new connection: ${conn.wrapped.id}');

    return conn;
  }

  Future<void> _closeLateConnection(T connection) async {
    try {
      await manager.close(connection).timeout(connectionAttemptTimeout);
    } catch (error, stackTrace) {
      logger.warning(
        'Failed closing a connection that completed after its timeout',
        error,
        stackTrace,
      );
    }
  }

  /// Returns a connection
  @override
  Future<ConnectionWrapper<T>> obtain() async {
    final deadline = DateTime.now().add(acquireTimeout);
    while (true) {
      if (_closed) {
        throw StateError('The connection pool is closed.');
      }
      final conn = _findUnusedConnection();
      if (conn != null) {
        return _allocate(conn);
      }
      if (_pool.length + _pendingOpens < maxSize) {
        _pendingOpens++;
        var reserved = true;
        try {
          final created = await _validConnection(null);
          _pendingOpens--;
          reserved = false;
          _signalAvailable();
          return await _allocate(created);
        } finally {
          if (reserved) {
            _pendingOpens--;
            _signalAvailable();
          }
        }
      }

      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw TimeoutException(
            'Timed out waiting for a connection', acquireTimeout);
      }
      logger.finer(() => 'awaiting connection');
      final signal = _available ??= Completer<void>();
      await signal.future.timeout(remaining);
    }
  }

  void _signalAvailable() {
    final signal = _available;
    _available = null;
    if (signal != null && !signal.isCompleted) {
      signal.complete();
    }
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
    if (_closed) {
      return;
    }
    logger.finer(() => 'releaseExcess called');
    if (_pool.length > minSize) {
      logger.finer(() => 'Found potentional connections to release');
      final oneMinuteAgo = DateTime.now().subtract(excessDuration);
      for (final conn in _pool.keys) {
        if (_pool[conn] ?? true) {
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
          } catch (e, st) {
            logger.severe(() => 'Failed closing connection', e, st);
          }

          /// we release no more than one per minute.
          break;
        }
      }
    }

    // restart the timer.
    if (!_closed) {
      _releaseTimer = Timer(excessDuration, _releaseExcess);
    }
  }

  /// Releases [connection] back to the pool
  @override
  Future<void> release(ConnectionWrapper<T> connection) async {
    if (_pool[connection] != true) {
      throw StateError('Connection is not checked out from this pool.');
    }
    _deallocate(connection);
    connection.lastUsed = DateTime.now();
    _signalAvailable();
  }

  Future<ConnectionWrapper<T>> _allocate(ConnectionWrapper<T> conn) async {
    logger.finer(() => 'obtained connection ${conn.wrapped.id}');

    /// mark conn as in use before we call await so
    /// that another async method can't obtain it.
    _pool[conn] = true;
    final conn0 = await _validConnection(conn, reserveReplacement: true);
    _pool[conn0] = true;
    return conn0;
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
  Future<ConnectionWrapper<T>> _validConnection(ConnectionWrapper<T>? conn,
      {bool reserveReplacement = false}) async {
    String? lastError;

    var reserved = false;
    void reserve() {
      if (reserveReplacement && !reserved) {
        _pendingOpens++;
        reserved = true;
      }
    }

    try {
      if (conn != null) {
        try {
          if (await conn.wrapped.test().timeout(connectionAttemptTimeout)) {
            return conn;
          }
        } catch (e) {
          lastError = e.toString();
          reserve();
          await _removeBadConnection(conn);
          if (!_isRetryable(e)) {
            rethrow;
          }
          conn = null;
        }
        if (conn != null) {
          reserve();
          await _removeBadConnection(conn);
        }
      }

      for (var attempt = 1; attempt <= maxConnectionAttempts; attempt++) {
        try {
          final replacement = await _createNew();
          if (lastError != null) {
            logger.warning('Connection to MySQL succeeded.');
          }
          return replacement;
        } catch (e) {
          lastError = e.toString();
          if (_isAccessDenied(e)) {
            break;
          }
          if (!_isRetryable(e)) {
            rethrow;
          }
          if (attempt < maxConnectionAttempts) {
            await _logAndWait(lastError);
          }
        }
      }

      logger.severe('Unable to connect to db. $lastError');
      throw MySqlORMException('Unable to connect to db. $lastError');
    } finally {
      if (reserved) {
        _pendingOpens--;
        _signalAvailable();
      }
    }
  }

  bool _isAccessDenied(Object error) =>
      (error is MySqlException &&
          error.message.contains('Access denied for user')) ||
      (error is mysql_client.MySQLServerException && error.errorCode == 1045);

  bool _isRetryable(Object error) =>
      error is StateError ||
      error is MySqlException ||
      error is mysql_client.MySQLClientException ||
      error is SocketException ||
      error is TimeoutException;

  /// Throws a MySQLException if we find a connection
  /// that hasn't been released or is still in a transaction.
  Future<void> close() async {
    final inTransaction = <int>[];
    final notReleased = <int>[];
    for (final conn in _pool.keys) {
      if (_pool[conn] ?? false) {
        notReleased.add(conn.id);
      } else if (conn.inTransaction) {
        inTransaction.add(conn.id);
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

    if (_pendingOpens != 0) {
      throw MySQLException('Connection opens are still pending.');
    }

    _closed = true;
    _signalAvailable();
    _releaseTimer.cancel();
    for (final conn in _pool.keys) {
      await conn.close();
    }
    _pool.clear();
  }

  Future<void> _logAndWait(String message) async {
    logger.warning('Connection attempt failed: $message. '
        'Retrying in ${retryDelay.inSeconds} seconds');
    await Future<void>.delayed(retryDelay);
  }

  Future<void> _removeBadConnection(ConnectionWrapper<T>? conn) async {
    if (conn != null) {
      logger.warning(() => 'Found bad connection: ${conn.id}. Replacing it.');
      _pool.remove(conn);
      try {
        await manager.close(conn.wrapped).timeout(connectionAttemptTimeout);
      } catch (error, stackTrace) {
        logger.fine(
          'Failed closing discarded connection ${conn.id}',
          error,
          stackTrace,
        );
      }
    }
  }
}

/// A connection
class ConnectionWrapper<T extends Transactionable> {
  /// The connection [Pool] this connection belongs to.
  final Pool<T> pool;

  /// The underlying connection
  final T _wrapped;

  /// Is this connection released to the pool?
  var isReleased = false;

  /// when this connection was last used.
  var lastUsed = DateTime.now();

  ConnectionWrapper._(this.pool, this._wrapped);

  /// Releases the connection
  Future<void> release() => pool.release(this);

  bool get inTransaction => _wrapped.inTransaction;

  int get id => _wrapped.id;

  T get wrapped => _wrapped;

  Future<void> close() => _wrapped.close();
}

/// Interface to open and close the connection [C]
abstract class ConnectionManager<C> {
  /// Establishes and returns a new connection
  Future<C> open();

  /// Closes provided[connection]
  Future<void> close(C connection);
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
