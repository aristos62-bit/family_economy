import 'package:package_info_plus/package_info_plus.dart';

/// Πληροφορίες έκδοσης της εφαρμογής.
///
/// Η έκδοση ΔΕΝ γράφεται στον κώδικα: διαβάζεται από το πραγματικό πακέτο
/// της πλατφόρμας, το οποίο παράγεται από το `version:` του `pubspec.yaml`.
///
/// - Android : versionName / versionCode
/// - Windows : ProductVersion του .exe ("2.0.1+2" -> 2.0.1 / 2)
/// - iOS/macOS: CFBundleShortVersionString / CFBundleVersion
/// - Web     : build/web/version.json (παράγεται από το `flutter build web`)
class AppInfo {
  const AppInfo._();

  static PackageInfo? _cached;

  /// Φορτώνει (μία φορά) τις πληροφορίες του πακέτου.
  static Future<PackageInfo> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    return _cached = await PackageInfo.fromPlatform();
  }

  /// Μόνο το κομμάτι SemVer, π.χ. `2.0.1`.
  static Future<String> version() async => _cleanVersion(await load());

  /// Μόνο το build number, π.χ. `2`.
  static Future<String> buildNumber() async => _cleanBuild(await load());

  /// Έτοιμο κείμενο για εμφάνιση, π.χ. `Έκδοση 2.0.1 (build 2)`.
  static Future<String> versionLabel() async {
    final info = await load();
    final version = _cleanVersion(info);
    final build = _cleanBuild(info);
    if (version.isEmpty) return '';
    if (build.isEmpty) return 'Έκδοση $version';
    return 'Έκδοση $version (build $build)';
  }

  /// Χωρίς κενά και χωρίς το τμήμα `+build` (το Windows το επιστρέφει μαζί).
  static String _cleanVersion(PackageInfo info) {
    final raw = info.version.trim();
    final plus = raw.indexOf('+');
    return (plus >= 0 ? raw.substring(0, plus) : raw).trim();
  }

  /// Το build number· αν λείπει, το παίρνει από το `+build` της έκδοσης.
  static String _cleanBuild(PackageInfo info) {
    final build = info.buildNumber.trim();
    if (build.isNotEmpty) return build;
    final raw = info.version.trim();
    final plus = raw.indexOf('+');
    if (plus < 0 || plus + 1 >= raw.length) return '';
    return raw.substring(plus + 1).trim();
  }
}
