/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'entity.dart';

abstract class EntityTenant<T> extends Entity<T> {
  // pass the primary key up.
  EntityTenant(super.id);
  late int tenantId;
}
