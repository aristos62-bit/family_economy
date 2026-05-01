import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'dart:io' show Platform;

class AccessibilityService {
  AccessibilityService._internal();
  static final AccessibilityService instance = AccessibilityService._internal();

  static DateTime? _lastAnnouncementAt;
  static String? _lastAnnouncement;
  static String? _lastAnnouncementHash;
  static Timer? _debounceTimer;

  static const Duration _minAnnouncementGap = Duration(milliseconds: 700);
  static const Duration _debounceDelay = Duration(milliseconds: 120);


  // ✅ ValueNotifier για το νέο liveRegion-based announcement σύστημα.
  // Αντί για deprecated sendAnnouncement(), αλλάζουμε απλά αυτή την τιμή
  // και το AnnouncementOverlay widget (που κάθεται στο tree) αντιδρά αυτόματα.
  static final ValueNotifier<String> announcementNotifier =
      ValueNotifier<String>('');

  static void announce(
      String message, {
        TextDirection textDirection = TextDirection.ltr,
        Assertiveness assertiveness = Assertiveness.polite,
      }) {
    final cleaned = message.trim();
    if (cleaned.isEmpty) return;

    // 🚫 Windows fix
    if (Platform.isWindows) {
      return;
    }

    final now = DateTime.now();

    // 🔁 Global hash-guard: αν είναι ΑΚΡΙΒΩΣ ίδιο με το προηγούμενο, κόψτο
    final hash = cleaned.hashCode.toString();
    if (_lastAnnouncementHash == hash &&
        _lastAnnouncementAt != null &&
        now.difference(_lastAnnouncementAt!) < _minAnnouncementGap) {
      DebugConfig.print('🔇 Accessibility: global duplicate blocked');
      return;
    }
    _lastAnnouncementHash = hash;

    if (_lastAnnouncement == cleaned &&
        _lastAnnouncementAt != null &&
        now.difference(_lastAnnouncementAt!) < _minAnnouncementGap) {
      return;
    }

    _lastAnnouncement = cleaned;
    _lastAnnouncementAt = now;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () {
      try {
        announcementNotifier.value = cleaned;
        DebugConfig.print('🔊 Accessibility announce: $cleaned');
      } catch (e) {
        DebugConfig.print('⚠️ Accessibility announce failed: $e');
      }
    });
  }


  static void announcePolite(String message) =>
      announce(message, assertiveness: Assertiveness.polite);

  static void announceAssertive(String message) =>
      announce(message, assertiveness: Assertiveness.assertive);

  static void announceLiveRegion(String message, {bool assertive = false}) {
    announce(
      message,
      assertiveness: assertive ? Assertiveness.assertive : Assertiveness.polite,
    );
  }

  /// Χρήσιμο όταν αλλάζει route / μετά από build (π.χ. Splash, μετά navigation).
  static Future<void> announceDelayed(
    String message, {
    Duration delay = const Duration(milliseconds: 300),
    TextDirection textDirection = TextDirection.ltr,
    Assertiveness assertiveness = Assertiveness.polite,
  }) async {
    await Future.delayed(delay);
    announce(
      message,
      textDirection: textDirection,
      assertiveness: assertiveness,
    );
  }

  /// Ανακοίνωση αμέσως μετά το πρώτο frame (πολύ αξιόπιστο).
  static void announceAfterFirstFrame(
    BuildContext context,
    String message, {
    TextDirection textDirection = TextDirection.ltr,
    Assertiveness assertiveness = Assertiveness.polite,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Αν έχει γίνει dispose το route/widget, απλά μην ανακοινώσεις.
      if (!context.mounted) return;
      announce(
        message,
        textDirection: textDirection,
        assertiveness: assertiveness,
      );
    });
  }

  // ============================================================
  // 🔁 FOCUS MANAGEMENT
  // ============================================================

  static void requestFocus(BuildContext context, FocusNode node) {
    // ✅ Απλά δίνουμε focus — ο screen reader αναλαμβάνει αυτόματα
    // να ανακοινώσει το label και τον τύπο του πεδίου.
    // Δεν προσθέτουμε δική μας ανακοίνωση για να αποφύγουμε
    // διπλή ανακοίνωση (system + εμείς).
    FocusScope.of(context).requestFocus(node);
  }

  static void focusNext(BuildContext context) =>
      FocusScope.of(context).nextFocus();
  static void focusPrevious(BuildContext context) =>
      FocusScope.of(context).previousFocus();
  static void unfocus(BuildContext context) => FocusScope.of(context).unfocus();

  // ============================================================
  // 🏷️ SEMANTIC HELPERS
  // ============================================================

  static Widget accessibleContainer({
    required Widget child,
    required String label,
    String? hint,
    String? value,
    bool isButton = false,
    bool isHeader = false,
    bool isLink = false,
    bool isImage = false,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      value: value,
      button: isButton,
      header: isHeader,
      link: isLink,
      image: isImage,
      enabled: enabled,
      // Προσοχή: βάλε onTap ΜΟΝΟ αν το child δεν έχει δικό του tap handler.
      onTap: onTap,
      child: child,
    );
  }

  /// ✅ ΔΙΟΡΘΩΣΗ: Δεν βάζουμε onTap και στο Semantics ΚΑΙ στο InkWell,
  /// γιατί μπορεί να προκαλέσει διπλά events/παράξενη συμπεριφορά σε TalkBack.
  static Widget accessibleButton({
    required Widget child,
    required String label,
    String? hint,
    VoidCallback? onPressed,
    bool enabled = true,
  }) {
    final canTap = enabled && onPressed != null;

    return Semantics(
      // ✅ Το Semantics δίνει ΜΟΝΟ το “νόημα”
      // και ΔΕΝ βάζουμε onTap εδώ για να μην έχουμε διπλά events.
      label: label,
      hint: hint,
      button: true,
      enabled: canTap,

      // ✅ Αυτό κόβει το ενδεχόμενο να διαβαστεί και το child (π.χ. Text)
      // δεύτερη φορά από screen reader.
      excludeSemantics: true,

      child: InkWell(onTap: canTap ? onPressed : null, child: child),
    );
  }

  static Widget accessibleTextField({
    required Widget child,
    required String label,
    String? hint,
    String? value,
    bool isPassword = false,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      value: value,
      textField: true,
      obscured: isPassword,
      child: child,
    );
  }

  static Widget decorative(Widget child) => ExcludeSemantics(child: child);
  static Widget merged({required Widget child}) => MergeSemantics(child: child);

  // ============================================================
  // 🧠 SMART LABEL HELPERS (προαιρετικά)
  // ============================================================

  static String currencyLabel(double amount, String currency) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final totalCents = (absAmount * 100).round();
    final euros = totalCents ~/ 100;
    final cents = totalCents % 100;

    final prefix = isNegative ? 'Μείον ' : '';
    final eurosText = '$euros ${currency == 'EUR' ? 'ευρώ' : currency}';
    final centsText = cents > 0 ? ' και $cents λεπτά' : '';

    return '$prefix$eurosText$centsText';
  }

  static String dateLabel(DateTime date) {
    const monthNames = [
      'Ιανουάριος',
      'Φεβρουάριος',
      'Μάρτιος',
      'Απρίλιος',
      'Μάιος',
      'Ιούνιος',
      'Ιούλιος',
      'Αύγουστος',
      'Σεπτέμβριος',
      'Οκτώβριος',
      'Νοέμβριος',
      'Δεκέμβριος',
    ];
    return '${monthNames[date.month - 1]} ${date.day}, ${date.year}';
  }

  static String transactionTypeLabel(
    String type,
    double amount,
    String category,
  ) {
    final amountLabel = currencyLabel(amount, 'EUR');
    final typeLabel = type == 'income'
        ? 'Έσοδο'
        : type == 'expense'
        ? 'Έξοδο'
        : 'Μεταφορά';
    return '$typeLabel $amountLabel στην κατηγορία $category';
  }

  static String accountBalanceLabel(
    String accountName,
    double balance,
    String currency,
  ) {
    final balanceLabel = currencyLabel(balance, currency);
    return 'Υπόλοιπο λογαριασμού $accountName: $balanceLabel';
  }

  static void announceTransactionAdded(
    String type,
    double amount,
    String category,
  ) {
    announcePolite(transactionTypeLabel(type, amount, category));
  }

  static void announceBalanceUpdate(
    double oldBalance,
    double newBalance,
    String currency,
  ) {
    final diff = newBalance - oldBalance;
    final diffLabel = currencyLabel(diff.abs(), currency);
    final action = diff > 0 ? 'αυξήθηκε' : 'μειώθηκε';

    announcePolite(
      'Το υπόλοιπο $action κατά $diffLabel. Νέο υπόλοιπο: ${currencyLabel(newBalance, currency)}',
    );
  }

  static void announceError(String error) =>
      announceAssertive('Σφάλμα: $error');
  static void announceSuccess(String message) => announcePolite(message);

  // ============================================================
  // 🧩 ENVIRONMENT HELPERS
  // ============================================================

  /// ⚠️ NOTE:
  /// `accessibleNavigation` ΔΕΝ σημαίνει "screen reader ενεργό".
  /// Σημαίνει προτίμηση χρήστη για πιο απλή πλοήγηση (π.χ. μειωμένα animations).
  static bool prefersAccessibleNavigation(BuildContext context) =>
      MediaQuery.of(context).accessibleNavigation;

  static bool isBoldTextEnabled(BuildContext context) =>
      MediaQuery.of(context).boldText;

  static double getTextScaleFactor(BuildContext context) =>
      MediaQuery.of(context).textScaler.scale(1.0);

  /// ✅ Επιστρέφει true αν ο χρήστης έχει ενεργοποιήσει "Reduce Motion"
  /// στις ρυθμίσεις προσβασιμότητας της συσκευής του.
  ///
  /// Χρήση: αν είναι true, παράλειψε ή απλοποίησε τα animations
  /// για χρήστες με vestibular disorders ή άλλες ανάγκες.
  ///
  /// Παράδειγμα:
  /// ```dart
  /// final reducedMotion = AccessibilityService.prefersReducedMotion(context);
  /// duration: reducedMotion ? Duration.zero : const Duration(milliseconds: 1500),
  /// ```
  static bool prefersReducedMotion(BuildContext context) =>
      MediaQuery.of(context).disableAnimations;

  static void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    announcementNotifier.dispose();
  }
}

// ============================================================
// 🔗 ACCESSIBILITY EXTENSIONS
// ============================================================

extension AccessibilityExtension on BuildContext {
  bool get prefersAccessibleNav =>
      AccessibilityService.prefersAccessibleNavigation(this);

  bool get isBoldTextActive => AccessibilityService.isBoldTextEnabled(this);
  double get textScale => AccessibilityService.getTextScaleFactor(this);
  bool get reducedMotion => AccessibilityService.prefersReducedMotion(this);

  void announce(String message, {bool assertive = false}) {
    AccessibilityService.announce(
      message,
      assertiveness: assertive ? Assertiveness.assertive : Assertiveness.polite,
    );
  }
}
// ============================================================
// 📢 ANNOUNCEMENT OVERLAY WIDGET
// ============================================================

/// ✅ Αυτό το widget πρέπει να τυλίγει το MaterialApp (ή το root widget).
/// Είναι εντελώς αόρατο — απλά "ακούει" το announcementNotifier
/// και ανακοινώνει αλλαγές μέσω liveRegion στον screen reader.
///
/// Χρήση στο main.dart ή στο root widget:
/// ```dart
/// AnnouncementOverlay(child: MaterialApp(...))
/// ```
class AnnouncementOverlay extends StatefulWidget {
  final Widget child;
  const AnnouncementOverlay({super.key, required this.child});

  @override
  State<AnnouncementOverlay> createState() => _AnnouncementOverlayState();
}

class _AnnouncementOverlayState extends State<AnnouncementOverlay> {

  @override
  void initState() {
    super.initState();
    AccessibilityService.announcementNotifier.addListener(
      _onAnnouncementChanged,
    );
  }

  void _onAnnouncementChanged() {
    if (!mounted) return;
    final message = AccessibilityService.announcementNotifier.value;
    if (message.isEmpty) return;
    final view = View.of(context);
    SemanticsService.sendAnnouncement(view, message, TextDirection.ltr);
  }

  @override
  void dispose() {
    AccessibilityService.announcementNotifier.removeListener(
      _onAnnouncementChanged,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Απλό passthrough — κανένα liveRegion widget στο tree.
    return widget.child;
  }
}
