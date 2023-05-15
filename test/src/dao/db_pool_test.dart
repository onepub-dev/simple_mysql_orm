/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */


import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:simple_mysql_orm/simple_mysql_orm.dart';
import 'package:simple_mysql_orm/src/dao/shared_pool.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() {
    // Logger.root.clearListeners();
    Logger.root.level = Level.INFO; // defaults to Level.INFO
    Logger.root.onRecord.listen((record) {
      // ignore: avoid_print
      print('${record.level.name}: ${record.time}: ${record.message}');
    });
  });

  test('db pool - obtain/release', () async {
    final pool = DbPool.fromSettings(
        pathToSettings: join('test', 'settings.yaml'),
        overrideMax: 3,
        overrideMin: 1,
        overrideExcessDuration: const Duration(seconds: 2000));

    final db = await pool.obtain();
    return pool.release(db);
  });

  test('db pool wait', () async {
    final pool = DbPool.fromSettings(
        pathToSettings: join('test', 'settings.yaml'),
        overrideMax: 2,
        overrideMin: 1);

    final obtained = <ConnectionWrapper<Db>>[];
    var index = 0;
    var released = false;
    Future.delayed(const Duration(seconds: 10), () {
      released = true;
      return pool.release(obtained[index++]);
    });

    for (var i = 0; i < 3; i++) {
      final db = await pool.obtain();
      obtained.add(db);
      // ignore: avoid_print
      print(db.wrapped.id);
    }
    expect(released, isTrue);

    /// cleanup by releasing all connections.
    for (var i = index; i < obtained.length; i++) {
      await pool.release(obtained[index++]);
    }
    await pool.close();
  });

  test('db pool no wait', () async {
    final pool = DbPool.fromSettings(
        pathToSettings: join('test', 'settings.yaml'),
        overrideMax: 3,
        overrideMin: 1);

    final obtained = <ConnectionWrapper<Db>>[];
    var index = 0;
    var released = false;
    Future.delayed(const Duration(seconds: 10), () {
      released = true;
      return pool.release(obtained[index++]);
    });

    for (var i = 0; i < 3; i++) {
      final db = await pool.obtain();
      obtained.add(db);
      // ignore: avoid_print
      print(db.wrapped.id);
    }

    /// we should get here before release is called.
    expect(released, isFalse);

    for (var i = index; i < obtained.length; i++) {
      await pool.release(obtained[index++]);
    }
    await pool.close();
  });

  test('db pool obtain/release', () async {
    final pool = DbPool.fromSettings(
        pathToSettings: join('test', 'settings.yaml'),
        overrideMax: 3,
        overrideMin: 1);

    final obtained = <ConnectionWrapper<Db>>[];
    var released = false;
    Future.delayed(const Duration(seconds: 10), () {
      released = true;
      return pool.release(obtained[0]);
    });

    for (var i = 0; i < 3; i++) {
      final db = await pool.obtain();
      obtained.add(db);
    }

    obtained.forEach(pool.release);

    /// we should get here before release is called.
    expect(released, isFalse);

    await pool.close();
  });

  test('db pool releaseExcess', () async {
    final pool = DbPool.fromSettings(
        pathToSettings: join('test', 'settings.yaml'),
        overrideMax: 3,
        overrideMin: 1,
        overrideExcessDuration: const Duration(seconds: 2));

    final obtained = <ConnectionWrapper<Db>>[];
    var released = false;
    Future.delayed(const Duration(seconds: 10), () {
      released = true;
      return pool.release(obtained[0]);
    });

    for (var i = 0; i < 3; i++) {
      final db = await pool.obtain();
      obtained.add(db);
    }

    obtained.forEach(pool.release);
    expect(pool.size, 3);

    /// wait for the excess release mechanism to kick in.
    await Future.delayed(const Duration(seconds: 6), () => null);

    expect(pool.size, 1);

    /// we should get here before release is called.
    expect(released, isFalse);

    await pool.close();
  });

  // TODO(bsutton): add logic to this test to start/stop the mysql.
  // whilst this tests runs.
  test('db pool reconnect', () async {
    final pool = DbPool.fromSettings(
        pathToSettings: join('test', 'settings.yaml'),
        overrideMax: 3,
        overrideMin: 1,
        overrideExcessDuration: const Duration(seconds: 2));

    for (var i = 0; i < 100; i++) {
      // logger.finer(() => 'obtaining connection')
      final db = await pool.obtain();
      await pool.release(db);
      await Future.delayed(const Duration(seconds: 10), () => null);
    }

    await pool.close();
  }, skip: true);
}
