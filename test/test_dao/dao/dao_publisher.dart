/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */


import 'package:simple_mysql_orm/simple_mysql_orm.dart';
import '../model/publisher.dart';

class PublisherDao extends Dao<Publisher> {
  PublisherDao() : super(tablename);

  PublisherDao.withDb(Db db) : super.withDb(db, tablename);

  Future<Publisher?> getByName(String name) async {
    final row = await tryByField('name', name);

    if (row == null) {
      return null;
    }

    return row;
  }

  static String get tablename => 'publisher';

  @override
  Publisher fromRow(Row row) => Publisher.fromRow(row);

  Future<List<Publisher>> search(String name) async =>
      query('select * from $tablename where name like ?', ['%$name%']);
}
