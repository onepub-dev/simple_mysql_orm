import 'package:galileo_mysql/galileo_mysql.dart' hide MySqlConnection;
import 'package:intl/intl.dart';
import 'db.dart';
import '../model/entity.dart';
import '../builder/builder.dart';
import 'row.dart';

abstract class Dao<E> {
  Dao(this.db, this._tablename);

  Db db;
  final String _tablename;

  E fromRow(Row row);

  Select<E> select() => Builder<E>.withDb(db, this).select();
  Delete<E> delete() => Builder<E>.withDb(db, this).delete();

  Future<List<E>> query(String query, ValueList values) async {
    final results = await db.query(query, values);

    return fromResults(results);
  }

  Future<List<E>> getListByField(String fieldName, String fieldValue) async =>
      query('select * from $_tablename where $fieldName = ?', [fieldValue]);

  Future<E?> getByField(String fieldName, String fieldValue) async {
    final rows = await getListByField(fieldName, fieldValue);

    if (rows.isEmpty) {
      return null;
    }
    if (rows.length != 1) {
      throw TooManyResultsException(
          'Multiple $_tablename named $fieldName found');
    }
    return rows.first;
  }

  Future<List<E>> getRowsByFieldInt(String fieldName, int fieldValue) async =>
      getListByField(fieldName, '$fieldValue');

  Future<E?> getByFieldInt(String fieldName, int fieldValue) async =>
      getByField(fieldName, '$fieldValue');

  Future<E?> getByFieldDate(String fieldName, DateTime fieldValue) async =>
      getByField(fieldName, '$fieldValue');

  Future<E> getByIdExpected(int id) async {
    final e = await getById(id);
    if (e == null) {
      throw IntegrityException('Id $id not found in $_tablename');
    }
    return e;
  }

  Future<E?> getById(int id) async {
    final rows = await query('select * from $_tablename where id = ?', [id]);

    // ignore: always_put_control_body_on_new_line
    if (rows.isEmpty) return null;

    if (rows.length != 1) {
      throw TooManyResultsException('Multiple $_tablename with id=$id found.');
    }
    return rows.first;
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

    final placeHolders = '${'?, ' * (fields.length - 1)}?';

    final sql = 'insert into $_tablename '
        '(`${fields.join("`,`")}`) values ($placeHolders)';

    final result = await db.query(sql, values);

    return result.insertId!;
  }

  Future<void> update(Entity<E> entity) async {
    final fields = entity.fields;
    final values = entity.values;

    final sql = 'update $_tablename '
        'set `${fields.join("`=?, `")}`=? '
        'where id=?';

    await db.query(sql, [...values, entity.id]);
  }

  Future<void> deleteByEntity(Entity<E> entity) async {
    final sql = 'delete from $_tablename where id = ?';

    await db.query(sql, [entity.id]);
  }

  Future<void> deleteById(int id) async {
    final sql = 'delete from $_tablename where id = ?';

    await db.query(sql, [id]);
  }

  String getTablename() => _tablename;

  /// converts each value to a format suitable to
  /// write to mysql.
  List<String> convertToDb(ValueList values) {
    List<String> convertedValues = <String>[];
    for (final value in values) {
      if (value.runtimeType == DateTime) {
        convertedValues
            .add(DateFormat('yyyy-MM-dd hh:mm:ss').format(value as DateTime));
      } else if (value.runtimeType == bool) {
        final v = value as bool;
        convertedValues.add(v ? '1' : '0');
      } else {
        convertedValues.add(value.toString());
      }
    }
    return convertedValues;
  }
}

class TooManyResultsException implements Exception {
  TooManyResultsException(this.message);
  String message;
}

class IntegrityException implements Exception {
  IntegrityException(this.message);
  String message;
}
