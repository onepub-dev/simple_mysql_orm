import 'package:dcli/dcli.dart';
import 'package:logging/logging.dart';
import 'package:simple_mysql_orm/simple_mysql_orm.dart';
import 'package:simple_mysql_orm/src/dao/shared_pool.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() {
    // Logger.root.clearListeners();
    Logger.root.level = Level.INFO; // defaults to Level.INFO
    Logger.root.onRecord.listen((record) {
      print('${record.level.name}: ${record.time}: ${record.message}');
    });
  });
  test('db pool wait', () async {
    final pool = DbPool.fromSettings(
        pathToSettings: join('test', 'settings.yaml'),
        overrideMax: 2,
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
      print(db.wrapped.id);
    }
    expect(released, isTrue);
  });

  test('db pool no wait', () async {
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
      print(db.wrapped.id);
    }

    /// we should get here before release is called.
    expect(released, isFalse);
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
  });
}
