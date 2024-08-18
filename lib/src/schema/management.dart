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
  await Transaction.current.db.query('''
ALTER TABLE `$databaseName`.`$table` 
DROP INDEX `$indexName` ;
''');
}

/// drops a foreign key from the [table]
Future<void> dropForeignKey({
  required String databaseName,
  required String foreignKeyName,
  required String table,
}) async {
  await Transaction.current.db.query('''
ALTER TABLE `$databaseName`.`$table` 
DROP FOREIGN KEY `$foreignKeyName` ;
''');
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
  /// restore the member constrant.
  await Transaction.current.db.query('''
ALTER TABLE `$databaseName`.`$table` 
ADD CONSTRAINT `$foreignKeyName`
  FOREIGN KEY (`$column`)
  REFERENCES `$databaseName`.`$foreignTable` (`$foreignColumn`)
  ON DELETE NO ACTION
  ON UPDATE NO ACTION;

''');
}

/// check if a database has a foreign key.
/// Foreign key names are global.
Future<bool> hasForeignKey(String foreignKeyName) async {
  final sql = '''
  SELECT * FROM sys.objects o 
  WHERE o.object_id = object_id(N'[dbo].[`$foreignKeyName`]') 
  AND OBJECTPROPERTY(o.object_id, N'IsForeignKey') = 1)''';

  final results = await Transaction.current.db.query(sql);
  return results.rows.isNotEmpty;
}

Future<void> dropDatabase(String databaseName) async {
  await Transaction.current.db.query('drop database if exists $databaseName');
}

Future<void> createDatabase(String databaseName) async {
  await Transaction.current.db
      .query('create database  if not exists  $databaseName');
}

/// Restores a database from a .sql file created by
/// mysqldump.
///
/// WARNING: calling this method will DROP your existing datbase.
///
/// if [thisWillDestroyMyDb] is not true then a [MySqlORMException]
/// will be thrown.
Future<void> restoreDatabase(
    {required String databaseName,
    required String pathToBackup,
    required bool thisWillDestroyMyDb}) async {
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
      if (statement.isNotEmpty) {
        await Transaction.current.db.query(statement);
      }
    }
  });
}

/// Returns try if the schema [databaseName] exists.
Future<bool> existsDatabase(String databaseName) async {
  final sql = '''
  SELECT SCHEMA_NAME
FROM INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME = '$databaseName'
''';

  final result = await Transaction.current.db.query(sql);
  return result.rows.isNotEmpty;
}

/// Allows you to update the database with foreign key constraints
/// disabled.
///
/// You need to call this method within an existing transaction.
Future<R> withNoConstraints<R>({required Future<R> Function() action}) async {
  await Transaction.current.db.query('SET FOREIGN_KEY_CHECKS=0');
  final R result;
  try {
    result = await action();
  } finally {
    await Transaction.current.db.query('SET FOREIGN_KEY_CHECKS=1');
  }

  return result;
}
