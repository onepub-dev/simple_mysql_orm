/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'package:recase/recase.dart';

///
/// Provides a collection of methods that help when working with
/// enums.
///
class EnumHelper {
  static final _self = EnumHelper._init();

  /// Factory Constructor.
  factory EnumHelper() => _self;

  EnumHelper._init();

  /// returns an enum based on its index.
  T getByIndex<T>(List<T> values, int index) => values.elementAt(index - 1);

  /// returns the index of a enum value.
  int getIndexOf<T>(List<T> values, T value) => values.indexOf(value);

  ///
  /// Returns the Enum name without the enum class.
  /// e.g. DayName.Wednesday becomes Wednesday.
  /// By default we recase the value to Title Case.
  /// You can pass an alternate method to control the format.
  ///
  String getName<T>(T enumValue) {
    final name = enumValue.toString();
    final period = name.indexOf('.');

    return ReCase(name.substring(period + 1)).titleCase;
  }

  /// returns a enum based on its name.
  T getEnum<T>(String enumName, List<T> values, {T? defaultValue}) {
    final cleanedName = ReCase(enumName).titleCase;
    for (var i = 0; i < values.length; i++) {
      if (cleanedName == getName(values[i])) {
        return values[i];
      }
    }
    if (defaultValue != null) {
      return defaultValue;
    }
    throw InvalidEnumValueException(
        "$cleanedName doesn't exist in the list of enums $values");
  }
}

class InvalidEnumValueException implements Exception {
  String message;

  InvalidEnumValueException(this.message);

  @override
  String toString() => message;
}
