class ConfigurationException extends MySqlORMException {
  ConfigurationException(String message) : super(message);
}

class DatabaseIntegrityException extends MySqlORMException {
  DatabaseIntegrityException(String message) : super(message);
}

class IdentityNotSetException extends MySqlORMException {
  IdentityNotSetException(String message) : super(message);
}

class MissingTenantException extends MySqlORMException {
  MissingTenantException(String message) : super(message);
}

class MySqlORMException implements Exception {
  MySqlORMException(this.message);
  String message;

  @override
  String toString() => message;
}

class NestedTransactionException extends MySqlORMException {
  NestedTransactionException(String message) : super(message);
}

class TooManyResultsException extends MySqlORMException {
  TooManyResultsException(String message) : super(message);
}

class UnknownEntityIdException extends MySqlORMException {
  UnknownEntityIdException(String message) : super(message);
}
