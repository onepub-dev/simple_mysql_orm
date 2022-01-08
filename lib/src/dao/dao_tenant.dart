import '../../simple_mysql_orm.dart';

abstract class DaoTenant<E> extends Dao<E> {
  DaoTenant({required String tableName, required String tenantFieldName})
      : super(tableName, tenantFieldName: tenantFieldName);

  /// Create a dao object with passed [db]
  DaoTenant.withDb(Db db,
      {required String tableName, required String tenantFieldName})
      : super.withDb(db, tableName, tenantFieldName: tenantFieldName);
}
