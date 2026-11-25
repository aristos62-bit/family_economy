// E58: η εκκίνηση πρέπει να είναι ανθεκτική — τα βοηθητικά βήματα είναι
// best-effort με όριο χρόνου, το connectivity διαδίδεται και το retry
// επαναχρησιμοποιεί τα ίδια instances.
import 'dart:async';

import 'package:family_economy/core/services/connectivity_service.dart';
import 'package:family_economy/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _FakeConnectivity extends ChangeNotifier implements ConnectivityService {
  @override
  bool isOnline = true;

  @override
  bool isOffline = false;

  @override
  bool isInitialized = true;

  @override
  bool isConfirmedOffline = false;
}

void main() {
  setUp(resetStartupForTest);

  test('prepareStartup εκτελεί theme → notifications → connectivity', () async {
    final order = <String>[];
    final fake = _FakeConnectivity();

    final deps = await prepareStartup(
      initTheme: () async => order.add('theme'),
      initNotifications: () async => order.add('notifications'),
      createConnectivity: () {
        order.add('connectivity');
        return fake;
      },
    );

    expect(order, ['theme', 'notifications', 'connectivity']);
    expect(identical(deps.connectivityService, fake), isTrue);
  });

  test('prepareStartup συνεχίζει όταν το theme κολλήσει', () async {
    final fake = _FakeConnectivity();
    var notificationsRan = false;

    await prepareStartup(
      initTheme: () => Completer<void>().future,
      themeTimeout: const Duration(milliseconds: 10),
      initNotifications: () async => notificationsRan = true,
      createConnectivity: () => fake,
    );

    expect(notificationsRan, isTrue);
  });

  test('prepareStartup συνεχίζει όταν οι ειδοποιήσεις αποτύχουν', () async {
    final fake = _FakeConnectivity();

    final deps = await prepareStartup(
      initTheme: () async {},
      initNotifications: () async => throw Exception('notifications down'),
      createConnectivity: () => fake,
    );

    expect(identical(deps.connectivityService, fake), isTrue);
  });

  test('prepareStartup διαδίδει σφάλμα από το connectivity', () async {
    await expectLater(
      prepareStartup(
        initTheme: () async {},
        initNotifications: () async {},
        createConnectivity: () => throw Exception('no plugin'),
      ),
      throwsException,
    );
  });

  test('η επανάληψη επαναχρησιμοποιεί το ίδιο ConnectivityService', () async {
    var created = 0;
    final fake = _FakeConnectivity();

    final first = await prepareStartup(
      initTheme: () async {},
      initNotifications: () async {},
      createConnectivity: () {
        created++;
        return fake;
      },
    );

    final second = await prepareStartup(
      initTheme: () async {},
      initNotifications: () async {},
      createConnectivity: () {
        created++;
        return _FakeConnectivity();
      },
    );

    expect(created, 1);
    expect(
      identical(first.connectivityService, second.connectivityService),
      isTrue,
    );
  });
}
