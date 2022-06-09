/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */


import 'package:dcli/dcli.dart';
import 'package:simple_mysql_orm/simple_mysql_orm.dart';
import 'package:test/test.dart';

import '../../test_dao/dao/dao_publisher.dart';

final settingsPath = join('test', 'settings.yaml');
void main() {
  setUp(() {
    if (!exists(dirname(settingsPath))) {
      createDir(dirname(settingsPath), recursive: true);
    }
    DbPool.fromSettings(pathToSettings: settingsPath);
  });

  test('builder ...', () async {
    await withTransaction<void>(action: () async {
      await PublisherDao().delete().where().eq('name', 'brett').run();
    });
  });
}
