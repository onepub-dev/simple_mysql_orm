/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */


import 'dart:async';

import 'package:dcli/dcli.dart';
import 'package:settings_yaml/settings_yaml.dart';

import '../exceptions.dart';
import '../util/connection_settings.dart';
import 'db.dart';
import 'shared_pool.dart';
import 'transaction.dart';

/// A pool of database connections.
class DbPool {
  factory DbPool() {
    if (_self == null) {
      throw StateError('You must initialise the pool first');
    }
    return _self!;
  }

  /// Create a DbPool from settings at [pathToSettings]
  /// ignoring the database name so no default schema is selected.
  ///
  /// Use this for operations that create and drop  schemas.
  ///
  /// Note: you can't use [DbPool()] to fetch this pool.
  ///
  /// The intended use case is to use this as a short lived
  /// alternate pool that you pass to [withTransaction].
  ///
  /// ```dart
  /// final pool = DbPool.fromSettingsNoDatabase(....);
  /// withTransation(action: () async {
  ///     restoreDatabase(pathToBackup: '/mybackup.sql');
  /// }
  /// , dbPool: pool
  /// );
  ///
  /// You can override the min no. of connections in the pool by passing in
  /// [overrideMin]. This is mainly for unit testing.
  /// You can override the max no. of connections in the pool by passing in
  /// [overrideMax]. This is mainly for unit testing.
  factory DbPool.fromSettingsNoDatabase(
          {required String pathToSettings,
          int? overrideMax,
          int? overrideMin,
          Duration? overrideExcessDuration}) =>
      DbPool._fromSettingsWithOverrides(
        pathToSettings: pathToSettings,
        overrideMax: overrideMax,
        overrideMin: overrideMin,
        overrideExcessDuration: overrideExcessDuration,
        useDatabase: false,
      );

  /// You can override the min no. of connections in the pool by passing in
  /// [overrideMin]. This is mainly for unit testing.
  /// You can override the max no. of connections in the pool by passing in
  /// [overrideMax]. This is mainly for unit testing.
  factory DbPool.fromSettings(
          {required String pathToSettings,
          int? overrideMax,
          int? overrideMin,
          Duration? overrideExcessDuration}) =>
      _self = DbPool._fromSettingsWithOverrides(
        pathToSettings: pathToSettings,
        overrideMax: overrideMax,
        overrideMin: overrideMin,
        overrideExcessDuration: overrideExcessDuration,
      );

  factory DbPool._fromSettingsWithOverrides(
      {required String pathToSettings,
      int? overrideMax,
      int? overrideMin,
      Duration? overrideExcessDuration,
      bool useDatabase = true}) {
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
    final database = settings.asString(Db.mysqlDatabaseKey.toLowerCase());
    final minSize = settings.asInt(DbPool.mysqMinPoolSizeKey, defaultValue: 5);
    final maxSize = settings.asInt(DbPool.mysqMaxPoolSizeKey, defaultValue: 50);

    final useSSL = settings.asBool(DbPool.useSSLKey);

    return DbPool._internal(
        host: host,
        port: port,
        user: username,
        password: password,
        database: useDatabase ? database : null,
        minSize: overrideMin ?? minSize,
        maxSize: overrideMax ?? maxSize,
        excessDuration: overrideExcessDuration ?? const Duration(minutes: 1),
        useSSL: useSSL);
  }

  factory DbPool.fromArgs({
    required String host,
    required String database,
    required String user,
    required String password,
    int port = 3306,
    int minSize = 5,
    int maxSize = 50,
    bool useSSL = true,
  }) =>
      _self = DbPool._internal(
          host: host,
          port: port,
          user: user,
          password: password,
          database: database,
          minSize: minSize,
          maxSize: maxSize,
          useSSL: useSSL);

  factory DbPool.fromEnv() {
    final user = Db.getEnv(Db.mysqlUsernameKey);
    final password = Db.getEnv(Db.mysqlPasswordKey);
    final minSize = Db.getEnv(DbPool.mysqMinPoolSizeKey, defaultValue: '5');
    final maxSize = Db.getEnv(DbPool.mysqMaxPoolSizeKey, defaultValue: '50');
    final useSSL = Db.getEnv(DbPool.useSSLKey, defaultValue: 'true');

    _self = DbPool._internal(
        host: env[Db.mysqlHostKey] ?? 'localhost',
        port: int.tryParse(env[Db.mysqlPortKey] ?? '3306') ?? 3306,
        user: user,
        password: password,
        database: env[Db.mysqlDatabaseKey] ?? 'onepub',
        minSize: int.tryParse(minSize) ?? 5,
        maxSize: int.tryParse(maxSize) ?? 50,
        useSSL: useSSL.trim().toLowerCase() == 'true');
    return _self!;
  }

  DbPool._internal({
    required String host,
    required int port,
    required String user,
    required String password,
    required int minSize,
    required int maxSize,
    required bool useSSL,
    String? database,
    Duration excessDuration = const Duration(minutes: 1),
  })  : _database = database,
        pool = SharedPool(
          MySqlConnectonManager(ConnectionSettings(
              host: host,
              port: port,
              user: user,
              password: password,
              db: database,
              useSSL: useSSL)),
          minSize: minSize,
          maxSize: maxSize,
          excessDuration: excessDuration,
        );

  static DbPool? _self;

  String? _database;

  /// Returns the database name this pool is attached to.
  String? get database => _database;

  /// The DbPool is open.
  bool open = true;
  final SharedPool<Db> pool;

  /// returns the no. of connections currently in the pool
  int get size => pool.size;

  /// obtains a wrapper containg a [Db] connection
  Future<ConnectionWrapper<Db>> obtain() async {
    if (open == false) {
      throw MySqlORMException('The DbPool has already been closed');
    }
    return pool.obtain();
  }

  /// relase the given connection [wrapper] back into the pool.
  Future<void> release(ConnectionWrapper<Db> wrapper) async {
    if (open == false) {
      throw MySqlORMException('The DbPool has already been closed');
    }
    await pool.release(wrapper);
  }

  static String mysqMaxPoolSizeKey = 'mysql_max_pool_size';
  static String mysqMinPoolSizeKey = 'mysql_min_pool_size';

  static String useSSLKey = 'mysql_use_ssl';

  /// Runs action passing in a [Db] from the pool
  Future<T> withDb<T>({required Future<T> Function(Db db) action}) async {
    final wrapper = await obtain();
    try {
      return action(wrapper.wrapped);
    } finally {
      await release(wrapper);
    }
  }

  Future<void> close() async {
    await pool.close();
    open = false;
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
