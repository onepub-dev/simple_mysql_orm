/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'dart:convert';

import 'package:date_time/date_time.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:mysql_client/mysql_client.dart';

import '../../simple_mysql_orm.dart';
import '../builder/builder.dart';

abstract class Dao<E> {
  Db db;

  final String _tablename;

  Dao(this._tablename) : db = Transaction.current.db;

  Dao.withDb(this.db, this._tablename);

  E fromRow(Row row);

  @protected
  E callFromRow(Row row) => fromRow(row);

  Future<int> execute(String statement, [ValueList values = const []]) {
    validate(statement);
    return db.withResults(
      statement,
      values: values,
      action: (rs) => rs.affectedRowsAsInt(),
    );
  }

  Select<E> select() => Builder<E>.withDb(db, this).select();

  Delete<E> delete() => Builder<E>.withDb(db, this).delete();

  /// Custom SELECT returning entities.
  Future<List<E>> query(String query, ValueList values) {
    validate(query);
    return db.withResults(query,
        values: values, action: (rs) => Future.value(fromResults(rs)));
  }

  /// Custom SELECT returning adapted objects.
  Future<List<O>> queryWithAdaptor<O>(
    String query,
    ValueList values,
    O Function(Row row) adaptor,
  ) {
    validate(query);
    return db.withResults(query, values: values, action: (rs) {
      final rows = <O>[];
      for (final raw in rs.rows) {
        rows.add(adaptor(Row(raw)));
      }
      return rows;
    });
  }

  Future<E> querySingle(String query, ValueList values) async {
    final list = await this.query(query, values);
    final entity = await trySingle(list);
    if (entity == null) {
      throw DatabaseIntegrityException('''
Failed to retrieve a single row using 
$query, ${values.join(',')}
when it was expected to exist''');
    }
    return entity;
  }

  Future<S?> queryColumn<S>(
    String query,
    ValueList values,
    String fieldName,
    S? Function(String value) convert,
  ) {
    validate(query);
    return db.withResults(query, values: values, action: (rs) {
      if (rs.rows.isEmpty) {
        return null;
      }
      if (rs.rows.length != 1) {
        throw TooManyResultsException(
          'Multiple rows from ${query}s matched when only one was expected.',
        );
      }
      final row = Row(rs.rows.first);
      final value = row.tryValue(fieldName);
      return value == null ? null : convert(value);
    });
  }

  Future<List<E>> getListByField(
    String fieldName,
    String fieldValue, {
    bool like = false,
    int offset = 0,
    int limit = 20,
    String? orderBy,
    SortDirection sortDirection = SortDirection.asc,
  }) {
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
      throw DatabaseIntegrityException(
        '''Failed to retrieve $fieldName=$fieldValue from $_tablename when it was expected to exist''',
      );
    }
    return entity;
  }

  Future<E?> tryByField(String fieldName, String fieldValue,
          {bool like = false}) async =>
      trySingle(await getListByField(fieldName, fieldValue, like: like));

  Future<E?> trySingle(List<E> rows) async {
    if (rows.isEmpty) {
      return null;
    }
    if (rows.length != 1) {
      throw TooManyResultsException(
        'Multiple rows from ${_tablename}s matched when only one was expected.',
      );
    }
    return rows.first;
  }

  Future<List<E>> getRowsByFieldInt(String fieldName, int fieldValue) =>
      getListByField(fieldName, '$fieldValue');

  Future<E?> getByFieldInt(String fieldName, int fieldValue) =>
      tryByField(fieldName, '$fieldValue');

  Future<E?> getByFieldDate(String fieldName, DateTime fieldValue) {
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

  Future<List<E>> getAll() {
    var sql = 'select * from $_tablename';
    final values = <String>[];
    sql = appendTenantClause(sql, values);
    return query(sql, values);
  }

  List<E> fromResults(IResultSet results) {
    final rows = <E>[];
    for (final row in results.rows) {
      rows.add(callFromRow(Row(row)));
    }
    return rows;
  }

  Iterable<E> fromRows(List<Row> rows) => rows.map(callFromRow);

  Future<int> persist(Entity<E> entity) {
    final fields = entity.fields;
    final values = convertToDb(entity.values);
    prepareInsert(fields, values);

    final placeholders = '${'?, ' * (fields.length - 1)}?';
    final sql = 'insert into $_tablename '
        '(`${fields.join("`,`")}`) values ($placeholders)';

    return db.withResults(sql,
        values: values, action: (rs) => rs.lastInsertID.toInt());
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

    await db.withResults(sql, values: values, action: (_) {});
  }

  Future<void> remove(Entity<E> entity) async {
    var sql = 'delete from $_tablename where id = ?';
    final values = <String>['${entity.id}'];
    sql = appendTenantClause(sql, values);
    await db.withResults(sql, values: values, action: (_) {});
  }

  Future<void> removeAll() async {
    var sql = 'delete from $_tablename ';
    final values = <String>[];
    sql = appendTenantClause(sql, values, addWhere: true);
    await db.withResults(sql, values: values, action: (_) {});
  }

  Future<void> removeById(int id) async {
    var sql = 'delete from $_tablename where id = ?';
    final values = <String>['$id'];
    sql = appendTenantClause(sql, values);
    await db.withResults(sql, values: values, action: (_) {});
  }

  String getTablename() => _tablename;

  List<String?> convertToDb(ValueList values) {
    final convertedValues = <String?>[];
    for (final value in values) {
      if (value == null) {
        convertedValues.add(null);
      } else if (value is DateTime) {
        convertedValues.add(DateFormat('yyyy-MM-dd HH:mm:ss').format(value));
      } else if (value is Date) {
        convertedValues.add(DateFormat('yyyy-MM-dd').format(value.asDateTime));
      } else if (value is Time) {
        convertedValues.add(value.format());
      } else if (value is bool) {
        convertedValues.add(value ? '1' : '0');
      } else if (value is Map) {
        convertedValues.add(jsonEncode(value));
      } else {
        convertedValues.add(value.toString());
      }
    }
    return convertedValues;
  }

  void validate(String query) {
    // no op (DaoTenant overrides)
  }

  String appendTenantClause(String sql, List<String?> values,
          {bool addWhere = false}) =>
      sql;

  void injectTenant(FieldList fields, List<String?> values) {}

  void prepareInsert(FieldList fields, List<String?> values) {}
}

enum SortDirection { asc, desc }

extension _IResultSetAffectedRows on IResultSet {
  int affectedRowsAsInt() {
    final ar = affectedRows;
    return ar.toInt();
  }
}
