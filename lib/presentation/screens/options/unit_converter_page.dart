// ============================================================
// FILE: converter_page.dart
// Path: lib/presentation/screens/options/converter_page.dart
// Ρόλος: Μετατροπή μονάδων: Μήκος, Βάρος, Υγρά, Βάρος↔Υγρά,
//         Νομίσματα (live), Crypto top-10 (live)
// ✅ Dark mode | Accessibility | ConnectivityService | Offline-safe
// ============================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/services/connectivity_service.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/utils/debug_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ──────────────────Fvoid initState() {───────────────────────────────────────────
// UNIT MODELS
// ─────────────────────────────────────────────────────────────

class _Unit {
  final String id;
  final String label;
  final double toBase; // factor to convert TO base unit

  const _Unit({required this.id, required this.label, required this.toBase});
}

// ─────────────────────────────────────────────────────────────
// SUBSTANCE for weight↔volume cross-conversion
// density in kg/L
// ─────────────────────────────────────────────────────────────

class _Substance {
  final String label;
  final double density; // kg per liter

  const _Substance({required this.label, required this.density});
}

// ─────────────────────────────────────────────────────────────
// CRYPTO MODEL
// ─────────────────────────────────────────────────────────────

class _CryptoItem {
  final String id;
  final String name;
  final String symbol;
  final String? image;
  final double price;
  final double change24h;
  final double marketCap;
  final double volume24h;

  const _CryptoItem({
    required this.id,
    required this.name,
    required this.symbol,
    this.image,
    required this.price,
    required this.change24h,
    required this.marketCap,
    required this.volume24h,
  });

  factory _CryptoItem.fromJson(Map<String, dynamic> j) => _CryptoItem(
    id: j['id'] as String,
    name: j['name'] as String,
    symbol: (j['symbol'] as String).toUpperCase(),
    image: j['image'] as String?,
    price: (j['current_price'] as num?)?.toDouble() ?? 0,
    change24h:
    (j['price_change_percentage_24h'] as num?)?.toDouble() ?? 0,
    marketCap: (j['market_cap'] as num?)?.toDouble() ?? 0,
    volume24h: (j['total_volume'] as num?)?.toDouble() ?? 0,
  );
}

// ─────────────────────────────────────────────────────────────
// UNIT DEFINITIONS
// ─────────────────────────────────────────────────────────────

// BASE: meters
const _lengthUnits = <_Unit>[
  _Unit(id: 'mm',   label: 'Χιλιοστόμετρο (mm)',    toBase: 0.001),
  _Unit(id: 'cm',   label: 'Εκατοστόμετρο (cm)',     toBase: 0.01),
  _Unit(id: 'dm',   label: 'Δεκατόμετρο (dm)',       toBase: 0.1),
  _Unit(id: 'm',    label: 'Μέτρο (m)',              toBase: 1.0),
  _Unit(id: 'km',   label: 'Χιλιόμετρο (km)',        toBase: 1000.0),
  _Unit(id: 'in',   label: 'Ίντσα (in)',             toBase: 0.0254),
  _Unit(id: 'ft',   label: 'Πόδι (ft)',              toBase: 0.3048),
  _Unit(id: 'yd',   label: 'Γιάρδα (yd)',            toBase: 0.9144),
  _Unit(id: 'mi',   label: 'Μίλι (mi)',              toBase: 1609.344),
  _Unit(id: 'nmi',  label: 'Ναυτικό μίλι (nmi)',     toBase: 1852.0),
];

// BASE: grams
const _weightUnits = <_Unit>[
  _Unit(id: 'mg',  label: 'Χιλιοστόγραμμο (mg)', toBase: 0.001),
  _Unit(id: 'g',   label: 'Γραμμάριο (g)',        toBase: 1.0),
  _Unit(id: 'kg',  label: 'Κιλό (kg)',            toBase: 1000.0),
  _Unit(id: 'ton', label: 'Τόνος (t)',            toBase: 1000000.0),
  _Unit(id: 'oz',  label: 'Ουγγιά (oz)',          toBase: 28.3495),
  _Unit(id: 'lb',  label: 'Λίμπρα (lb)',          toBase: 453.592),
  _Unit(id: 'st',  label: 'Στόνο (st)',           toBase: 6350.29),
];

// BASE: milliliters
const _volumeUnits = <_Unit>[
  _Unit(id: 'ml',      label: 'Χιλιοστόλιτρο (mL)',   toBase: 1.0),
  _Unit(id: 'cl',      label: 'Εκατοστόλιτρο (cL)',    toBase: 10.0),
  _Unit(id: 'dl',      label: 'Δεκατόλιτρο (dL)',      toBase: 100.0),
  _Unit(id: 'l',       label: 'Λίτρο (L)',             toBase: 1000.0),
  _Unit(id: 'm3',      label: 'Κυβικό μέτρο (m³)',     toBase: 1000000.0),
  _Unit(id: 'floz_us', label: 'Fl. oz US',             toBase: 29.5735),
  _Unit(id: 'cup_us',  label: 'Cup US',                toBase: 236.588),
  _Unit(id: 'pt_us',   label: 'Pint US',               toBase: 473.176),
  _Unit(id: 'qt_us',   label: 'Quart US',              toBase: 946.353),
  _Unit(id: 'gal_us',  label: 'Gallon US',             toBase: 3785.41),
  _Unit(id: 'floz_uk', label: 'Fl. oz UK',             toBase: 28.4131),
  _Unit(id: 'pt_uk',   label: 'Pint UK',               toBase: 568.261),
  _Unit(id: 'gal_uk',  label: 'Gallon UK',             toBase: 4546.09),
];

const _substances = <_Substance>[
  _Substance(label: 'Νερό',          density: 1.000),
  _Substance(label: 'Γάλα (αγελ.)', density: 1.030),
  _Substance(label: 'Ελαιόλαδο',    density: 0.916),
  _Substance(label: 'Ηλιέλαιο',     density: 0.920),
  _Substance(label: 'Κρασί',        density: 0.990),
  _Substance(label: 'Μέλι',         density: 1.420),
  _Substance(label: 'Αλεύρι',       density: 0.593),
  _Substance(label: 'Ζάχαρη',       density: 0.849),
  _Substance(label: 'Αλάτι',        density: 1.217),
  _Substance(label: 'Βούτυρο',      density: 0.911),
];

const _currencyCodes = [
  'EUR','USD','GBP','JPY','CHF','AUD','CAD','CNY',
  'SEK','NOK','DKK','PLN','CZK','HUF','RON','BGN',
  'TRY','RUB','INR','BRL','MXN','ZAR','SGD','HKD',
];

const _currencyNames = {
  'EUR': 'Ευρώ',       'USD': 'Αμερ. Δολάριο',  'GBP': 'Βρετ. Λίρα',
  'JPY': 'Ιαπ. Γεν',  'CHF': 'Ελβ. Φράγκο',    'AUD': 'Αυστρ. Δολάριο',
  'CAD': 'Καναδ. Δολάριο', 'CNY': 'Κιν. Γιουάν','SEK': 'Σουηδ. Κορόνα',
  'NOK': 'Νορβ. Κορόνα',  'DKK': 'Δαν. Κορόνα', 'PLN': 'Πολ. Ζλότι',
  'CZK': 'Τσεχ. Κορόνα',  'HUF': 'Ουγγρ. Φιορίνι','RON': 'Ρουμ. Λέου',
  'BGN': 'Βουλγ. Λέβα',   'TRY': 'Τουρκ. Λίρα', 'RUB': 'Ρωσ. Ρούβλι',
  'INR': 'Ινδ. Ρουπία',   'BRL': 'Βραζ. Ρεάλ',  'MXN': 'Μεξ. Πέσο',
  'ZAR': 'Ν.Αφρ. Ραντ',   'SGD': 'Δολ. Σινγκαπ.','HKD': 'Δολ. Χ. Κονγκ',
};

// Σύμβολα νομισμάτων για εμφάνιση στο badge
const _currencySymbols = {
  'EUR': '€',  'USD': '\$',  'GBP': '£',  'JPY': '¥',
  'CHF': 'CHF','AUD': 'A\$', 'CAD': 'CA\$','CNY': '¥',
  'SEK': 'kr', 'NOK': 'kr',  'DKK': 'kr', 'PLN': 'zł',
  'CZK': 'Kč', 'HUF': 'Ft',  'RON': 'lei','BGN': 'лв',
  'TRY': '₺',  'RUB': '₽',   'INR': '₹',  'BRL': 'R\$',
  'MXN': 'MX\$','ZAR': 'R',  'SGD': 'S\$','HKD': 'HK\$',
};

// ─────────────────────────────────────────────────────────────
// TABS ENUM
// ─────────────────────────────────────────────────────────────
enum _ConverterTab { length, weight, volume, crossConvert, currency, crypto }

// ─────────────────────────────────────────────────────────────
// MAIN PAGE
// ─────────────────────────────────────────────────────────────

class ConverterPage extends StatefulWidget {
  const ConverterPage({super.key});

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;

  // ── Μήκος ────────────────────────────────────
  _Unit _fromLength = _lengthUnits[3]; // m
  _Unit _toLength   = _lengthUnits[4]; // km
  final _fromLengthCtrl = TextEditingController(text: '1');
  final _toLengthCtrl   = TextEditingController();
  bool  _lengthFromFocus = true;

  // ── Βάρος ────────────────────────────────────
  _Unit _fromWeight = _weightUnits[2]; // kg
  _Unit _toWeight   = _weightUnits[5]; // lb
  final _fromWeightCtrl = TextEditingController(text: '1');
  final _toWeightCtrl   = TextEditingController();
  bool  _weightFromFocus = true;

  // ── Υγρά ─────────────────────────────────────
  _Unit _fromVol = _volumeUnits[3]; // L
  _Unit _toVol   = _volumeUnits[9]; // gal_us
  final _fromVolCtrl = TextEditingController(text: '1');
  final _toVolCtrl   = TextEditingController();
  bool  _volFromFocus = true;

  // ── Cross-convert ────────────────────────────
  // Βάρος ↔ Υγρά ανά ουσία
  _Substance _substance = _substances[0]; // νερό
  bool _crossFromWeight = true; // true=βάρος→υγρά, false=υγρά→βάρος
  _Unit _crossWeightUnit = _weightUnits[2]; // kg
  _Unit _crossVolUnit    = _volumeUnits[3]; // L
  final _crossFromCtrl = TextEditingController(text: '1');
  final _crossToCtrl   = TextEditingController();

  // ── Νομίσματα ────────────────────────────────
  String _fromCurrency = 'EUR';
  String _toCurrency   = 'USD';
  final _fromCurrCtrl = TextEditingController(text: '1');
  final _toCurrCtrl   = TextEditingController();
  bool   _currFromFocus = true;

  Map<String, double>? _currencyRates; // EUR-based
  DateTime? _ratesUpdatedAt;
  bool _currencyLoading = false;
  String? _currencyError;

  // ── Crypto: κατάλογος για αναζήτηση ─────────
  List<_CryptoItem> _cryptoCatalog = [];
  bool _catalogLoading = false;

  // ── Crypto: παρακολουθούμενα ────────────────
  final List<String> _watchedIds = [];
  final Map<String, _CryptoItem> _watchedData = {};
  bool _watchedLoading = false;
  String? _cryptoError;
  DateTime? _cryptoUpdatedAt;

  DateTime? _lastRefresh;
  DateTime? _rateLimitUntil;
  bool _isRefreshing = false;

  // ── Crypto: μετατροπή ───────────────────────
  String? _convFromId;
  String? _convToId;
  final  _convAmtCtrl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    AccessibilityService.announceAfterFirstFrame(
      context,
      'Μετατροπέας Μονάδων. Μήκος, Βάρος, Υγρά, Νομίσματα και Crypto.',
    );
    _loadWatchedIds(); // ← φόρτωσε αποθηκευμένα IDs
    _tabController.addListener(() {
      setState(() {});
      final tab = _ConverterTab.values[_tabController.index];
      if (tab == _ConverterTab.currency && _currencyRates == null) {
        _fetchCurrencyRates();
      }
      if (tab == _ConverterTab.crypto && _cryptoCatalog.isEmpty) {
        _fetchCryptoCatalog();
      }
    });
    // Initial calculations
    _calcLength();
    _calcWeight();
    _calcVolume();
    _calcCross();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fromLengthCtrl.dispose(); _toLengthCtrl.dispose();
    _fromWeightCtrl.dispose(); _toWeightCtrl.dispose();
    _fromVolCtrl.dispose();    _toVolCtrl.dispose();
    _crossFromCtrl.dispose();  _crossToCtrl.dispose();
    _fromCurrCtrl.dispose();   _toCurrCtrl.dispose();
    _convAmtCtrl.dispose();
    super.dispose();
  }

  // ── Conversion helpers ────────────────────────

  double _convert(double value, _Unit from, _Unit to) {
    final inBase = value * from.toBase;
    return inBase / to.toBase;
  }

  String _fmt(double v) {
    if (v == 0) return '0';
    if (v.abs() >= 1e10 || (v.abs() < 1e-6 && v != 0)) {
      return v.toStringAsExponential(6);
    }
    // Smart precision
    final s = v.toStringAsFixed(10).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    // Max 10 digits shown
    final parts = s.split('.');
    if (parts.length == 1) return parts[0];
    return '${parts[0]}.${parts[1].substring(0, parts[1].length.clamp(0, 8))}';
  }

  void _calcLength() {
    final val = double.tryParse(_fromLengthCtrl.text.replaceAll(',', '.')) ?? 0;
    _toLengthCtrl.text = _fmt(_convert(val, _fromLength, _toLength));
  }

  void _calcLengthReverse() {
    final val = double.tryParse(_toLengthCtrl.text.replaceAll(',', '.')) ?? 0;
    _fromLengthCtrl.text = _fmt(_convert(val, _toLength, _fromLength));
  }

  void _calcWeight() {
    final val = double.tryParse(_fromWeightCtrl.text.replaceAll(',', '.')) ?? 0;
    _toWeightCtrl.text = _fmt(_convert(val, _fromWeight, _toWeight));
  }

  void _calcWeightReverse() {
    final val = double.tryParse(_toWeightCtrl.text.replaceAll(',', '.')) ?? 0;
    _fromWeightCtrl.text = _fmt(_convert(val, _toWeight, _fromWeight));
  }

  void _calcVolume() {
    final val = double.tryParse(_fromVolCtrl.text.replaceAll(',', '.')) ?? 0;
    _toVolCtrl.text = _fmt(_convert(val, _fromVol, _toVol));
  }

  void _calcVolumeReverse() {
    final val = double.tryParse(_toVolCtrl.text.replaceAll(',', '.')) ?? 0;
    _fromVolCtrl.text = _fmt(_convert(val, _toVol, _fromVol));
  }

  void _calcCross() {
    final val = double.tryParse(_crossFromCtrl.text.replaceAll(',', '.')) ?? 0;
    if (_crossFromWeight) {
      // kg → L: litres = grams / (density * 1000) → kg / density
      final grams = val * _crossWeightUnit.toBase; // in grams
      final kg = grams / 1000.0;
      final litres = kg / _substance.density;
      final ml = litres * 1000.0;
      _crossToCtrl.text = _fmt(ml / _crossVolUnit.toBase);
    } else {
      // L → kg: kg = litres * density
      final ml = val * _crossVolUnit.toBase;
      final litres = ml / 1000.0;
      final kg = litres * _substance.density;
      final grams = kg * 1000.0;
      _crossToCtrl.text = _fmt(grams / _crossWeightUnit.toBase);
    }
  }

  void _calcCurrency() {
    if (_currencyRates == null) return;
    if (_currFromFocus) {
      final val = double.tryParse(_fromCurrCtrl.text.replaceAll(',', '.')) ?? 0;
      final rateFrom = _currencyRates![_fromCurrency] ?? 1.0;
      final rateTo   = _currencyRates![_toCurrency]   ?? 1.0;
      final eur = val / rateFrom;
      _toCurrCtrl.text = _fmt(eur * rateTo);
    } else {
      final val = double.tryParse(_toCurrCtrl.text.replaceAll(',', '.')) ?? 0;
      final rateFrom = _currencyRates![_fromCurrency] ?? 1.0;
      final rateTo   = _currencyRates![_toCurrency]   ?? 1.0;
      final eur = val / rateTo;
      _fromCurrCtrl.text = _fmt(eur * rateFrom);
    }
  }

  // ── Network fetches ───────────────────────────

  Future<void> _fetchCurrencyRates() async {
    final connectivity = context.read<ConnectivityService>();
    if (connectivity.isOffline) {
      setState(() {
        _currencyError =
        'Χωρίς σύνδεση. Δεν είναι δυνατή η ενημέρωση ισοτιμιών.';
      });
      return;
    }

    setState(() { _currencyLoading = true; _currencyError = null; });

    try {
      final uri = Uri.parse('https://open.er-api.com/v6/latest/EUR');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawRates = data['rates'] as Map<String, dynamic>;
        final rates = <String, double>{};
        rawRates.forEach((k, v) {
          rates[k] = (v as num).toDouble();
        });
        if (!mounted) return;
        setState(() {
          _currencyRates = rates;
          _ratesUpdatedAt = DateTime.now();
          _currencyLoading = false;
        });
        _calcCurrency();
        AccessibilityService.announcePolite('Ισοτιμίες ενημερώθηκαν');
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currencyError = 'Σφάλμα λήψης ισοτιμιών: $e';
        _currencyLoading = false;
      });
    }
  }

  // Φόρτωση top-250 για αναζήτηση
  Future<void> _fetchCryptoCatalog() async {
    final connectivity = context.read<ConnectivityService>();
    if (connectivity.isOffline) {
      setState(() {
        _cryptoError = 'Χωρίς σύνδεση. Δεν είναι δυνατή η αναζήτηση.';
      });
      return;
    }
    setState(() { _catalogLoading = true; _cryptoError = null; });
    try {
      final uri = Uri.parse(
        'https://api.coingecko.com/api/v3/coins/markets'
            '?vs_currency=eur&order=market_cap_desc&per_page=250&page=1&sparkline=false',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        if (!mounted) return;
        setState(() {
          _cryptoCatalog = list.map((e) => _CryptoItem.fromJson(e)).toList();
          _catalogLoading = false;
        });
      } else {
        throw Exception('HTTP \${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cryptoError = 'Σφάλμα: \$e';
        _catalogLoading = false;
      });
    }
  }

  // Φόρτωση watched IDs από SharedPreferences
  Future<void> _loadWatchedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('crypto_watched_ids') ?? [];
      if (saved.isEmpty) return;
      setState(() => _watchedIds.addAll(saved));
      DebugConfig.print('✅ Loaded watched IDs: $saved');
      // Φόρτωσε αμέσως τιμές
      _lastRefresh = null;
      _refreshWatchedPrices();
    } catch (e) {
      DebugConfig.print('❌ Error loading watched IDs: $e');
    }
  }

  // Αποθήκευση watched IDs στο SharedPreferences
  Future<void> _saveWatchedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('crypto_watched_ids', _watchedIds);
      DebugConfig.print('💾 Saved watched IDs: $_watchedIds');
    } catch (e) {
      DebugConfig.print('❌ Error saving watched IDs: $e');
    }
  }

  // Ανανέωση τιμών μόνο για watched
  Future<void> _refreshWatchedPrices() async {
    DebugConfig.print('🔄 Refresh watched prices called');

    if (_watchedIds.isEmpty) {
      DebugConfig.print('⚠ No watched ids');
      return;
    }

    final connectivity = context.read<ConnectivityService>();
    if (connectivity.isOffline) {
      DebugConfig.print('⚠ Offline mode - skipping refresh');
      return;
    }

    // ⛔ Μην τρέχει δεύτερη φορά αν ήδη τρέχει
    if (_isRefreshing) {
      DebugConfig.print('⏳ Refresh skipped (already running)');
      return;
    }

    // ⏱ Rate limit backoff (μετά από 429)
    if (_rateLimitUntil != null && DateTime.now().isBefore(_rateLimitUntil!)) {
      final secs = _rateLimitUntil!.difference(DateTime.now()).inSeconds;
      DebugConfig.print('⏳ Rate limited — αναμονή ${secs}s');
      setState(() => _cryptoError = 'Υπέρβαση ορίου API. Αναμονή ${secs}s...');
      return;
    }

// ⏱ Cooldown 30 δευτερόλεπτα
    if (_lastRefresh != null &&
        DateTime.now().difference(_lastRefresh!) < const Duration(seconds: 30)) {
      DebugConfig.print('⏳ Refresh skipped (cooldown)');
      return;
    }

    _isRefreshing = true;
    _lastRefresh = DateTime.now();

    setState(() {
      _watchedLoading = true;
      _cryptoError = null;
    });

    try {
      final ids = _watchedIds.join(',');
      DebugConfig.print('📌 Watched IDs: $ids');

      final uri = Uri.parse(
        'https://api.coingecko.com/api/v3/coins/markets'
            '?vs_currency=eur'
            '&ids=$ids'
            '&order=market_cap_desc'
            '&per_page=250'
            '&page=1'
            '&sparkline=false',
      );

      DebugConfig.print('🌍 Request URI: $uri');

      final response =
      await http.get(uri).timeout(const Duration(seconds: 10));

      DebugConfig.print('📡 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;

        DebugConfig.print('📦 Items returned: ${list.length}');

        if (!mounted) return;

        final newData = <String, _CryptoItem>{};

        for (final e in list) {
          final item = _CryptoItem.fromJson(e);
          newData[item.id] = item;
          DebugConfig.print('💰 ${item.id} = ${item.price}');
        }

        setState(() {
          _watchedData.addAll(newData);
          _watchedLoading = false;
          _cryptoUpdatedAt = DateTime.now();
        });

        AccessibilityService.announcePolite(
          'Τιμές crypto ενημερώθηκαν',
        );
      } else if (response.statusCode == 429) {
        DebugConfig.print('🚫 Rate limit exceeded (429)');
        _rateLimitUntil = DateTime.now().add(const Duration(seconds: 90));
        throw Exception('Υπέρβαση ορίου API. Δοκιμάστε ξανά σε 90 δευτερόλεπτα.');
      } else {
        DebugConfig.print('❌ HTTP ${response.statusCode}');
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      DebugConfig.print('❌ Refresh error: $e');

      if (!mounted) return;

      setState(() {
        _cryptoError = 'Σφάλμα ανανέωσης: $e';
        _watchedLoading = false;
      });
    } finally {
      _isRefreshing = false;
    }
  }

  // Μετατροπή crypto
  // Πάντα σε τεμάχια (TO crypto ή EUR)
  String _calcConversion() {
    final amt = double.tryParse(_convAmtCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amt <= 0) return '0';

    final fromItem = _convFromId != null ? _watchedData[_convFromId] : null;
    final toItem   = _convToId   != null ? _watchedData[_convToId]   : null;

    // Crypto → Crypto: amt τεμάχια FROM → τεμάχια TO
    if (_convFromId != null && _convToId != null) {
      if (fromItem == null || toItem == null || toItem.price == 0) return '—';
      final eur = amt * fromItem.price;
      return _fmtCrypto(eur / toItem.price);
    }

    // Crypto → EUR: amt τεμάχια FROM → €
    if (_convFromId != null && _convToId == null) {
      if (fromItem == null) return '—';
      return _fmtCurrency(amt * fromItem.price);
    }

    // EUR → Crypto: amt € → τεμάχια TO
    if (_convFromId == null && _convToId != null) {
      if (toItem == null || toItem.price == 0) return '—';
      return _fmtCrypto(amt / toItem.price);
    }

    return '—';
  }

  // Αξία σε € — εμφανίζεται ΜΟΝΟ στο crypto→crypto σαν δεύτερη γραμμή
  // Επιστρέφει null αν δεν χρειάζεται
  String? _calcEurValue() {
    final amt = double.tryParse(_convAmtCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amt <= 0) return null;
    if (_convFromId == null || _convToId == null) return null;

    final fromItem = _watchedData[_convFromId];
    final toItem   = _watchedData[_convToId];
    if (fromItem == null || toItem == null) return null;

    // Αξία των amt τεμαχίων FROM σε €
    final eurFrom = amt * fromItem.price;
    // Αξία των αποτελεσμάτων TO σε € (πρέπει να είναι ίδια)

    return '${_fmtCurrency(eurFrom)} €';
  }

  String _fmtCrypto(double v) {
    if (v <= 0) return '0';
    if (v >= 1000) return NumberFormat('#,##0.00', 'el_GR').format(v);
    if (v >= 1)    return NumberFormat('#,##0.0000', 'el_GR').format(v);
    // μικρές τιμές — έως 8 δεκαδικά
    final s = v.toStringAsFixed(10);
    final trimmed = s.replaceAll(RegExp(r'0+\$'), '').replaceAll(RegExp(r'\.\$'), '');
    final dot = trimmed.indexOf('.');
    if (dot == -1) return trimmed;
    final dec = trimmed.substring(dot + 1);
    return '${trimmed.substring(0, dot + 1)}${dec.substring(0, dec.length.clamp(0, 8))}';
  }

  String _fmtCurrency(double v) {
    return NumberFormat('#,##0.00', 'el_GR').format(v);
  }

  // ═══════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final primary = ColorsUI.getPrimary(brightness);
    final onPrimary = ColorsUI.getOnPrimary(brightness);
    final bgColor  = ColorsUI.getBackground(brightness);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        iconTheme: IconThemeData(color: onPrimary),
        title: Text(
          'Μετατροπή Μονάδων',
          style: TextStyle(
            color: onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: onPrimary,
          unselectedLabelColor: onPrimary.withValues(alpha: 0.6),
          indicatorColor: onPrimary,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: ExcludeSemantics(child: Icon(Icons.straighten_rounded, size: 18)), text: 'Μήκος'),
            Tab(icon: ExcludeSemantics(child: Icon(Icons.fitness_center_rounded, size: 18)), text: 'Βάρος'),
            Tab(icon: ExcludeSemantics(child: Icon(Icons.water_drop_rounded, size: 18)), text: 'Υγρά'),
            Tab(icon: ExcludeSemantics(child: Icon(Icons.swap_horiz_rounded, size: 18)), text: 'Βάρος↔Υγρά'),
            Tab(icon: ExcludeSemantics(child: Icon(Icons.currency_exchange_rounded, size: 18)), text: 'Νομίσματα'),
            Tab(icon: ExcludeSemantics(child: Icon(Icons.currency_bitcoin_rounded, size: 18)), text: 'Crypto'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUnitTab(
            brightness: brightness, isDark: isDark,
            fromUnit: _fromLength, toUnit: _toLength,
            units: _lengthUnits,
            fromCtrl: _fromLengthCtrl, toCtrl: _toLengthCtrl,
            fromFocus: _lengthFromFocus,
            onFromChanged: (v) { _lengthFromFocus = true; _calcLength(); },
            onToChanged:   (v) { _lengthFromFocus = false; _calcLengthReverse(); },
            onFromUnitChanged: (u) => setState(() { _fromLength = u; _calcLength(); }),
            onToUnitChanged:   (u) => setState(() { _toLength = u; _calcLength(); }),
            onSwap: () => setState(() {
              final tmp = _fromLength; _fromLength = _toLength; _toLength = tmp;
              final tv = _fromLengthCtrl.text;
              _fromLengthCtrl.text = _toLengthCtrl.text;
              _toLengthCtrl.text = tv;
            }),
          ),
          _buildUnitTab(
            brightness: brightness, isDark: isDark,
            fromUnit: _fromWeight, toUnit: _toWeight,
            units: _weightUnits,
            fromCtrl: _fromWeightCtrl, toCtrl: _toWeightCtrl,
            fromFocus: _weightFromFocus,
            onFromChanged: (v) { _weightFromFocus = true; _calcWeight(); },
            onToChanged:   (v) { _weightFromFocus = false; _calcWeightReverse(); },
            onFromUnitChanged: (u) => setState(() { _fromWeight = u; _calcWeight(); }),
            onToUnitChanged:   (u) => setState(() { _toWeight = u; _calcWeight(); }),
            onSwap: () => setState(() {
              final tmp = _fromWeight; _fromWeight = _toWeight; _toWeight = tmp;
              final tv = _fromWeightCtrl.text;
              _fromWeightCtrl.text = _toWeightCtrl.text;
              _toWeightCtrl.text = tv;
            }),
          ),
          _buildUnitTab(
            brightness: brightness, isDark: isDark,
            fromUnit: _fromVol, toUnit: _toVol,
            units: _volumeUnits,
            fromCtrl: _fromVolCtrl, toCtrl: _toVolCtrl,
            fromFocus: _volFromFocus,
            onFromChanged: (v) { _volFromFocus = true; _calcVolume(); },
            onToChanged:   (v) { _volFromFocus = false; _calcVolumeReverse(); },
            onFromUnitChanged: (u) => setState(() { _fromVol = u; _calcVolume(); }),
            onToUnitChanged:   (u) => setState(() { _toVol = u; _calcVolume(); }),
            onSwap: () => setState(() {
              final tmp = _fromVol; _fromVol = _toVol; _toVol = tmp;
              final tv = _fromVolCtrl.text;
              _fromVolCtrl.text = _toVolCtrl.text;
              _toVolCtrl.text = tv;
            }),
          ),
          _buildCrossTab(brightness: brightness, isDark: isDark),
          _buildCurrencyTab(brightness: brightness, isDark: isDark),
          _buildCryptoTab(brightness: brightness, isDark: isDark),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // GENERIC UNIT TAB
  // ═══════════════════════════════════════════════

  Widget _buildUnitTab({
    required Brightness brightness,
    required bool isDark,
    required _Unit fromUnit,
    required _Unit toUnit,
    required List<_Unit> units,
    required TextEditingController fromCtrl,
    required TextEditingController toCtrl,
    required bool fromFocus,
    required ValueChanged<String> onFromChanged,
    required ValueChanged<String> onToChanged,
    required ValueChanged<_Unit> onFromUnitChanged,
    required ValueChanged<_Unit> onToUnitChanged,
    required VoidCallback onSwap,
  }) {
    final primary   = ColorsUI.getPrimary(brightness);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _ConvCard(
            brightness: brightness,
            child: Column(
              children: [
                // FROM
                _UnitField(
                  label: 'Από',
                  ctrl: fromCtrl,
                  unit: fromUnit,
                  units: units,
                  brightness: brightness,
                  onChanged: onFromChanged,
                  onUnitChanged: onFromUnitChanged,
                  isFocused: fromFocus,
                ),
                const SizedBox(height: 8),

                // SWAP
                Center(
                  child: Semantics(
                    button: true,
                    label: 'Αντιστροφή μονάδων',
                    child: InkWell(
                      onTap: onSwap,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: ExcludeSemantics(
                          child: Icon(Icons.swap_vert_rounded, color: primary, size: 26),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // TO
                _UnitField(
                  label: 'Σε',
                  ctrl: toCtrl,
                  unit: toUnit,
                  units: units,
                  brightness: brightness,
                  onChanged: onToChanged,
                  onUnitChanged: onToUnitChanged,
                  isFocused: !fromFocus,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // CROSS-CONVERT TAB (Βάρος ↔ Υγρά)
  // ═══════════════════════════════════════════════

  Widget _buildCrossTab({
    required Brightness brightness,
    required bool isDark,
  }) {
    final primary       = ColorsUI.getPrimary(brightness);
    final textPrimary   = ColorsUI.getTextPrimary(brightness);
    final onPrimary     = ColorsUI.getOnPrimary(brightness);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // Info card
          _InfoCard(
            brightness: brightness,
            icon: Icons.info_outline_rounded,
            text: 'Μετατροπή μεταξύ βάρους και όγκου ανάλογα με την πυκνότητα '
                'της επιλεγμένης ουσίας.',
          ),

          const SizedBox(height: 12),

          // Substance picker
          _ConvCard(
            brightness: brightness,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(Icons.science_rounded, color: primary, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text('Ουσία',
                        style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 10),
                _DropdownField<_Substance>(
                  value: _substance,
                  items: _substances,
                  label: (s) => '${s.label}  (${s.density} kg/L)',
                  brightness: brightness,
                  onChanged: (s) => setState(() { _substance = s; _calcCross(); }),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Πυκνότητα: ${_substance.density} kg/L  '
                        '→  1 kg = ${_fmt(1.0 / _substance.density)} L  |  '
                        '1 L = ${_fmt(_substance.density)} kg',
                    style: TextStyle(
                        color: primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Direction toggle
          _ConvCard(
            brightness: brightness,
            child: Row(
              children: [
                Expanded(
                  child: _DirectionBtn(
                    label: 'Βάρος → Υγρά',
                    icon: Icons.fitness_center_rounded,
                    selected: _crossFromWeight,
                    primary: primary,
                    onPrimary: onPrimary,
                    textPrimary: textPrimary,
                    onTap: () => setState(() {
                      _crossFromWeight = true;
                      _calcCross();
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DirectionBtn(
                    label: 'Υγρά → Βάρος',
                    icon: Icons.water_drop_rounded,
                    selected: !_crossFromWeight,
                    primary: primary,
                    onPrimary: onPrimary,
                    textPrimary: textPrimary,
                    onTap: () => setState(() {
                      _crossFromWeight = false;
                      _calcCross();
                    }),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Input
          _ConvCard(
            brightness: brightness,
            child: Column(
              children: [
                _UnitField(
                  label: _crossFromWeight ? 'Βάρος (από)' : 'Υγρά (από)',
                  ctrl: _crossFromCtrl,
                  unit: _crossFromWeight ? _crossWeightUnit : _crossVolUnit,
                  units: _crossFromWeight ? _weightUnits : _volumeUnits,
                  brightness: brightness,
                  onChanged: (v) { _calcCross(); },
                  onUnitChanged: (u) => setState(() {
                    if (_crossFromWeight) { _crossWeightUnit = u; } else { _crossVolUnit = u; }
                    _calcCross();
                  }),
                  isFocused: true,
                ),

                const SizedBox(height: 8),

                Center(
                  child: ExcludeSemantics(
                    child: Icon(Icons.arrow_downward_rounded,
                        color: primary, size: 26),
                  ),
                ),

                const SizedBox(height: 8),

                _UnitField(
                  label: _crossFromWeight ? 'Υγρά (αποτέλεσμα)' : 'Βάρος (αποτέλεσμα)',
                  ctrl: _crossToCtrl,
                  unit: _crossFromWeight ? _crossVolUnit : _crossWeightUnit,
                  units: _crossFromWeight ? _volumeUnits : _weightUnits,
                  brightness: brightness,
                  readOnly: true,
                  onChanged: (_) {},
                  onUnitChanged: (u) => setState(() {
                    if (_crossFromWeight) { _crossVolUnit = u; } else { _crossWeightUnit = u; }
                    _calcCross();
                  }),
                  isFocused: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // CURRENCY TAB
  // ═══════════════════════════════════════════════

  Widget _buildCurrencyTab({
    required Brightness brightness,
    required bool isDark,
  }) {
    final primary       = ColorsUI.getPrimary(brightness);
    final textPrimary   = ColorsUI.getTextPrimary(brightness);
    final textSecondary = ColorsUI.getTextSecondary(brightness);
    final successColor  = isDark ? ColorsUI.successDark : ColorsUI.successLight;
    ColorsUI.getInputFill(brightness);
    final cardColor     = ColorsUI.getCard(brightness);
    final connectivity  = context.watch<ConnectivityService>();

    // Τρέχον αποτέλεσμα για εμφάνιση
    final fromSymbol = _currencySymbols[_fromCurrency] ?? _fromCurrency;
    final toName     = _currencyNames[_toCurrency]     ?? _toCurrency;
    final resultText = _toCurrCtrl.text.isNotEmpty ? _toCurrCtrl.text : '—';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // ── Offline banner ───────────────────────
          if (connectivity.isOffline)
            _OfflineBanner(brightness: brightness),

          // ── Status card ──────────────────────────
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _ratesUpdatedAt != null
                  ? successColor.withValues(alpha: 0.12)
                  : (isDark ? ColorsUI.warningDark : ColorsUI.warningLight)
                  .withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _ratesUpdatedAt != null
                    ? successColor.withValues(alpha: 0.4)
                    : (isDark ? ColorsUI.warningDark : ColorsUI.warningLight)
                    .withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    _ratesUpdatedAt != null
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    color: _ratesUpdatedAt != null
                        ? successColor
                        : (isDark ? ColorsUI.warningDark : ColorsUI.warningLight),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _ratesUpdatedAt != null
                        ? 'Ισοτιμίες ενημερωμένες: '
                        '${DateFormat('HH:mm').format(_ratesUpdatedAt!)} — '
                        'Πηγή: open.er-api.com'
                        : 'Πατήστε ανανέωση για φόρτωση ισοτιμιών',
                    style: TextStyle(
                      color: _ratesUpdatedAt != null
                          ? successColor
                          : (isDark
                          ? ColorsUI.warningDark
                          : ColorsUI.warningLight),
                      fontSize: 12,
                    ),
                  ),
                ),
                if (_currencyLoading)
                  const SizedBox(
                    width: 20, height: 20,
                    child: ExcludeSemantics(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Semantics(
                    button: true,
                    label: 'Ανανέωση ισοτιμιών',
                    child: IconButton(
                      icon: Icon(Icons.refresh_rounded,
                          color: _ratesUpdatedAt != null
                              ? successColor
                              : primary),
                      onPressed:
                      connectivity.isOffline ? null : _fetchCurrencyRates,
                    ),
                  ),
              ],
            ),
          ),

          if (_currencyError != null) ...[
            _ErrorCard(brightness: brightness, message: _currencyError!),
            const SizedBox(height: 8),
          ],

          // ── Ποσό προς μετατροπή ──────────────────
          _ConvCard(
            brightness: brightness,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ποσό προς μετατροπή',
                    style: TextStyle(color: textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: _fromCurrCtrl,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: primary.withValues(alpha: 0.06),
                    prefixText: '$fromSymbol ',
                    prefixStyle: TextStyle(
                        color: textSecondary,
                        fontSize: 22,
                        fontWeight: FontWeight.w500),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 16),
                  ),
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                  onChanged: (v) {
                    _currFromFocus = true;
                    _calcCurrency();
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── FROM selector ────────────────────────
          if (_currencyRates != null) ...[
            _ConvCard(
              brightness: brightness,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Από',
                      style:
                      TextStyle(color: textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  _CurrencySelector(
                    currency: _fromCurrency,
                    currencies: _currencyCodes,
                    brightness: brightness,
                    onChanged: (c) => setState(() {
                      _fromCurrency = c;
                      _currFromFocus = true;
                      _calcCurrency();
                    }),
                  ),
                ],
              ),
            ),

            // Swap button
            Center(
              child: Semantics(
                button: true,
                label: 'Αντιστροφή νομισμάτων',
                child: InkWell(
                  onTap: () => setState(() {
                    final tmp = _fromCurrency;
                    _fromCurrency = _toCurrency;
                    _toCurrency = tmp;
                    final tv = _fromCurrCtrl.text;
                    _fromCurrCtrl.text = _toCurrCtrl.text;
                    _toCurrCtrl.text = tv;
                    _currFromFocus = true;
                    _calcCurrency();
                  }),
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cardColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: ColorsUI.getBorder(brightness)),
                    ),
                    child: Icon(Icons.swap_vert_rounded,
                        color: primary, size: 24),
                  ),
                ),
              ),
            ),

            // ── TO selector ──────────────────────
            _ConvCard(
              brightness: brightness,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Σε',
                      style:
                      TextStyle(color: textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  _CurrencySelector(
                    currency: _toCurrency,
                    currencies: _currencyCodes,
                    brightness: brightness,
                    onChanged: (c) => setState(() {
                      _toCurrency = c;
                      _currFromFocus = true;
                      _calcCurrency();
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Αποτέλεσμα card ──────────────────
            _ConvCard(
              brightness: brightness,
              child: Column(
                children: [
                  Text('Αποτέλεσμα',
                      style: TextStyle(
                          color: textSecondary, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    '$fromSymbol ${_fromCurrCtrl.text.isEmpty ? "1" : _fromCurrCtrl.text}',
                    style: TextStyle(
                        color: textSecondary, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  ExcludeSemantics(
                    child: Icon(Icons.arrow_downward_rounded,
                        color: textSecondary, size: 18),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        resultText,
                        style: TextStyle(
                          color: successColor,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _toCurrency,
                        style: TextStyle(
                          color: successColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(toName,
                      style: TextStyle(
                          color: textSecondary, fontSize: 13)),
                  const SizedBox(height: 14),
                  // Αντιγραφή button
                  Semantics(
                    button: true,
                    label: 'Αντιγραφή αποτελέσματος',
                    child: OutlinedButton.icon(
                      onPressed: resultText == '—'
                          ? null
                          : () {
                        Clipboard.setData(
                            ClipboardData(text: resultText));
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text('Αντιγράφηκε!'),
                          duration: Duration(seconds: 2),
                        ));
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primary,
                        side: BorderSide(color: primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        minimumSize:
                        const Size(double.infinity, 44),
                      ),
                      icon: const ExcludeSemantics(child: Icon(Icons.copy_rounded, size: 16)),
                      label: const Text('Αντιγραφή'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Πίνακας αναφοράς 1 X = ... ──────
            _ConvCard(
              brightness: brightness,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(Icons.currency_exchange_rounded,
                            color: primary, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '1 $_fromCurrency = ...',
                        style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Divider(
                      color: ColorsUI.getDivider(brightness), height: 1),
                  ..._currencyCodes
                      .where((c) => c != _fromCurrency)
                      .map((c) {
                    final rF =
                        _currencyRates![_fromCurrency] ?? 1.0;
                    final rC = _currencyRates![c] ?? 1.0;
                    final rate = rC / rF;
                    final sym = _currencySymbols[c] ?? c;
                    final name = _currencyNames[c] ?? c;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 9),
                          child: Row(
                            children: [
                              // Symbol badge
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color:
                                  primary.withValues(alpha: 0.1),
                                  borderRadius:
                                  BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    sym,
                                    style: TextStyle(
                                        color: primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: sym.length <= 2
                                            ? 16
                                            : 11),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(name,
                                    style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 13)),
                              ),
                              Text(
                                '${_fmt(rate)} $c',
                                style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                            color: ColorsUI.getDivider(brightness),
                            height: 1),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ] else if (!_currencyLoading)
            _ConvCard(
              brightness: brightness,
              child: Column(
                children: [
                  ExcludeSemantics(
                    child: Icon(Icons.currency_exchange_rounded,
                        size: 48, color: primary.withValues(alpha: 0.4)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Πατήστε Ανανέωση για να φορτωθούν οι ισοτιμίες',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: connectivity.isOffline
                        ? null
                        : _fetchCurrencyRates,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: ColorsUI.getOnPrimary(brightness),
                    ),
                    icon: const ExcludeSemantics(child: Icon(Icons.refresh_rounded)),
                    label: const Text('Φόρτωση Ισοτιμιών'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // CRYPTO TAB
  // ═══════════════════════════════════════════════

  Widget _buildCryptoTab({
    required Brightness brightness,
    required bool isDark,
  }) {
    final primary       = ColorsUI.getPrimary(brightness);
    final textPrimary   = ColorsUI.getTextPrimary(brightness);
    final textSecondary = ColorsUI.getTextSecondary(brightness);
    final successColor  = isDark ? ColorsUI.successDark : ColorsUI.successLight;
    final connectivity  = context.watch<ConnectivityService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (connectivity.isOffline) _OfflineBanner(brightness: brightness),
          if (_cryptoError != null) ...[
            _ErrorCard(brightness: brightness, message: _cryptoError!),
            const SizedBox(height: 8),
          ],

          // ══ ΕΝΟΤΗΤΑ 1: Επιλογή παρακολούθησης ════════════════
          _SectionHeader(
            label: 'Παρακολούθηση Crypto',
            icon: Icons.bookmark_rounded,
            brightness: brightness,
          ),
          const SizedBox(height: 8),

          // Κουμπί αναζήτησης / προσθήκης
          Semantics(
            button: true,
            label: 'Αναζήτηση και προσθήκη crypto',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _catalogLoading
                  ? null
                  : () async {
                if (_cryptoCatalog.isEmpty) await _fetchCryptoCatalog();
                if (!mounted) return;
                final picked = await showModalBottomSheet<String>(
                  context: context,
                  backgroundColor: ColorsUI.getCard(brightness),
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20)),
                  ),
                  builder: (_) => _CryptoSearchSheet(
                    catalog: _cryptoCatalog,
                    watchedIds: _watchedIds,
                    brightness: brightness,
                  ),
                );
                if (picked != null && !_watchedIds.contains(picked)) {
                  setState(() => _watchedIds.add(picked));
                  _saveWatchedIds();

                  // Περίμενε την υπόλοιπη ώρα του cooldown αντί να το μηδενίζεις
                  final now = DateTime.now();
                  final waitMs = _lastRefresh == null
                      ? 0
                      : (30000 - now.difference(_lastRefresh!).inMilliseconds).clamp(0, 30000);

                  if (waitMs == 0) {
                    _refreshWatchedPrices();
                  } else {
                    DebugConfig.print('⏳ Νέο coin — refresh σε ${waitMs}ms');
                    Future.delayed(Duration(milliseconds: waitMs), () {
                      if (mounted) _refreshWatchedPrices();
                    });
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: ColorsUI.getCard(brightness),
                  borderRadius: BorderRadius.circular(12),
                  border:
                  Border.all(color: primary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(Icons.search_rounded, color: primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Αναζήτηση crypto για προσθήκη...',
                        style: TextStyle(color: textSecondary),
                      ),
                    ),
                    if (_catalogLoading)
                      SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: primary),
                      )
                    else
                      ExcludeSemantics(
                        child: Icon(Icons.add_circle_outline_rounded, color: primary, size: 20),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Header ανανέωσης
          if (_watchedIds.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _watchedLoading
                        ? 'Ενημέρωση τιμών...'
                        : _cryptoUpdatedAt != null
                        ? 'Ενημ.: ${DateFormat('HH:mm').format(_cryptoUpdatedAt!)}'
                        : 'Πατήστε ανανέωση',
                    style: TextStyle(
                      color: _watchedLoading ? primary : textSecondary,
                      fontSize: 11,
                      fontWeight: _watchedLoading
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (_watchedLoading)
                  const SizedBox(
                    width: 18, height: 18,
                    child: ExcludeSemantics(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Semantics(
                    button: true,
                    label: 'Ανανέωση τιμών',
                    child: IconButton(
                      icon: Icon(Icons.refresh_rounded,
                          color: primary, size: 20),
                      onPressed: connectivity.isOffline
                          ? null
                          : _refreshWatchedPrices,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
              ],
            ),

          const SizedBox(height: 4),

          // Lista παρακολουθούμενων
          if (_watchedIds.isEmpty)
            _ConvCard(
              brightness: brightness,
              child: Column(
                children: [
                  ExcludeSemantics(
                    child: Icon(Icons.bookmark_border_rounded,
                        size: 44,
                        color: primary.withValues(alpha: 0.35)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Δεν παρακολουθείτε κανένα crypto ακόμα.\n'
                        'Χρησιμοποιήστε την αναζήτηση για να προσθέσετε.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ..._watchedIds.map((id) {
              final item = _watchedData[id];
              return _WatchedCryptoCard(
                id: id,
                item: item,
                brightness: brightness,
                isDark: isDark,
                isSelectedFrom: _convFromId == id,
                isSelectedTo: _convToId == id,
                onSelect: () => setState(() {
                  if (_convFromId == id) {
                    _convFromId = null;
                  } else if (_convToId == id) {
                    _convToId = null;
                  } else if (_convFromId == null) {
                    _convFromId = id;
                  } else {
                    _convToId = id;
                  }
                }),
                onRemove: () => setState(() {
                  _watchedIds.remove(id);
                  _watchedData.remove(id);
                  _saveWatchedIds();
                  if (_convFromId == id) _convFromId = null;
                  if (_convToId == id) _convToId = null;
                }),
              );
            }),

          const SizedBox(height: 16),

          // ══ ΕΝΟΤΗΤΑ 2: Μετατροπή ══════════════════════════════
          _SectionHeader(
            label: 'Μετατροπή Crypto',
            icon: Icons.swap_horiz_rounded,
            brightness: brightness,
          ),
          const SizedBox(height: 8),

          _ConvCard(
            brightness: brightness,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Info
                if (_watchedIds.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _InfoCard(
                      brightness: brightness,
                      icon: Icons.info_outline_rounded,
                      text: 'Προσθέστε crypto από την αναζήτηση για να ενεργοποιήσετε τη μετατροπή.',
                    ),
                  ),

                // FROM row
                Text('Από', style: TextStyle(color: textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                _ConvCryptoSelector(
                  selectedId: _convFromId,
                  watchedIds: _watchedIds,
                  watchedData: _watchedData,
                  brightness: brightness,
                  label: 'EUR (Ευρώ)',
                  onChanged: (id) => setState(() => _convFromId = id),
                ),

                const SizedBox(height: 8),
                Center(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      final tmp = _convFromId;
                      _convFromId = _convToId;
                      _convToId = tmp;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: ExcludeSemantics(
                        child: Icon(Icons.swap_vert_rounded, color: primary, size: 22),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // TO row
                Text('Σε', style: TextStyle(color: textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                _ConvCryptoSelector(
                  selectedId: _convToId,
                  watchedIds: _watchedIds,
                  watchedData: _watchedData,
                  brightness: brightness,
                  label: 'EUR (Ευρώ)',
                  onChanged: (id) => setState(() => _convToId = id),
                ),

                const SizedBox(height: 14),
                ExcludeSemantics(
                  child: Divider(color: ColorsUI.getDivider(brightness), height: 1),
                ),
                const SizedBox(height: 14),

                // Amount input — prefix πάντα το FROM crypto (ή € αν FROM=EUR)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _convAmtCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                        ],
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: primary.withValues(alpha: 0.06),
                          prefixText: _convFromId != null
                              ? '${(_watchedData[_convFromId]?.symbol ?? _convFromId!).toUpperCase()} '
                              : '€ ',
                          prefixStyle: TextStyle(color: textSecondary, fontSize: 16),
                          hintText: '0',
                          hintStyle: TextStyle(color: textSecondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: primary, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                        style: TextStyle(
                            color: textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Αποτέλεσμα
                Builder(builder: (ctx) {
                  final result   = _calcConversion();
                  final eurValue = _calcEurValue(); // null αν δεν είναι crypto→crypto
                  final toLabel  = _convToId != null
                      ? (_watchedData[_convToId]?.symbol ?? _convToId!).toUpperCase()
                      : 'EUR';

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: successColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: successColor.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Αποτέλεσμα',
                            style: TextStyle(color: textSecondary, fontSize: 12)),
                        const SizedBox(height: 6),

                        // Γραμμή 1: τεμάχια TO
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text(
                                result,
                                style: TextStyle(
                                  color: successColor,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              toLabel,
                              style: TextStyle(
                                color: successColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        // Γραμμή 2: αξία σε € (ΜΟΝΟ για crypto→crypto)
                        if (eurValue != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              ExcludeSemantics(
                                child: Icon(Icons.euro_rounded, color: textSecondary, size: 14),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                eurValue,
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],

                        if (result != '—' && result != '0') ...[
                          const SizedBox(height: 10),
                          Semantics(
                            button: true,
                            label: 'Αντιγραφή αποτελέσματος',
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: result));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Αντιγράφηκε!'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primary,
                                side: BorderSide(color: primary),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const ExcludeSemantics(child: Icon(Icons.copy_rounded, size: 14)),
                              label: const Text('Αντιγραφή', style: TextStyle(fontSize: 13)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HELPER WIDGETS
// ─────────────────────────────────────────────────────────────

// ── ConvCard ─────────────────────────────────────────────────
class _ConvCard extends StatelessWidget {
  final Widget child;
  final Brightness brightness;

  const _ConvCard({required this.child, required this.brightness});

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorsUI.getCard(brightness),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: isDark ? ColorsUI.shadowDark : ColorsUI.shadowLight,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── UnitField ─────────────────────────────────────────────────
class _UnitField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final _Unit unit;
  final List<_Unit> units;
  final Brightness brightness;
  final ValueChanged<String> onChanged;
  final ValueChanged<_Unit> onUnitChanged;
  final bool isFocused;
  final bool readOnly;

  const _UnitField({
    required this.label,
    required this.ctrl,
    required this.unit,
    required this.units,
    required this.brightness,
    required this.onChanged,
    required this.onUnitChanged,
    required this.isFocused,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary   = ColorsUI.getPrimary(brightness);
    final textPrimary = ColorsUI.getTextPrimary(brightness);
    final textSec   = ColorsUI.getTextSecondary(brightness);
    final inputFill = ColorsUI.getInputFill(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: textSec,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Row(
          children: [
            // Value input
            Expanded(
              flex: 5,
              child: Semantics(
                label: '$label τιμή',
                textField: true,
                child: TextField(
                  controller: ctrl,
                  readOnly: readOnly,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[\d.,\-eE]')),
                  ],
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isFocused
                        ? primary.withValues(alpha: 0.06)
                        : inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                  onChanged: onChanged,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Unit dropdown
            Expanded(
              flex: 6,
              child: Semantics(
                label: '$label μονάδα',
                child: _DropdownField<_Unit>(
                  value: unit,
                  items: units,
                  label: (u) => u.label,
                  brightness: brightness,
                  onChanged: onUnitChanged,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── DropdownField ──────────────────────────────────────────────
class _DropdownField<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) label;
  final Brightness brightness;
  final ValueChanged<T> onChanged;

  const _DropdownField({
    required this.value,
    required this.items,
    required this.label,
    required this.brightness,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary     = ColorsUI.getPrimary(brightness);
    final textPrimary = ColorsUI.getTextPrimary(brightness);
    final inputFill   = ColorsUI.getInputFill(brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: ColorsUI.getBorder(brightness).withValues(alpha: 0.5)),
      ),
      child: DropdownButton<T>(
        value: value,
        underline: const SizedBox(),
        isExpanded: true,
        style: TextStyle(color: textPrimary, fontSize: 13),
        dropdownColor: ColorsUI.getCard(brightness),
        icon: ExcludeSemantics(
          child: Icon(Icons.keyboard_arrow_down_rounded,
              color: primary, size: 18),
        ),
        items: items.map((u) => DropdownMenuItem<T>(
          value: u,
          child: Text(label(u),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textPrimary, fontSize: 13)),
        )).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    );
  }
}

// ── CurrencySelector ─────────────────────────────────────────
// Full-width button με symbol badge + code + name + chevron
class _CurrencySelector extends StatelessWidget {
  final String currency;
  final List<String> currencies;
  final Brightness brightness;
  final ValueChanged<String> onChanged;

  const _CurrencySelector({
    required this.currency,
    required this.currencies,
    required this.brightness,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary     = ColorsUI.getPrimary(brightness);
    final textPrimary = ColorsUI.getTextPrimary(brightness);
    final textSec     = ColorsUI.getTextSecondary(brightness);
    final inputFill   = ColorsUI.getInputFill(brightness);
    final sym  = _currencySymbols[currency] ?? currency;
    final name = _currencyNames[currency]   ?? currency;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final selected = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: ColorsUI.getCard(brightness),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          isScrollControlled: true,
          builder: (_) => _CurrencyPickerSheet(
            selected: currency,
            currencies: currencies,
            brightness: brightness,
          ),
        );
        if (selected != null) onChanged(selected);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: ColorsUI.getBorder(brightness).withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            // Symbol badge
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  sym,
                  style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.bold,
                      fontSize: sym.length <= 2 ? 17 : 11),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Code + name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(currency,
                      style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text(name,
                      style: TextStyle(color: textSec, fontSize: 12)),
                ],
              ),
            ),
            ExcludeSemantics(
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  color: textSec, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

// ── CurrencyPickerSheet ───────────────────────────────────────
class _CurrencyPickerSheet extends StatefulWidget {
  final String selected;
  final List<String> currencies;
  final Brightness brightness;

  const _CurrencyPickerSheet({
    required this.selected,
    required this.currencies,
    required this.brightness,
  });

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final primary     = ColorsUI.getPrimary(widget.brightness);
    final textPrimary = ColorsUI.getTextPrimary(widget.brightness);
    final textSec     = ColorsUI.getTextSecondary(widget.brightness);
    final inputFill   = ColorsUI.getInputFill(widget.brightness);

    final filtered = widget.currencies.where((c) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return c.toLowerCase().contains(q) ||
          (_currencyNames[c] ?? '').toLowerCase().contains(q);
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: textSec.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Αναζήτηση νομίσματος...',
                hintStyle: TextStyle(color: textSec),
                prefixIcon: ExcludeSemantics(
                  child: Icon(Icons.search_rounded, color: textSec),
                ),
                filled: true,
                fillColor: inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                const EdgeInsets.symmetric(vertical: 12),
              ),
              style: TextStyle(color: textPrimary),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final c    = filtered[i];
                final sym  = _currencySymbols[c] ?? c;
                final name = _currencyNames[c]   ?? c;
                final isSelected = c == widget.selected;
                return ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primary.withValues(alpha: 0.2)
                          : primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(sym,
                          style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.bold,
                              fontSize: sym.length <= 2 ? 15 : 10)),
                    ),
                  ),
                  title: Text(c,
                      style: TextStyle(
                          color: textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal)),
                  subtitle: Text(name,
                      style: TextStyle(color: textSec, fontSize: 12)),
                  trailing: isSelected
                      ? ExcludeSemantics(
                    child: Icon(Icons.check_circle_rounded, color: primary),
                  )
                      : null,
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── DirectionBtn ──────────────────────────────────────────────
class _DirectionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color primary;
  final Color onPrimary;
  final Color textPrimary;
  final VoidCallback onTap;

  const _DirectionBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.primary,
    required this.onPrimary,
    required this.textPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? primary : primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? primary : primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(
              child: Icon(icon,
              size: 16,
              color: selected ? onPrimary : textPrimary),
        ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    style: TextStyle(
                        color: selected ? onPrimary : textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── InfoCard ──────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final Brightness brightness;
  final IconData icon;
  final String text;

  const _InfoCard(
      {required this.brightness, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    final color = isDark ? ColorsUI.infoDark : ColorsUI.infoLight;
    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(color: color, fontSize: 12))),
        ],
      ),
    );
  }
}

// ── ErrorCard ─────────────────────────────────────────────────
class _ErrorCard extends StatelessWidget {
  final Brightness brightness;
  final String message;

  const _ErrorCard({required this.brightness, required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    final color = isDark ? ColorsUI.errorDark : ColorsUI.errorLight;
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(Icons.error_outline_rounded, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 12))),
        ],
      ),
    );
  }
}

// ── OfflineBanner ─────────────────────────────────────────────
class _OfflineBanner extends StatelessWidget {
  final Brightness brightness;

  const _OfflineBanner({required this.brightness});

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    final color = isDark ? ColorsUI.warningDark : ColorsUI.warningLight;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(Icons.wifi_off_rounded, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Εκτός σύνδεσης — απαιτείται σύνδεση για ενημέρωση.',
                style: TextStyle(color: color, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── SectionHeader ─────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Brightness brightness;
  const _SectionHeader({required this.label, required this.icon, required this.brightness});

  @override
  Widget build(BuildContext context) {
    final primary = ColorsUI.getPrimary(brightness);
    final textPrimary = ColorsUI.getTextPrimary(brightness);
    return Row(children: [
      ExcludeSemantics(
        child: Icon(icon, color: primary, size: 16),
      ),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
    ]);
  }
}

// ── WatchedCryptoCard ──────────────────────────────────────────
class _WatchedCryptoCard extends StatelessWidget {
  final String id;
  final _CryptoItem? item;
  final Brightness brightness;
  final bool isDark;
  final bool isSelectedFrom;
  final bool isSelectedTo;
  final VoidCallback onSelect;
  final VoidCallback onRemove;

  const _WatchedCryptoCard({
    required this.id,
    required this.item,
    required this.brightness,
    required this.isDark,
    required this.isSelectedFrom,
    required this.isSelectedTo,
    required this.onSelect,
    required this.onRemove,
  });

  String _fmtPrice(double v) {
    if (v >= 1000) return NumberFormat('#,##0.00', 'el_GR').format(v);
    if (v >= 1)    return NumberFormat('#,##0.0000', 'el_GR').format(v);
    if (v <= 0)    return '0';
    final s = v.toStringAsFixed(10).replaceAll(RegExp(r'0+$'), '');
    final dot = s.indexOf('.');
    if (dot == -1) return s;
    return '${s.substring(0, dot + 1)}${s.substring(dot + 1, (dot + 9).clamp(0, s.length))}';
  }

  @override
  Widget build(BuildContext context) {
    final primary       = ColorsUI.getPrimary(brightness);
    final textPrimary   = ColorsUI.getTextPrimary(brightness);
    final textSecondary = ColorsUI.getTextSecondary(brightness);
    final successColor  = isDark ? ColorsUI.successDark : ColorsUI.successLight;
    final errorColor    = isDark ? ColorsUI.errorDark   : ColorsUI.errorLight;
    final infoColor     = isDark ? ColorsUI.infoDark    : ColorsUI.infoLight;

    final borderColor = isSelectedFrom ? primary
        : isSelectedTo ? infoColor
        : ColorsUI.getBorder(brightness);
    final up = (item?.change24h ?? 0) >= 0;
    final chColor = up ? successColor : errorColor;

    return Semantics(
      label: '${item?.name ?? id}, τιμή ${item != null ? _fmtPrice(item!.price) : "φόρτωση"} EUR',
      button: true,
      child: GestureDetector(
        onTap: onSelect,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: ColorsUI.getCard(brightness),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: isSelectedFrom || isSelectedTo ? 2 : 1),
            boxShadow: [BoxShadow(
              color: isDark ? ColorsUI.shadowDark : ColorsUI.shadowLight,
              blurRadius: 4, offset: const Offset(0, 1),
            )],
          ),
          child: Row(children: [
            if (item?.image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(item!.image!, width: 34, height: 34,
                    errorBuilder: (_, _, _) => _CryptoFallbackIcon(
                        symbol: item!.symbol.isNotEmpty ? item!.symbol[0] : '?',
                        primary: primary)),
              )
            else
              _CryptoFallbackIcon(
                  symbol: (item?.symbol ?? id).isNotEmpty ? (item?.symbol ?? id)[0].toUpperCase() : '?',
                  primary: primary),

            const SizedBox(width: 10),

            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item?.name ?? id, style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              Text(item?.symbol ?? '', style: TextStyle(color: textSecondary, fontSize: 11)),
            ])),

            if (item != null)
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${_fmtPrice(item!.price)} €',
                    style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  ExcludeSemantics(
                    child: Icon(up ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                        color: chColor, size: 15),
                  ),
                  Text('${item!.change24h.abs().toStringAsFixed(2)}%',
                      style: TextStyle(color: chColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ])
            else
              Text(
                'Ενημέρωση...',
                style: TextStyle(
                  color: ColorsUI.getPrimary(brightness),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),

            const SizedBox(width: 6),

            if (isSelectedFrom)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Text('ΑΠΟ', style: TextStyle(color: primary, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            else if (isSelectedTo)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: infoColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Text('ΣΕ', style: TextStyle(color: infoColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),

            const SizedBox(width: 4),

            Semantics(
              button: true,
              label: 'Αφαίρεση',
              child: InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: ExcludeSemantics(
                    child: Icon(Icons.close_rounded, size: 16, color: textSecondary.withValues(alpha: 0.6)),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── CryptoFallbackIcon ─────────────────────────────────────────
class _CryptoFallbackIcon extends StatelessWidget {
  final String symbol;
  final Color primary;
  const _CryptoFallbackIcon({required this.symbol, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34, height: 34,
      decoration: BoxDecoration(color: primary.withValues(alpha: 0.15), shape: BoxShape.circle),
      child: Center(child: Text(symbol,
          style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 14))),
    );
  }
}

// ── ConvCryptoSelector ─────────────────────────────────────────
class _ConvCryptoSelector extends StatelessWidget {
  final String? selectedId;
  final List<String> watchedIds;
  final Map<String, _CryptoItem> watchedData;
  final Brightness brightness;
  final String label;
  final ValueChanged<String?> onChanged;

  const _ConvCryptoSelector({
    required this.selectedId,
    required this.watchedIds,
    required this.watchedData,
    required this.brightness,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary     = ColorsUI.getPrimary(brightness);
    final textPrimary = ColorsUI.getTextPrimary(brightness);
    final textSec     = ColorsUI.getTextSecondary(brightness);
    final inputFill   = ColorsUI.getInputFill(brightness);

    final items = <DropdownMenuItem<String?>>[
      DropdownMenuItem<String?>(
        value: null,
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Center(child: Text('€', style: TextStyle(color: primary, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: textPrimary, fontSize: 14)),
        ]),
      ),
      ...watchedIds.map((id) {
        final item = watchedData[id];
        final sym  = item?.symbol ?? id.toUpperCase();
        final name = item?.name   ?? id;
        return DropdownMenuItem<String?>(
          value: id,
          child: Row(children: [
            if (item?.image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(item!.image!, width: 28, height: 28,
                    errorBuilder: (_, _, _) => _CryptoFallbackIcon(
                        symbol: sym.isNotEmpty ? sym[0] : '?', primary: primary)),
              )
            else
              _CryptoFallbackIcon(symbol: sym.isNotEmpty ? sym[0] : '?', primary: primary),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(sym, style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              Text(name, style: TextStyle(color: textSec, fontSize: 11), overflow: TextOverflow.ellipsis),
            ])),
          ]),
        );
      }),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorsUI.getBorder(brightness).withValues(alpha: 0.6)),
      ),
      child: DropdownButton<String?>(
        value: selectedId,
        underline: const SizedBox(),
        isExpanded: true,
        dropdownColor: ColorsUI.getCard(brightness),
        icon: ExcludeSemantics(
          child: Icon(Icons.keyboard_arrow_down_rounded, color: primary),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

// ── CryptoSearchSheet ──────────────────────────────────────────
class _CryptoSearchSheet extends StatefulWidget {
  final List<_CryptoItem> catalog;
  final List<String> watchedIds;
  final Brightness brightness;

  const _CryptoSearchSheet({
    required this.catalog,
    required this.watchedIds,
    required this.brightness,
  });

  @override
  State<_CryptoSearchSheet> createState() => _CryptoSearchSheetState();
}

class _CryptoSearchSheetState extends State<_CryptoSearchSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final primary     = ColorsUI.getPrimary(widget.brightness);
    final textPrimary = ColorsUI.getTextPrimary(widget.brightness);
    final textSec     = ColorsUI.getTextSecondary(widget.brightness);
    final inputFill   = ColorsUI.getInputFill(widget.brightness);

    final filtered = widget.catalog.where((c) {
      if (_q.isEmpty) return true;
      final q = _q.toLowerCase();
      return c.name.toLowerCase().contains(q) || c.symbol.toLowerCase().contains(q);
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 8),
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: textSec.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Αναζήτηση (Bitcoin, BTC, ETH...)',
              hintStyle: TextStyle(color: textSec),
              prefixIcon: ExcludeSemantics(
                child: Icon(Icons.search_rounded, color: textSec),
              ),
              filled: true, fillColor: inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            style: TextStyle(color: textPrimary),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: ctrl,
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final c = filtered[i];
              final isWatched = widget.watchedIds.contains(c.id);
              return ListTile(
                leading: c.image != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(c.image!, width: 36, height: 36,
                      errorBuilder: (_, _, _) => _CryptoFallbackIcon(
                          symbol: c.symbol[0], primary: primary)),
                )
                    : _CryptoFallbackIcon(symbol: c.symbol[0], primary: primary),
                title: Text(c.name, style: TextStyle(
                    color: textPrimary,
                    fontWeight: isWatched ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text(c.symbol, style: TextStyle(color: textSec, fontSize: 12)),
                trailing: isWatched
                    ? ExcludeSemantics(
                  child: Icon(Icons.check_circle_rounded, color: primary),
                )
                    : ExcludeSemantics(
                  child: Icon(Icons.add_circle_outline_rounded, color: primary.withValues(alpha: 0.7)),
                ),
                onTap: isWatched ? null : () => Navigator.pop(context, c.id),
              );
            },
          ),
        ),
      ]),
    );
  }
}