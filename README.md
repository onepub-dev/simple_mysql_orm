# A simple ORM for MySQL

simple_mysql_orm provides a thin wrapper for the galileo_mysql package adding
in an Object Relational Mapping (orm) layer.

Features:
  * full transaction support
  * DB connection pool
  * a really crappy builder (help wanted to make this useful)

Currently you need to manually build the bindings between each class and the
underlying table but it's a fairly simple process.

If you are intersted in getting involved I'm looking to add auto generation of the bindings based on a class and/or db schema.

Example usage. See the examples directory for the full workings.

For each table you need to create a Data Access Object (dao) which should contain all of your business rules
and an Entity which shhould just contain the fields of the entity.

Dao example:
```dart
import 'package:simple_mysql_orm/simple_mysql_orm.dart';

import '../../test_dao/model/system.dart';

class DaoSystem extends Dao<System> {
  DaoSystem() : super(tablename);
  DaoSystem.withDb(Db db) : super.withDb(db, tablename);

  static String get tablename => 'system';

  @override
  System fromRow(Row row) => System.fromRow(row);

  Future<String?> getByKey(String keyName) async =>
      (await getByField('key', keyName)).value;

  Future<String?> tryByKey(String keyName) async =>
      (await tryByField('key', keyName))?.value;
}

```

Entity Example

```dart 
import 'package:simple_mysql_orm/simple_mysql_orm.dart';

class System extends Entity<System> {
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
    final value = row.tryAsString('value');
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

  late String key;
  late String? value;

  late DateTime createdAt;
  late DateTime updatedAt;
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

```

Using your Dao and entity.
```dart
import 'package:logging/logging.dart';
import 'package:settings_yaml/settings_yaml.dart';
import 'package:simple_mysql_orm/simple_mysql_orm.dart';

import 'dao/package_dao.dart';
import 'model/package.dart';

Future<void> main() async {
  /// Configure the logger to output each sql command.
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  /// Create  settings file.
  SettingsYaml.fromString(content: settingsYaml, filePath: 'settings.yaml')
      .save();

  /// Initialise the db pool from the setings.
  DbPool.fromSettings(pathToSettings: 'settings.yaml');

  /// create a transaction and run a set of queries
  /// within the transaction.
  await withTransaction<void>(action: () async {
    final dao = PackageDao();

    /// create a package and save it.
    final package = Package(name: 'dcli', private: false);
    await dao.persist(package);

    /// update the package to public
    package.private = false;
    await dao.update(package);

    /// query the package using VERY basic and incomplete builder
    var rows = await dao.select().where().eq('name', 'dcli').run();
    for (final row in rows) {
      print('name: ${row.name} private: ${row.private}');
    }

    /// Run a custom query
    rows = await dao.query('select * from package where id = ?', [package.id]);
    for (final row in rows) {
      print('name: ${row.name} private: ${row.private}');
    }

    // delete the package
    await dao.remove(package);

    /// changed my mind
    Transaction.current.rollback();
  });
}

const settingsYaml = '''
mysql_user: root
mysql_password: my root password
mysql_host: localhost
mysql_port: 3306
mysql_db: some_db_name
''';

```


# Multi-tenancy

SMO supports the concept of a multi-tenancy database

This is a fairly light implementation and does require you to do some work to 
ensure that all of your queries are fully mulit-tenant.

## schema
Each table that is a multi-tenant table must have a tenant id.

You can choose the column name and it can be different for each table but
by convention you should use the same column name in each field.

The tenant id is usually the primary key of a table that defines the 
tenant.

This might be something like Tenant, Publisher, Company.

Example

```
Company
  int id
  String name

Staff Member
  int id
  int companyId
  String name

Team
  int id
  int companyId
  String name
```

## DaoTenant

For each table that has a tenant id you must create a DaoTenant rather than a Dao.

The DaoTenant requires you to provide the tenant field for that table

```dart

class DaoMember extends DaoTenant<Member> {
  DaoMember() : super(tableName: tablename, tenantFieldName: 'companyId');
  DaoMember.withDb(Db db)
      : super.withDb(db, tableName: tablename, tenantFieldName: 'companyId');

  /// Throws an [UnknownMemberException] if the [email]
  /// is not from one of the tenant's members.
  Future<Member> getByEmail({required String email}) async {
    final member = await trySingle(
        await query('select * from $tablename '
        'where email = ? '
        'and companyId = ?', [email, Tenant.tenantId]));
    if (member == null) {
      throw UnknownMemberException(
          'The email address $email is not for a know member');
    }
    return member;
  }
}
```

The Company table however should be derived from Dao rather than DaoTenant.

You are also likely to have some 'non-tenant' tables, for example a System table
used to hold global values such as your SMTP servers host address.

These tables should use Dao and do not need a tenant id.

## Entities

Tenant Entites are just like regular entities except that they do not expose the
tenant id field (where as a normal entity should expose all of its fields).

The tenant id should never be mentioned in a tenant entity as it is injected.


```dart
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
  FieldList get fields => [
        'email',
        'startDate',
        'enabled',
        'createdAt',
        'updatedAt'
      ];

  @override
  ValueList get values => [email, startDate, enabled, createdAt, updatedAt];
}

typedef MemberId = int;

```


## Access tenant tables

To access a tenant table you need to place all access to these tables within
a Tenant scope.

We do this via the `withTenant` method.

```dart

  /// The company is not a tenant so we can access it outside
  /// the withTenant scope.
  await DaoCompany().getByName('noojee');
  await withTenant(
          tenantId: company.id,
          action: () async {

            /// Insert a member, the tenant id will be set automatically.
            const noojeeEmail = 'sales@noojee.com.au';
            final noojeeMember =
                Member(publisherId: noojeeId, email: noojeeEmail);
            final noojeeMemberId = await daoMember.persist(noojeeMember);

    
            /// fetch a member, the tenant id will be added to the where clause
            final member = await daoMember.getByEmail(email: noojeeEmail);

            /// The System table is a non-tenant table. 
            /// We can access it within or outside a scope.
            await DaoSystem().getByKey('smtp')

          });
```          


## By pass tenant access

By default SMO will attempt to check that you always fitler your queries with a tenant id.

This method is not fool proof (see below).

There are however times when you will want to access a table that implements DaoTenant but not use
the tenant id to restrict the results.

For example a System Administrator will need access to the Staff Members of
all tenants.

You will also likely need to access a User table in both tenant and tenant by pass mode.

During the log in process you won't know the tenant util you do a query of the User table.
However in normal operation the User table should always be access as a tenant table.

For these scenarios you use `withTenantBypass`.

When using `withTenantBypass` DaoTenant will not inject the tenant id into your queries.


```dart

  Future<User?> loginUser(String username) async  {
     return  await withTenantByPass(
          action: () async {
    
            /// fetch a member, the tenant id will be added to the where clause
            return  await daoMember.tryByEmail(email: username);
          });
```          

For this to work you need to ensure that the username is unique across all of your
tenants.

You can also nest `withTenant` within a `withTenantBypass` to any level.

## tenant query validation

SMO allows you to write custom queries. When writting a custom query it is up to use
to ensure that you follow the tenant rules.

SMO attempts to validate that all queries contain the tenant field but this is a fairly crude
check (we just look for the presense of the column name). 

## writing custom queries

When writing custom queries you mostly know when you are a tenant or not as your custom code should live
in a Dao or TenantDao derived class.

For those types when you that might not be the case you can use the following:

```dart

    if (Tenant.inTenantScope)
    {
      /// called within [withTenant] call.
    }

    if (Tenant.inTenantBypassScope)
    {
      /// called within [withTenantBypass]
    }

    if (dao is DaoTenant)
    {

    }

# logging
To output each query sent to the db set logging to FINE.
To get all db interactions so logging to FINER.



# Code Generator

We now have a very crude code generator.

It can generate a model and dao class from a database table.

To use the generator

```bash
dart pub global activate simple_mysql_orm
build_dao --host <host> --port <port> --database <db> --user <user> --password <password> --table <table>
```

The above will generate files in the current directory

* <table>.dart
* dao_<table>.dart

If either file exists the build will fail.

You can exclude the generation of the dao file by passing the `--no-dao` flag.

You can control the name of the output files by passing --file <filename>.
The dao filename will be `dao_<filename>`

