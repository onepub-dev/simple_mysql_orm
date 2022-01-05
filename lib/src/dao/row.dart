import 'dart:convert';

import 'package:date_time/date_time.dart';
import 'package:money2/money2.dart';

class Row {
  Row(this.fields);
  Map<String, dynamic> fields;

  String fieldAsString(String name) => fields[name].toString();

  String? fieldAsStringNullable(String name) => fields[name]?.toString();

  int fieldAsInt(String name) => fields[name] as int;

  /// Currently expects a Blob
  Map<String, dynamic> fieldAsMap(String name) =>
      jsonDecode(fields[name].toString()) as Map<String, dynamic>;

  bool fieldAsBool(String name) => (fields[name] as int) == 1;
  DateTime fieldAsDateTime(String name) => fields[name] as DateTime;
  Date fieldAsDate(String name) => Date.from(fields[name] as DateTime);

  /// Extract the field [name] as a nullable Date
  Date? fieldAsDateNullable(String name) {
    if (fields[name] == null) {
      return null;
    }
    return Date.from(fields[name] as DateTime);
  }

  Time fieldAsTime(String name) => Time.fromStr(fields[name] as String)!;
  Money fieldAsMoney(String name, Currency currency) =>
      Money.fromIntWithCurrency(fields[name] as int, currency);
}

// DateTime parse(String) => 
