import 'entity.dart';

abstract class EntityTenant<T> extends Entity<T> {
  // pass the primary key up.
  EntityTenant(int id) : super(id);
  late int tenantId;
}
