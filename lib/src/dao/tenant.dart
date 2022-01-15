import 'package:scope/scope.dart';
import '../exceptions.dart';
import '../model/entity.dart';
import 'transaction.dart';

/// SMO lightly supports the concept of a multi-tenant system.
///
/// You still need to do some work yourself !
///
/// To setup a multi-tenant system you must
/// Runs [action] with all db access scoped to only those records
/// owned by the tenant.
///
/// You need to inject your own [Transaction] into the scope.
Future<T> withTenant<T>(
    {required int tenantId, required Future<T> Function() action}) async {
  if (tenantId == Entity.notSet) {
    throw IdentityNotSetException('Invalid id ($tenantId) passed. '
        "If you don't have a tenant use 'withTenantByPass'");
  }
  return (Scope('withTenant')
        ..value<int>(Tenant.tenantIdKey, tenantId)
        ..value<bool>(Tenant._bypassTenantKey, false))
      .run(() async => action());
}

/// Allows a DaoTenant to access the db withouth passing in a tenant id.
/// Use this method with CARE.
///
/// Use this method to access DaoTenants without constraining
/// the results to a single tenant.
/// It is appropriate to use this for things like cross tenant reporting.
Future<R> withTenantByPass<R>({required Future<R> Function() action}) async =>
    await (Scope('withTenantByPass')
          ..value<bool>(Tenant._bypassTenantKey, true))
        .run(() async => action());

// ignore: avoid_classes_with_only_static_members
class Tenant {
  /// On a multi-tenant system this key is used to
  /// inject the tenant id.
  /// Use the [withTenant] function to inject the value.
  static final ScopeKey<int> tenantIdKey = ScopeKey<int>('tenantIdKey');

  ///
  static final ScopeKey<bool> _bypassTenantKey =
      ScopeKey<bool>('bypassTenantKey');

  // static String get tenantFieldName => Scope.use(tenantFieldKey);
  static int get tenantId => Scope.use(tenantIdKey);

  /// True if we are in tenant bypass mode as the user
  /// called [withTenantByPass].
  static bool get inTenantBypassScope =>
      Scope.hasScopeKey<bool>(_bypassTenantKey) &&
      use(_bypassTenantKey) == true;

  /// True if we are in tenant mode as the user called [withTenant]
  /// and we have not been bypassed.
  static bool get inTenantScope =>
      Scope.hasScopeKey<int>(tenantIdKey) && !inTenantBypassScope;
}
