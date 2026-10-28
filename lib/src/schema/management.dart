/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'package:dcli/dcli.dart';

import '../../simple_mysql_orm.dart';
import '../util/sql_identifier.dart';

/// Drops an index from [databaseName].
Future<void> dropIndex({
  required String databaseName,
  required String indexName,
  required String table,
}) async {
  await Transaction.current.db.withResults(
    '''
ALTER TABLE ${sqlIdentifier(databaseName)}.${sqlIdentifier(table)}
DROP INDEX ${sqlIdentifier(indexName)} ;
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
ALTER TABLE ${sqlIdentifier(databaseName)}.${sqlIdentifier(table)}
DROP FOREIGN KEY ${sqlIdentifier(foreignKeyName)} ;
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
ALTER TABLE ${sqlIdentifier(databaseName)}.${sqlIdentifier(table)}
ADD CONSTRAINT ${sqlIdentifier(foreignKeyName)}
  FOREIGN KEY (${sqlIdentifier(column)})
  REFERENCES ${sqlIdentifier(databaseName)}.${sqlIdentifier(foreignTable)} (${sqlIdentifier(foreignColumn)})
  ON DELETE NO ACTION
  ON UPDATE NO ACTION;
''',
    action: (_) {},
  );
}

/// check if a database has a foreign key.
Future<bool> hasForeignKey(String foreignKeyName, {String? databaseName}) {
  final schema = databaseName ?? Transaction.current.db.settings.db;
  if (schema == null || schema.isEmpty) {
    throw ArgumentError('A database name is required to check a foreign key.');
  }
  const sql = '''
  SELECT CONSTRAINT_NAME
  FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
  WHERE CONSTRAINT_TYPE = 'FOREIGN KEY'
    AND CONSTRAINT_SCHEMA = ?
    AND CONSTRAINT_NAME = ?
''';

  return Transaction.current.db.withResults(sql,
      values: [schema, foreignKeyName], action: (rs) => rs.rows.isNotEmpty);
}

Future<void> dropDatabase(String databaseName) async {
  await Transaction.current.db.withResults(
    'DROP DATABASE IF EXISTS ${sqlIdentifier(databaseName)}',
    action: (_) {},
  );
}

Future<void> createDatabase(String databaseName) async {
  await Transaction.current.db.withResults(
    'CREATE DATABASE IF NOT EXISTS ${sqlIdentifier(databaseName)}',
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

  final schemaScript = (read(pathToBackup).toList()
        ..removeWhere((line) => line.startsWith('--'))
        ..removeWhere((line) => line.startsWith('/*'))
        ..removeWhere((line) => line.isEmpty))
      .join('\n');

  // Validate the backup is readable before destroying an existing database.
  if (schemaScript.trim().isEmpty) {
    throw ArgumentError.value(pathToBackup, 'pathToBackup', 'Empty backup');
  }
  await dropDatabase(databaseName);

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
  const sql = '''
SELECT SCHEMA_NAME
FROM INFORMATION_SCHEMA.SCHEMATA
  WHERE SCHEMA_NAME = ?
''';

  return Transaction.current.db.withResults(sql,
      values: [databaseName], action: (rs) => rs.rows.isNotEmpty);
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
