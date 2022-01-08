import 'package:date_time/date_time.dart';
import 'package:simple_mysql_orm/simple_mysql_orm.dart';

/// What unpud refers to as an uploader
class Member extends Entity<Member> {
  factory Member({
    required int publisherId,
    required String email,
  }) =>
      Member._internal(
          publisherId: publisherId,
          email: email,
          startDate: DateExtension.now(),
          enabled: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          id: -1);

  factory Member.fromRow(Row row) {
    final id = row.asInt('id');
    final publisherId = row.asInt('publisherId');
    final email = row.asString('email');
    final startDate = row.asDate('startDate');
    final enabled = row.asBool('enabled');
    final createdAt = row.asDateTime('createdAt');
    final updatedAt = row.asDateTime('updatedAt');

    return Member._internal(
        publisherId: publisherId,
        email: email,
        startDate: startDate,
        enabled: enabled,
        createdAt: createdAt,
        updatedAt: updatedAt,
        id: id);
  }

  Member._internal({
    required int id,
    required this.publisherId,
    required this.email,
    required this.startDate,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  }) : super(id);

  /// The publisher that owns the package.
  /// for pub.dev packages this is the actual uploader.
  late int publisherId;

  late String email;

  late Date startDate;
  late bool enabled;

  late DateTime createdAt;
  late DateTime updatedAt;

  @override
  FieldList get fields => [
        'publisherId',
        'email',
        'startDate',
        'enabled',
        'createdAt',
        'updatedAt'
      ];

  @override
  ValueList get values =>
      [publisherId, email, startDate, enabled, createdAt, updatedAt];
}

typedef MemberId = int;
