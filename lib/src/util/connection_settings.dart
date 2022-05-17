import 'package:mysql_client/mysql_client.dart';

class ConnectionSettings {
  ConnectionSettings(
      {required this.host,
      required this.port,
      required this.user,
      required this.password,
      this.db,
      this.useSSL = true});
  String host;

  int port;

  String user;

  String password;

  String? db;

  bool useSSL;
  Future<MySQLConnection> createConnection() async {
    final connection = await MySQLConnection.createConnection(
        host: host,
        port: port,
        userName: user,
        password: password,
        databaseName: db,
        secure: useSSL);

    await connection.connect();
    return connection;
  }
}
