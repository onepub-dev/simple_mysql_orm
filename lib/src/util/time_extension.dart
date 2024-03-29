/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'package:date_time/date_time.dart';

extension TimeExtension on Time {
  static Time from(DateTime dateTime) => Time(
      hour: dateTime.hour, minute: dateTime.minute, second: dateTime.second);
}
