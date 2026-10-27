import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:bible_ai_app/core/theme.dart';
import 'package:bible_ai_app/data/plan_service.dart';
import 'package:bible_ai_app/data/translation_downloader.dart';

void main() {
  test('Bible AI theme exposes the parchment palette', () {
    final theme = AppTheme.build(ThemeMode.light, 'parchment');
    expect(theme.extension<AppPalette>()!.primary.toARGB32(), 0xFF8C3B2E);
  });

  test('reading plans distribute chapters across their scheduled days', () {
    final plan = PlanService.byId('bible-year')!;
    expect(plan.length, 365);
    expect(plan.days.expand((day) => day.readings).length, greaterThan(0));
    expect(PlanService.progressPercent(plan, {1, 2}), 1);
  });

  test('translation bundles reject malformed data', () {
    expect(
      () => TranslationDownloader.validateBundle(<String, dynamic>{}),
      throwsFormatException,
    );
    expect(
      () => TranslationDownloader.validateBundle({
        'id': 'demo',
        'books': [
          {'id': 'gen', 'chapters': []},
        ],
      }),
      returnsNormally,
    );
  });
}
