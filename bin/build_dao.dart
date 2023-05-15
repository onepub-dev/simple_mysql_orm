#! /usr/bin/env dcli

/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */



import 'dart:io';

import 'package:args/args.dart';
import 'package:dcli/dcli.dart' hide Column;
import 'package:simple_mysql_orm/simple_mysql_orm.dart';
import 'package:simple_mysql_orm/src/generator/dao.dart';
import 'package:simple_mysql_orm/src/generator/model.dart';

/// Creates a Dao and Model class from a table name.
///

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('host',
        abbr: 'h',
        defaultsTo: 'localhost',
        help: 'Hostname of the mysql server.')
    ..addOption('port',
        abbr: 'o', defaultsTo: '3306', help: 'TCP Port of mysql server.')
    ..addOption('database',
        abbr: 'd', mandatory: true, help: 'Name of database')
    ..addOption('user', abbr: 'u', mandatory: true, help: 'Username')
    ..addOption('password', abbr: 'p', mandatory: true, help: 'Password')
    ..addOption('table', abbr: 't', mandatory: true, help: 'Table')
    ..addOption('filename', abbr: 'f', help: 'Path to the output file')
    ..addFlag('dao', abbr: 'a', help: 'Generate the Dao file as well');

  final ArgResults result;
  try {
    result = parser.parse(args);
  } on FormatException catch (e) {
    printerr(red(e.message));
    exit(1);
  }

  final host = result['host'] as String;
  final port = int.parse(result['port'] as String);
  final database = result['database'] as String;
  final user = result['user'] as String;
  final password = result['password'] as String;
  final tablename = result['table'] as String;
  final filename = result['filename'] as String?;
  DbPool.fromArgs(
    host: host,
    port: port,
    database: database,
    user: user,
    password: password,
  );

  await _createDao(tablename: tablename, filename: filename);

  await DbPool().close();
}

Future<void> _createDao({required String tablename, String? filename}) async {
  await withTransaction(action: () async {
    final rows = await tquery('SHOW COLUMNS from $tablename');

    final columns = <Column>[];

    for (final row in rows) {
      columns.add(Column.fromRow(row));
    }

    generateModel(tablename, columns, filename: filename);
    generateDao(tablename, columns,
        filename: filename != null ? 'dao_$filename' : null);
  });
}
