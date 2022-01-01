import 'package:dcli/dcli.dart';
import 'package:simple_mysql_orm/simple_mysql_orm.dart';
import 'package:test/test.dart';

import '../../test_dao/dao/uploader_dao.dart';

final settingsPath = join('test', 'settings.yaml');
void main() {
  setUp(() {
    if (!exists(dirname(settingsPath))) {
      createDir(dirname(settingsPath), recursive: true);
    }
    DbPool.fromSettings(pathToSettings: settingsPath);
  });

  test('builder ...', () async {
    await withTransaction<void>(() async {
      await PublisherDao().delete().where().eq('name', 'brett').run();
    });
  });
}
