/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */


import 'package:simple_mysql_orm/simple_mysql_orm.dart';

class Package extends Entity<Package> {
  factory Package({required String name, bool private = true}) =>
      Package._internal(
          id: Entity.notSet,
          name: name,
          latestVersion: '1.0.0',
          private: private,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          downloads: 0);

  factory Package.fromRow(Row row) {
    final id = row.asInt('id');
    final name = row.asString('name');
    final latestVersion = row.asString('latestVersion');
    final private = row.asBool('private');
    final createdAt = row.asDateTime('createdAt');
    final updatedAt = row.asDateTime('updatedAt');
    final downloads = row.asInt('downloads');

    return Package._internal(
        id: id,
        name: name,
        //  publisherId: publisherId,
        latestVersion: latestVersion,
        private: private,
        createdAt: createdAt,
        updatedAt: updatedAt,
        downloads: downloads);
  }

  Package._internal(
      {required int id,
      required this.name,
      required this.latestVersion,
      required this.private,
      required this.createdAt,
      required this.updatedAt,
      required this.downloads})
      : super(id);

  /// name of this package.
  late String name;

  /// The latest version no. for this package.
  late String latestVersion;

  /// If this package is private
  late bool private;

  // When this package was first uploaded
  late DateTime createdAt;

  /// The last time the package was updated.
  late DateTime updatedAt;

  /// total number of downloads for all versions of this package.
  late int downloads;

  @override
  FieldList get fields => [
        'name',
        'latestVersion',
        'private',
        'createdAt',
        'updatedAt',
        'downloads',
      ];

  @override
  ValueList get values =>
      [name, latestVersion, private, createdAt, updatedAt, downloads];
}
