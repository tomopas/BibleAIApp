import 'dart:convert';
import 'package:flutter/services.dart';

/// Configuration for white-labeling / church branding.
///
/// By default, Bible AI runs in standard mode with official branding.
/// Churches and ministries can fork or configure this file via
/// `scripts/personalize.py` to display their own Bible name, church info,
/// service times, custom pictures, and website.
class BrandingConfig {
  const BrandingConfig({
    this.appName = 'Bible AI',
    this.shortName = 'Bible AI',
    this.tagline =
        'Offline-first Bible reader with AI study perspectives and audio',
    this.organizationName = '',
    this.welcomeTitle = 'Welcome to Bible AI',
    this.welcomeMessage =
        'Read offline, save your own study notes, and explore interpretations from several traditions.',
    this.websiteUrl = '',
    this.contactEmail = '',
    this.churchServiceInfo = '',
    this.logoAsset = 'assets/icon/app_icon.png',
    this.bannerAsset = '',
  });

  /// The primary display name of the Bible app (e.g. "Grace Bible" or "Bible AI").
  final String appName;

  /// Shorter name used for compact UI headers or app labels.
  final String shortName;

  /// Tagline or mission motto (e.g. "To know Christ and make Him known").
  final String tagline;

  /// Church or ministry name (e.g. "Grace Community Church").
  final String organizationName;

  /// Welcome banner headline shown on first launch.
  final String welcomeTitle;

  /// Welcome banner description shown on first launch.
  final String welcomeMessage;

  /// Church or ministry official website URL.
  final String websiteUrl;

  /// Church or ministry contact email.
  final String contactEmail;

  /// Worship service times, address, or livestream details.
  final String churchServiceInfo;

  /// Asset path to the app icon / church logo.
  final String logoAsset;

  /// Optional asset path to a church banner / photo.
  final String bannerAsset;

  /// Returns true if custom church / organization details are present.
  bool get hasChurchInfo =>
      organizationName.isNotEmpty ||
      websiteUrl.isNotEmpty ||
      churchServiceInfo.isNotEmpty ||
      contactEmail.isNotEmpty;

  /// Returns true if a custom banner image is specified.
  bool get hasBanner => bannerAsset.isNotEmpty;

  factory BrandingConfig.fromJson(Map<String, dynamic> json) {
    String str(String key, String fallback) {
      final val = json[key];
      if (val is String && val.trim().isNotEmpty) {
        return val.trim();
      }
      return fallback;
    }

    String optStr(String key) {
      final val = json[key];
      if (val is String) {
        return val.trim();
      }
      return '';
    }

    return BrandingConfig(
      appName: str('appName', 'Bible AI'),
      shortName: str('shortName', 'Bible AI'),
      tagline: str(
        'tagline',
        'Offline-first Bible reader with AI study perspectives and audio',
      ),
      organizationName: optStr('organizationName'),
      welcomeTitle: str('welcomeTitle', 'Welcome to Bible AI'),
      welcomeMessage: str(
        'welcomeMessage',
        'Read offline, save your own study notes, and explore interpretations from several traditions.',
      ),
      websiteUrl: optStr('websiteUrl'),
      contactEmail: optStr('contactEmail'),
      churchServiceInfo: optStr('churchServiceInfo'),
      logoAsset: str('logoAsset', 'assets/icon/app_icon.png'),
      bannerAsset: optStr('bannerAsset'),
    );
  }

  Map<String, dynamic> toJson() => {
    'appName': appName,
    'shortName': shortName,
    'tagline': tagline,
    'organizationName': organizationName,
    'welcomeTitle': welcomeTitle,
    'welcomeMessage': welcomeMessage,
    'websiteUrl': websiteUrl,
    'contactEmail': contactEmail,
    'churchServiceInfo': churchServiceInfo,
    'logoAsset': logoAsset,
    'bannerAsset': bannerAsset,
  };

  static BrandingConfig _current = const BrandingConfig();
  static BrandingConfig get current => _current;

  /// Loads the branding config from [assets/branding.json].
  /// Falls back to default Bible AI branding if missing or invalid.
  static Future<BrandingConfig> load() async {
    try {
      final raw = await rootBundle.loadString('assets/branding.json');
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _current = BrandingConfig.fromJson(decoded);
      } else if (decoded is Map) {
        _current = BrandingConfig.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      _current = const BrandingConfig();
    }
    return _current;
  }

  /// Manually override current branding (useful for testing or dynamic themes).
  static void setMock(BrandingConfig config) {
    _current = config;
  }
}
