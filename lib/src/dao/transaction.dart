import 'package:zone_di2/zone_di2.dart';

import 'db.dart';
import 'db_pool.dart';

Token<Db> dbToken = Token<Db>('transaction db');
Token<Transaction> transactionToken = Token<Transaction>('transaction');

Transaction get transaction => inject(transactionToken);

/// Obtains a connection and starts a transaction
/// The [action] is called within the scope of the transaction.
/// When the [action] returns the transaction is automatically
/// committed.
/// If [action] throws any exception the transaction is
/// rollback.
Future<R> withTransaction<R>(R Function() action) async {
  final wrapper = await DbPool().obtain();

  final transaction = Transaction<R>(wrapper.wrapped);

  return provide(
      <Token<Transaction>, Transaction>{transactionToken: transaction},
      () async {
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

class Transaction<R> {
  Transaction(this.db) {
    // _begin();
  }

  final Db db;

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

  Future<R> run(R Function() action) async => db.transaction(() => action());
}

class InvalidTransactionStateException implements Exception {
  InvalidTransactionStateException(this.message);
  String message;
}
