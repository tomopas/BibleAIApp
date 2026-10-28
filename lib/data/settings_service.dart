import 'dart:io';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/canonical_books.dart';

class SettingsService {
  SettingsService._(this._prefs);

  final SharedPreferences _prefs;

  static Future<SettingsService> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService._(prefs);
  }

  /// Baked in at build time so release APKs point at the hosted backend:
  /// `flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com`
  ///
  /// A URL saved in Settings still wins over this default.
  static const String _apiBaseUrlFromEnvironment = String.fromEnvironment(
    'API_BASE_URL',
  );

  String get defaultServerUrl {
    if (_apiBaseUrlFromEnvironment.isNotEmpty) {
      return _apiBaseUrlFromEnvironment;
    }
    if (Platform.isAndroid) return 'http://10.0.2.2:8765';
    return 'http://127.0.0.1:8765';
  }

  String get serverUrl => _prefs.getString('serverUrl') ?? defaultServerUrl;
  set serverUrl(String value) => _prefs.setString('serverUrl', value.trim());

  String get translationId => _prefs.getString('translationId') ?? 'en-kjv';
  set translationId(String value) => _prefs.setString('translationId', value);

  String get bookId => _prefs.getString('bookId') ?? 'jhn';
  set bookId(String value) => _prefs.setString('bookId', value);

  int get chapter => _prefs.getInt('chapter') ?? 1;
  set chapter(int value) => _prefs.setInt('chapter', value);

  int get verse => _prefs.getInt('verse') ?? 1;
  set verse(int value) => _prefs.setInt('verse', value);

  String get themeMode => _prefs.getString('themeMode') ?? 'system';
  set themeMode(String value) => _prefs.setString('themeMode', value);

  String get themeStyle => _prefs.getString('themeStyle') ?? 'parchment';
  set themeStyle(String value) => _prefs.setString('themeStyle', value);

  double get fontSize => _prefs.getDouble('fontSize') ?? 18.0;
  set fontSize(double value) => _prefs.setDouble('fontSize', value);

  double get lineHeight => _prefs.getDouble('lineHeight') ?? 1.65;
  set lineHeight(double value) => _prefs.setDouble('lineHeight', value);

  String get fontFamily => _prefs.getString('fontFamily') ?? 'serif';
  set fontFamily(String value) => _prefs.setString('fontFamily', value);

  bool get showVerseNumbers => _prefs.getBool('showVerseNumbers') ?? true;
  set showVerseNumbers(bool value) => _prefs.setBool('showVerseNumbers', value);

  String get defaultPerspective =>
      _prefs.getString('defaultPerspective') ?? 'protestant';
  set defaultPerspective(String value) =>
      _prefs.setString('defaultPerspective', value);

  String get audioVoice => _prefs.getString('audioVoice') ?? '';
  set audioVoice(String value) => _prefs.setString('audioVoice', value);

  double get audioRate => _prefs.getDouble('audioRate') ?? 1.0;
  set audioRate(double value) => _prefs.setDouble('audioRate', value);

  bool get audioAutoNext => _prefs.getBool('audioAutoNext') ?? false;
  set audioAutoNext(bool value) => _prefs.setBool('audioAutoNext', value);

  /// Playback source: `auto` (recorded when available), `server` (recorded
  /// only) or `device` (on-device text-to-speech).
  String get narrationSource => _prefs.getString('narrationSource') ?? 'auto';
  set narrationSource(String value) =>
      _prefs.setString('narrationSource', value);

  bool get onboardingDone => _prefs.getBool('onboardingDone') ?? false;
  set onboardingDone(bool value) => _prefs.setBool('onboardingDone', value);

  String get planId => _prefs.getString('planId') ?? '';
  set planId(String value) => _prefs.setString('planId', value);

  String get planStartDate => _prefs.getString('planStartDate') ?? '';
  set planStartDate(String value) => _prefs.setString('planStartDate', value);

  bool get syncEnabled => _prefs.getBool('syncEnabled') ?? false;
  set syncEnabled(bool value) => _prefs.setBool('syncEnabled', value);

  String get userId {
    final existing = _prefs.getString('userId');
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final value = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _prefs.setString('userId', value);
    return value;
  }

  set userId(String value) => _prefs.setString('userId', value);

  bool get samplesSeeded => _prefs.getBool('samplesSeeded') ?? false;
  set samplesSeeded(bool value) => _prefs.setBool('samplesSeeded', value);

  bool get isFirstLaunch => !onboardingDone;

  String get currentReference =>
      '${canonicalBookById[bookId]?.name ?? bookId} $chapter';
}
