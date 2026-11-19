// ============================================================
// FILE: schema_service.dart
// Path: lib/core/data/schema_service.dart
// Ρόλος: Εκτελεί την απόφαση του schema.dart με πραγματικό Firestore.
// - Χρησιμοποιεί το doc που έχει ήδη διαβαστεί (0 επιπλέον reads).
// - Γράφει ΜΟΝΟ όταν χρειάζεται migration.
// - Timeout στην εγγραφή + επαλήθευση από το τοπικό cache.
// ============================================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_economy/core/data/schema.dart';
import 'package:family_economy/core/utils/debug_config.dart';

class SchemaService {
  SchemaService({
    FirebaseFirestore? firestore,
    Duration writeTimeout = const Duration(seconds: 3),
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _writeTimeout = writeTimeout;

  final FirebaseFirestore _db;
  final Duration _writeTimeout;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  /// Ελέγχει την έκδοση των δεδομένων και, αν χρειάζεται, τρέχει migrations.
  ///
  /// Το [exists] και το [data] προέρχονται από το doc που έχει ήδη
  /// διαβαστεί — δεν γίνεται δεύτερη ανάγνωση.
  ///
  /// Πετάει [SchemaBlockedException] όταν η εφαρμογή δεν πρέπει να
  /// συνεχίσει (νεότερα δεδομένα ή αποτυχία ενημέρωσης).
  Future<SchemaDecision> checkAndMigrate({
    required String uid,
    required bool exists,
    Map<String, dynamic>? data,
  }) async {
    final decision = Schema.decide(exists: exists, data: data);

    if (decision.versionUnreadable) {
      DebugConfig.print(
        '⚠️ schema_version μη αναγνώσιμο για uid=$uid — '
            'αντιμετωπίζεται ως baseline ${Schema.baseline}',
      );
    }

    switch (decision.status) {
      case SchemaStatus.noData:
      case SchemaStatus.upToDate:
        return decision;

      case SchemaStatus.newerThanApp:
        DebugConfig.print(
          '⛔ Δεδομένα έκδοσης ${decision.fromVersion} > '
              'εφαρμογής ${Schema.current} (uid=$uid)',
        );
        throw const SchemaBlockedException(
          title: Schema.newerTitle,
          message: Schema.newerMessage,
        );

      case SchemaStatus.pending:
        await _migrate(uid: uid, decision: decision);
        return decision;
    }
  }

  /// Τρέχει τα βήματα migration και γράφει την έκδοση στο τέλος.
  Future<void> _migrate({
    required String uid,
    required SchemaDecision decision,
  }) async {
    DebugConfig.print(
      '🔧 Migration δεδομένων ${decision.fromVersion} → '
          '${decision.toVersion} (uid=$uid)',
    );

    // ── Migrations ──────────────────────────────────────────
    // Δεν υπάρχει καταχωρημένο βήμα σε αυτή την έκδοση: όσο
    // Schema.current == Schema.baseline η ροή είναι αδύνατη.
    // Πριν ανέβει το Schema.current, το βήμα γράφεται ΕΔΩ (idempotent)
    // μαζί με το test του.
    // ────────────────────────────────────────────────────────

    await _writeVersion(uid: uid, targetVersion: decision.toVersion);
  }

  /// Γράφει την έκδοση και αποφασίζει αν πέτυχε.
  Future<void> _writeVersion({
    required String uid,
    required int targetVersion,
  }) async {
    final ref = _userRef(uid);

    final payload = <String, dynamic>{
      Schema.versionField: targetVersion,
      Schema.updatedAtField: FieldValue.serverTimestamp(),
    };

    try {
      await ref.set(payload, SetOptions(merge: true)).timeout(_writeTimeout);
      DebugConfig.print(
        '✅ Έκδοση δεδομένων → $targetVersion (επιβεβαίωση server)',
      );
      return;
    } on TimeoutException {
      DebugConfig.print(
        '⏳ Timeout εγγραφής έκδοσης — έλεγχος τοπικού cache',
      );
    } catch (e) {
      final code = _errorCode(e);
      DebugConfig.print('❌ Αποτυχία εγγραφής έκδοσης: code=$code error=$e');
      throw _blocked(code);
    }

    // Το timeout δεν είναι αποτυχία: η εγγραφή μπορεί να εφαρμόστηκε
    // στο τοπικό cache και να περιμένει συγχρονισμό. Δεν μαντεύουμε —
    // διαβάζουμε και κρίνουμε.
    final verified = await _readCachedVersion(ref);

    final outcome = Schema.resolveWrite(
      targetVersion: targetVersion,
      timedOut: true,
      verifiedVersion: verified,
    );

    if (outcome == SchemaWriteOutcome.appliedLocally) {
      DebugConfig.print(
        '✅ Έκδοση $targetVersion εφαρμόστηκε τοπικά (εκκρεμεί sync)',
      );
      return;
    }

    DebugConfig.print(
      '❌ Έκδοση $targetVersion δεν επιβεβαιώθηκε τοπικά '
          '(cache=$verified)',
    );
    throw _blocked('unavailable');
  }

  /// Διαβάζει την έκδοση από το τοπικό cache.
  ///
  /// Πρώτα `Source.cache`: επιστρέφει αμέσως και βλέπει τις εκκρεμείς
  /// τοπικές εγγραφές — απαραίτητο όταν η εφαρμογή είναι offline.
  /// Αν το cache δεν έχει το doc, γίνεται μία κανονική ανάγνωση
  /// (serverAndCache) ως εφεδρική.
  Future<int?> _readCachedVersion(
      DocumentReference<Map<String, dynamic>> ref,
      ) async {
    try {
      final cached = await ref
          .get(const GetOptions(source: Source.cache))
          .timeout(_writeTimeout);
      final version = Schema.readVersion(
        cached.data()?[Schema.versionField],
      );
      if (version != null) return version;
    } catch (e) {
      DebugConfig.print('⚠️ Cache read απέτυχε: $e');
    }

    try {
      final doc = await ref.get().timeout(_writeTimeout);
      return Schema.readVersion(doc.data()?[Schema.versionField]);
    } catch (e) {
      DebugConfig.print('⚠️ Αποτυχία επαλήθευσης έκδοσης: $e');
      return null;
    }
  }

  SchemaBlockedException _blocked(String? code) {
    final failure = Schema.failureFor(code);
    return SchemaBlockedException(
      title: failure.title,
      message: failure.message,
      code: code,
    );
  }

  String? _errorCode(Object error) {
    if (error is FirebaseException) return error.code;
    return null;
  }
}