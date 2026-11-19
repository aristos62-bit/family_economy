import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_economy/core/widgets/startup_error_view.dart';

void main() {
  group('StartupErrorView', () {
    testWidgets('εμφανίζει τίτλο, μήνυμα και κύρια ενέργεια', (
        tester,
        ) async {
      var taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StartupErrorView(
              title: 'Σφάλμα Αρχικοποίησης',
              message: 'Η εφαρμογή δεν μπόρεσε να συνδεθεί.',
              primaryLabel: 'Επανεκκίνηση',
              onPrimary: () => taps++,
            ),
          ),
        ),
      );

      expect(find.text('Σφάλμα Αρχικοποίησης'), findsOneWidget);
      expect(find.text('Η εφαρμογή δεν μπόρεσε να συνδεθεί.'), findsOneWidget);
      expect(find.text('Επανεκκίνηση'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);

      await tester.tap(find.text('Επανεκκίνηση'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('κρύβει τις λεπτομέρειες όταν είναι null ή κενές', (
        tester,
        ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StartupErrorView(
              title: 'Τίτλος',
              message: 'Μήνυμα',
              primaryLabel: 'Ξανά',
              onPrimary: () {},
            ),
          ),
        ),
      );

      expect(find.text('Σφάλμα: δοκιμή'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StartupErrorView(
              title: 'Τίτλος',
              message: 'Μήνυμα',
              details: '   ',
              primaryLabel: 'Ξανά',
              onPrimary: () {},
            ),
          ),
        ),
      );

      expect(find.text('   '), findsNothing);
    });

    testWidgets('εμφανίζει τις λεπτομέρειες όταν έχουν περιεχόμενο', (
        tester,
        ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StartupErrorView(
              title: 'Τίτλος',
              message: 'Μήνυμα',
              details: 'Σφάλμα: δοκιμή',
              primaryLabel: 'Ξανά',
              onPrimary: () {},
            ),
          ),
        ),
      );

      expect(find.text('Σφάλμα: δοκιμή'), findsOneWidget);
    });

    testWidgets('δείχνει δευτερεύουσα ενέργεια μόνο όταν δοθεί', (
        tester,
        ) async {
      var secondaryTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StartupErrorView(
              title: 'Τίτλος',
              message: 'Μήνυμα',
              primaryLabel: 'Ξανά',
              onPrimary: () {},
              secondaryLabel: 'Αποσύνδεση',
              onSecondary: () => secondaryTaps++,
            ),
          ),
        ),
      );

      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.text('Αποσύνδεση'), findsOneWidget);

      await tester.tap(find.text('Αποσύνδεση'));
      await tester.pump();

      expect(secondaryTaps, 1);
    });

    testWidgets('δεν πετά overflow σε μικρή οθόνη με textScale 1.45', (
        tester,
        ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 480),
              textScaler: TextScaler.linear(1.45),
            ),
            child: Scaffold(
              body: StartupErrorView(
                title: 'Νεότερη έκδοση δεδομένων',
                message:
                'Τα δεδομένα σας ανήκουν σε νεότερη έκδοση της '
                    'εφαρμογής. Ενημερώστε την εφαρμογή και δοκιμάστε ξανά.',
                details:
                'Σφάλμα: unavailable — δοκιμή μεγάλου κειμένου '
                    'για έλεγχο overflow',
                primaryLabel: 'Δοκιμή',
                onPrimary: () {},
                secondaryLabel: 'Αποσύνδεση',
                onSecondary: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}