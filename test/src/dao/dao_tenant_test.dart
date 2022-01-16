import 'package:simple_mysql_orm/simple_mysql_orm.dart';
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
    await withTransaction(action: () async {
      final daoSystem = await createTestSystemKey();

      final noojee =
          Publisher(name: 'Noojee', contactEmail: 'info@noojee.com.au');
      final noojeeId = await DaoPublisher().persist(noojee);

      final smo = Publisher(name: 'smo', contactEmail: 'info@smo.com.au');
      final smoId = await DaoPublisher().persist(smo);

      final daoMember = DaoMember();

      const smoEmail = 'sales@smo.com.au';
      await withTenant(
          tenantId: smoId,
          action: () async {
            final smoMember = Member(email: smoEmail);
            await daoMember.persist(smoMember);
          });

      await withTenant(
          tenantId: noojeeId,
          action: () async {
            const noojeeEmail = 'sales@noojee.com.au';
            final noojeeMember = Member(email: noojeeEmail);
            final noojeeMemberId = await daoMember.persist(noojeeMember);

            /// access non-tenant entity
            expect(await daoSystem.getByKey('smtp'), 'localhost');

            /// access entity within the tenant
            expect((await daoMember.getByEmail(email: noojeeEmail)).id,
                noojeeMemberId);

            /// fail to access entity not in the tenant.
            expect(() => daoMember.getByEmail(email: smoEmail),
                throwsA(isA<UnknownMemberException>()));

            /// try to bypass tenant
            expect(
                () => daoMember
                    .query('select * from member where email = ?', [smoEmail]),
                throwsA(isA<MissingTenantException>()));

            /// permitted by pass of tenant
            await withTenantByPass(action: () async {
              final member = await daoMember
                  .query('select * from member where email = ?', [smoEmail]);
              expect(member.first.email, smoEmail);
            });

            expect((await daoMember.getByField('email', noojeeEmail)).id,
                noojeeMemberId);

            expect(
                (await daoMember.getListByField('email', noojeeEmail)).length,
                1);

            /// select builder
            final rows =
                await daoMember.select().where().eq('email', noojeeEmail).run();
            expect(rows.length, 1);
            expect(rows.first.email, noojeeEmail);

            await withTenantByPass(action: () async {
              final rows = await daoMember
                  .select()
                  .where()
                  .like('email', '%@%')
                  .orderBy('email')
                  .run();
              expect(rows.length, 2);
              expect(rows[0].email, noojeeEmail);
              expect(rows[1].email, smoEmail);

              await daoMember.delete().where().eq('email', smoEmail).run();
              final members = await daoMember.getAll();
              expect(members.length, 1);
              expect(members[0].email, noojeeEmail);
            });

            /// delete
            final member = await daoMember.getById(noojeeMemberId);
            await daoMember.remove(member);
          });
    }, debugName: 'dao_tenant_test');
  });
}

Future<DaoSystem> createTestSystemKey() async {
  final daoSystem = DaoSystem();

  for (final system in await daoSystem.getAll()) {
    await daoSystem.remove(system);
  }

  await daoSystem.persist(System(key: 'smtp', value: 'localhost'));
  return daoSystem;
}
