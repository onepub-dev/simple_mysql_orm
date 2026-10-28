/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'package:meta/meta.dart';

import '../../simple_mysql_orm.dart';
import '../util/sql_identifier.dart';

abstract class DaoTenant<E extends EntityTenant<E>> extends Dao<E> {
  String tenantFieldName;

  DaoTenant(super._tablename, {required this.tenantFieldName});

  /// Create a dao object with passed [db]
  DaoTenant.withDb(super.db, super._tablename, {required this.tenantFieldName})
      : super.withDb();

  /// Adds a tenant predicate to a simple SELECT from this DAO's table.
  ///
  /// Other query shapes must use [query] with an explicit tenant predicate.
  Future<List<E>> queryTenant(String query, ValueList values) {
    _requireTenantScope();
    if (Tenant.inTenantBypassScope) {
      return this.query(query, values);
    }
    final table = getTablename();
    final pattern = RegExp(
        '^select\\s+\\*\\s+from\\s+`?${RegExp.escape(table)}`?\\s+where\\s+([\\s\\S]+)\$',
        caseSensitive: false);
    final match = pattern.firstMatch(query.trim());
    final predicate = match?.group(1)?.trim();
    if (predicate == null ||
        predicate.isEmpty ||
        predicate.contains(';') ||
        predicate.contains('(') ||
        predicate.contains(')') ||
        predicate.contains('--') ||
        predicate.contains('/*') ||
        predicate.contains('#') ||
        RegExp(r'\b(select|union|join|group|order|having|limit|offset|window|over|for|lock)\b',
                caseSensitive: false)
            .hasMatch(predicate)) {
      throw ArgumentError('queryTenant requires SELECT * FROM the DAO table '
          'WHERE a simple predicate without trailing clauses.');
    }
    final tenantColumn = sqlIdentifier(tenantFieldName);
    return this.query(
        'select * from ${sqlIdentifier(table)} '
        'where ($predicate) and $tenantColumn = ?',
        [...values, Tenant.tenantId]);
  }

  @override
  Future<List<E>> getListByField(String fieldName, String fieldValue,
      {bool like = false,
      int offset = 0,
      int limit = 20,
      String? orderBy,
      SortDirection sortDirection = SortDirection.asc}) {
    var sql =
        'select * from ${sqlIdentifier(getTablename(), qualified: true)} ';

    final values = [fieldValue];
    final column = sqlIdentifier(fieldName);

    if (like) {
      sql += 'where $column like ? ';
    } else {
      sql += 'where $column = ? ';
    }

    sql = appendTenantWhere(sql);
    appendTenantValue(values);

    if (orderBy != null) {
      sql += 'order by ${sqlOrderBy(orderBy)} ${sortDirection.name} ';
    }

    sql += 'limit $offset, $limit ';

    return query(sql, values);
  }

  String appendTenantWhere(String sql, {bool addWhere = false}) {
    _requireTenantScope();
    if (Tenant.inTenantScope) {
      if (addWhere) {
        sql += ' where ';
      } else {
        sql += ' and ';
      }

      final table = sqlIdentifier(getTablename(), qualified: true);
      final column = sqlIdentifier(tenantFieldName);
      sql += '$table.$column= ? ';
    }
    return sql;
  }

  @override
  String appendTenantClause(String sql, List<String?> values,
      {bool addWhere = false}) {
    appendTenantValue(values);
    return appendTenantWhere(sql, addWhere: addWhere);
  }

  ValueList appendTenantValue(List<Object?> values) {
    _requireTenantScope();
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
    _requireTenantScope();
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
    _requireTenantScope();
    if (!Tenant.inTenantBypassScope) {
      fields.add(tenantFieldName);
      values.add('${Tenant.tenantId}');
    }
  }

  void _requireTenantScope() {
    if (!Tenant.inTenantScope && !Tenant.inTenantBypassScope) {
      throw MissingTenantException(
          'A tenant DAO requires withTenant or withTenantByPass.');
    }
  }
}
