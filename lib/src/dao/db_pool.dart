import 'dart:async';

import 'package:dcli_core/dcli_core.dart';
import 'package:galileo_mysql/galileo_mysql.dart';
import 'package:settings_yaml/settings_yaml.dart';

import '../exceptions.dart';
import 'db.dart';
import 'shared_pool.dart';

/// A pool of database connections.
class DbPool {
  factory DbPool() {
    if (_self == null) {
      throw StateError('You must initialise the pool first');
    }
    return _self!;
  }

  /// You can override the min no. of connections in the pool by passing in
  /// [overrideMin]. This is mainly for unit testing.
  /// You can override the max no. of connections in the pool by passing in
  /// [overrideMax]. This is mainly for unit testing.
  factory DbPool.fromSettings(
      {required String pathToSettings,
      int? overrideMax,
      int? overrideMin,
      Duration? overrideExcessDuration}) {
    if (!exists(pathToSettings)) {
      throw ConfigurationException('The settings file for mysql is missing: '
          '${truepath(pathToSettings)}');
    }

    final settings = SettingsYaml.load(pathToSettings: pathToSettings);
    final username = settings.asString(Db.mysqlUsernameKey.toLowerCase());
    final password = settings.asString(Db.mysqlPasswordKey.toLowerCase());
    final host = settings.asString(Db.mysqlHostKey.toLowerCase(),
        defaultValue: 'localhost');
    final port =
        settings.asInt(Db.mysqlPortKey.toLowerCase(), defaultValue: 3306);
    final database = settings.asString(Db.mysqlDatabaseKey.toLowerCase(),
        defaultValue: 'onepub');
    final minSize = settings.asInt(DbPool.mysqMinPoolSizKey, defaultValue: 5);
    final maxSize = settings.asInt(DbPool.mysqMaxPoolSizKey, defaultValue: 50);

    _self = DbPool._internal(
        host: host,
        port: port,
        user: username,
        password: password,
        database: database,
        minSize: overrideMin ?? minSize,
        maxSize: overrideMax ?? maxSize,
        excessDuration: overrideExcessDuration ?? const Duration(minutes: 1));
    return _self!;
  }

  factory DbPool.fromEnv() {
    final user = Db.getEnv(Db.mysqlUsernameKey);
    final password = Db.getEnv(Db.mysqlPasswordKey);
    final minSize = Db.getEnv(DbPool.mysqMinPoolSizKey, defaultValue: '5');
    final maxSize = Db.getEnv(DbPool.mysqMaxPoolSizKey, defaultValue: '50');

    _self = DbPool._internal(
      host: env[Db.mysqlHostKey] ?? 'localhost',
      port: int.tryParse(env[Db.mysqlPortKey] ?? '3306') ?? 3306,
      user: user,
      password: password,
      database: env[Db.mysqlDatabaseKey] ?? 'onepub',
      minSize: int.tryParse(minSize) ?? 5,
      maxSize: int.tryParse(maxSize) ?? 50,
    );
    return _self!;
  }

  DbPool._internal(
      {required String host,
      required int port,
      required String user,
      required String password,
      required String database,
      required int minSize,
      required int maxSize,
      Duration excessDuration = const Duration(minutes: 1)})
      : pool = SharedPool(
            MySqlConnectonManager(ConnectionSettings(
                host: host,
                port: port,
                user: user,
                password: password,
                db: database)),
            minSize: minSize,
            maxSize: maxSize,
            excessDuration: excessDuration);

  static DbPool? _self;

  final SharedPool<Db> pool;

  /// returns the no. of connections currently in the pool
  int get size => pool.size;

  /// obtains a wrapper containg a [Db] connection
  Future<ConnectionWrapper<Db>> obtain() async => pool.obtain();

  Future<void> release(ConnectionWrapper<Db> wrapper) async {
    await pool.release(wrapper);
  }

  static String mysqMaxPoolSizKey = 'mysql_min_pool_size';
  static String mysqMinPoolSizKey = 'mysql_max_pool_size';

  /// Runs action passing in a [Db] from the pool
  Future<T> withDb<T>(Future<T> Function(Db db) action) async {
    final wrapper = await obtain();
    try {
      return action(wrapper.wrapped);
    } finally {
      await release(wrapper);
    }
  }
}

class MySqlConnectonManager implements ConnectionManager<Db> {
  MySqlConnectonManager(this.settings);

  ConnectionSettings settings;

  @override
  FutureOr<Db> open() async {
    final db = Db.fromSettings(settings);
    await db.connect();
    return db;
  }

  @override
  FutureOr<void> close(Db db) async {
    await db.connection.close();
  }
}
