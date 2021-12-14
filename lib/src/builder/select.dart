part of builder;

class Select<E> {
  Select(this._builder);
  final Builder<E> _builder;

  Where<E> where() => _builder._where = Where<E>(_builder);

  Future<List<E>> _query() async {
    final dao = _builder.dao;
    final table = dao.getTablename();

    final values = <Object>[];
    final sql = StringBuffer()..write('select * from $table ');

    if (_builder._where != null) {
      sql.write('where ');
    }

    for (final exp in _builder._whereExpressions) {
      values.addAll(exp._values);
      sql.write('$exp ');
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
