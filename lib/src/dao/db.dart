import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dcli/dcli.dart';

import 'package:galileo_mysql/galileo_mysql.dart' as g;
import 'package:galileo_mysql/galileo_mysql.dart';
import 'package:logging/logging.dart';
import 'package:scope/scope.dart';

import '../../simple_mysql_orm.dart';

class Db implements Transactionable {
  // factory Db() {
  //   if (_self == null) {
  //     throw StateError('You must initialise MySQLConnection first');
  //   }
  //   return _self!;
  // }
  factory Db.fromEnv() {
    final user = getEnv(mysqlUsernameKey);
    final password = getEnv(mysqlPasswordKey);

    return Db._internal(
        host: env[mysqlHostKey] ?? 'localhost',
        port: int.tryParse(env[mysqlPortKey] ?? '3306') ?? 3306,
        user: user,
        password: password,
        database: env[mysqlDatabaseKey] ?? 'onepub');
  }

  /// Connects the mysql server without setting the default schema.
  /// You can use this for actions like restoring a database.
  ///
  factory Db.fromSettingsNoDatabase(g.ConnectionSettings settings) =>
      Db._internal(
          database: null,
          host: settings.host,
          port: settings.port,
          user: settings.user!,
          password: settings.password!);

  factory Db.fromSettings(g.ConnectionSettings settings) => Db._internal(
      database: settings.db,
      host: settings.host,
      port: settings.port,
      user: settings.user!,
      password: settings.password!);

  Db._internal({
    required String host,
    required int port,
    required String user,
    required String password,
    required String? database,
  }) {
    id = _nextId;
    settings = g.ConnectionSettings(
        host: host, port: port, user: user, password: password, db: database);
  }
  final logger = Logger('Db');

  static int __nextId = 0;

  /// generates a unique id for each transaction for debugging purposes.
  /// If we are running in a [TransactionTestScope] then we use
  /// a sequence specific to that scope rather than a global sequence.
  static int get _nextId =>
      use(TransactionTestScope.dbTestIdKey, withDefault: () => __nextId++);

  /// Unique id used in logging to identify which [Db] conection
  /// was used to execute a query.
  @override
  late final int id;

  static String mysqlPortKey = 'MYSQL_PORT';
  static String mysqlHostKey = 'MYSQL_HOST';

  static String mysqlDatabaseKey = 'MYSQL_DATABASE';
  static const String mysqlUsernameKey = 'MYSQL_USER';
  static const String mysqlPasswordKey = 'MYSQL_PASSWORD';

  late final g.ConnectionSettings settings;

  g.MySqlConnection? _connection;

  g.MySqlConnection get connection {
    if (_connection == null) {
      throw StateError('You must call connect() first.');
    }
    return _connection!;
  }

  Future<void> connect() async {
    _connection = await g.MySqlConnection.connect(settings);
  }

  @override
  Future<void> close() async => _connection?.close();

  static int queryCount = 0;

  /// Query the db.
  /// The [query] to be run with the passed [values]
  ///
  /// ```dart
  /// var userId = 1;
  ///  var results = await conn.query('select name, email from users
  ///   where id = ?', [userId]);
  /// ```
  Future<g.Results> query(String query, [ValueList? values]) async {
    logger.info(() => 'Db: $id qid: $queryCount ${_colour(query)}, '
        'values:[${_expandValues(values)}]');

    try {
      final results = await connection.query(query, values);
      logger.info(() => 'Db: $id qid: $queryCount '
          'Rows encountered: ${results.affectedRows ?? results.length}');
      queryCount++;
      return results;
    } on MySqlException catch (e) {
      /// We don't want to use the stack trace from the exception
      /// as it is a useless async callback that does the results
      /// processing and gives the user no context.
      final stack = StackTrace.current;
      logger.severe('''
Db: $id qid: $queryCount ${_colour(query)}, values:[${_expandValues(values)}]');
Error: ${e.message}''', e.errorNumber);
      Error.throwWithStackTrace(e, stack);
    }
  }

  static String getEnv(String key, {String? defaultValue}) {
    final value = env[key] ?? defaultValue;
    if (value == null) {
      throw MySQLException('Did not find the $key environment variable');
    }
    return value;
  }

  @override
  bool inTransaction = false;

  Future<R> transaction<R>(Future<R> Function() action) async {
    inTransaction = true;
    try {
      late final R result;
      // ignore: avoid_annotating_with_dynamic
      await _connection!.transaction((dynamic context) async {
        result = await action();
      });

      return result;
    } finally {
      inTransaction = false;
    }
  }

  Future<void> rollback() async {
    await query('rollback');
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
      final sValue = value.toString();
      final length = sValue.length;
      sb.write(sValue.substring(0, min(length, 20)));
      if (length > 20) {
        sb.write('[..$length]');
      }
    }
    return sb.toString();
  }

  @override
  Future<bool> test() async {
    final results = await query('select 1 as testprob');
    if (results.length != 1) {
      return false;
    }

    final values = results.single.values;
    if (values == null || values.length != 1) {
      return false;
    }
    return values[0] == 1;
  }

  String _colour(String query) {
    final firstWord = query.split(' ').firstOrNull;
    if (firstWord != null) {
      switch (firstWord) {
        case 'select':
          return green(query);
        case 'insert':
          return magenta(query);
        case 'update':
          return orange(query);

        case 'delete':
          return red(query);
      }
    }
    return query;
  }
}

class MySQLException implements Exception {
  MySQLException(this.message);
  String message;
  @override
  String toString() => message;
}

abstract class Transactionable {
  int get id;
  bool get inTransaction;

  /// Test if the instance is still valid.
  /// This should test the connection is still up.
  Future<bool> test();

  Future<void> close();
}
