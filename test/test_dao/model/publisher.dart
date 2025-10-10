/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'package:simple_mysql_orm/simple_mysql_orm.dart';

/// What unpud refers to as an uploader
class Publisher extends Entity<Publisher> {
  /// for private packages this is the user
  /// for pub.dev packages this is the actual publisher.
  late String name;

  late String contactEmail;

  late DateTime createdAt;

  late DateTime updatedAt;

  factory Publisher({required String name, required String contactEmail}) =>
      Publisher._internal(
          name: name,
          contactEmail: contactEmail,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          id: -1);

  factory Publisher.fromRow(Row row) {
    final id = row.asInt('id');
    final name = row.asString('name');
    final contactEmail = row.asString('contactEmail');
    final createdAt = row.asDateTime('createdAt');
    final updatedAt = row.asDateTime('updatedAt');

    return Publisher._internal(
      name: name,
      contactEmail: contactEmail,
      createdAt: createdAt,
      updatedAt: updatedAt,
      id: id,
    );
  }

  Publisher._internal({
    required int id,
    required this.name,
    required this.contactEmail,
    required this.createdAt,
    required this.updatedAt,
  }) : super(id);

  @override
  FieldList get fields => [
        'name',
        'contactEmail',
        'createdAt',
        'updatedAt',
      ];

  @override
  ValueList get values => [
        name,
        contactEmail,
        createdAt,
        updatedAt,
      ];
}
