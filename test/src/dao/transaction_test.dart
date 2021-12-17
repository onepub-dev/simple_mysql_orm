import 'package:dcli/dcli.dart' hide equals;
import 'package:simple_mysql_orm/simple_mysql_orm.dart';
import 'package:test/test.dart';

import '../../test_dao/dao/publisher_dao.dart';
import '../../test_dao/model/publisher.dart';

void main() {
  setUp(() {
    DbPool.fromSettings(pathToSettings: join('test', 'settings.yaml'));
  });
  test('transaction ...', () async {
    var ran = false;
    await await withTransaction(() async {
      final db = transaction.db;
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
}
