/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */


part of builder;

class Delete<E> {
  Delete(this._builder);
  final Builder<E> _builder;

  Where<E> where() => _builder._where = Where<E>(_builder);

  Future<List<E>> _query() async {
    final dao = _builder.dao;
    final table = dao.getTablename();

    final values = <Object>[];
    final sql = StringBuffer()..write('delete from $table ');

    if (_builder._where != null) {
      sql.write('where ');

      for (final exp in _builder._whereExpressions) {
        values.addAll(exp._values);
        sql.write('$exp ');
      }

      if (dao is DaoTenant && !Tenant.inTenantBypassScope) {
        sql.write('and `${dao.getTablename()}`. '
            '`${(dao as DaoTenant).tenantFieldName}` = ? ');
        values.add(Tenant.tenantId);
      }
    }

    if (_builder._orderBy != null) {
      final orderBy = _builder._orderBy!;
      final field = orderBy._field;
      var asc = 'asc';
      if (orderBy._asc == false) {
        asc = 'desc';
      }
      sql.write('order by $field $asc ');
    }
    print('sql $sql');
    print('values: $values');
    return dao.query(sql.toString(), values);
  }
}
