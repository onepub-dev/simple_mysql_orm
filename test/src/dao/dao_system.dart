/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'package:simple_mysql_orm/simple_mysql_orm.dart';

import '../../test_dao/model/system.dart';

class DaoSystem extends Dao<System> {
  DaoSystem() : super(tablename);
  DaoSystem.withDb(Db db) : super.withDb(db, tablename);

  static String get tablename => 'system';

  @override
  System fromRow(Row row) => System.fromRow(row);

  Future<String?> getByKey(String keyName) async =>
      (await getByField('key', keyName)).value;

  Future<String?> tryByKey(String keyName) async =>
      (await tryByField('key', keyName))?.value;
}
