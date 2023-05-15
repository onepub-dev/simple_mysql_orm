/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'package:simple_mysql_orm/simple_mysql_orm.dart';

import '../../test_dao/model/publisher.dart';

class DaoPublisher extends Dao<Publisher> {
  DaoPublisher() : super(tablename);
  DaoPublisher.withDb(Db db) : super.withDb(db, tablename);

  static String get tablename => 'publisher';

  static String get publicPublisher => '__Public__';

  Future<Publisher> getByName({required String name}) async {
    final publisher = await tryByName(name: name);

    if (publisher == null) {
      throw UnknownPublisherException('The publisher $name does not exist');
    }
    return publisher;
  }

  Future<Publisher?> tryByName({required String name}) async => trySingle(
      await query('select * from $tablename where name = ? ', [name]));

  @override
  Publisher fromRow(Row row) => Publisher.fromRow(row);

  Future<List<Publisher>> search({required String partialName}) async =>
      query('select * from $tablename where name like ?', ['%$partialName%']);
}

class AccountDisabledException extends SMOException {
  AccountDisabledException(super.message);
}

class UnknownMemberException extends SMOException {
  UnknownMemberException(super.message);
}

class UnknownPublisherException extends SMOException {
  UnknownPublisherException(super.message);
}

class SMOException implements Exception {
  SMOException(this.message);

  String message;

  @override
  String toString() => message;
}
