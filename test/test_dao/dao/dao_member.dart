import 'package:simple_mysql_orm/simple_mysql_orm.dart';
import '../model/member.dart';

class MemberDao extends DaoTenant<Member> {
  MemberDao() : super(tableName: tablename, tenantFieldName: 'publisherId');

  MemberDao.withDb(Db db)
      : super.withDb(db, tableName: tablename, tenantFieldName: 'publisherId');

  Future<Member?> getByName(String name) async {
    final row = await tryByField('email', name);

    if (row == null) {
      return null;
    }

    return row;
  }

  static String get tablename => 'member';

  @override
  Member fromRow(Row row) => Member.fromRow(row);

  Future<List<Member>> search(String name) async => query(
      'select * from $tablename where name like ? and publisherId = ?',
      ['%$name%', Tenant.tenantId]);
}
