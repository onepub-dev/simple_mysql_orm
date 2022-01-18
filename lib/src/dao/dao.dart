// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';

import 'package:date_time/date_time.dart';
import 'package:galileo_mysql/galileo_mysql.dart' hide MySqlConnection;
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

import '../../simple_mysql_orm.dart';
import '../builder/builder.dart';

abstract class Dao<E> {
  /// Create a dao object taking the Database from
  /// the in scope [Transaction]
  Dao(this._tablename) : db = Transaction.current.db;

  /// Create a dao object with passed [db]
  Dao.withDb(this.db, this._tablename);

  Db db;
  final String _tablename;

  E fromRow(Row row);

  @protected

  /// Used by DaoTenant to inject the tenant id
  E callFromRow(Row row) => fromRow(row);

  Select<E> select() => Builder<E>.withDb(db, this).select();
  Delete<E> delete() => Builder<E>.withDb(db, this).delete();

  /// Allows you to write a custom query against the db.
  ///
  /// If you are using multi-tenanting then you MUST be certain
  /// to filter by the tenant id as we are unable to inject the
  /// tenant id.
  Future<List<E>> query(String query, ValueList values) async {
    validate(query);

    final results = await db.query(query, values);

    return fromResults(results);
  }

  Future<E> querySingle(String query, ValueList values) async {
    final entity = await trySingle(await this.query(query, values));
    if (entity == null) {
      throw DatabaseIntegrityException('''
Failed to retrieve a single row using 
$query, ${values.join(',')}
when it was expected to exist''');
    }
    return entity;
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
  Future<S?> queryColumn<S>(String query, ValueList values, String fieldName,
      S? Function(String value) convert) async {
    validate(query);

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

  /// Perform a query with a where clause [fieldName] = [fieldValue]
  /// unles the [like] is true in which case we perform
  /// [fieldName] like [fieldValue].
  ///
  /// You can do pagination by passing [offset] and [limit].
  ///
  /// Sort the results by passing [orderBy] and [sortDirection]
  Future<List<E>> getListByField(String fieldName, String fieldValue,
      {bool like = false,
      int offset = 0,
      int limit = 20,
      String? orderBy,
      SortDirection sortDirection = SortDirection.asc}) async {
    var sql = 'select * from $_tablename ';
    if (like) {
      sql += 'where `$fieldName` like ? ';
    } else {
      sql += 'where `$fieldName` = ? ';
    }

    if (orderBy != null) {
      sql += 'order by $orderBy ${sortDirection.name} ';
    }

    sql += 'limit $offset, $limit ';

    return query(sql, [fieldValue]);
  }

  Future<E> getByField(String fieldName, String fieldValue,
      {bool like = false}) async {
    final entity = await trySingle(
        await getListByField(fieldName, fieldValue, like: like));
    if (entity == null) {
      throw DatabaseIntegrityException('Failed to retrieve '
          '$fieldName=$fieldValue from '
          '$_tablename when it was expected to exist');
    }
    return entity;
  }

  Future<E?> tryByField(String fieldName, String fieldValue,
          {bool like = false}) async =>
      trySingle(await getListByField(fieldName, fieldValue, like: like));

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
      tryByField(fieldName, '$fieldValue');

  Future<E?> getByFieldDate(String fieldName, DateTime fieldValue) async {
    final formatter = DateFormat('yyyy-MM-dd');
    final formatted = formatter.format(fieldValue);

    return tryByField(fieldName, formatted);
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
    final values = ['$id'];
    sql = appendTenantClause(sql, values);
    return trySingle(await query(sql, values));
  }

  Future<List<E>> getAll() async {
    var sql = 'select * from $_tablename';
    final values = <String>[];
    sql = appendTenantClause(sql, values);
    return query(sql, values);
  }

  List<E> fromResults(Results results) {
    final rows = <E>[];
    for (final results in results) {
      rows.add(callFromRow(Row(results.fields)));
    }
    return rows;
  }

  Iterable<E> fromRows(List<Row> rows) => rows.map(callFromRow);

  Future<int> persist(Entity<E> entity) async {
    final fields = entity.fields;
    final values = convertToDb(entity.values);

    prepareInsert(fields, values);

    final placeHolders = '${'?, ' * (fields.length - 1)}?';

    final sql = 'insert into $_tablename '
        '(`${fields.join("`,`")}`) values ($placeHolders)';

    final result = await db.query(sql, values);

    return result.insertId!;
  }

  Future<void> update(Entity<E> entity) async {
    if (entity.id == Entity.notSet) {
      throw IdentityNotSetException('id not set on $_tablename during update. '
          'Did you forget to retrieve the new entity after calling persist?');
    }
    final fields = entity.fields;
    final values = convertToDb(entity.values);

    var sql = 'update $_tablename '
        'set `${fields.join("`=?, `")}`=? '
        'where id=?';

    values.add('${entity.id}');

    sql = appendTenantClause(sql, values);

    await query(sql, values);
  }

  Future<void> remove(Entity<E> entity) async {
    var sql = 'delete from $_tablename where id = ?';

    final values = <String>['${entity.id}'];
    sql = appendTenantClause(sql, values);

    await query(sql, values);
  }

  Future<void> removeAll() async {
    var sql = 'delete from $_tablename ';

    final values = <String>[];

    sql = appendTenantClause(sql, values, addWhere: true);

    await query(sql, values);
  }

  Future<void> removeById(int id) async {
    var sql = 'delete from $_tablename where id = ?';

    final values = <String>['$id'];

    sql = appendTenantClause(sql, values);

    await query(sql, values);
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
      } else if (value is Date) {
        convertedValues.add(DateFormat('yyyy-MM-dd').format(value.asDateTime));
      } else if (value is Time) {
        convertedValues.add(value.format());
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

  /// If this Dao is a [DaoTenant] then the [DaoTenant.validate]
  /// method will be called to check that multi-tenancy is being
  /// enforced in the query.
  void validate(String query) {
    // no op
  }

  /// Is overriden by [DaoTenant] if this Dao is
  /// a [DaoTenant]
  String appendTenantClause(String sql, List<String?> values,
          {bool addWhere = false}) =>
      sql;

  /// Overrride point for [DaoTenant]
  void injectTenant(FieldList fields, List<String?> values) {}

  /// override point for [DaoTenant]
  void prepareInsert(FieldList fields, List<String?> values) {}
}

enum SortDirection { asc, desc }
