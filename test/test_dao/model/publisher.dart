import 'package:simple_mysql_orm/simple_mysql_orm.dart';

/// What unpud refers to as an uploader
class Publisher extends Entity<Publisher> {
  factory Publisher({required String name, required String email}) =>
      Publisher._internal(name: name, email: email, id: -1);

  factory Publisher.fromRow(Row row) {
    final id = row.asInt('id');
    final name = row.asString('name');
    final email = row.asString('email');

    return Publisher._internal(name: name, email: email, id: id);
  }

  Publisher._internal({
    required int id,
    required this.name,
    required this.email,
  }) : super(id);

  /// for private packages this is the user
  /// for pub.dev packages this is the actual publisher.
  late String name;

  late String email;

  @override
  FieldList get fields => ['name', 'email'];

  @override
  ValueList get values => [name, email];
}
