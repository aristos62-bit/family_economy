// ============================================================
// FILE: app_messenger_test.dart
// Path: test/unit/core/messaging/app_messenger_test.dart
// Ρόλος: Widget tests για τον κεντρικό presenter μηνυμάτων (L11).
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:family_economy/core/messaging/app_messenger.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/utils/message_policy.dart';

Future<BuildContext> _pumpHost(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Size size = const Size(800, 600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: Builder(
          builder: (BuildContext c) {
            context = c;
            return const SizedBox.expand();
          },
        ),
      ),
    ),
  );
  return context;
}

/// Αφήνει τον timer του SnackBar να λήξει, ώστε να μη μείνει pending.
Future<void> _drain(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 10));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('success: semantic χρώματα, εικονίδιο, floating, πλάτος 560', (
    WidgetTester tester,
  ) async {
    final context = await _pumpHost(tester);

    AppMessenger.success(context, 'Αποθηκεύτηκε');
    await tester.pumpAndSettle();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    final background = ColorsUI.getSuccess(Brightness.light);
    final foreground = MessagePolicy.foregroundFor(background);

    expect(snackBar.backgroundColor, background);
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.width, MessagePolicy.wideWidth);
    expect(snackBar.duration, const Duration(seconds: 3));
    expect(snackBar.persist, isFalse);

    final text = tester.widget<Text>(find.text('Αποθηκεύτηκε'));
    expect(text.style?.color, foreground);

    final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle_outline));
    expect(icon.color, foreground);

    await _drain(tester);
  });

  testWidgets('error σε dark: background/foreground από το policy', (
    WidgetTester tester,
  ) async {
    final context = await _pumpHost(tester, brightness: Brightness.dark);

    AppMessenger.error(context, 'Κάτι πήγε στραβά');
    await tester.pumpAndSettle();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    final background = ColorsUI.getError(Brightness.dark);
    final foreground = MessagePolicy.foregroundFor(background);

    expect(snackBar.backgroundColor, background);
    expect(snackBar.duration, const Duration(seconds: 6));
    expect(
      tester.widget<Text>(find.text('Κάτι πήγε στραβά')).style?.color,
      foreground,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.error_outline)).color,
      foreground,
    );

    await _drain(tester);
  });

  testWidgets('warning με action: textColor = foreground, persist = true', (
    WidgetTester tester,
  ) async {
    final context = await _pumpHost(tester);
    var pressed = 0;

    AppMessenger.warning(
      context,
      'Προσοχή',
      actionLabel: 'ΟΚ',
      onAction: () => pressed++,
    );
    await tester.pumpAndSettle();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    final background = ColorsUI.getWarning(Brightness.light);
    final foreground = MessagePolicy.foregroundFor(background);
    final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));

    expect(snackBar.backgroundColor, background);
    expect(snackBar.persist, isTrue);
    expect(action.textColor, foreground);
    expect(action.label, 'ΟΚ');

    await tester.tap(find.text('ΟΚ'));
    await tester.pumpAndSettle();

    expect(pressed, 1);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('persist:false με action αντικαθίσταται και λήγει σε 5s', (
    WidgetTester tester,
  ) async {
    final context = await _pumpHost(tester);

    AppMessenger.warning(
      context,
      'Προγραμματισμένη κίνηση',
      actionLabel: 'Αναίρεση',
      onAction: () {},
      persist: false,
    );
    await tester.pumpAndSettle();

    final first = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(first.persist, isFalse);
    expect(first.duration, const Duration(seconds: 5));

    AppMessenger.info(context, 'Νεότερο μήνυμα');
    await tester.pumpAndSettle();

    expect(find.text('Προγραμματισμένη κίνηση'), findsNothing);
    expect(find.text('Νεότερο μήνυμα'), findsOneWidget);

    await _drain(tester);
  });

  testWidgets('δύο άμεσες κλήσεις: μένει μόνο η δεύτερη', (
    WidgetTester tester,
  ) async {
    final context = await _pumpHost(tester);

    AppMessenger.error(context, 'πρώτο');
    AppMessenger.info(context, 'δεύτερο');
    await tester.pumpAndSettle();

    expect(find.text('πρώτο'), findsNothing);
    expect(find.text('δεύτερο'), findsOneWidget);

    await _drain(tester);
  });

  testWidgets('ορατό μη-persist αντικαθίσταται από το επόμενο', (
    WidgetTester tester,
  ) async {
    final context = await _pumpHost(tester);

    AppMessenger.error(context, 'πρώτο');
    await tester.pump();
    expect(find.text('πρώτο'), findsOneWidget);

    AppMessenger.info(context, 'δεύτερο');
    await tester.pumpAndSettle();

    expect(find.text('πρώτο'), findsNothing);
    expect(find.text('δεύτερο'), findsOneWidget);

    await _drain(tester);
  });

  testWidgets('persistent δεν αντικαθίσταται· το επόμενο εμφανίζεται μετά', (
    WidgetTester tester,
  ) async {
    final context = await _pumpHost(tester);

    AppMessenger.warning(
      context,
      'Μόνιμο',
      actionLabel: 'Κλείσιμο',
      onAction: () {},
    );
    await tester.pumpAndSettle();

    AppMessenger.success(context, 'Μετά');
    await tester.pumpAndSettle();

    expect(find.text('Μόνιμο'), findsOneWidget);
    expect(find.text('Μετά'), findsNothing);

    await tester.tap(find.text('Κλείσιμο'));
    await tester.pumpAndSettle();

    expect(find.text('Μόνιμο'), findsNothing);
    expect(find.text('Μετά'), findsOneWidget);

    await _drain(tester);
  });

  testWidgets('στενή οθόνη: width null (default περιθώρια)', (
    WidgetTester tester,
  ) async {
    final context = await _pumpHost(tester, size: const Size(400, 800));

    AppMessenger.info(context, 'Στενό');
    await tester.pumpAndSettle();

    expect(tester.widget<SnackBar>(find.byType(SnackBar)).width, isNull);

    await _drain(tester);
  });

  testWidgets('ρητό ScaffoldMessengerState (nested messenger)', (
    WidgetTester tester,
  ) async {
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    late BuildContext context;

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: <Widget>[
            Builder(
              builder: (BuildContext c) {
                context = c;
                return const SizedBox(height: 10);
              },
            ),
            Expanded(
              child: ScaffoldMessenger(
                key: messengerKey,
                child: const Scaffold(body: SizedBox.expand()),
              ),
            ),
          ],
        ),
      ),
    );

    AppMessenger.info(context, 'Nested', messenger: messengerKey.currentState);
    await tester.pumpAndSettle();

    expect(find.text('Nested'), findsOneWidget);

    await _drain(tester);
  });

  testWidgets('χωρίς ScaffoldMessenger δεν πετάει', (
    WidgetTester tester,
  ) async {
    late BuildContext context;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: Theme(
            data: ThemeData(),
            child: Builder(
              builder: (BuildContext c) {
                context = c;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );

    AppMessenger.info(context, 'Χωρίς messenger');
    expect(find.byType(SnackBar), findsNothing);
  });
}
