/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */


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

class ModelFileExistsException extends MySqlORMException {
  ModelFileExistsException(String message) : super(message);
}

class DaoFileExistsException extends MySqlORMException {
  DaoFileExistsException(String message) : super(message);
}

class MySQLException implements Exception {
  MySQLException(this.message);
  String message;
  @override
  String toString() => message;
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
