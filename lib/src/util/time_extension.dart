import 'package:date_time/date_time.dart';

extension TimeExtension on Time {
  static Time from(DateTime dateTime) => Time(
      hour: dateTime.hour, minute: dateTime.minute, second: dateTime.second);
}
