class Row {
  Row(this.fields);
  Map<String, dynamic> fields;

  String fieldAsString(String name) => fields[name] as String;

  int fieldAsInt(String name) => fields[name] as int;

  bool fieldAsBool(String name) => fields[name] as bool;
  DateTime fieldAsDateTime(String name) => fields[name] as DateTime;
  DateTime fieldAsDate(String name) => fields[name] as DateTime;
}
