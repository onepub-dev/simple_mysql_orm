/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dcli/dcli.dart';
import 'package:logging/logging.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:scope/scope.dart';

import '../../simple_mysql_orm.dart';
import '../util/connection_settings.dart';
import '../util/my_sql_exception.dart';

class Db implements Transactionable {
  final logger = Logger('Db');

  static var __nextId = 0;

  @override
  late final int id;

  static var mysqlPortKey = 'MYSQL_PORT';

  static var mysqlHostKey = 'MYSQL_HOST';

  static var mysqlDatabaseKey = 'MYSQL_DATABASE';

  static const mysqlUsernameKey = 'MYSQL_USER';

  static const mysqlPasswordKey = 'MYSQL_PASSWORD';

  static const mysqlUseSSLKey = 'MYSQL_USE_SSL';

  late final ConnectionSettings settings;

  MySQLConnection? _connection;

  static var queryCount = 0;

  var _localQueryCount = 0;

  @override
  var inTransaction = false;

  factory Db.fromEnv() {
    final user = getEnv(mysqlUsernameKey);
    final password = getEnv(mysqlPasswordKey);

    final useSSL =
        (env[mysqlUseSSLKey] ?? 'true').trim().toLowerCase() == 'true';

    return Db._internal(
      host: env[mysqlHostKey] ?? 'localhost',
      port: int.tryParse(env[mysqlPortKey] ?? '3306') ?? 3306,
      user: user,
      password: password,
      database: env[mysqlDatabaseKey] ?? 'smo',
      useSSL: useSSL,
    );
  }

  factory Db.fromSettingsNoDatabase(ConnectionSettings settings) =>
      Db._internal(
        database: null,
        host: settings.host,
        port: settings.port,
        user: settings.user,
        password: settings.password,
        useSSL: settings.useSSL,
      );

  factory Db.fromSettings(ConnectionSettings settings) => Db._internal(
        database: settings.db,
        host: settings.host,
        port: settings.port,
        user: settings.user,
        password: settings.password,
        useSSL: settings.useSSL,
      );

  Db._internal({
    required String host,
    required int port,
    required String user,
    required String password,
    required String? database,
    required bool useSSL,
  }) {
    id = _nextId;
    settings = ConnectionSettings(
      host: host,
      port: port,
      user: user,
      password: password,
      db: database,
      useSSL: useSSL,
    );
  }

  static int get _nextId =>
      use(TransactionTestScope.dbTestIdKey, withDefault: () => __nextId++);

  MySQLConnection get connection {
    if (_connection == null) {
      throw StateError('You must call connect() first.');
    }
    return _connection!;
  }

  Future<void> connect() async {
    _connection = await settings.createConnection();
  }

  @override
  Future<void> close() async {
    await _connection?.close();
    _connection = null;
  }

  /// NEW: run a query, expose `IResultSet` to a callback, then free any PS.
  /// Use this for SELECTs (or any query) when callers need to read rows.
  Future<T> withResults<T>(
    String query, {
    required FutureOr<T> Function(IResultSet rs) action,
    ValueList? values,
  }) async {
    logger.fine(() => 'Db: $id qid: $_localQueryCount ${_colour(query)}, '
        'values:[${_expandValues(values)}]');

    PreparedStmt? stmt;
    IResultSet? rs;
    try {
      if (values == null || values.isEmpty) {
        // Text protocol; no server-side PS.
        rs = await connection.execute(query);
      } else {
        stmt = await connection.prepare(query); // alloc server PS
        rs = await stmt.execute(values);
      }
      _localQueryCount++;
      queryCount++;
      return await action(rs);
    } on MySqlException catch (e) {
      final userStack = StackTrace.current;
      logger.severe(
        'Db: $id qid: $_localQueryCount ${_colour(query)}, '
        'values:[${_expandValues(values)}]\n'
        'Error ${e.errorNumber}: ${e.message}',
        e,
        userStack,
      );
      Error.throwWithStackTrace(e, userStack);
    } finally {
      if (stmt != null) {
        try {
          await stmt.deallocate(); // frees server PS after callback completes
          // ignore all errors
          // ignore: avoid_catches_without_on_clauses
        } catch (_) {
          // ignore
        }
      }
    }
  }

  /// PRIVATE: the old `query` (kept for internal/simple DML usage).
  Future<IResultSet> _query(String query, [ValueList? values]) async {
    logger.fine(() => 'Db: $id qid: $_localQueryCount ${_colour(query)}, '
        'values:[${_expandValues(values)}]');

    PreparedStmt? stmt;
    try {
      if (values == null || values.isEmpty) {
        final rs = await connection.execute(query);
        _localQueryCount++;
        queryCount++;
        return rs;
      }

      stmt = await connection.prepare(query);
      final rs = await stmt.execute(values);
      _localQueryCount++;
      queryCount++;
      return rs;
    } on MySqlException catch (e) {
      final userStack = StackTrace.current;
      logger.severe(
        'Db: $id qid: $_localQueryCount ${_colour(query)}, '
        'values:[${_expandValues(values)}]\n'
        'Error ${e.errorNumber}: ${e.message}',
        e,
        userStack,
      );
      Error.throwWithStackTrace(e, userStack);
    } finally {
      if (stmt != null) {
        try {
          await stmt.deallocate();
          // ignore all errors as we are in a finally
          // ignore: avoid_catches_without_on_clauses
        } catch (_) {}
      }
    }
  }

  static String getEnv(String key, {String? defaultValue}) {
    final value = env[key] ?? defaultValue;
    if (value == null) {
      throw MySQLException('Did not find the $key environment variable');
    }
    return value;
  }

  Future<R> transaction<R>(Future<R> Function() action) async {
    inTransaction = true;
    try {
      late final R result;
      await _connection!.transactional((dynamic _) async {
        result = await action();
      });
      return result;
    } finally {
      inTransaction = false;
    }
  }

  Future<void> rollback() async {
    await withResults('ROLLBACK', action: (rs) => {});
  }

  String _expandValues(ValueList? values) {
    final sb = StringBuffer();
    if (values == null) {
      return '';
    }
    for (final value in values) {
      if (sb.isNotEmpty) {
        sb.write(', ');
      }
      final s = value.toString();
      final len = s.length;
      sb.write(s.substring(0, min(len, 20)));
      if (len > 20) {
        sb.write('[..$len]');
      }
    }
    return sb.toString();
  }

  @override
  Future<bool> test()  =>
      withResults('select 1 as testprob', action: (rs) {
        if (rs.rows.length != 1) {
          return false;
        }
        final row = rs.rows.first;
        if (row.numOfColumns != 1) {
          return false;
        }
        final values = row.colAt(0);
        if (values == null || values.length != 1) {
          return false;
        }
        return values[0] == '1';
      });

  String _colour(String query) {
    final first =
        query.trimLeft().split(RegExp(r'\s+')).firstOrNull?.toLowerCase();
    switch (first) {
      case 'select':
        return green(query);
      case 'insert':
        return magenta(query);
      case 'update':
        return orange(query);
      case 'delete':
        return red(query);
      default:
        return query;
    }
  }
}

/// NEW: public static façade that hides the instance `_query`.
Future<IResultSet> query(Db db, String query, [ValueList? values]) =>
    db._query(query, values);

abstract class Transactionable {
  int get id;
  bool get inTransaction;
  Future<bool> test();
  Future<void> close();
}
