/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'dart:developer';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:scope/scope.dart';

import '../exceptions.dart';
import 'db.dart';
import 'db_pool.dart';
import 'row.dart';
import 'shared_pool.dart';

/// Obtains a connection and starts a MySQL transaction.
///
/// (docstring unchanged for brevity)
Future<R> withTransaction<R>({
  required Future<R> Function() action,
  TransactionNesting nesting = TransactionNesting.nested,
  bool useTransaction = true,
  DbPool? dbPool,
  String? debugName,
}) {
  final nestedTransaction = Scope.hasScopeKey(Transaction.transactionKey);

  switch (nesting) {
    case TransactionNesting.notAllowed:
      if (nestedTransaction) {
        throw NestedTransactionException('You are already in a transaction. '
            'Specify TransactionNesting.nestedTransaction');
      }
      return _runTransaction(
        action,
        useTransaction: useTransaction,
        shareDb: false,
        debugName: debugName,
      );

    case TransactionNesting.detached:
      return _runTransaction(
        action,
        useTransaction: useTransaction,
        shareDb: false,
        debugName: debugName,
      );

    case TransactionNesting.nested:
      return _runTransaction(
        action,
        useTransaction: useTransaction && !nestedTransaction,
        shareDb: nestedTransaction,
        debugName: debugName,
      );
  }
}

Future<R> _runTransaction<R>(
  Future<R> Function() action, {
  required bool useTransaction,
  required bool shareDb,
  required String? debugName,
  DbPool? dbPool,
}) async {
  ConnectionWrapper<Db>? wrapper;

  dbPool ??= DbPool();

  try {
    Db db;
    if (shareDb) {
      db = Transaction.current.db;
    } else {
      wrapper = await dbPool.obtain();
      db = wrapper.wrapped;
    }

    final transaction = Transaction<R>(db, useTransaction: useTransaction);

    return await (Scope('runTransaction')
          ..value(Transaction.transactionKey, transaction))
        .run(() => transaction.run(action, debugName: debugName));
  } finally {
    if (wrapper != null) {
      await dbPool.release(wrapper);
    }
  }
}

enum TransactionNesting { detached, nested, notAllowed }

/// Use the [TransactionTestScope]
class TransactionTestScope {
  var nextTransactionId = 0;

  var nextDbId = 0;

  static var transactionTestIdKey = const ScopeKey<int>('transactionTestId');

  static var dbTestIdKey = const ScopeKey<int>('dbTestId');

  TransactionTestScope();

  Future<R> run<R>(Future<R> Function() action) =>
      (Scope('TransactionTestScope')
            ..sequence<int>(transactionTestIdKey, () => nextTransactionId++)
            ..sequence<int>(dbTestIdKey, () => nextDbId++))
          .run(() => action());
}

class Transaction<R> {
  final logger = Logger('Transaction');

  static var __nextId = 0;

  /// unique id used for debugging
  int id;

  final Db db;

  /// For debugging purposes the user can suppress
  /// the use of a transaction so that they can see db
  /// updates as they happen.
  final bool useTransaction;

  var _commited = false;

  @visibleForTesting
  static const transactionKey =
      // we don't know the type here.
      // ignore: strict_raw_type
      ScopeKey<Transaction>('transaction');

  /// Create a database transaction for [db].
  ///
  /// If [useTransaction] is false the transaction
  /// isn't created. This should only be used for debugging.
  Transaction(this.db, {required this.useTransaction}) : id = _nextId;

  static int get _nextId => use(TransactionTestScope.transactionTestIdKey,
      withDefault: () => __nextId++);

  // we don't know the type
  // ignore: strict_raw_type
  static Transaction get current {
    // we don't know the type
    // ignore: strict_raw_type
    Transaction transaction;
    try {
      transaction = use(transactionKey);
      // we don't know the type
      // ignore: strict_raw_type
    } on MissingDependencyException catch (_) {
      throw TransactionNotInScopeException();
    }
    return transaction;
  }

  /// [useTransaction] is intended for debugging purposes.
  Future<R> run(Future<R> Function() action,
      {required String? debugName}) async {
    logger.finer(() => 'Start transaction($id db: ${db.id} '
        'isolate: ${Service.getIsolateId(Isolate.current)}): '
        'useTransaction: $useTransaction '
        'debugName: ${debugName ?? 'none'}');
    if (useTransaction) {
      final result = await db.transaction(()  => action());
      _commited = true;
      logger.finer(() =>
          'End transaction($id db: ${db.id}): useTransaction: $useTransaction '
          'debugName: ${debugName ?? 'none'}');
      return result;
    } else {
      final result = await action();
      _commited = true;
      logger.finer(() =>
          'End transaction($id db: ${db.id}): useTransaction: $useTransaction '
          'debugName: ${debugName ?? 'none'}');
      return result;
    }
  }

  Future<void> rollback() async {
    if (!useTransaction) {
      return;
    }
    if (_commited) {
      throw InvalidTransactionStateException('commit has already been called');
    }
    // Use withResults to ensure any PS are properly freed.
    await db.withResults('ROLLBACK', action: (_) {});
  }
}

/// Lets you run a query outside the scope of a Dao.
///
/// Requires an active [Transaction].
Future<List<Row>> tquery(String sql) =>
    Transaction.current.db.withResults(sql, action: (rs) {
      final rows = <Row>[];
      for (final r in rs.rows) {
        rows.add(Row(r));
      }
      return rows;
    });

class InvalidTransactionStateException implements Exception {
  String message;

  InvalidTransactionStateException(this.message);
}

class TransactionNotInScopeException implements Exception {
  TransactionNotInScopeException();
  @override
  String toString() =>
      'You tried to access a Transaction when none was in scope.'
      ' Check that you are within a call to withTransaction()';
}
