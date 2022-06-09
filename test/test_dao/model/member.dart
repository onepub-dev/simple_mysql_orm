/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */


import 'package:date_time/date_time.dart';
import 'package:simple_mysql_orm/simple_mysql_orm.dart';

/// What unpud refers to as an uploader
class Member extends EntityTenant<Member> {
  factory Member({
    required String email,
  }) =>
      Member._internal(
          email: email,
          startDate: DateExtension.now(),
          enabled: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          id: -1);

  factory Member.fromRow(Row row) {
    final id = row.asInt('id');
    final email = row.asString('email');
    final startDate = row.asDate('startDate');
    final enabled = row.asBool('enabled');
    final createdAt = row.asDateTime('createdAt');
    final updatedAt = row.asDateTime('updatedAt');

    return Member._internal(
        email: email,
        startDate: startDate,
        enabled: enabled,
        createdAt: createdAt,
        updatedAt: updatedAt,
        id: id);
  }

  Member._internal({
    required int id,
    required this.email,
    required this.startDate,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  }) : super(id);

  late String email;

  late Date startDate;
  late bool enabled;

  late DateTime createdAt;
  late DateTime updatedAt;

  @override
  FieldList get fields =>
      ['email', 'startDate', 'enabled', 'createdAt', 'updatedAt'];

  @override
  ValueList get values => [email, startDate, enabled, createdAt, updatedAt];
}

typedef MemberId = int;
