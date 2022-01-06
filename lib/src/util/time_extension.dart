import 'package:date_time/date_time.dart';

extension TimeExtension on Time {
  static Time from(DateTime dateTime) =>
      Time(dateTime.hour, mins: dateTime.minute, secs: dateTime.second);
}
