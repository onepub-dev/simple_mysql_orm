import 'package:simple_mysql_orm/simple_mysql_orm.dart';
import 'package:simple_mysql_orm/src/generator/dao.dart';
import 'package:simple_mysql_orm/src/generator/model.dart';
import 'package:simple_mysql_orm/src/util/sql_identifier.dart';
import 'package:test/test.dart';

import '../../test_dao/model/member.dart';
import 'dao_member.dart';

void main() {
  test('SQL identifiers are quoted, including embedded backticks', () {
    expect(sqlIdentifier('db`name'), '`db``name`');
    expect(sqlIdentifier('db.table', qualified: true), '`db`.`table`');
    expect(sqlOrderBy('name, id'), '`name`, `id`');
  });

  test('source generator rejects database names that alter Dart code', () {
    expect(() => generateDao("table'; import 'x", []), throwsArgumentError);
    expect(() => generateModel("table'; import 'x", []), throwsArgumentError);
  });

  test('tenant writes require an explicit tenant or bypass scope', () async {
    final dao = DaoMember.withDb(_UnexpectedDb());

    await expectLater(dao.removeAll(), throwsA(isA<MissingTenantException>()));
    await expectLater(
        dao.removeById(7), throwsA(isA<MissingTenantException>()));
    expect(() => dao.queryTenant('select * from member where email = ?', ['x']),
        throwsA(isA<MissingTenantException>()));
  });

  test('builder scopes tenant queries even without a field condition',
      () async {
    final dao = _RecordingMemberDao();
    await withTenant(
        tenantId: 7,
        action: () async {
          await dao.select().run();
          expect(dao.lastSql, contains('where `member`.`publisherId` = ?'));
          expect(dao.lastValues, [7]);

          await dao.delete().where().eq('email', 'a@example.com').run();
          expect(dao.lastSql,
              contains('where `email` = ? and `member`.`publisherId` = ?'));
          expect(dao.lastValues, ['a@example.com', 7]);
        });
  });

  test('custom OR query filters every returned row by tenant', () async {
    final dao = _RecordingMemberDao();
    await withTenant(
        tenantId: 7,
        action: () async {
          await dao.queryTenant(
              'select * from member where email = ? OR enabled = ?',
              ['a@example.com', '1']);
          expect(
              dao.lastSql,
              contains('from `member` where (email = ? OR enabled = ?) '
                  'and `publisherId` = ?'));
          expect(dao.lastValues, ['a@example.com', '1', 7]);

          expect(
              () => dao.queryTenant(
                  'select *, FIRST_VALUE(email) OVER (ORDER BY id) '
                  'from member where enabled = ?',
                  ['1']),
              throwsArgumentError);
          expect(
              () => dao.queryTenant(
                  'select * from member where email = ?) OR 1=1 --', ['x']),
              throwsArgumentError);
        });
  });

  test('field identifiers cannot change generated predicates', () async {
    final dao = _RecordingMemberDao();
    await withTenant(
        tenantId: 7,
        action: () async {
          await dao.select().where().eq('1=1 OR email', 'x').run();
          expect(dao.lastSql, contains('where `1=1 OR email` = ? and'));

          await dao.getListByField('email` OR 1=1 --', 'x');
          expect(dao.lastSql, contains('where `email`` OR 1=1 --` = ?'));

          await dao.select().where().eq('email', 'x').orderBy('id DESC').run();
          expect(dao.lastSql, contains('order by `id DESC` asc'));

          await dao.getListByField('display-name', 'x');
          expect(dao.lastSql, contains('where `display-name` = ?'));

          await dao.getListByField('café', 'x');
          expect(dao.lastSql, contains('where `café` = ?'));
        });
  });

  test('lookup exceptions omit bound values', () async {
    final dao = _RecordingMemberDao();
    const secret = 'SENTINEL_PRIVATE_VALUE';
    await withTenant(
        tenantId: 7,
        action: () async {
          await expectLater(
              dao.getByField('email', secret),
              throwsA(predicate((error) =>
                  error is DatabaseIntegrityException &&
                  !error.toString().contains(secret))));
          await expectLater(
              dao.querySingle(
                  'select * from member where email = ? and publisherId = ?',
                  [secret, 7]),
              throwsA(predicate((error) =>
                  error is DatabaseIntegrityException &&
                  !error.toString().contains(secret))));
        });
  });
}

class _UnexpectedDb implements Db {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('A database call was made before validation');
}

class _RecordingMemberDao extends DaoMember {
  _RecordingMemberDao() : super.withDb(_UnexpectedDb());

  String? lastSql;
  ValueList? lastValues;

  @override
  Future<List<Member>> query(String query, ValueList values) async {
    lastSql = query;
    lastValues = List.of(values);
    return [];
  }
}
