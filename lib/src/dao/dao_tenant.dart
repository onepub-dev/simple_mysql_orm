import '../../simple_mysql_orm.dart';

abstract class DaoTenant<E> extends Dao<E> {
  DaoTenant({required String tableName, required String tenantColumnName})
      : super(tableName, tenantFieldName: tenantColumnName);

  /// Create a dao object with passed [db]
  DaoTenant.withDb(Db db,
      {required String tableName, required String tenantColumnName})
      : super.withDb(db, tableName, tenantFieldName: tenantColumnName);
}
