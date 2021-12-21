import 'package:scope/scope.dart';

import 'db.dart';
import 'db_pool.dart';

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
///
/// A new [Db] connection will always be obtained and a new MySQL transaction
/// will be started.
///
Future<R> withTransaction<R>(Future<R> Function() action,
    {TransactionNesting nesting = TransactionNesting.notAllowed}) async {
  final wrapper = await DbPool().obtain();

  final transaction = Transaction<R>(wrapper.wrapped);

  return (Scope()..value(Transaction._transactionKey, transaction))
      .run(() async {
    try {
      return await transaction.run(() => action());
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      await DbPool().release(wrapper);
      rethrow;
    }
  });

//  final tran = Transaction();

  // try {
  //   action(tran.db);
  //   tran._commit();
  //   // ignore: avoid_catches_without_on_clauses
  // } catch (e) {
  //   tran._rollback();
  //   rethrow;
  // }
}

class NestedTransactionException implements Exception {
  NestedTransactionException(this.message);
  String message;
}

enum TransactionNesting {
  detached,
  nested,
  notAllowed,
}

class Transaction<R> {
  Transaction(this.db) {
    // _begin();
  }

  static Transaction get current => use(_transactionKey);
  final Db db;

  static final ScopeKey<Db> _dbKey = ScopeKey<Db>('transaction db');
  
  static final ScopeKey<Transaction> _transactionKey =
      ScopeKey<Transaction>('transaction');

  Transaction get transaction => use(_transactionKey);

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

  // void _rollback() {
  //   if (committed) {
  //     throw InvalidTransactionStateException(
  //  'commit has already been called');
  //   }

  //   db.rollback();
  // }

  Future<R> run(Future<R> Function() action) async =>
      db.transaction(() => action());
}

class InvalidTransactionStateException implements Exception {
  InvalidTransactionStateException(this.message);
  String message;
}
