/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */


import 'package:simple_mysql_orm/simple_mysql_orm.dart';
import '../model/package.dart';

class PackageDao extends Dao<Package> {
  PackageDao() : super(tablename);
  PackageDao.withDb(Db db) : super.withDb(db, tablename);

  Future<Package?> getByName(String name) async {
    final row = await tryByField('name', name);

    if (row == null) {
      return null;
    }

    return row;
  }

  static String get tablename => 'package';

  @override
  Package fromRow(Row row) => Package.fromRow(row);

  Future<Iterable<Package>> search({
    required int size,
    required int page,
    required String sort,
    String? keyword,
    String? uploader,
    String? dependency,
  })  {
    final values = <String>[];

    var where = '';
    if (keyword != null) {
      where += 'name like "*?*" ';
      values.add(keyword);
    }

    if (uploader != null) {
      where += 'pub.name="?" ';
      values.add(uploader);
    }

    if (dependency != null) {
      where += r'JSON_CONTAINS_PATH("$dependencies.?") ';
      values.add(dependency);
    }

    final sql = '''
select * from $tablename 
where   $where
limit ${page * size}, $size 
order by ? descending
''';

    return query(sql, [
      if (keyword != null) keyword,
      if (uploader != null) uploader,
      if (dependency != null) dependency,
      sort
    ]);
  }
}
