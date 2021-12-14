library builder;

import '../dao/db.dart';
import '../dao/dao.dart';

part 'select.dart';
part 'delete.dart';

class Builder<E> {
  Builder.withDb(this.db, this.dao);
  Db db;
  Dao<E> dao;
  Select<E> select() => _select = Select<E>(this);

  Delete<E> delete() => _delete = Delete<E>(this);

  Select<E>? _select;
  Delete<E>? _delete;
  Where<E>? _where;
  final _whereExpressions = <WhereExpression>[];
  OrderBy? _orderBy;
}

class Where<E> {
  Where(this._builder);
  final Builder<E> _builder;

  WhereExpression<E> like(String field, String match) {
    final exp = LikeExpression<E>(_builder, field, match);
    _builder._whereExpressions.add(exp);
    return exp;
  }
}

class LikeExpression<E> extends WhereExpression<E> {
  LikeExpression(Builder<E> builder, this._field, this._match) : super(builder);

  final String _field;
  final String _match;

  @override
  List<Object> get _values => [_match];

  @override
  String toString() => '$_field like ?';
}

abstract class WhereExpression<E> extends Query<E> {
  WhereExpression(Builder<E> builder) : super(builder);

  List<Object> get _values;

  OrderBy<E> orderBy(String field, {bool asc = true}) =>
      builder._orderBy = OrderBy<E>(builder, field, asc: asc);
}

class OrderBy<E> extends Query<E> {
  OrderBy(Builder<E> builder, this._field, {bool asc = true})
      : _asc = asc,
        super(builder);
  final String _field;
  final bool _asc;
}

class Query<E> {
  Query(this.builder);
  Builder<E> builder;

  Future<List<E>> query() async {
    if (builder._select != null) {
      return builder._select!._query();
    } else if (builder._delete != null) {
      return builder._delete!._query();
    }
    throw StateError('We are missing a query type');
  }
}
