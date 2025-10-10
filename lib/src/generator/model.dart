/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'package:dcli/dcli.dart' hide Column;
import 'package:recase/recase.dart';

import '../exceptions.dart';
import '../schema/column.dart';

/// throws [ModelFileExistsException] if the output file already exists.
void generateModel(String tablename, List<Column> columns, {String? filename}) {
  final filename0 = filename ??= '${ReCase(tablename).snakeCase}.dart';

  if (exists(filename0)) {
    throw ModelFileExistsException(
        'The file ${truepath(filename0)} already exists');
  }

  sortColumns(columns);

  filename0.write(_getSource(tablename, columns));
}

String _getSource(String tablename, List<Column> columns) {
  final className = ReCase(tablename).pascalCase;

  return '''
${importDateTime(columns)}
import 'package:simple_mysql_orm/simple_mysql_orm.dart';

class $className extends EntityTenant<$className> {
  factory $className({
${_ctorArgs(columns, 4)}
  }) =>
      $className._internal(
${_ctorInternal(columns, 10)}
          );

  factory $className.fromRow(Row row) {
${_fromRow(columns, 4)}    


    return $className._internal(
${_returnInternal(columns, 8)}      
        );
  }

  $className._internal({
${_internalArgs(columns, 4)}    
  }) : super(id);

${_fields(columns, 2)}

  @override
  FieldList get fields => [
${_fieldList(columns, 8)}    
      ];

  @override
  ValueList get values => [
${_valueList(columns, 8)}    
      ];
}

typedef ${className}Id = int;

''';
}

/// Import the date_time package if a column is
/// of type Date or Time.
String importDateTime(List<Column> columns) {
  var include = false;
  for (final column in columns) {
    if (column.type == Type.date || column.type == Type.time) {
      include = true;
    }
  }
  return include ? "import 'package:date_time/date_time.dart';\n" : '';
}

String _valueList(List<Column> columns, int indent) {
  final result = StringBuffer();

  final prefix = _indent(indent);

  for (final column in columns) {
    if (column.name == 'id') {
      continue;
    }
    if (column.type == Type.enumT) {
      result.writeln('''$prefix${column.name}.name,''');
    } else {
      result.writeln('''$prefix${column.name},''');
    }
  }
  return result.toString();
}

String _fieldList(List<Column> columns, int indent) {
  final result = StringBuffer();

  final prefix = _indent(indent);

  for (final column in columns) {
    if (column.name == 'id') {
      continue;
    }
    result.writeln('''$prefix'${column.name}',''');
  }
  return result.toString();
}

String _fields(List<Column> columns, int indent) {
  final result = StringBuffer();

  final prefix = _indent(indent);

  for (final column in columns) {
    if (column.name == 'id') {
      continue;
    }
    final allowNull = column.allowNull;
    if (allowNull) {
      result.writeln('''${prefix}late ${column.dartType()}? ${column.name};''');
    } else {
      result.writeln('''${prefix}late ${column.dartType()} ${column.name};''');
    }
  }
  return result.toString();
}

String _internalArgs(List<Column> columns, int indent) {
  final result = StringBuffer();

  final prefix = _indent(indent);

  for (final column in columns) {
    if (column.name == 'id') {
      result.writeln('''${prefix}required int ${column.name},''');
    } else {
      result.writeln('''${prefix}required this.${column.name},''');
    }
  }
  return result.toString();
}

String _returnInternal(List<Column> columns, int indent) {
  final result = StringBuffer();

  final prefix = _indent(indent);

  for (final column in columns) {
    result.writeln('''$prefix${column.name}: ${column.name},''');
  }
  return result.toString();
}

String _fromRow(List<Column> columns, int indent) {
  final result = StringBuffer();

  final prefix = _indent(indent);

  for (final column in columns) {
    result.writeln('''${prefix}final ${column.name} = ${_fromType(column)};''');
  }
  return result.toString();
}

String _fromType(Column column) {
  final name = column.name;
  final get = column.allowNull ? 'try' : 'as';

  switch (column.type) {
    case Type.int:
      return "row.${get}Int('$name')";
    case Type.varchar:
      return "row.${get}String('$name')";
    case Type.datetime:
      return "row.${get}DateTime('$name')";
    case Type.date:
      return "row.${get}Date('$name')";
    case Type.tinyint:
      return "row.${get}Bool('$name')";
    case Type.time:
      return "row.${get}Date('$name')";
    case Type.enumT:
      final typeName = column.typeDetails.enumName;
      return "row.${get}Custom('$name', "
          '(value) => ${typeName}Ex.fromName(value as String))!';
  }
}

String _ctorInternal(List<Column> columns, int indent) {
  final result = StringBuffer();

  final prefix = _indent(indent);

  for (final column in columns) {
    if (column.name == 'id') {
      result.writeln('''${prefix}id: Entity.notSet,''');
    } else {
      result.writeln('''$prefix${column.name}: ${column.name},''');
    }
  }
  return result.toString();
}

String _ctorArgs(List<Column> columns, int indent) {
  final result = StringBuffer();
  for (final column in columns) {
    if (column.name == 'id') {
      continue;
    }
    if (!column.allowNull) {
      result.writeln(
          '''${' ' * indent} required ${column.dartType()} ${ReCase(column.name).camelCase},''');
    } else {
      result.writeln(
          '''${' ' * indent} ${column.dartType()}? ${ReCase(column.name).camelCase},''');
    }
  }
  return result.toString();
}

void sortColumns(List<Column> columns) {
  columns.sort((l, r) {
    // put the id last.
    if (l.name == 'id') {
      return 0;
    }
    if (l.allowNull == r.allowNull) {
      return l.name.compareTo(r.name);
    } else {
      return l.allowNull ? 1 : 0;
    }
  });
}

String _indent(int indent) => ' ' * indent;
