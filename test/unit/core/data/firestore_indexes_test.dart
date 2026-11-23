import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Τα 5 composite indexes που απαιτούν τα τρέχοντα queries.
/// Αναλυτικά: DESIGN.md §6.3 (στήλη «Χρήση»).
const List<String> _requiredSignatures = <String>[
  'account_id:ASCENDING,deleted:ASCENDING,date:ASCENDING',
  'account_id:ASCENDING,deleted:ASCENDING,date:DESCENDING',
  'deleted:ASCENDING,date:ASCENDING',
  'deleted:ASCENDING,date:DESCENDING',
  'is_scheduled:ASCENDING,is_executed:ASCENDING,deleted:ASCENDING,'
      'scheduled_for_date:ASCENDING',
];

const String _indexesPath = 'firestore.indexes.json';

Map<String, dynamic> _readIndexesFile() {
  final file = File(_indexesPath);

  expect(
    file.existsSync(),
    isTrue,
    reason: 'Δεν βρέθηκε το $_indexesPath. '
        'Τρέξε το test από τη ρίζα του project (flutter test).',
  );

  final decoded = jsonDecode(file.readAsStringSync());
  expect(
    decoded,
    isA<Map<String, dynamic>>(),
    reason: 'Το $_indexesPath δεν περιέχει JSON object.',
  );

  return decoded as Map<String, dynamic>;
}

List<Map<String, dynamic>> _indexesOf(Map<String, dynamic> json) {
  final raw = json['indexes'];
  expect(
    raw,
    isA<List<dynamic>>(),
    reason: 'Το πεδίο "indexes" λείπει ή δεν είναι λίστα.',
  );

  return (raw as List<dynamic>).cast<Map<String, dynamic>>();
}

/// Κανονικοποίηση για σύγκριση:
/// - αγνοεί το `__name__` (το CLI το προσθέτει αυτόματα),
/// - αγνοεί το `density` (default `SPARSE_ALL` για STANDARD edition).
String _signatureOf(Map<String, dynamic> index) {
  final fields = (index['fields'] as List<dynamic>).cast<Map<String, dynamic>>();

  return fields
      .where((field) => field['fieldPath'] != '__name__')
      .map((field) => '${field['fieldPath']}:${field['order']}')
      .join(',');
}

void main() {
  group('firestore.indexes.json', () {
    test('είναι έγκυρο JSON με δομή indexes/fieldOverrides', () {
      final json = _readIndexesFile();
      final indexes = _indexesOf(json);

      expect(indexes, isNotEmpty, reason: 'Το αρχείο δεν περιέχει indexes.');
      expect(
        json['fieldOverrides'],
        isA<List<dynamic>>(),
        reason: 'Το πεδίο "fieldOverrides" λείπει ή δεν είναι λίστα.',
      );

      for (final index in indexes) {
        expect(
          index['collectionGroup'],
          'transactions',
          reason: 'Όλα τα indexes πρέπει να αφορούν τη συλλογή transactions.',
        );
        expect(
          index['queryScope'],
          'COLLECTION',
          reason: 'Όλα τα indexes πρέπει να είναι COLLECTION scope.',
        );
        expect(
          index['fields'],
          isA<List<dynamic>>(),
          reason: 'Κάθε index χρειάζεται πεδίο "fields".',
        );
        expect(
          (index['fields'] as List<dynamic>),
          isNotEmpty,
          reason: 'Κάθε index χρειάζεται τουλάχιστον ένα πεδίο.',
        );
      }
    });

    test('περιέχει και τα 5 composite indexes που απαιτεί ο κώδικας', () {
      final signatures =
          _indexesOf(_readIndexesFile()).map(_signatureOf).toSet();

      for (final required in _requiredSignatures) {
        expect(
          signatures,
          contains(required),
          reason: 'Λείπει composite index: $required\n'
              'Χρησιμοποιείται από υπάρχον query (DESIGN.md §6.3). '
              'Μην το αφαιρέσεις χωρίς αλλαγή κώδικα.',
        );
      }
    });

    test('δεν έχει διπλότυπα indexes', () {
      final signatures =
          _indexesOf(_readIndexesFile()).map(_signatureOf).toList();

      final seen = <String>{};
      final duplicates = <String>{};
      for (final signature in signatures) {
        if (!seen.add(signature)) {
          duplicates.add(signature);
        }
      }

      expect(
        duplicates,
        isEmpty,
        reason: 'Βρέθηκαν διπλότυπα indexes: $duplicates',
      );
    });
  });
}
