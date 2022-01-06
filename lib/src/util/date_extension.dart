import 'package:date_time/date_time.dart';
import 'package:intl/intl.dart';

extension DateExtension on Date {
  /// Parses a date based on the given [pattern]
  ///
  /// The [pattern] must confirm to the patterns accepted
  /// by the [DateFormat] class in the intl package
  /// https://pub.dev/documentation/intl/latest/intl/DateFormat-class.html
  ///
  /// Throws a [FormatException] if the date doesn't
  /// match the passed [pattern].
  static Date parse(String date, String pattern) {
    final format = DateFormat(pattern);

    return Date.from(format.parse(date));
  }

  static Date now() => Date.from(DateTime.now());

  /// Parses a date based on the given [pattern]
  ///
  /// The [pattern] must confirm to the patterns accepted
  /// by the [DateFormat] class in the intl package
  /// https://pub.dev/documentation/intl/latest/intl/DateFormat-class.html
  ///
  /// Returns null if [date] if the date doesn't
  /// match the passed [pattern].
  static Date? tryParse(String date, String pattern) {
    final format = DateFormat(pattern);

    final Date result;
    try {
      result = Date.from(format.parse(date));
    } on FormatException {
      return null;
    }
    return result;
  }
}


