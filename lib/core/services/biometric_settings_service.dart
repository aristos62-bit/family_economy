import 'package:cloud_firestore/cloud_firestore.dart';

class BiometricSettings {
  final bool enabled;
  final String mode; // 'always' | 'on_demand'
  final bool remember;

  const BiometricSettings({
    required this.enabled,
    required this.mode,
    required this.remember,
  });

  factory BiometricSettings.defaults() => const BiometricSettings(
    enabled: false,
    mode: 'always',
    remember: false,
  );

  BiometricSettings copyWith({
    bool? enabled,
    String? mode,
    bool? remember,
  }) =>
      BiometricSettings(
        enabled: enabled ?? this.enabled,
        mode: mode ?? this.mode,
        remember: remember ?? this.remember,
      );
}

class BiometricSettingsService {
  BiometricSettingsService._();
  static final BiometricSettingsService instance = BiometricSettingsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _firestore.collection('users').doc(uid);

  Future<BiometricSettings> load(String uid) async {
    final doc = await _userRef(uid).get();
    final data = doc.data();
    if (data == null) return BiometricSettings.defaults();

    return BiometricSettings(
      enabled: (data['fingerprint_enabled'] as bool?) ?? false,
      mode: (data['biometric_mode'] as String?) ?? 'always',
      remember: (data['biometric_remember'] as bool?) ?? false,
    );
  }

  Future<void> setEnabled(String uid, bool enabled) async {
    await _userRef(uid).set(
      {
        'fingerprint_enabled': enabled,
        'updated_at': Timestamp.now(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> setMode(String uid, String mode) async {
    // ασφαλιστικό: δέχεται μόνο 2 τιμές
    final safeMode = (mode == 'on_demand') ? 'on_demand' : 'always';

    await _userRef(uid).set(
      {
        'biometric_mode': safeMode,
        'updated_at': Timestamp.now(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> setRemember(String uid, bool remember) async {
    await _userRef(uid).set(
      {
        'biometric_remember': remember,
        'updated_at': Timestamp.now(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> saveAll(String uid, BiometricSettings s) async {
    final safeMode = (s.mode == 'on_demand') ? 'on_demand' : 'always';

    await _userRef(uid).set(
      {
        'fingerprint_enabled': s.enabled,
        'biometric_mode': safeMode,
        'biometric_remember': s.remember,
        'updated_at': Timestamp.now(),
      },
      SetOptions(merge: true),
    );
  }
}
