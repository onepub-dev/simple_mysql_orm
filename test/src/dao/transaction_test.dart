import 'package:dcli/dcli.dart' hide equals;
import 'package:di_zone2/di_zone2.dart';
import 'package:simple_mysql_orm/simple_mysql_orm.dart';
import 'package:test/test.dart';

import '../../test_dao/dao/uploader_dao.dart';
import '../../test_dao/model/publisher.dart';

final settingsPath = join('test', 'settings.yaml');
void main() {
  setUp(() {
    if (!exists(dirname(settingsPath))) {
      createDir(dirname(settingsPath), recursive: true);
    }
    DbPool.fromSettings(pathToSettings: settingsPath);
  });

  test('transaction ...', () async {
    var ran = false;
    await withTransaction(() async {
      final db = Transaction.current.db;
      expect(db, isNotNull);
      final dao = PublisherDao();
      await dao.delete().where().eq('name', 'brett').run();
      final publisher = Publisher(name: 'brett', email: 'me@my.com');
      final identity = await dao.persist(publisher);
      final inserted = await dao.getById(identity);

      expect(inserted, isNotNull);
      expect(inserted!.name, equals('brett'));
      expect(inserted.email, equals('me@my.com'));
      ran = true;
    });
    expect(ran, isTrue);
  });

  test('invalid nested transaction ...', () async {
    expect(
        () async => withTransaction(() async {
              await withTransaction(() async {});
            }),
        throwsA(isA<NestedTransactionException>()));
  });

  test('nested with no nesting transaction ...', () async {
    var ran = false;
    await withTransaction(() async {
      ran = true;
      expect(Scope.hasScopeKey(Transaction.transactionKey), isTrue);
    }, nesting: TransactionNesting.nested);
    expect(ran, isTrue);
  });
  test('valid nested transaction ...', () async {
    var ran = false;
    Db db;
    await withTransaction(() async {
      db = Transaction.current.db;
      await withTransaction(() async {
        expect(db, equals(Transaction.current.db));
        ran = true;
      }, nesting: TransactionNesting.nested);
    });
    expect(ran, isTrue);
  });

  test('detached nested transaction ...', () async {
    var ran = false;
    Db db;
    await withTransaction(() async {
      db = Transaction.current.db;
      await withTransaction(() async {
        ran = true;
        expect(db, isNot(equals(Transaction.current.db)));
      }, nesting: TransactionNesting.detached);
    });
    expect(ran, isTrue);
  });

  test('!useTransaction ...', () async {
    var ran = false;
    Db db;
    await withTransaction(() async {
      db = Transaction.current.db;
      await withTransaction(() async {
        ran = true;
        expect(db, isNot(equals(Transaction.current.db)));
      }, nesting: TransactionNesting.detached);
    }, useTransaction: false);
    expect(ran, isTrue);
  });
}
