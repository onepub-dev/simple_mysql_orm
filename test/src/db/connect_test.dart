/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'package:mysql_client/mysql_client.dart';
import 'package:test/test.dart';

void main() {
  test('tenant ...', () async {
    final conn = await MySQLConnection.createConnection(
        host: '127.0.0.1',
        port: 3306,
        userName: 'root',
        password: 'the cat lives here',
        databaseName: 'smo',
        secure: false);

    // actually connect to database
    await conn.connect();

    expect(true, true);
  });
}
