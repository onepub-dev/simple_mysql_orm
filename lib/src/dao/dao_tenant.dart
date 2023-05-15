/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'package:meta/meta.dart';

import '../../simple_mysql_orm.dart';

abstract class DaoTenant<E extends EntityTenant<E>> extends Dao<E> {
  DaoTenant(super.tablename, {required this.tenantFieldName});

  /// Create a dao object with passed [db]
  DaoTenant.withDb(super.db, super.tableName, {required this.tenantFieldName})
      : super.withDb();

  String tenantFieldName;

  /// Assumes that the last clause in [query] is a where clause
  /// and appends the tenant id if we are in tenant mode.
  Future<List<E>> queryTenant(String _query, ValueList values) async =>
      query(appendTenantWhere(_query), appendTenantValue(values));

  @override
  Future<List<E>> getListByField(String fieldName, String fieldValue,
      {bool like = false,
      int offset = 0,
      int limit = 20,
      String? orderBy,
      SortDirection sortDirection = SortDirection.asc}) async {
    var sql = 'select * from ${getTablename()} ';

    final values = [fieldValue];

    if (like) {
      sql += 'where `$fieldName` like ? ';
    } else {
      sql += 'where `$fieldName` = ? ';
    }

    sql = appendTenantWhere(sql);
    appendTenantValue(values);

    if (orderBy != null) {
      sql += 'order by $orderBy ${sortDirection.name} ';
    }

    sql += 'limit $offset, $limit ';

    return query(sql, values);
  }

  String appendTenantWhere(String sql, {bool addWhere = false}) {
    var _sql = sql;
    if (Tenant.inTenantScope) {
      if (addWhere) {
        _sql += ' where ';
      } else {
        _sql += ' and ';
      }

      _sql += '`${getTablename()}`.`$tenantFieldName`= ? ';
    }
    return _sql;
  }

  @override
  String appendTenantClause(String sql, List<String?> values,
      {bool addWhere = false}) {
    appendTenantValue(values);
    return appendTenantWhere(sql, addWhere: addWhere);
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

  @protected
  @override
  void prepareInsert(FieldList fields, List<String?> values) {
    if (!Tenant.inTenantBypassScope) {
      fields.add(tenantFieldName);
      values.add('${Tenant.tenantId}');
    }
  }
}
