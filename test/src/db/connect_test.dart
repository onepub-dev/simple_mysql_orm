import 'package:mysql_client/mysql_client.dart';
import 'package:test/test.dart';

void main() {
  test('tenant ...', () async {
    final conn = await MySQLConnection.createConnection(
        host: '127.0.0.1',
        port: 3306,
        userName: 'root',
        password: 'the cat lives here',
        databaseName: 'onepub',
        secure: false);

// actually connect to database
    await conn.connect();

    print('connected');
  });
}
