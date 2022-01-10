import '../../simple_mysql_orm.dart';

abstract class DaoTenant<E extends EntityTenant<E>> extends Dao<E> {
  DaoTenant({required String tableName, required this.tenantFieldName})
      : super(tableName);

  /// Create a dao object with passed [db]
  DaoTenant.withDb(Db db,
      {required String tableName, required this.tenantFieldName})
      : super.withDb(db, tableName);

  String tenantFieldName;

  @override
  String appendTenantClause(String sql, List<String?> values) {
    var _sql = sql;
    if (Tenant.inTenantScope) {
      _sql += ' and `${getTablename()}`.`$tenantFieldName`=?';
      values.add('${Tenant.tenantId}');
    }
    return _sql;
  }

  @override
  Future<List<E>> getListByField(String fieldName, String fieldValue,
      {bool like = false}) async {
    var sql = 'select * from ${getTablename()} ';

    final values = [fieldValue];

    if (like) {
      sql += 'where `$fieldName` like ? ';
    } else {
      sql += 'where `$fieldName` = ? ';
    }
    if (Tenant.inTenantScope) {
      sql += ' and `${getTablename()}`.`$tenantFieldName`=? ';
      values.add('${Tenant.tenantId}');
    }

    return query(sql, values);
  }

  @override
  E callFromRow(Row row) {
    final entity = fromRow(row)..tenantId = row.asInt(tenantFieldName);

    return entity;
  }

  /// Validates the multi-tenant has been configured correctly.
  /// Throws [MissingTenantException] if the tenant has been
  /// mis-configured.
  @override
  void validate(String query) {
    if (Tenant.inTenantScope) {
      // if (!Tenant.hasTenantId) {
      //   /// oops. [dao] is a tenant but no tenant id has been passed.
      //   throw MissingTenantException('The dao ${getTablename()} is a tenant '
      //       'but no tenant was injected.');
      // }

      /// This won't catch everything but should be somewhat useful.
      /// We could improve this by checking for the presense of a join
      /// or where clause with the tenantColumn.
      if (!query.contains(tenantFieldName)) {
        throw MissingTenantException(
            "You have written a custom sql script which doesn't appear "
            'to filter by tenant.');
      }
    }
  }

  @override
  void prepareInsert(FieldList fields, List<String?> values) {
    if (!Tenant.inTenantBypassScope) {
      fields.add(tenantFieldName);
      values.add('${Tenant.tenantId}');
    }
  }
}
