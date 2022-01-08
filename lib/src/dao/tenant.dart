import 'package:scope/scope.dart';
import '../../simple_mysql_orm.dart';

/// SMO lightly supports the concept of a multi-tenant system.
///
/// You still need to do some work yourself !
///
/// To setup a multi-tenant system you must
/// Runs [action] with all db access scoped to only those records
/// owned by the tenant.
void withTenant({required int tenantId, required void Function() action}) {
  Scope('withTenant')
    ..value<int>(Tenant.tenantIdKey, tenantId)
    ..run(() {
      action();
    });
}

/// Allows a DaoTenant to access the db withouth passing in a tenant id.
/// Use this method with CARE.
///
/// Use this method to access DaoTenants without constraining
/// the results to a single tenant.
/// It is appropriate to use this for things like cross tenant reporting.
Future<void> withTenantByPass({required Future<void> Function() action}) async {
  await (Scope('withTenantByPass')..value<bool>(Tenant.bypassTenantKey, true))
      .run(() async {
    await action();
  });
}

// ignore: avoid_classes_with_only_static_members
class Tenant {
  /// On a multi-tenant system this key is used to
  /// inject the tenant id.
  /// Use the [withTenant] function to inject the value.
  static final ScopeKey<int> tenantIdKey = ScopeKey<int>('tenantIdKey');
  static final ScopeKey<String> tenantFieldKey =
      ScopeKey<String>('tenantFieldKey');
  static final ScopeKey<bool> bypassTenantKey =
      ScopeKey<bool>('bypassTenantKey');

  static String get tenantFieldName => Scope.use(tenantFieldKey);
  static int get tenantId => Scope.use(tenantIdKey);
  static bool get bypassTenant =>
      Scope.hasScopeKey<bool>(bypassTenantKey) && Scope.use(bypassTenantKey);

  /// true if a tentantId has been injected and we are not in bypassTenant
  /// mode.
  static bool get hasTenant =>
      Scope.hasScopeKey<int>(tenantIdKey) && !bypassTenant;

  /// Validates the multi-tenant has been configured correctly.
  /// Throws [MissingTenantException] if the tenant has been
  /// mis-configured.
  static void validate(Dao dao, String query) {
    if (dao is DaoTenant) {
      if (!bypassTenant) {
        if (!Scope.hasScopeKey<int>(tenantIdKey)) {
          /// oops. [dao] is a tenant but no tenant id has been passed.
          throw MissingTenantException(
              'The dao ${dao.getTablename()} is a tenant '
              'but no tenant was injected.');
        }

        if (Tenant.hasTenant) {
          /// This won't catch everything but should be somewhat useful.
          /// We could improve this by checking for the presense of a join
          /// or where clause with the tenantColumn.
          if (!query.contains(Tenant.tenantFieldName)) {
            throw MissingTenantException(
                "You have written a custom sql script which doesn't appear "
                'to filter by tenant.');
          }
        }
      }
    }
  }
}
