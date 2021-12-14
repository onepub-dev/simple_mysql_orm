typedef FieldList = List<String>;
typedef ValueList = List<Object?>;

abstract class Entity<T> {
  Entity(this.id);

  /// The primary key of the entity
  /// Your table MUST have an auto increment field
  /// called 'id' which is the primary key.
  late int id;

  /// List of fields for this entity
  /// Do NOT return the identity.
  FieldList get fields;

  /// Values must be in the same order as [fields]
  /// Do NOT return the identity
  ValueList get values;
}
