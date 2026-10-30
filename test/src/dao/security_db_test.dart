import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:simple_mysql_orm/simple_mysql_orm.dart';
import 'package:test/test.dart';

import '../../test_dao/dao/dao_publisher.dart';
import '../../test_dao/model/publisher.dart';

final String _settingsPath = p.join('test', 'settings.yaml');

void main() {
  test('an explicit pool is used without a singleton', () async {
    final pool = DbPool.fromSettingsNoDatabase(
        pathToSettings: _settingsPath, overrideMin: 0, overrideMax: 2);
    try {
      await withTransaction(
          dbPool: pool,
          action: () async {
            expect(Transaction.current.db.settings.db, isNull);
            await withTransaction(
                nesting: TransactionNesting.detached,
                action: () async {
                  expect(Transaction.current.db.settings.db, isNull);
                });
          });
    } finally {
      await pool.close();
    }
  });

  test('schema lookup values are bound and scoped to a database', () async {
    final pool = DbPool.fromSettings(
        pathToSettings: _settingsPath, overrideMin: 0, overrideMax: 1);
    try {
      await withTransaction(
          dbPool: pool,
          action: () async {
            expect(await existsDatabase('smo'), isTrue);
            expect(await existsDatabase("smo' OR 1=1 --"), isFalse);
            expect(await hasForeignKey('fk_member_publisher'), isTrue);
            expect(
                await hasForeignKey('fk_member_publisher',
                    databaseName: 'information_schema'),
                isFalse);
          });
    } finally {
      await pool.close();
    }
  });

  test('a nested transaction rejects a different explicit pool', () async {
    final first = DbPool.fromSettingsNoDatabase(
        pathToSettings: _settingsPath, overrideMin: 0, overrideMax: 1);
    final second = DbPool.fromSettingsNoDatabase(
        pathToSettings: _settingsPath, overrideMin: 0, overrideMax: 1);
    try {
      await withTransaction(
          dbPool: first,
          action: () async {
            await expectLater(
                withTransaction(dbPool: second, action: () async {}),
                throwsStateError);
          });
    } finally {
      await first.close();
      await second.close();
    }
  });

  test('a detached transaction may select a different explicit pool', () async {
    final first = DbPool.fromSettingsNoDatabase(
        pathToSettings: _settingsPath, overrideMin: 0, overrideMax: 1);
    final second = DbPool.fromSettings(
        pathToSettings: _settingsPath, overrideMin: 0, overrideMax: 1);
    try {
      await withTransaction(
          dbPool: first,
          action: () async {
            expect(Transaction.current.db.settings.db, isNull);
            await withTransaction(
                dbPool: second,
                nesting: TransactionNesting.detached,
                action: () async {
                  expect(Transaction.current.db.settings.db, 'smo');
                });
          });
    } finally {
      await first.close();
      await second.close();
    }
  });

  test('rollback request prevents persisted writes', () async {
    final pool = DbPool.fromSettings(
        pathToSettings: _settingsPath, overrideMin: 0, overrideMax: 1);
    int? id;
    try {
      await expectLater(
          withTransaction<void>(
              dbPool: pool,
              action: () async {
                id = await PublisherDao().persist(Publisher(
                    name: 'security-rollback-test',
                    contactEmail: 'rollback@example.invalid'));
                await Transaction.current.rollback();
                await expectLater(
                    Transaction.current.db.transaction<void>(() async {}),
                    throwsA(isA<InvalidTransactionStateException>()));
              }),
          throwsA(isA<TransactionRolledBackException>()));
      await withTransaction(
          dbPool: pool,
          action: () async {
            expect(await PublisherDao().tryById(id!), isNull);
          });
    } finally {
      await pool.close();
    }
  });

  test('nested rollback aborts the outer transaction', () async {
    final pool = DbPool.fromSettingsNoDatabase(
        pathToSettings: _settingsPath, overrideMin: 0, overrideMax: 1);
    try {
      await expectLater(
          withTransaction(
              dbPool: pool,
              action: () async {
                await withTransaction(action: () async {
                  await Transaction.current.rollback();
                });
              }),
          throwsA(isA<TransactionRolledBackException>()));
    } finally {
      await pool.close();
    }
  });

  test('withDb retains checkout until asynchronous work ends', () async {
    final pool = DbPool.fromSettings(
        pathToSettings: _settingsPath, overrideMin: 0, overrideMax: 1);
    final entered = Completer<void>();
    final gate = Completer<void>();
    var secondEntered = false;
    try {
      final first = pool.withDb(action: (db) async {
        entered.complete();
        await gate.future;
        expect(await db.test(), isTrue);
      });
      await entered.future;
      final second = pool.withDb(action: (db) async {
        secondEntered = true;
        expect(await db.test(), isTrue);
      });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(secondEntered, isFalse);
      gate.complete();
      await first;
      await second;
      expect(secondEntered, isTrue);
    } finally {
      if (!gate.isCompleted) {
        gate.complete();
      }
      await pool.close();
    }
  });
}
