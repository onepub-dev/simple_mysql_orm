/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */


import 'dart:collection';

class CountedSet<T> {
  CountedSet();
  final _set = SplayTreeMap<int, Set<T>>();

  final _values = <T, int>{};

  Iterable<T> get values => _values.keys;

  int get length => _values.length;

  void add(int count, T value) {
    if (_values.containsKey(value)) {
      throw CountedSetException('Already present!');
    }
    final set = _set[count] ??= <T>{};
    _values[value] = count;
    set.add(value);
  }

  void remove(T value) {
    if (!_values.containsKey(value)) {
      throw CountedSetException('Not present!');
    }
    final count = _values[value];

    final set = _set[count];
    if (set == null) {
      _values.remove(value);
      throw CountedSetException('$value is not located at $count!');
    }

    if (!set.remove(value)) {
      _values.remove(value);
      throw CountedSetException('$value is not located at $count!');
    }
    if (set.isEmpty) {
      _set.remove(count);
    }

    _values.remove(value);
  }

  void inc(T value) {
    var count = _values[value];
    if (count == null) {
      throw CountedSetException('$value is not present!');
    }

    var set = _set[count];
    if (set == null) {
      throw CountedSetException('$value is not located at $count!');
    }
    if (!set.remove(value)) {
      throw CountedSetException('$value is not located at $count!');
    }
    if (set.isEmpty) {
      _set.remove(count);
    }

    count++;
    set = _set[count] ??= <T>{};
    _values[value] = count;
    set.add(value);
  }

  void dec(T value) {
    var count = _values[value];
    if (count == null) {
      throw CountedSetException('$value is not present!');
    }

    var set = _set[count];
    if (set == null) {
      throw CountedSetException('$value is not located at $count!');
    }
    if (!set.remove(value)) {
      throw CountedSetException('$value is not located at $count!');
    }
    if (set.isEmpty) {
      _set.remove(count);
    }

    count--;
    set = _set[count] ??= <T>{};
    _values[value] = count;
    set.add(value);
  }

  T? get leastUsed {
    if (_values.isEmpty) {
      return null;
    }
    final firstKey = _set.firstKey();
    return _set[firstKey]?.first;
  }

  int numAt(int count) {
    final set = _set[count];
    if (set == null) {
      return 0;
    }
    return set.length;
  }

  List<T> removeAllAt(int count) {
    final set = _set[count];
    if (set == null) {
      return [];
    }

    set.forEach(_values.remove);
    _set.remove(count);

    return set.toList();
  }

  bool contains(T value) => _values.containsKey(value);

  int? countOf(T value) => _values[value];
}

class CountedSetException implements Exception {
  CountedSetException(this.message);

  String message;

  @override
  String toString() => message;
}
