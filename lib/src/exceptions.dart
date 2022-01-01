class TooManyResultsException extends MySqlORMException {
  TooManyResultsException(String message) : super(message);
}

class IntegrityException extends MySqlORMException {
  IntegrityException(String message) : super(message);
}

class NestedTransactionException extends MySqlORMException {
  NestedTransactionException(String message) : super(message);
}

class ConfigurationException extends MySqlORMException {
  ConfigurationException(String message) : super(message);
}

class MySqlORMException implements Exception {
  MySqlORMException(this.message);
  String message;
}
