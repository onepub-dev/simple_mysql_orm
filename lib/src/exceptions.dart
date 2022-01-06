class TooManyResultsException extends MySqlORMException {
  TooManyResultsException(String message) : super(message);
}

class UnknownEntityIdException extends MySqlORMException {
  UnknownEntityIdException(String message) : super(message);
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
