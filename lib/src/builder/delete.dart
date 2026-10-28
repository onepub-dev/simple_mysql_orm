/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

part of 'builder.dart';

class Delete<E> {
  final Builder<E> _builder;

  Delete(this._builder);

  Where<E> where() => Where<E>(_builder);

  Future<List<E>> _query() {
    final dao = _builder.dao;
    final table = sqlIdentifier(dao.getTablename(), qualified: true);

    final values = <Object>[];
    final sql = StringBuffer()..write('delete from $table ');

    _builder.writeWhere(sql, values);

    if (_builder._orderBy != null) {
      final orderBy = _builder._orderBy!;
      final field = orderBy._field;
      var asc = 'asc';
      if (!orderBy._asc) {
        asc = 'desc';
      }
      sql.write('order by ${sqlOrderBy(field)} $asc ');
    }
    // print('sql $sql');
    // print('values: $values');
    return dao.query(sql.toString(), values);
  }
}
