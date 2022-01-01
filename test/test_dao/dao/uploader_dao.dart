import 'package:simple_mysql_orm/simple_mysql_orm.dart';
import '../model/publisher.dart';

class PublisherDao extends Dao<Publisher> {
  PublisherDao() : super(tablename);

  PublisherDao.withDb(Db db) : super.withDb(db, tablename);

  Future<Publisher?> getByName(String name) async {
    final row = await getByField('name', name);

    if (row == null) {
      return null;
    }

    return row;
  }

  static String get tablename => 'uploader';

  @override
  Publisher fromRow(Row row) => Publisher.fromRow(row);

  Future<List<Publisher>> search(String name) async =>
      query('select * from $tablename where name like ?', ['%$name%']);
}
