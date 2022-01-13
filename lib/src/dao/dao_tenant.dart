import '../../simple_mysql_orm.dart';

abstract class DaoTenant<E extends EntityTenant<E>> extends Dao<E> {
  DaoTenant({required String tableName, required this.tenantFieldName})
      : super(tableName);

  /// Create a dao object with passed [db]
  DaoTenant.withDb(Db db,
      {required String tableName, required this.tenantFieldName})
      : super.withDb(db, tableName);

  String tenantFieldName;

  /// Assumes that the last clause in [query] is a where clause
  /// and appends the tenant id if we are in tenant mode.
  Future<List<E>> queryTenant(String _query, ValueList values) async =>
      query(appendTenantWhere(_query), appendTenantValue(values));

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

    return queryTenant(sql, values);
  }

  String appendTenantWhere(String sql) {
    var _sql = sql;
    if (Tenant.inTenantScope) {
      _sql += ' and `${getTablename()}`.`$tenantFieldName`=? ';
    }
    return _sql;
  }

  @override
  String appendTenantClause(String sql, List<String?> values) {
    appendTenantValue(values);
    return appendTenantWhere(sql);
  }

  ValueList appendTenantValue(List<Object?> values) {
    if (Tenant.inTenantScope) {
      values.add('${Tenant.tenantId}');
    }
    return values;
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
    if (!Tenant.inTenantBypassScope) {
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
