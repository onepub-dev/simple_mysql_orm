/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'package:dcli/dcli.dart' hide Column;
import 'package:recase/recase.dart';

import '../../simple_mysql_orm.dart';
import 'model.dart';

/// throws [DaoFileExistsException] if the output file already exists.
void generateDao(String tablename, List<Column> columns, {String? filename}) {
  // we needed a non-const init
  // ignore: no_leading_underscores_for_local_identifiers
  final _filename = filename ??= 'dao_${ReCase(tablename).snakeCase}.dart';

  if (exists(_filename)) {
    throw DaoFileExistsException(
        'The file ${truepath(_filename)} already exists');
  }

  sortColumns(columns);

  _filename.write(_getSource(tablename, columns));
}

String _getSource(String tablename, List<Column> columns) {
  final modelClassName = ReCase(tablename).pascalCase;
  final className = 'Dao$modelClassName';
  final modelFileName = ReCase(tablename).snakeCase;

  return '''

import 'package:simple_mysql_orm/simple_mysql_orm.dart';
import '$modelFileName.dart';

class $className extends Dao<$modelClassName> {
  $className() : super(tablename);
  $className.withDb(Db db)
      : super.withDb(db, tablename);

  static String get tablename => '$tablename';

  @override
  $modelClassName fromRow(Row row) => $modelClassName.fromRow(row);
}
''';
}
