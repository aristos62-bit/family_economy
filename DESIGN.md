# Family Economy — DESIGN.md

> Σκοπός: αυστηρά τεχνολογίες, δομή και αρχιτεκτονική. Χωρίς ιστορικό αλλαγών/fixes (βλ. `oldsessions.md`).

## 1. Τεχνολογίες

| Τεχνολογία | Έκδοση (`pubspec.yaml`) | Χρήση |
|---|---|---|
| Flutter SDK | `^3.10.4` | UI framework (Android, iOS, Web, Windows, Linux, macOS) |
| Dart | `^3.10.4` | Γλώσσα |
| firebase_core | `^4.5.0` | Αρχικοποίηση Firebase |
| firebase_auth | `^6.2.0` | Authentication (email/password, persisted state) |
| cloud_firestore | `^6.1.3` | Βάση δεδομένων NoSQL, real-time listeners, offline persistence |
| provider | `^6.1.2` | State management (`ChangeNotifier`) |
| connectivity_plus | `^7.0.0` | Ανίχνευση online/offline |
| flutter_secure_storage | `^10.0.0` | Ασφαλής αποθήκευση credentials |
| local_auth | `^3.0.1` | Biometric authentication (fingerprint / Face ID) |
| shared_preferences | `^2.5.4` | Persist theme mode |
| flutter_local_notifications | `^18.0.1` | Τοπικές ειδοποιήσεις |
| timezone | `^0.10.1` | Ζώνες ώρας για ειδοποιήσεις |
| permission_handler | `^12.0.1` | Άδειες συστήματος |
| fl_chart | `^1.1.1` | Γραφήματα |
| pdf | `^3.11.3` | Εξαγωγή PDF |
| excel | `^4.0.6` | Εξαγωγή Excel |
| file_picker | `^10.3.10` | Επιλογή αρχείων |
| http | `^1.6.0` | HTTP requests |
| uuid | `^4.5.3` | Δημιουργία UUID (`uuid`, `transfer_group_id`) |
| intl | `^0.20.2` | Formatting ημερομηνιών/νομισμάτων |
| responsive_framework | `^1.5.1` | Responsive UI |
| flutter_phoenix | `^1.1.1` | Restart app (`Phoenix.rebirth`, `ErrorApp`) |
| cupertino_icons | `^1.0.8` | iOS icons |
| flutter_lints | `^6.0.0` | Linting (dev) |
| flutter_launcher_icons | `^0.14.4` | App icons (dev) |

Γραμματοσειρά: `NotoSans` (Regular, Bold, Italic) — `assets/fonts/`.
Assets: `assets/images/`, `assets/icons/` (accounts, categories income/expense, subcategories income/expense).

## 2. Δομή `lib/`

```
lib/
  main.dart                    # Entry point, Firebase init, MultiProvider, MaterialApp, ErrorApp
  firebase_options.dart        # Firebase config ανά πλατφόρμα

  core/
    accessibility/
      accessibility_service.dart
    services/
      auth_service.dart                 # Firebase Auth API
      biometric_auth_service.dart       # LocalAuth API
      biometric_settings_service.dart   # Biometric mode ανά χρήστη (always / on_demand)
      connectivity_service.dart         # Online/offline (ChangeNotifier, 2s debounce, onSyncComplete)
      database_cleanup_service.dart     # Καθαρισμός παλιών / soft-deleted
      message_service.dart              # SnackBar + μηνύματα sync
      transactions_actions_service.dart # ΜΟΝΑΔΙΚΟ σημείο CRUD transactions + balances (batch + FieldValue.increment)
    session/
      session.dart              # Data class: userId, defaultCurrency
      session_scope.dart        # InheritedWidget + extension context.session
    theme/
      app_theme.dart            # lightTheme / darkTheme (Material 3)
      ui_tokens.dart            # ColorsUI, TypographyUI
    utils/
      chart_helpers.dart
      currency_formatter.dart
      debug_config.dart         # Κεντρικός διακόπτης log (OFF σε production)
      icon_mapper.dart
    widgets/                    # Κοινά reusable widgets
      biometric_gate.dart
      calculator_engine.dart
      custom_currency_field.dart
      custom_text_field.dart
      helper_calculator_sheet.dart
      notification_edit_dialog.dart
      notifications_list_widget.dart
      offline_banner.dart
      tag_selector_widget.dart

  models/
    budget_model.dart           # BudgetModel + matchesTransaction(tx), budget_type, περίοδος, spent
    notification_model.dart     # NotificationModel + recurring (series, stop conditions)

  providers/                    # ChangeNotifier + StreamSubscription (real-time)
    accounts_provider.dart      # Accounts + local balance deltas
    budgets_provider.dart       # Budgets + calculateSpentAmountsFromCache (in-memory)
    categories_provider.dart    # Categories + subcategories
    notifications_provider.dart # Notifications + offline-first scheduling + recurring engine
    tags_provider.dart          # Tags (optimistic CRUD)
    theme_provider.dart         # ThemeMode (SharedPreferences)
    transactions_provider.dart  # Transactions ανά περίοδο + cache + φίλτρα

  presentation/
    auth/
      app_start.dart            # Auth gateway (auto-login / routing σε SessionScope)
      login_page.dart           # Login / Register
    dialogs/
      category_actions_dialog.dart
      category_type_selector_dialog.dart
      create_type_selector_dialog.dart
      edit_category_dialog.dart
    screens/
      accounts/accounts_page.dart
      budget/budget_page.dart
      budget/input_budget_page.dart
      calendar/calendar_page.dart
      categories/expense_categories_page.dart
      categories/income_categories_page.dart
      charts/chart_registry.dart
      charts/general_view_page.dart
      charts/graf_1_page.dart .. graf_6_page.dart
      charts/graf_7_monthly_trend_page.dart  # Πορεία ανά Μήνα (1/1 τρέχοντος έτους, toggle Έσοδα/Έξοδα, 1 μπλε γραμμή)
      charts/view_option_page.dart
      home/home_page.dart
      options/options_page.dart
      options/change_password_page.dart
      options/database_cleanup_page.dart
      options/delete_account_page.dart
      options/user_details_option.dart
      options/unit_converter_page.dart
      options/oil_page.dart + oil/  # oil.dart, tank_*.dart, purchase_*.dart, consumption_card.dart, dimensions_card.dart, utils.dart
      scheduled/scheduled_transactions_page.dart
      splash/splash_screen.dart
      stats/stats_page.dart
      stats/stats2_averages_page.dart
      stats/stats3_page.dart
      stats/stats4_budget_page.dart
      stats/tag_stats_page.dart
      tags/tags_management_page.dart
      transactions/transaction_entry_page.dart          # Multi-step entry
      transactions/transaction_entry_accounts_step.dart
      transactions/transaction_entry_details_step.dart
      transactions/transaction_entry_state.dart
      transactions/transactions_show_page.dart
      transactions/widgets/transaction_edit_sheet.dart

  services/
    account_duplicate_service.dart
    notifications_service.dart            # Singleton flutter_local_notifications (initialize/schedule/cancel/show)
    onboarding_service.dart               # Πρώτη εγκατάσταση: default account, categories, subcategories
    recurring_notifications_service.dart  # Ανενεργό / νεκρός κώδικας (generateAhead σχολιασμένο)
    scheduled_transactions_service.dart   # Μελλοντικά income/expense/transfer (is_scheduled, is_executed)
```

## 3. Αρχιτεκτονική

### Layers

```
Presentation (Widgets / Pages)
  ↓ context.watch / context.read
Providers (ChangeNotifier, StreamSubscription snapshots)
  ↓ read real-time
Firestore (users/{userId}/...)
  ↑ write: provider methods (optimistic local + background Firestore)
  ↑ write: Core Services (TransactionsActionsService, ScheduledTransactionsService)
```

- **State management:** αποκλειστικά `Provider` (`ChangeNotifier`). Όχι Bloc/Riverpod.
- **Firestore access:** μόνο από Providers ή Services. Ποτέ απευθείας από widgets.
- **Real-time:** κάθε Provider κρατά `StreamSubscription` (`snapshots()`). Σε `permission-denied` (logout) σταματά τους listeners χωρίς spam.
- **Optimistic updates:** άμεση αλλαγή local state → `notifyListeners()` → Firestore write στο background.
- **Offline-first:** `Settings(persistenceEnabled: true, cacheSizeUnlimited)` (`main.dart:64`). Pending writes επιτρέπονται.
- **Connectivity:** `ConnectivityService` με 2s debounce → `onSyncComplete` → `MessageService.showSyncComplete`.
- **Balances:** ΜΟΝΟ `TransactionsActionsService` (batch + `FieldValue.increment`). Κανένα άλλο σημείο δεν αλλάζει υπόλοιπα.
- **Budgets spent:** `transactionsP.getTransactionsForPeriod('BUDGETS_PAGE')` → `budgetsP.calculateSpentAmountsFromCache(txs)` — 1 pass in-memory, 0 extra queries. Content-aware hash (`id:amount`) για αποφυγή άσκοπων recalc.

### Session

- `Session(userId, defaultCurrency)` (`core/session/session.dart`).
- `SessionScope` (`InheritedWidget`) + `context.session / context.sessionOrNull`.
- Δημιουργείται στο `app_start.dart` μετά από επιτυχημένο login και τυλίγει όλο το tree.

### Startup flow (`main.dart`)

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `ThemeProvider.initialize()` (SharedPreferences)
3. `NotificationsService().initialize()`
4. `ConnectivityService()` δημιουργία instance
5. `Firebase.initializeApp(options)`
6. `FirebaseAuth.authStateChanges().first` με 2s timeout (persisted user, κυρίως Windows)
7. `Firestore.settings = Settings(persistenceEnabled: true, cacheSizeUnlimited)`
8. `Firestore.setLoggingEnabled(DebugConfig.isDebug)`
9. `runApp(MultiProvider(ThemeProvider, ConnectivityService) → MyApp)`
10. `MyApp` (StatefulWidget, `Phoenix` wrapper, `navigatorKey`, localization el-GR/en-US, Material 3 themes, textScaler clamp 0.85–1.45, `AnnouncementOverlay`) → `SplashScreen`
11. Fallback: `ErrorApp` (κόκκινη οθόνη + `Phoenix.rebirth`)

## 4. Firebase (Firestore)

### Collections

```
exchange_rates/{rateId}          # Global, read-only

users/{userId}/
  accounts/{accountId}
  account_snapshots/{snapshotId}
  attachments/{attachmentId}
  budgets/{budgetId}             # budget_type: total / category / subcategory
  categories/{categoryId}/subcategories/{subcategoryId}
  notifications/{notificationId} # recurring: series + stop condition
  oil_purchases/{purchaseId}
  settings/{settingId}
  tags/{tagId}
  transactions/{transactionId}   # income / expense / transfer / scheduled
  transaction_splits/{splitId}
  transaction_tags/{tagLinkId}
```

### Indexes (`firestore.indexes.json`)

| Collection | Πεδία |
|---|---|
| transactions | `account_id ASC`, `deleted ASC`, `date DESC`, `__name__ DESC` (SPARSE_ALL) |
| transactions | `user_id ASC`, `is_scheduled ASC`, `is_executed ASC`, `deleted ASC`, `scheduled_for_date ASC` |
| transactions | `is_scheduled ASC`, `is_executed ASC`, `deleted ASC`, `scheduled_for_date ASC` |

### Security Rules (`firestore.rules`)

- `users/{userId}` και όλες οι subcollections: `allow read/create/update/delete if isSignedIn() && request.auth.uid == userId`.
- `categories/{categoryId}/{allSubcollections=**}`: recursive wildcard για subcategories.
- `exchange_rates`: `allow read: true`, `allow write: false`.

### Soft-delete + sync

- Αντί διαγραφής: `deleted: boolean`.
- Πεδία συγχρονισμού: `uuid`, `updated_at`, `last_modified_device_id`, `deleted`.

## 5. Βασικά patterns

- **Μεταφορές:** 2 transaction docs με κοινό `transfer_group_id` (πηγή αρνητική, προορισμός θετική).
- **Notifications:** offline-first (local schedule → Firestore write). Recurring με υποχρεωτική συνθήκη τερματισμού (end date Ή max occurrences).
- **Onboarding:** `OnboardingService` φτιάχνει default account + categories + subcategories σε νέο χρήστη.
- **Scheduled:** `is_scheduled=true`, `is_executed=false`, `scheduled_for_date` για μελλοντικές εκτελέσεις.
- **Theme:** Material 3 (`useMaterial3: true`), light/dark/system, persist με SharedPreferences.
- **Localization:** `el-GR` (προεπιλογή), fallback `en-US`.
- **Logging:** `DebugConfig.print/startup/isDebug`, default OFF. `FirebaseFirestore.setLoggingEnabled(DebugConfig.isDebug)`.
