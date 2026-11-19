import 'package:flutter_test/flutter_test.dart';
import 'package:family_economy/core/data/schema.dart';

void main() {
  // ============================================================
  // PARSER — ανεκτική ανάγνωση της έκδοσης
  // ============================================================
  group('Schema.readVersion', () {
    test('null returns null', () {
      expect(Schema.readVersion(null), isNull);
    });

    test('int is returned as is', () {
      expect(Schema.readVersion(1), 1);
      expect(Schema.readVersion(7), 7);
    });

    test('zero and negative are rejected', () {
      expect(Schema.readVersion(0), isNull);
      expect(Schema.readVersion(-3), isNull);
    });

    test('whole double is accepted', () {
      expect(Schema.readVersion(2.0), 2);
    });

    test('fractional double is rejected', () {
      expect(Schema.readVersion(2.5), isNull);
    });

    test('non-finite double is rejected', () {
      expect(Schema.readVersion(double.nan), isNull);
      expect(Schema.readVersion(double.infinity), isNull);
    });

    test('numeric string is accepted and trimmed', () {
      expect(Schema.readVersion('2'), 2);
      expect(Schema.readVersion(' 2 '), 2);
      expect(Schema.readVersion('2.0'), 2);
    });

    test('empty and non-numeric strings are rejected', () {
      expect(Schema.readVersion(''), isNull);
      expect(Schema.readVersion('   '), isNull);
      expect(Schema.readVersion('abc'), isNull);
      expect(Schema.readVersion('2,5'), isNull);
    });

    test('absurdly large value is rejected', () {
      expect(Schema.readVersion(1000000000), isNull);
      expect(Schema.readVersion('1e9'), isNull);
    });

    test('upper boundary is inclusive', () {
      expect(
        Schema.readVersion(Schema.maxReasonableVersion),
        Schema.maxReasonableVersion,
      );
      expect(Schema.readVersion(Schema.maxReasonableVersion + 1), isNull);
    });

    test('non-numeric types are rejected', () {
      expect(Schema.readVersion(true), isNull);
      expect(Schema.readVersion(<String>[]), isNull);
    });
  });

  // ============================================================
  // DECISION — τι θα γίνει με τα δεδομένα
  // ============================================================
  group('Schema.decide', () {
    test('missing document is noData', () {
      final d = Schema.decide(exists: false, data: null);
      expect(d.status, SchemaStatus.noData);
      expect(d.fromVersion, Schema.baseline);
      expect(d.toVersion, Schema.current);
      expect(d.needsMigration, isFalse);
      expect(d.isBlocked, isFalse);
    });

    test('null data is noData', () {
      final d = Schema.decide(exists: true, data: null);
      expect(d.status, SchemaStatus.noData);
    });

    test('deleted document is noData', () {
      final d = Schema.decide(
        exists: true,
        data: <String, dynamic>{
          Schema.deletedField: true,
          Schema.versionField: 1,
        },
      );
      expect(d.status, SchemaStatus.noData);
    });

    test('missing version field is upToDate at baseline', () {
      final d = Schema.decide(
        exists: true,
        data: <String, dynamic>{'email': 'a@b.c'},
      );
      expect(d.status, SchemaStatus.upToDate);
      expect(d.fromVersion, Schema.baseline);
      expect(d.versionUnreadable, isFalse);
    });

    test('current version is upToDate', () {
      final d = Schema.decide(
        exists: true,
        data: <String, dynamic>{Schema.versionField: Schema.current},
      );
      expect(d.status, SchemaStatus.upToDate);
      expect(d.fromVersion, Schema.current);
      expect(d.versionUnreadable, isFalse);
    });

    test('unreadable version is treated as baseline with a flag', () {
      final d = Schema.decide(
        exists: true,
        data: <String, dynamic>{Schema.versionField: 'abc'},
      );
      expect(d.status, SchemaStatus.upToDate);
      expect(d.fromVersion, Schema.baseline);
      expect(d.versionUnreadable, isTrue);
    });

    test('newer version is blocked', () {
      final d = Schema.decide(
        exists: true,
        data: <String, dynamic>{Schema.versionField: Schema.current + 1},
      );
      expect(d.status, SchemaStatus.newerThanApp);
      expect(d.fromVersion, Schema.current + 1);
      expect(d.isBlocked, isTrue);
      expect(d.needsMigration, isFalse);
    });

    test('plausible large version still blocks', () {
      final d = Schema.decide(
        exists: true,
        data: <String, dynamic>{Schema.versionField: 999},
      );
      expect(d.status, SchemaStatus.newerThanApp);
      expect(d.fromVersion, 999);
    });

    test('deleted=false keeps the document usable', () {
      final d = Schema.decide(
        exists: true,
        data: <String, dynamic>{
          Schema.deletedField: false,
          Schema.versionField: 1,
        },
      );
      expect(d.status, SchemaStatus.upToDate);
    });

    test('pending is unreachable while current equals baseline', () {
      // Προστατεύει την "αδράνεια" του E4: όσο current == baseline
      // δεν μπορεί να υπάρξει migration, άρα κανένα write.
      expect(Schema.current, Schema.baseline);

      final candidates = <Object?>[
        null,
        0,
        -1,
        2,
        '2',
        'abc',
        999,
        1000000000,
      ];

      for (final candidate in candidates) {
        final d = Schema.decide(
          exists: true,
          data: <String, dynamic>{Schema.versionField: candidate},
        );
        expect(
          d.needsMigration,
          isFalse,
          reason: 'version=$candidate δεν πρέπει να ζητήσει migration',
        );
      }
    });
  });

  // ============================================================
  // FAILURE — ελληνικά μηνύματα ανά κωδικό σφάλματος
  // ============================================================
  group('Schema.failureFor', () {
    test('permission-denied maps to permission texts', () {
      final f = Schema.failureFor('permission-denied');
      expect(f.title, Schema.permissionTitle);
      expect(f.message, Schema.permissionMessage);
    });

    test('network related codes map to connection message', () {
      const codes = <String>[
        'unavailable',
        'deadline-exceeded',
        'network-request-failed',
      ];
      for (final code in codes) {
        final f = Schema.failureFor(code);
        expect(f.title, Schema.blockedTitle);
        expect(f.message, Schema.updateFailedMessage);
      }
    });

    test('unknown or null code maps to generic message', () {
      final codes = <String?>[null, 'internal', 'invalid-argument'];
      for (final code in codes) {
        final f = Schema.failureFor(code);
        expect(f.title, Schema.blockedTitle);
        expect(f.message, Schema.genericFailureMessage);
      }
    });

    test('messages never start with the accessibility prefix', () {
      const messages = <String>[
        Schema.updateFailedMessage,
        Schema.newerMessage,
        Schema.permissionMessage,
        Schema.genericFailureMessage,
      ];
      for (final message in messages) {
        expect(message, isNotEmpty);
        expect(message.startsWith('Σφάλμα:'), isFalse);
      }
    });
  });

  // ============================================================
  // WRITE OUTCOME — timeout ≠ αποτυχία (Β3)
  // ============================================================
  group('Schema.resolveWrite', () {
    test('acknowledged write is applied', () {
      expect(
        Schema.resolveWrite(targetVersion: 2),
        SchemaWriteOutcome.applied,
      );
    });

    test('timeout with verified target is appliedLocally', () {
      expect(
        Schema.resolveWrite(
          targetVersion: 2,
          timedOut: true,
          verifiedVersion: 2,
        ),
        SchemaWriteOutcome.appliedLocally,
      );
    });

    test('timeout without verification fails', () {
      expect(
        Schema.resolveWrite(targetVersion: 2, timedOut: true),
        SchemaWriteOutcome.failed,
      );
      expect(
        Schema.resolveWrite(
          targetVersion: 2,
          timedOut: true,
          verifiedVersion: 1,
        ),
        SchemaWriteOutcome.failed,
      );
    });

    test('real error fails even without timeout', () {
      expect(
        Schema.resolveWrite(
          targetVersion: 2,
          errorCode: 'permission-denied',
        ),
        SchemaWriteOutcome.failed,
      );
    });

    test('real error wins over verified cache', () {
      expect(
        Schema.resolveWrite(
          targetVersion: 2,
          timedOut: true,
          errorCode: 'unavailable',
          verifiedVersion: 2,
        ),
        SchemaWriteOutcome.failed,
      );
    });

    test('empty error code is ignored', () {
      expect(
        Schema.resolveWrite(targetVersion: 2, errorCode: ''),
        SchemaWriteOutcome.applied,
      );
    });
  });

  // ============================================================
  // EXCEPTION — συμβόλαιο για το login_page
  // ============================================================
  group('SchemaBlockedException', () {
    test('toString returns only the message', () {
      const e = SchemaBlockedException(
        title: 'Απαιτείται ενημέρωση δεδομένων',
        message: 'Δεν ήταν δυνατή η ενημέρωση.',
        code: 'unavailable',
      );

      expect(e.toString(), 'Δεν ήταν δυνατή η ενημέρωση.');
      expect(e.toString().contains('Exception:'), isFalse);
      expect(e.code, 'unavailable');
      expect(e.title, 'Απαιτείται ενημέρωση δεδομένων');
    });
  });

  // ============================================================
  // CONSTANTS — συμβόλαιο με το Firestore
  // ============================================================
  group('Schema constants', () {
    test('firestore field names are snake_case', () {
      expect(Schema.versionField, 'schema_version');
      expect(Schema.updatedAtField, 'schema_updated_at');
      expect(Schema.deletedField, 'deleted');
    });

    test('current version equals baseline at this release', () {
      expect(Schema.current, 1);
      expect(Schema.baseline, 1);
    });
  });
}