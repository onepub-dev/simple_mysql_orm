/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

typedef FieldList = List<String>;
typedef ValueList = List<Object?>;

abstract class Entity<T> {
  /// The primary key of the entity
  /// Your table MUST have an auto increment field
  /// called 'id' which is the primary key.
  late int id;

  /// Used to initialise the [id] of an entity
  /// that has yet to be persisted.
  static const notSet = -1;

  Entity(this.id);

  /// List of fields for this entity
  /// Do NOT return the identity.
  FieldList get fields;

  /// Values must be in the same order as [fields]
  /// Do NOT return the identity
  ValueList get values;
}
