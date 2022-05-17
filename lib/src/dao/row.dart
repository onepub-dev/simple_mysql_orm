import 'dart:convert';

import 'package:date_time/date_time.dart';
import 'package:money2/money2.dart';
import 'package:mysql_client/mysql_client.dart';

class Row {
  Row(this.row) {
    // this.fields =
    //     CanonicalizedMap<String, String, dynamic>((key)
    //    => key.toUpperCase());

    // this.fields.addAll(fields);
  }
  ResultSetRow row;
  // late final CanonicalizedMap<String, String, dynamic> fields;

  /// convert the field with [name] to a string.
  String asString(String name) => tryString(name)!;
  String? tryString(String name) => tryValue(name);

  /// convert the field with [name] to a int.
  int asInt(String name) => tryInt(name)!;
  int? tryInt(String name) {
    final value = tryValue(name);

    if (value == null) {
      return null;
    }
    return int.parse(value);
  }

  /// convert the field with [name] to a Map.
  /// Currently expects that the map is stored as a Blob
  Map<String, dynamic> asMap(String name) =>
      jsonDecode(row.colByName(name).toString()) as Map<String, dynamic>;

  /// convert the field with [name] to a bool.
  bool asBool(String name) => tryBool(name)!;
  bool? tryBool(String name) {
    final value = tryInt(name);
    if (value == null) {
      return null;
    }
    return value == 1;
  }

  /// convert the field with [name] to a DateTime.
  DateTime asDateTime(String name) => tryDateTime(name)!;
  DateTime? tryDateTime(String name) {
    final value = tryValue(name);
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  /// convert the field with [name] to a Date.
  Date asDate(String name) => tryDate(name)!;
  Date? tryDate(String name) {
    final value = tryDateTime(name);
    if (value == null) {
      return null;
    }
    return Date.from(value);
  }

  /// convert the field with [name] to a Date.
  Time asTime(String name) => tryTime(name)!;
  Time? tryTime(String name) {
    final value = tryValue(name);
    if (value == null) {
      return null;
    }
    return Time.fromStr(value);
  }

  Money asMoney(String name, Currency currency) => tryMoney(name, currency)!;

  Money? tryMoney(String name, Currency currency) {
    final value = tryInt(name);
    if (value == null) {
      return null;
    }
    return Money.fromIntWithCurrency(value, currency);
  }

  T asCustom<T>(String name, T Function(Object value) convertTo) =>
      tryCustom(name, (value) => convertTo(value!)!)!;

  T? tryCustom<T>(String name, T? Function(Object? value) convertTo) {
    final dynamic value = tryInt(name);

    if (value == null) {
      return null;
    }
    return convertTo(value);
  }

  //  E? _tryValue<E>(String name) => tryValue(row, name);

  String? tryValue(String name) => row.colByName(name);
}
