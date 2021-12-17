import 'dart:async';

import 'package:dcli_core/dcli_core.dart';
import 'package:galileo_mysql/galileo_mysql.dart';

import '../model/entity.dart';

class Db {
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

  factory Db.fromSettings(ConnectionSettings settings) => Db._internal(
      database: settings.db!,
      host: settings.host,
      port: settings.port,
      user: settings.user!,
      password: settings.password!);

  Db._internal(
      {required String host,
      required int port,
      required String user,
      required String password,
      required String database}) {
    settings = ConnectionSettings(
        host: host, port: port, user: user, password: password, db: database);
  }

  static String mysqlPortKey = 'MYSQL_PORT';
  static String mysqlHostKey = 'MYSQL_HOST';

  static String mysqlDatabaseKey = 'MYSQL_DATABASE';
  static const String mysqlUsernameKey = 'MYSQL_USER';
  static const String mysqlPasswordKey = 'MYSQL_PASSWORD';

  late final ConnectionSettings settings;

  MySqlConnection? _connection;

  MySqlConnection get connection {
    if (_connection == null) {
      throw StateError('You must call connect() first.');
    }
    return _connection!;
  }

  Future<void> connect() async {
    _connection = await MySqlConnection.connect(settings);
  }

  /// Query the db.
  /// The [query] to be run with the passed [values]
  ///
  /// ```dart
  /// var userId = 1;
  ///  var results = await conn.query('select name, email from users
  ///   where id = ?', [userId]);
  /// ```
  Future<Results> query(String query, [ValueList? values]) async =>
      connection.query(query, values);

  static String getEnv(String key, {String? defaultValue}) {
    final value = env[key] ?? defaultValue;
    if (value == null) {
      throw MySQLException('Did not find the $key environment variable');
    }
    return value;
  }

  Future<R> transaction<R>(Future<R> Function() action) async =>
      // ignore: avoid_annotating_with_dynamic
      await _connection!.transaction((dynamic context) => action()) as R;
}

class MySQLException implements Exception {
  MySQLException(this.message);
  String message;
  @override
  String toString() => message;
}
