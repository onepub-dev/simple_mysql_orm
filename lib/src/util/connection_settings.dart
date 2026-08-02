/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'package:mysql_client/mysql_client.dart';

class ConnectionSettings {
  String host;

  int port;

  String user;

  String password;

  String? db;

  bool useSSL;

  Duration connectionTimeout;

  Duration queryTimeout;

  ConnectionSettings(
      {required this.host,
      required this.port,
      required this.user,
      required this.password,
      this.db,
      this.useSSL = true,
      this.connectionTimeout = const Duration(seconds: 10),
      this.queryTimeout = const Duration(seconds: 30)});

  Future<MySQLConnection> createConnection() async {
    final create = MySQLConnection.createConnection(
      host: host,
      port: port,
      userName: user,
      password: password,
      databaseName: db,
      secure: useSSL,
    );
    final connection = await create;
    try {
      await connection
          .connect(timeoutMs: connectionTimeout.inMilliseconds)
          .timeout(connectionTimeout);
      return connection;
    } catch (_) {
      if (connection.connected) {
        await connection.close();
      }
      rethrow;
    }
  }
}
