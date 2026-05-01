// ============================================================
// FILE: session.dart
// Ρόλος: Session data με user currency
// ============================================================

class Session {
  final String userId;
  final String defaultCurrency;

  const Session({
    required this.userId,
    required this.defaultCurrency,
  });
}
