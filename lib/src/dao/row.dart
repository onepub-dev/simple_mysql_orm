import 'dart:convert';

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
  DateTime fieldAsDate(String name) => fields[name] as DateTime;
}
