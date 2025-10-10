/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'package:dcli/dcli.dart';

import '../../simple_mysql_orm.dart';

/// Drops an index from [databaseName].
Future<void> dropIndex({
  required String databaseName,
  required String indexName,
  required String table,
}) async {
  await Transaction.current.db.withResults(
    '''
ALTER TABLE `$databaseName`.`$table` 
DROP INDEX `$indexName` ;
''',
    action: (_) {},
  );
}

/// drops a foreign key from the [table]
Future<void> dropForeignKey({
  required String databaseName,
  required String foreignKeyName,
  required String table,
}) async {
  await Transaction.current.db.withResults(
    '''
ALTER TABLE `$databaseName`.`$table` 
DROP FOREIGN KEY `$foreignKeyName` ;
''',
    action: (_) {},
  );
}

/// Add a foreign key to a table.
Future<void> addForeignKey({
  required String databaseName,
  required String foreignKeyName,
  required String table,
  required String column,
  required String foreignTable,
  required String foreignColumn,
}) async {
  await Transaction.current.db.withResults(
    '''
ALTER TABLE `$databaseName`.`$table` 
ADD CONSTRAINT `$foreignKeyName`
  FOREIGN KEY (`$column`)
  REFERENCES `$databaseName`.`$foreignTable` (`$foreignColumn`)
  ON DELETE NO ACTION
  ON UPDATE NO ACTION;
''',
    action: (_) {},
  );
}

/// check if a database has a foreign key.
Future<bool> hasForeignKey(String foreignKeyName) {
  final sql = '''
  SELECT CONSTRAINT_NAME
  FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
  WHERE CONSTRAINT_TYPE = 'FOREIGN KEY'
    AND CONSTRAINT_NAME = '$foreignKeyName'
''';

  return Transaction.current.db
      .withResults(sql, action: (rs) => rs.rows.isNotEmpty);
}

Future<void> dropDatabase(String databaseName) async {
  await Transaction.current.db.withResults(
    'DROP DATABASE IF EXISTS `$databaseName`',
    action: (_) {},
  );
}

Future<void> createDatabase(String databaseName) async {
  await Transaction.current.db.withResults(
    'CREATE DATABASE IF NOT EXISTS `$databaseName`',
    action: (_) {},
  );
}

/// Restores a database from a .sql file created by mysqldump.
///
/// WARNING: calling this method will DROP your existing database.
Future<void> restoreDatabase({
  required String databaseName,
  required String pathToBackup,
  required bool thisWillDestroyMyDb,
}) async {
  if (!thisWillDestroyMyDb) {
    throw MySqlORMException(
        'You must call this function with thisWillDestroyMyDb = true');
  }

  await dropDatabase(databaseName);

  final schemaScript = (read(pathToBackup).toList()
        ..removeWhere((line) => line.startsWith('--'))
        ..removeWhere((line) => line.startsWith('/*'))
        ..removeWhere((line) => line.isEmpty))
      .join('\n');

  final statements = schemaScript.split(';');

  await withNoConstraints(action: () async {
    for (final statement in statements) {
      final sql = statement.trim();
      if (sql.isNotEmpty) {
        await Transaction.current.db.withResults(sql, action: (_) {});
      }
    }
  });
}

/// Returns true if the schema [databaseName] exists.
Future<bool> existsDatabase(String databaseName) {
  final sql = '''
SELECT SCHEMA_NAME
FROM INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME = '$databaseName'
''';

  return Transaction.current.db
      .withResults(sql, action: (rs) => rs.rows.isNotEmpty);
}

/// Allows you to update the database with foreign key constraints disabled.
/// You need to call this method within an existing transaction.
Future<R> withNoConstraints<R>({required Future<R> Function() action}) async {
  await Transaction.current.db
      .withResults('SET FOREIGN_KEY_CHECKS=0', action: (_) {});
  final R result;
  try {
    result = await action();
  } finally {
    await Transaction.current.db
        .withResults('SET FOREIGN_KEY_CHECKS=1', action: (_) {});
  }
  return result;
}
