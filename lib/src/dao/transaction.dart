import 'dart:developer';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:scope/scope.dart';

import '../exceptions.dart';
import 'db.dart';
import 'db_pool.dart';
import 'shared_pool.dart';

/// Obtains a connection and starts a MySQL transaction.
///
/// The [action] is called within the scope of the transaction.
/// When the [action] returns the transaction is automatically
/// committed.
/// If [action] throws any exception the transaction is
/// rolledback.
///
/// In most cases you will want to call [withTransaction] at the very
/// top of your call stack. This ensures that all db interactions occur
/// within the one transaction. This is important because any db interactions
/// that are performed outside of the transaction will not have visiblity
/// of the db changes associated with the transaction until the transaction
/// is committed.
///
/// MySQL does not allow nested transaction, therefore if you attempt
/// to nest a transation a [NestedTransactionException] is thrown unless...
///
/// Thre are some circumstances where you may want to call [withTransaction]
/// within the scope of an existing [withTransaction] call.
///
/// 1) you have a method that may or may not be called within the scope of an
/// existing [withTransaction] call.
/// In this case pass [nesting] = [TransactionNesting.nested].
///
/// If you code is called within the scope of an existing [withTransaction]
/// call then it will be attached to the same [Db] connection and the
/// same transaction. This is still NOT a nested MYSQL transaction and
/// if you transaction fails the outer one will also fail.
///
/// If your code is called outside the scope of an existing [withTransaction]
/// then a new [Db] connection will be obtained and a MySQL transaction
/// started.
///
/// 2) you may need to start a second MySQL transaction whilst in the scope
/// of a [withTransaction] call.
///
/// In this case pass [TransactionNesting.detached].
/// A new [Db] connection will be obtained and a new MySQL transaction
/// will be started. You need to be careful that you don't create a live
/// lock (two transactions viaing for the same resources).
///
/// [useTransaction] is intended for debugging purposes.
/// By setting [useTransaction] any db changes are visible
/// as soon as the occur rather than only once the transaction
/// completes. So this option allows you to inspect the db
/// as updates occur.
/// 
/// For most operations you don't provide a [DbPool] and the
/// transaction obtains one by calling [DbPool()].
/// In some cases you may want to provide db connections from 
/// an alternate pool. In these cases pass a pool to [dbPool].
Future<R> withTransaction<R>(Future<R> Function() action,
    {TransactionNesting nesting = TransactionNesting.nested,
    bool useTransaction = true,
    DbPool? dbPool,
    String? debugName}) async {
  final nestedTransaction = Scope.hasScopeKey(Transaction.transactionKey);

  switch (nesting) {
    case TransactionNesting.notAllowed:
      if (nestedTransaction) {
        throw NestedTransactionException('You are already in a transaction. '
            'Specify TransactionNesting.nestedTransaction');
      }
      return _runTransaction(action,
          useTransaction: useTransaction, shareDb: false, debugName: debugName);

    case TransactionNesting.detached:
      return _runTransaction(action,
          useTransaction: useTransaction, shareDb: false, debugName: debugName);

    case TransactionNesting.nested:
      return _runTransaction(action,
          useTransaction: useTransaction && !nestedTransaction,
          shareDb: nestedTransaction,
          debugName: debugName);
  }
}

Future<R> _runTransaction<R>(Future<R> Function() action,
    {required bool useTransaction,
    required bool shareDb,
    required String? debugName,
    DbPool? dbPool}) async {
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
        .run(() async => transaction.run(action, debugName: debugName));
  } finally {
    if (wrapper != null) {
      await dbPool.release(wrapper);
    }
  }
}

enum TransactionNesting {
  detached,
  nested,
  notAllowed,
}

/// Use the [TransactionTestScope]
class TransactionTestScope {
  TransactionTestScope();

  int nextTransactionId = 0;
  int nextDbId = 0;

  static ScopeKey<int> transactionTestIdKey =
      ScopeKey<int>('transactionTestId');
  static ScopeKey<int> dbTestIdKey = ScopeKey<int>('dbTestId');

  Future<R> run<R>(Future<R> Function() action) =>
      (Scope('TransactionTestScope')
            ..sequence<int>(transactionTestIdKey, () => nextTransactionId++)
            ..sequence<int>(dbTestIdKey, () => nextDbId++))
          .run(() => action());
}

class Transaction<R> {
  /// Create a database transaction for [db].
  ///
  /// If [useTransaction] is false the transation
  /// isn't created. This should only be used for debugging.
  Transaction(this.db, {required this.useTransaction}) : id = _nextId {
    // _begin();
  }

  final logger = Logger('Transaction');

  static int __nextId = 0;

  /// generates a unique id for each transaction for debugging purposes.
  /// If we are running in a [TransactionTestScope] then we use
  /// a sequence specific to that scope rather than a global sequence.
  static int get _nextId => use(TransactionTestScope.transactionTestIdKey,
      withDefault: () => __nextId++);

  /// unique id used for debugging
  int id;

  // ignore: strict_raw_type
  static Transaction get current {
    // ignore: strict_raw_type
    Transaction transaction;

    try {
      transaction = use(transactionKey);
      // ignore: strict_raw_type
    } on MissingDependencyException catch (_) {
      throw TransactionNotInScopeException();
    }

    return transaction;
  }

  final Db db;

  /// For debugging purposes the user can suppress
  /// the use of a transaction so that they can see db
  /// updates as they happen.
  final bool useTransaction;

  bool _commited = false;

  @visibleForTesting
  // ignore: strict_raw_type
  static final ScopeKey<Transaction> transactionKey =
      // ignore: strict_raw_type
      ScopeKey<Transaction>('transaction');

  // Transaction get transaction => use(transactionKey);

  /// [useTransaction] is intended for debugging purposes.
  /// By setting [useTransaction] and db changes are visible
  /// as soon as the occur rather than only once the transaction
  /// completes. So this option allows you to inspect the db
  /// as updates occur.
  Future<R> run(Future<R> Function() action,
      {required String? debugName}) async {
    logger.info(() => 'Start transaction($id db: ${db.id} '
        'isolate: ${Service.getIsolateID(Isolate.current)}): '
        'useTransaction: $useTransaction '
        'debugName: ${debugName ?? 'none'}');
    if (useTransaction) {
      /// run using a transaction
      final result = await db.transaction(() async => action());
      _commited = true;
      logger.info(() =>
          'End transaction($id db: ${db.id}): useTransaction: $useTransaction '
          'debugName: ${debugName ?? 'none'}');
      return result;
    } else {
      // run without a transaction
      final result = await action();
      _commited = true;
      logger.info(() =>
          'End transaction($id db: ${db.id}): useTransaction: $useTransaction '
          'debugName: ${debugName ?? 'none'}');
      return result;
    }
  }

  // /// The transaction has started
  // bool started = false;

  // /// The transation has been commtied
  // bool committed = false;

  // /// Transaction
  // bool rolledback = false;

  // void _begin() {
  //   if (started == true) {
  //     throw InvalidTransactionStateException(
  //'begin has already been called');
  //   }
  //   db.begin();
  //   started = true;
  // }

  // void _commit() {
  //   if (committed) {
  //     throw InvalidTransactionStateException(
  //'commit has already been called');
  //   }
  //   db.commit();
  //   committed = true;
  // }

  void rollback() {
    if (!useTransaction) {
      return;
    }
    if (_commited) {
      throw InvalidTransactionStateException('commit has already been called');
    }

    db.rollback();
  }
}

class InvalidTransactionStateException implements Exception {
  InvalidTransactionStateException(this.message);
  String message;
}

class TransactionNotInScopeException implements Exception {
  TransactionNotInScopeException();
  @override
  String toString() =>
      'You tried to access a Transaction when none was in scope.'
      ' Check that you are within a call to withTransaction()';
}
