import 'package:flutter/widgets.dart';
import 'session.dart';

class SessionScope extends InheritedWidget {
  final Session session;

  const SessionScope({
    super.key,
    required this.session,
    required super.child,
  });

  static Session of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    if (scope == null) {
      throw FlutterError(
        'SessionScope not found. Wrap your page with SessionScope before using it.',
      );
    }
    return scope.session;
  }

  @override
  bool updateShouldNotify(SessionScope oldWidget) =>
      oldWidget.session.userId != session.userId;
}

// ✅ convenience
extension SessionX on BuildContext {
  Session get session => SessionScope.of(this);

  // ✅ ΝΕΟΣ: Safe accessor που επιστρέφει null αν δεν υπάρχει
  Session? get sessionOrNull {
    try {
      return SessionScope.of(this);
    } catch (e) {
      return null;
    }
  }
}
