import 'dart:convert';

import 'package:date_time/date_time.dart';
import 'package:money2/money2.dart';

class Row {
  Row(this.fields);
  Map<String, dynamic> fields;

  /// convert the field with [name] to a string.
  String asString(String name) => fields[name].toString();
  String? tryString(String name) => fields[name]?.toString();

  /// convert the field with [name] to a int.
  int asInt(String name) => fields[name] as int;
  int? tryInt(String name) => fields[name] == null ? null : fields[name] as int;

  /// convert the field with [name] to a Map.
  /// Currently expects that the map is stored as a Blob
  Map<String, dynamic> asMap(String name) =>
      jsonDecode(fields[name].toString()) as Map<String, dynamic>;

  /// convert the field with [name] to a bool.
  bool asBool(String name) => (fields[name] as int) == 1;
  bool? tryBool(String name) =>
      (fields[name] == null ? null : fields[name] as int) == 1;

  /// convert the field with [name] to a DateTime.
  DateTime asDateTime(String name) => fields[name] as DateTime;
  DateTime? tryDateTime(String name) =>
      fields[name] == null ? null : fields[name] as DateTime;

  /// convert the field with [name] to a Date.
  Date asDate(String name) => Date.from(fields[name] as DateTime);
  Date? tryDate(String name) =>
      fields[name] == null ? null : fields[name] as Date;

  /// convert the field with [name] to a Date.
  Time asTime(String name) => Time.fromStr(fields[name] as String)!;
  Time? tryTime(String name) =>
      fields[name] == null ? null : fields[name] as Time;

  Money asMoney(String name, Currency currency) =>
      Money.fromIntWithCurrency(fields[name] as int, currency);

  Money? tryMoney(String name) =>
      fields[name] == null ? null : fields[name] as Money;

  T asCustom<T>(String name, T Function(Object value) convertTo) =>
      tryCustom(name, (value) => convertTo(value!)!)!;

  T? tryCustom<T>(String name, T? Function(Object? value) convertTo) {
    final dynamic value = fields[name];

    if (value == null) {
      return null;
    }
    return convertTo(value);
  }
}
