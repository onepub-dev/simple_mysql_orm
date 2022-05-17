class MySqlException implements Exception {
  MySqlException(this.message);
  Object? errorNumber;

  String message;
}
