/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'package:recase/recase.dart';

import '../dao/row.dart';
import '../util/enum_helper.dart';

/// Holds a column definition as returned by
/// 'show columns from <table>'
class Column {
  Column.fromRow(Row row) {
    name = row.asString('Field');
    typeDetails = _parseType(row.asString('Type'), name);
    type = typeDetails.type;
    size = typeDetails.size;
    allowNull = row.asString('Null') == 'YES';
    key = KeyEx.fromName(row.asString('Key'));
    autoIncrement = (row.asString('Extra')) == 'auto_increment';
  }

  late String name;
  late Type type;
  late int size;
  late bool allowNull;
  late Key key;
  late bool autoIncrement;
  late TypeDetails typeDetails;

  String dartType() {
    switch (type) {
      case Type.int:
        if (size < 4) {
          return 'bool';
        }
        return 'int';
      case Type.varchar:
        return 'String';
      case Type.datetime:
        return 'DateTime';
      case Type.date:
        return 'Date';
      case Type.tinyint:
        return 'bool';
      case Type.time:
        return 'Time';
      case Type.enumT:
        return typeDetails.enumName!;
    }
  }

  TypeDetails _parseType(String type, String name) {
    if (type.startsWith('enum(')) {
      return _parseEnumType(type, name);
    }
    final index = type.indexOf('(');
    if (index != -1) {
      // int(4)
      final typeName = type.substring(0, index);
      final size = type.substring(index + 1, type.length - 1);
      return TypeDetails(typeName, int.parse(size));
    }

    return TypeDetails(type, 1);
  }
}

/// For an enum we just return the column name in PascalCase
TypeDetails _parseEnumType(String type, String name) =>
    TypeDetails.forEnum(name);

class TypeDetails {
  TypeDetails(String type, this.size) : type = TypeEx.fromName(type);

  TypeDetails.forEnum(String columnName)
      : type = Type.enumT,
        size = 1,
        enumName = ReCase(columnName).pascalCase;
  Type type;
  int size;

  /// only set if [type] == [Type.enumT]
  String? enumName;
}

enum Key {
  // primary key
  pri,
  // first column of non-unique index
  mul,
  // first column of a unique index
  uni,
  // not a key
  none
}

enum Type {
  int,
  tinyint,
  varchar,
  datetime,
  date,
  time,
  enumT,
}

extension TypeEx on Type {
  /// Throws an [Exception] if the name isn't a valid enum.
  static Type fromName(String name) => EnumHelper().getEnum(name, Type.values);
}

extension KeyEx on Key {
  /// Throws an [Exception] if the name isn't a valid enum.
  static Key fromName(String name) =>
      EnumHelper().getEnum(name, Key.values, defaultValue: Key.none);
}
