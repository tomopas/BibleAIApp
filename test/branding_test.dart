import 'package:bible_ai_app/core/branding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BrandingConfig', () {
    test('default configuration matches Bible AI standard defaults', () {
      const config = BrandingConfig();
      expect(config.appName, 'Bible AI');
      expect(config.shortName, 'Bible AI');
      expect(config.tagline, contains('Offline-first Bible reader'));
      expect(config.organizationName, isEmpty);
      expect(config.welcomeTitle, 'Welcome to Bible AI');
      expect(config.websiteUrl, isEmpty);
      expect(config.churchServiceInfo, isEmpty);
      expect(config.contactEmail, isEmpty);
      expect(config.hasChurchInfo, isFalse);
      expect(config.hasBanner, isFalse);
      expect(config.logoAsset, 'assets/icon/app_icon.png');
    });

    test('parses church personalization fields properly', () {
      final json = {
        'appName': 'Grace Study Bible',
        'shortName': 'Grace Bible',
        'tagline': 'Growing in Grace together',
        'organizationName': 'Grace Community Church',
        'welcomeTitle': 'Welcome to Grace Bible',
        'welcomeMessage': 'Read scripture with our church family.',
        'websiteUrl': 'https://gracechurch.example.com',
        'contactEmail': 'pastor@gracechurch.example.com',
        'churchServiceInfo': 'Sunday 10:00 AM | Main Sanctuary',
        'logoAsset': 'assets/icon/app_icon.png',
        'bannerAsset': 'assets/images/church_banner.png',
      };

      final config = BrandingConfig.fromJson(json);
      expect(config.appName, 'Grace Study Bible');
      expect(config.shortName, 'Grace Bible');
      expect(config.tagline, 'Growing in Grace together');
      expect(config.organizationName, 'Grace Community Church');
      expect(config.welcomeTitle, 'Welcome to Grace Bible');
      expect(config.welcomeMessage, 'Read scripture with our church family.');
      expect(config.websiteUrl, 'https://gracechurch.example.com');
      expect(config.contactEmail, 'pastor@gracechurch.example.com');
      expect(config.churchServiceInfo, 'Sunday 10:00 AM | Main Sanctuary');
      expect(config.hasChurchInfo, isTrue);
      expect(config.hasBanner, isTrue);
      expect(config.bannerAsset, 'assets/images/church_banner.png');

      final serialized = config.toJson();
      expect(serialized['appName'], 'Grace Study Bible');
      expect(serialized['organizationName'], 'Grace Community Church');
    });

    test('gracefully falls back to defaults for empty or missing values', () {
      final config = BrandingConfig.fromJson({
        'appName': '   ',
        'welcomeTitle': '',
      });
      expect(config.appName, 'Bible AI');
      expect(config.welcomeTitle, 'Welcome to Bible AI');
      expect(config.hasChurchInfo, isFalse);
    });
  });
}
