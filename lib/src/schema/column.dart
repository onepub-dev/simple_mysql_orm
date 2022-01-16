import '../dao/row.dart';
import '../util/enum_helper.dart';

/// Holds a column definition as returned by
/// 'show columns from <table>'
class Column {
  Column.fromRow(Row row) {
    name = row.fields['Field'] as String;
    final _typeDetails = _parseType(row.fields['Type'].toString());
    type = _typeDetails.type;
    size = _typeDetails.size;
    allowNull = (row.fields['Null'] as String) == 'YES';
    key = KeyEx.fromName(row.fields['Key'] as String);
    autoIncrement = (row.fields['Extra'] as String) == 'auto_increment';
  }
  late String name;
  late Type type;
  late int size;
  late bool allowNull;
  late Key key;
  late bool autoIncrement;

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
    }
  }

  _TypeDetails _parseType(String type) {
    final index = type.indexOf('(');
    if (index != -1) {
      // int(4)
      final typeName = type.substring(0, index);
      final size = type.substring(index + 1, type.length - 1);
      return _TypeDetails(typeName, int.parse(size));
    }

    return _TypeDetails(type, 1);
  }
}

class _TypeDetails {
  _TypeDetails(String type, this.size) : type = TypeEx.fromName(type);

  Type type;
  int size;
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
