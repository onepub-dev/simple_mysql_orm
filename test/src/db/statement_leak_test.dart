/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'package:simple_mysql_orm/simple_mysql_orm.dart';
import 'package:test/test.dart';

import '../../test_setup.dart';

void main() {
  setUp(testSetup);

  group('prepared statement hygiene', () {
    test('no leak for parameterised queries', () async {
      await withTransaction(
          action: () async {
            // 1) Snapshot global counters
            final before = await _stmtCounters();

            // 2) Run MANY parameterised queries via withResults (alloc+free PS)
            const iters = 200;
            for (var i = 0; i < iters; i++) {
              await Transaction.current.db.withResults(
                'SELECT ? AS x',
                values: [i],
                action: (rs) {
                  // read result to ensure cursor is consumed
                  expect(rs.rows.length, 1);
                  return null;
                },
              );
            }

            // 3) Snapshot again
            final after = await _stmtCounters();

            // 4) Assertions
            final dPrepare = after.comStmtPrepare - before.comStmtPrepare;
            final dClose = after.comStmtClose - before.comStmtClose;
            final dOpen = after.preparedStmtCount - before.preparedStmtCount;

            // Under normal conditions prepare ≈ close (allow tiny skew if 
            // other tests run)
            // If this fails, statements are being left open.
            expect((dPrepare - dClose).abs() <= 2, isTrue,
                reason:
                    'Prepared/Close mismatch: prepared=$dPrepare, closed=$dClose');

            // The number of currently open server PS should not grow 
            // significantly.
            // Allow a couple in flight.
            expect(dOpen <= 2, isTrue,
                reason: 'Prepared_stmt_count grew by $dOpen (possible leak).');
          },
          debugName: 'prepared_stmt_leak_param');
    });

    test('text-protocol (no params) does not touch PS counters', () async {
      await withTransaction(
          action: () async {
            final before = await _stmtCounters();

            // Run MANY no-param queries (should use text protocol 
            //in Db.withResults)
            const iters = 200;
            for (var i = 0; i < iters; i++) {
              await Transaction.current.db.withResults(
                'SELECT 1 AS x',
                action: (rs) {
                  expect(rs.rows.length, 1);
                  return null;
                },
              );
            }

            final after = await _stmtCounters();

            final dPrepare = after.comStmtPrepare - before.comStmtPrepare;
            final dClose = after.comStmtClose - before.comStmtClose;

            // No parameters => driver should not create server-side PS.
            expect(dPrepare, equals(0),
                reason:
                    'Com_stmt_prepare changed for no-param queries: $dPrepare');
            expect(dClose, equals(0),
                reason: 'Com_stmt_close changed for no-param queries: $dClose');
          },
          debugName: 'prepared_stmt_text_protocol');
    });
  });
}

/// Snapshot of global prepared-statement counters.
class _StmtCounters {
  final int comStmtPrepare;

  final int comStmtClose;

  final int preparedStmtCount;

  _StmtCounters({
    required this.comStmtPrepare,
    required this.comStmtClose,
    required this.preparedStmtCount,
  });
}

Future<_StmtCounters> _stmtCounters() async {
  final db = Transaction.current.db;

  final prepare = await _readGlobalStatusInt(db, 'Com_stmt_prepare');
  final close = await _readGlobalStatusInt(db, 'Com_stmt_close');
  final open = await _readGlobalStatusInt(db, 'Prepared_stmt_count');

  return _StmtCounters(
    comStmtPrepare: prepare,
    comStmtClose: close,
    preparedStmtCount: open,
  );
}

Future<int> _readGlobalStatusInt(Db db, String name)  => db.withResults(
      "SHOW GLOBAL STATUS LIKE '$name'",
      action: (rs) {
        if (rs.rows.isEmpty) {
          return 0;
        }

        final row = rs.rows.first;
        final value = row.colByName('Value') ?? '0';
        return int.tryParse(value) ?? 0;
      },
    );
