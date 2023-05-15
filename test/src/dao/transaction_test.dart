@Timeout(Duration(minutes: 3))
library;

/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'package:dcli/dcli.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' hide equals;
import 'package:scope/scope.dart';
import 'package:simple_mysql_orm/simple_mysql_orm.dart';
import 'package:test/test.dart';

import '../../test_dao/dao/dao_publisher.dart';
import '../../test_dao/model/publisher.dart';

final settingsPath = join('test', 'settings.yaml');
void main() {
  setUpAll(() {
    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen((record) {
      // ignore: avoid_print
      print('${record.level.name}: ${record.time}: ${record.message}');
    });
  });

  setUp(() {
    if (!exists(dirname(settingsPath))) {
      createDir(dirname(settingsPath), recursive: true);
    }
    DbPool.fromSettings(pathToSettings: settingsPath);
  });

  test('transaction ... obtain/release', () async {
    await withTransaction(action: () async {
      expect(() => DbPool().close(), throwsA(isA<MySQLException>()));
    });
    await DbPool().close();
  });
  test('transaction ...', () async {
    var ran = false;
    await withTransaction(action: () async {
      final db = Transaction.current.db;
      expect(db, isNotNull);
      final dao = PublisherDao();
      await dao.delete().where().eq('name', 'brett').run();
      final publisher = Publisher(name: 'brett', contactEmail: 'member@me.com');
      final identity = await dao.persist(publisher);
      final inserted = await dao.tryById(identity);

      expect(inserted, isNotNull);
      expect(inserted!.name, equals('brett'));
      expect(inserted.contactEmail, equals('member@me.com'));
      ran = true;
    });
    expect(ran, isTrue);
    await DbPool().close();
  });

  test('invalid nested transaction ...', () async {
    await expectLater(
        () async => withTransaction(action: () async {
              await withTransaction(
                  action: () async {}, nesting: TransactionNesting.notAllowed);
            }),
        throwsA(isA<NestedTransactionException>()));
    await DbPool().close();
  });

  test('multiple transactions - different db', () async {
    final used = <int>[];

    await TransactionTestScope().run(() async {
      final a = Future.delayed(
          const Duration(seconds: 1),
          () => withTransaction<void>(action: () {
                used.add(Transaction.current.db.id);
                return Future.delayed(const Duration(seconds: 10));
              }));
      final b = Future.delayed(
          const Duration(seconds: 1),
          () => withTransaction<void>(action: () {
                used.add(Transaction.current.db.id);
                return Future.delayed(const Duration(seconds: 10));
              }));

      final c = Future.delayed(
          const Duration(seconds: 1),
          () => withTransaction<void>(action: () {
                used.add(Transaction.current.db.id);
                return Future.delayed(const Duration(seconds: 10));
              }));

      await Future.wait([a, b, c]);
      expect(used, unorderedEquals(<int>[0, 1, 2]));
    });
  });
  test('transaction with result', () async {
    final count = await withTransaction<int>(action: () async => 1);
    expect(count, 1);

    final name = await withTransaction<String?>(action: () async => null);
    expect(name, isNull);
  });
  test('nested with no nesting transaction ...', () async {
    var ran = false;
    await withTransaction(
        action: () async {
          ran = true;
          expect(Scope.hasScopeKey(Transaction.transactionKey), isTrue);
        },
        nesting: TransactionNesting.nested);
    expect(ran, isTrue);
    await DbPool().close();
  });
  test('valid nested transaction ...', () async {
    var ran = false;
    Db db;
    await withTransaction(action: () async {
      db = Transaction.current.db;
      await withTransaction(
          action: () async {
            expect(db, equals(Transaction.current.db));
            ran = true;
          },
          nesting: TransactionNesting.nested);
    });
    expect(ran, isTrue);
    await DbPool().close();
  });

  test('detached nested transaction ...', () async {
    var ran = false;
    Db db;
    await withTransaction(action: () async {
      db = Transaction.current.db;
      await withTransaction(
          action: () async {
            ran = true;
            expect(db, isNot(equals(Transaction.current.db)));
          },
          nesting: TransactionNesting.detached);
    });
    expect(ran, isTrue);
    await DbPool().close();
  });

  test('!useTransaction ...', () async {
    var ran = false;
    Db db;
    await withTransaction(
        action: () async {
          db = Transaction.current.db;
          await withTransaction(
              action: () async {
                ran = true;
                expect(db, isNot(equals(Transaction.current.db)));
              },
              nesting: TransactionNesting.detached);
        },
        useTransaction: false);
    expect(ran, isTrue);
    await DbPool().close();
  });
}
