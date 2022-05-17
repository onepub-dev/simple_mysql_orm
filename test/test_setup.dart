import 'package:dcli/dcli.dart';
import 'package:logging/logging.dart';
import 'package:simple_mysql_orm/simple_mysql_orm.dart';
import 'package:test/test.dart';

import 'src/dao/dao_member.dart';
import 'src/dao/dao_publisher.dart';
import 'test_dao/model/member.dart';
import 'test_dao/model/publisher.dart';

bool setup = false;
Future<void> testSetup() async {
  if (!setup) {
    setup = true;
    initLogger();
    DbPool.fromSettings(
        pathToSettings:
            join(DartProject.self.pathToProjectRoot, 'test', 'settings.yaml'));
  }

  await _cleanUpDb();
}

Future<void> _cleanUpDb() async {
  await withTenantByPass(action: () async {
    await withTransaction(
        action: () async {
          /// if the db doesn't exist then run
          /// dmysql restore smo schema createv2.sql
          expect(await existsDatabase('smo'), true);

          /// we need to remove references to members to overcome
          /// foreign key constraints.
          final daoPublisher = DaoPublisher();
          for (final publisher in await daoPublisher.getAll()) {
            await daoPublisher.update(publisher);
          }

          /// members
          for (final member in await DaoMember().getAll()) {
            await DaoMember().remove(member);
          }
          for (final publisher in await daoPublisher.getAll()) {
            await daoPublisher.remove(publisher);
          }
        },
        debugName: 'test - cleanupDb');
  });
}

Future<Member> getTestMember({required int publisherId}) async {
  final daoMember = DaoMember();
  var member = await daoMember.tryByEmail(email: testMemberEmail);
  if (member == null) {
    final memberId = await daoMember.persist(createMember(testMemberEmail));
    member = await daoMember.getById(memberId);
  }
  return member;
}

Future<Publisher> getTestPublisher() async {
  final daoPublisher = DaoPublisher();
  var publisher = await daoPublisher.tryByName(name: testPublisherName);

  if (publisher == null) {
    final publisherId =
        await daoPublisher.persist(createPublisher(testPublisherName));
    publisher = await daoPublisher.getById(publisherId);
  }
  return publisher;
}

const testTransientMemberEmail = 'transient@noojee.com.au';
const testMemberEmail = 'member@noojee.com.au';
const testPublisherName = 'noojee.com.au';
const testTeamName = 'The cool team';

bool loggerInitialised = false;
void initLogger() {
  if (loggerInitialised == false) {
    loggerInitialised = true;
    recordStackTraceAtLevel = Level.SEVERE;
    Logger.root.level = Level.INFO; // defaults to Level.INFO
    Logger.root.onRecord.listen((record) {
      print('${record.level.name}: ${record.time}:'
          ' ${record.message} : ${record.error}');
      if (record.stackTrace != null) {
        print(record.stackTrace);
      }
    });
  }
}

Publisher createPublisher(String name) {
  final publisher = Publisher(
    name: name,
    contactEmail: 'member@noojee.com.au',
  );
  return publisher;
}

Member createMember(String email) {
  final member = Member(email: email);

  return member;
}
