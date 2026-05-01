// ============================================================
// Chart Registry - FULLY ADAPTED
// Location: lib/presentation/screens/charts/chart_registry.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:family_economy/presentation/screens/charts/graf_1_page.dart';
import 'package:family_economy/presentation/screens/charts/graf_2_page.dart';
import 'package:family_economy/presentation/screens/charts/graf_3_page.dart';
import 'package:family_economy/presentation/screens/charts/graf_4_page.dart';
import 'package:family_economy/presentation/screens/charts/graf_5_page.dart';
import 'package:family_economy/presentation/screens/charts/graf_6_page.dart';

class ChartItem {
  final String id;
  final String name;
  final Widget Function(String selectedPeriod) builder;

  ChartItem({required this.id, required this.name, required this.builder});
}

/// Available charts
final List<ChartItem> availableCharts = [
  ChartItem(
    id: 'graf_1',
    name: 'Έσοδα / Έξοδα',
    builder: (selectedPeriod) => Graf1Page(selectedPeriod: selectedPeriod),
  ),
  ChartItem(
    id: 'graf_2',
    name: 'Κατηγορίες Εσόδων',
    builder: (selectedPeriod) => Graf2Page(selectedPeriod: selectedPeriod),
  ),
  ChartItem(
    id: 'graf_3',
    name: 'Κατηγορίες Εξόδων',
    builder: (selectedPeriod) => Graf3Page(selectedPeriod: selectedPeriod),
  ),
  ChartItem(
    id: 'graf_4',
    name: 'Υπόλοιπα Λογαριασμών',
    builder: (_) => const Graf4Page(), // No period needed
  ),
  ChartItem(
    id: 'graf_5',
    name: 'Υποκατηγορίες Εξόδων',
    builder: (period) => Graf5Page(selectedPeriod: period),
  ),
  ChartItem(
    id: 'graf_6',
    name: 'Αναλυτική Προβολή Κινήσεων',
    builder: (period) => Graf6Page(selectedPeriod: period),
  ),
];
