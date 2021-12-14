import 'db.dart';
import 'db_pool.dart';

/// Obtains a connection and starts a transaction
/// The [action] is called within the scope of the transaction.
/// When the [action] returns the transaction is automatically
/// committed.
/// If [action] throws any exception the transaction is
/// rollback.
Future<void> withTransaction(void Function(Db db) action) async {
  final wrapper = await DbPool().obtain();
  try {
    await wrapper.wrapped.transaction(() => action(wrapper.wrapped));
    // ignore: avoid_catches_without_on_clauses
  } catch (e) {
    await DbPool().release(wrapper);
    rethrow;
  }

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

// class Transaction {
//   Transaction() {
//     _begin();
//   }

//   final db = Db();

//   /// The transaction has started
//   bool started = false;

//   /// The transation has been commtied
//   bool committed = false;

//   /// Transaction
//   bool rolledback = false;

//   void _begin() {
//     if (started == true) {
//       throw InvalidTransactionStateException(
//        'begin has already been called');
//     }
//     db.begin();
//     started = true;
//   }

//   void _commit() {
//     if (committed) {
//       throw InvalidTransactionStateException(
//      'commit has already been called');
//     }
//     db.commit();
//     committed = true;
//   }

//   void _rollback() {
//     if (committed) {
//       throw InvalidTransactionStateException(
//      'commit has already been called');
//     }

//     db.rollback();
//   }
// }

class InvalidTransactionStateException implements Exception {
  InvalidTransactionStateException(this.message);
  String message;
}
