import 'package:simple_mysql_orm/simple_mysql_orm.dart';

import '../../test_dao/model/member.dart';
import 'dao_publisher.dart';

class DaoMember extends DaoTenant<Member> {
  DaoMember() : super(tableName: tablename, tenantFieldName: 'publisherId');
  DaoMember.withDb(Db db)
      : super.withDb(db, tableName: tablename, tenantFieldName: 'publisherId');

  /// Throws an [UnknownMemberException] if the [email]
  /// is not from one of members.
  Future<Member> getByEmail({required String email}) async {
    final member = await trySingle(await query(
        'select * from $tablename '
        'where email = ? '
        'and publisherId = ?',
        [email, Tenant.tenantId]));
    if (member == null) {
      throw UnknownMemberException(
          'The email address $email is not for a know member');
    }
    return member;
  }

  Future<Member?> tryByEmail({required String email}) async => trySingle(
      await query('select * from $tablename where email = ?', [email]));

  static String get tablename => 'member';

  @override
  Member fromRow(Row row) => Member.fromRow(row);

  Future<List<Member>> search(String email) async =>
      query('select * from $tablename where email like ?', ['%$email%']);
}
