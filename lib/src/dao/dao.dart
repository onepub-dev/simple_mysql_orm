import 'dart:convert';

import 'package:galileo_mysql/galileo_mysql.dart' hide MySqlConnection;
import 'package:intl/intl.dart';

import '../builder/builder.dart';
import '../exceptions.dart';
import '../model/entity.dart';
import 'db.dart';
import 'row.dart';
import 'tenant.dart';
import 'transaction.dart';

abstract class Dao<E> {
  /// Create a dao object taking the Database from
  /// the in scope [Transaction]
  Dao(this._tablename, {this.tenantFieldName}) : db = Transaction.current.db;

  /// Create a dao object with passed [db]
  Dao.withDb(this.db, this._tablename, {this.tenantFieldName});

  Db db;
  final String _tablename;

  bool get _hasTenant => Tenant.hasTenant;
  String? tenantFieldName;
  int get _tenantId => Tenant.tenantId;

  E fromRow(Row row);

  Select<E> select() => Builder<E>.withDb(db, this).select();
  Delete<E> delete() => Builder<E>.withDb(db, this).delete();

  /// Allows you to write a custom query against the db.
  ///
  /// If you are using multi-tenanting then you MUST be certain
  /// to filter by the tenant id as we are unable to inject the
  /// tenant id.
  Future<List<E>> query(String query, ValueList values) async {
    Tenant.validate(this, query);

    final results = await db.query(query, values);

    return fromResults(results);
  }

  /// use this to execute a query that returns a single row with
  /// a single column
  /// Its useful for 'sum' type queries.
  /// The [fieldName] to extract from the query.
  /// [values] to pass to the query
  /// [convert] a function to convert the return value (as a string)
  /// to [S].
  ///
  /// If you are using multi-tenanting then you MUST be certain
  /// to filter by the tenant id as we are unable to inject the
  /// tenant id.
  Future<S?> querySingle<S>(String query, ValueList values, String fieldName,
      S? Function(String value) convert) async {
    Tenant.validate(this, query);

    final results = await db.query(query, values);
    if (results.isEmpty) {
      return null;
    }

    if (results.length != 1) {
      throw TooManyResultsException('Multiple rows from ${query}s matched '
          'when only one was expected.');
    }

    final row = results.first;

    final value = convert(row.fields[fieldName] as String);
    return value;
  }

  String appendTenantClause(String sql) {
    var _sql = sql;
    if (Tenant.hasTenant) {
      _sql += ' and `$_tablename.$tenantFieldName`=?';
    }
    return _sql;
  }

  Future<List<E>> getListByField(String fieldName, String fieldValue) async {
    final sql = 'select * from $_tablename where `$fieldName` = ?';

    return query(sql, [fieldValue]);
  }

  Future<E?> getByField(String fieldName, String fieldValue) async =>
      trySingle(await getListByField(fieldName, fieldValue));

  /// Expects [rows] to have zero or one elements.
  /// Throws [TooManyResultsException] if more than one row exists.
  /// Returns null if no rows exist.
  Future<E?> trySingle(List<E> rows) async {
    if (rows.isEmpty) {
      return null;
    }
    if (rows.length != 1) {
      throw TooManyResultsException('Multiple rows from ${_tablename}s matched '
          'when only one was expected.');
    }
    return rows.first;
  }

  Future<List<E>> getRowsByFieldInt(String fieldName, int fieldValue) async =>
      getListByField(fieldName, '$fieldValue');

  Future<E?> getByFieldInt(String fieldName, int fieldValue) async =>
      getByField(fieldName, '$fieldValue');

  Future<E?> getByFieldDate(String fieldName, DateTime fieldValue) async {
    final formatter = DateFormat('yyyy-MM-dd');
    final formatted = formatter.format(fieldValue);

    return getByField(fieldName, formatted);
  }

  Future<E> getById(int id) async {
    final e = await tryById(id);
    if (e == null) {
      throw UnknownEntityIdException('Id $id not found in $_tablename');
    }
    return e;
  }

  Future<E?> tryById(int id) async {
    var sql = 'select * from $_tablename where id = ?';
    sql = appendTenantClause(sql);
    return trySingle(await query(sql, [id]));
  }

  Future<List<E>> getAll() async {
    var sql = 'select * from $_tablename';
    sql = appendTenantClause(sql);
    return query(sql, []);
  }

  List<E> fromResults(Results results) {
    final rows = <E>[];
    for (final results in results) {
      rows.add(fromRow(Row(results.fields)));
    }
    return rows;
  }

  Iterable<E> fromRows(List<Row> rows) => rows.map(fromRow);

  Future<int> persist(Entity<E> entity) async {
    final fields = entity.fields;
    final values = convertToDb(entity.values);

    if (Tenant.hasTenant) {
      fields.add(Tenant.tenantFieldName);
      values.add('$_tenantId');
    }

    final placeHolders = '${'?, ' * (fields.length - 1)}?';

    final sql = 'insert into $_tablename '
        '(`${fields.join("`,`")}`) values ($placeHolders)';

    final result = await db.query(sql, values);

    return result.insertId!;
  }

  Future<void> update(Entity<E> entity) async {
    final fields = entity.fields;
    final values = convertToDb(entity.values);

    var sql = 'update $_tablename '
        'set `${fields.join("`=?, `")}`=? '
        'where id=?';

    sql = appendTenantClause(sql);

    await query(sql, [
      ...values,
      entity.id,
      if (_hasTenant) _tenantId,
    ]);
  }

  Future<void> remove(Entity<E> entity) async {
    var sql = 'delete from $_tablename where id = ?';

    sql = appendTenantClause(sql);

    await query(sql, [
      entity.id,
      if (_hasTenant) _tenantId,
    ]);
  }

  Future<void> deleteById(int id) async {
    var sql = 'delete from $_tablename where id = ?';

    sql = appendTenantClause(sql);

    await query(sql, [
      id,
      if (_hasTenant) _tenantId,
    ]);
  }

  String getTablename() => _tablename;

  /// converts each value to a format suitable to
  /// write to mysql.
  List<String?> convertToDb(ValueList values) {
    final convertedValues = <String?>[];
    for (final value in values) {
      if (value == null) {
        convertedValues.add(null);
      }
      // datetime
      else if (value is DateTime) {
        convertedValues.add(DateFormat('yyyy-MM-dd HH:mm:ss').format(value));
      }
      // bool
      else if (value is bool) {
        final v = value;
        convertedValues.add(v ? '1' : '0');
      }
      // map
      else if (value is Map) {
        convertedValues.add(jsonEncode(value));
      }
      // anything else we convert to a string.
      else {
        convertedValues.add(value.toString());
      }
    }
    return convertedValues;
  }
}
