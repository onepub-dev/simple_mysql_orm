/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'package:simple_mysql_orm/simple_mysql_orm.dart';

/// What unpud refers to as an uploader
class System extends Entity<System> {
  late String key;

  late String? value;

  late DateTime createdAt;

  late DateTime updatedAt;

  factory System({required String key, required String value}) =>
      System._internal(
          key: key,
          value: value,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          id: -1);

  factory System.fromRow(Row row) {
    final id = row.asInt('id');
    final key = row.asString('key');
    final value = row.tryString('value');
    final createdAt = row.asDateTime('createdAt');
    final updatedAt = row.asDateTime('updatedAt');

    return System._internal(
        id: id,
        key: key,
        value: value,
        createdAt: createdAt,
        updatedAt: updatedAt);
  }

  System._internal({
    required int id,
    required this.key,
    required this.value,
    required this.createdAt,
    required this.updatedAt,
  }) : super(id);

  @override
  FieldList get fields => [
        'key',
        'value',
        'createdAt',
        'updatedAt',
      ];

  @override
  ValueList get values => [
        key,
        value,
        createdAt,
        updatedAt,
      ];
}
