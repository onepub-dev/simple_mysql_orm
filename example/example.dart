/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */


import 'package:logging/logging.dart';
import 'package:settings_yaml/settings_yaml.dart';
import 'package:simple_mysql_orm/simple_mysql_orm.dart';

import 'dao/package_dao.dart';
import 'model/package.dart';

Future<void> main() async {
  /// Configure the logger to output each sql command.
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  /// Create  settings file.
  SettingsYaml.fromString(content: settingsYaml, filePath: 'settings.yaml')
      .save();

  /// Initialise the db pool
  DbPool.fromSettings(pathToSettings: 'settings.yaml');

  /// create a transaction and run a set of queries
  /// within the transaction.
  await withTransaction<void>(action: () async {
    final dao = PackageDao();

    /// create a package and save it.
    final package = Package(name: 'dcli', private: false);
    await dao.persist(package);

    /// update the package to public
    package.private = false;
    await dao.update(package);

    /// query the package using VERY basic and incomplete builder
    var rows = await dao.select().where().eq('name', 'dcli').run();
    for (final row in rows) {
      print('name: ${row.name} private: ${row.private}');
    }

    /// Run a custom query
    rows = await dao.query('select * from package where id = ?', [package.id]);
    for (final row in rows) {
      print('name: ${row.name} private: ${row.private}');
    }

    // delete the package
    await dao.remove(package);

    /// changed my mind
    Transaction.current.rollback();
  });
}

const settingsYaml = '''
mysql_user: root
mysql_password: my root password
mysql_host: localhost
mysql_port: 3306
mysql_db: some_db_name
''';
