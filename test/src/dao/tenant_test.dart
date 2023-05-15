/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'package:simple_mysql_orm/simple_mysql_orm.dart';
import 'package:test/test.dart';

void main() {
  test('tenant ...', () async {
    expect(
        () =>
            withTenant(tenantId: Entity.notSet, action: () => Future.value(1)),
        throwsA(isA<IdentityNotSetException>()));

    await withTenant(
        tenantId: 1,
        action: () async {
          expect(true, true);
          return Future.value(1);
        });
  });
}
