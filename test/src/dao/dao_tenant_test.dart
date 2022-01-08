import 'package:simple_mysql_orm/simple_mysql_orm.dart';
import 'package:simple_mysql_orm/src/dao/tenant.dart';
import 'package:test/test.dart';

import '../../test_dao/model/member.dart';
import '../../test_dao/model/publisher.dart';
import '../../test_dao/model/system.dart';
import '../../test_setup.dart';
import 'dao_member.dart';
import 'dao_publisher.dart';
import 'dao_system.dart';

void main() {
  setUp(testSetup);

  test('dao tenant ...', () async {
    await withTransaction(() async {
      final daoSystem = DaoSystem();
      await daoSystem.persist(System(key: 'smtp', value: 'localhost'));

      final noojee =
          Publisher(name: 'Noojee', contactEmail: 'info@noojee.com.au');
      final noojeeId = await DaoPublisher().persist(noojee);

      final smo = Publisher(name: 'smo', contactEmail: 'info@smo.com.au');
      final smoId = await DaoPublisher().persist(smo);

      const noojeeEmail = 'sales@noojee.com.au';
      final daoMember = DaoMember();
      final noojeeMember = Member(publisherId: noojeeId, email: noojeeEmail);
      final noojeeMemberId = daoMember.persist(noojeeMember);

      const smoEmail = 'sales@smo.com.au';
      final smoMember = Member(publisherId: smoId, email: smoEmail);
      final smoMemberId = daoMember.persist(smoMember);

      withTenant(
          tenantId: noojee.id,
          action: () async {
            /// access non-tenant entity
            expect(await daoSystem.getByKey('smtp'), 'localhost');

            /// access entity within the tenant
            expect(daoMember.getByEmail(email: noojeeEmail), noojeeMemberId);

            /// fail to access entity not in the tenant.
            expect(() => daoMember.getByEmail(email: smoEmail),
                throwsA(isA<UnknownMemberException>()));

            /// try to bypass tenant
            expect(
                await daoMember
                    .query('select * from member where email = ?', [smoEmail]),
                throwsA(isA<MissingTenantException>()));
          });
    }, debugName: 'dao_tenant_test');
  });
}
