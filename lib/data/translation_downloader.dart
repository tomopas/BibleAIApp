import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../data/api_client.dart';
import '../data/canonical_books.dart';
import '../data/models.dart';

class DownloadUpdate {
  const DownloadUpdate({required this.message, this.fraction});
  final String message;
  final double? fraction;
}

class TranslationDownloader {
  TranslationDownloader({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _rawBase =
      'https://raw.githubusercontent.com/scrollmapper/bible_databases/master/formats/json';

  Future<List<CatalogTranslation>> loadFallbackCatalog() async {
    final raw = await rootBundle.loadString(
      'assets/data/catalog_fallback.json',
    );
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .whereType<Map>()
        .map((e) => CatalogTranslation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> download(
    CatalogTranslation entry, {
    ApiClient? api,
    void Function(DownloadUpdate update)? onUpdate,
  }) async {
    if (entry.bundled) {
      final raw = await rootBundle.load('assets/bibles/en-kjv.json.gz');
      final bytes = gzip.decode(raw.buffer.asUint8List());
      final bundle = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      validateBundle(bundle);
      return bundle;
    }

    if (api != null) {
      try {
        onUpdate?.call(
          const DownloadUpdate(
            message: 'Contacting Bible AI server…',
            fraction: 0,
          ),
        );
        final bundle = await api.downloadBundle(
          entry.id,
          onProgress: (progress, received, total) {
            onUpdate?.call(
              DownloadUpdate(
                message: total > 0
                    ? 'Downloading ${(received / 1000000).toStringAsFixed(1)} / ${(total / 1000000).toStringAsFixed(1)} MB'
                    : 'Downloading…',
                fraction: progress,
              ),
            );
          },
        );
        validateBundle(bundle);
        return bundle;
      } catch (_) {
        // Fall through to a direct public-domain download.
      }
    }

    if (entry.sourceFile.isEmpty) {
      throw Exception(
        'This translation can only be downloaded through the server.',
      );
    }
    onUpdate?.call(
      const DownloadUpdate(
        message: 'Downloading from the public-domain archive…',
        fraction: 0,
      ),
    );
    final url = Uri.parse(
      '$_rawBase/${Uri.encodeComponent(entry.sourceFile)}.json',
    );
    final request = http.Request('GET', url);
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw Exception(
        'Archive download failed (${response.statusCode}). Check your connection.',
      );
    }
    final total = response.contentLength ?? 0;
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
      if (total > 0) {
        onUpdate?.call(
          DownloadUpdate(
            message:
                'Downloading ${(bytes.length / 1000000).toStringAsFixed(1)} MB…',
            fraction: (bytes.length / total).clamp(0, 1).toDouble(),
          ),
        );
      }
    }
    onUpdate?.call(
      const DownloadUpdate(message: 'Preparing text…', fraction: 0.92),
    );
    final source = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final bundle = normalizeScrollmapper(source, entry);
    validateBundle(bundle);
    onUpdate?.call(const DownloadUpdate(message: 'Ready', fraction: 1));
    return bundle;
  }

  Map<String, dynamic> normalizeScrollmapper(
    Map<String, dynamic> source,
    CatalogTranslation entry,
  ) {
    final rawBooks = (source['books'] as List?) ?? const [];
    final books = <Map<String, dynamic>>[];
    var totalVerses = 0;
    final canon = entry.canon;

    for (final rawBook in rawBooks.whereType<Map>()) {
      final name = (rawBook['name'] as String?) ?? '';
      final meta = canonicalBookByScrollmapperName[name];
      if (meta == null) continue;
      if (canon == 'protestant' && meta.isDeuterocanon) continue;
      if (canon == 'ot' && meta.isNewTestament) continue;
      if (canon == 'nt' && !meta.isNewTestament) continue;

      final chapters = <List<String>>[];
      for (final rawChapter in (rawBook['chapters'] as List? ?? const [])) {
        if (rawChapter is! Map) continue;
        final versesMap = <int, String>{};
        for (final rawVerse in (rawChapter['verses'] as List? ?? const [])) {
          if (rawVerse is! Map) continue;
          final number = int.tryParse('${rawVerse['verse']}');
          final text = cleanText('${rawVerse['text'] ?? ''}');
          if (number == null || number <= 0) continue;
          versesMap[number] = text;
        }

        if (versesMap.isEmpty) continue;
        final last = versesMap.keys.reduce((a, b) => a > b ? a : b);
        final chapter = List<String>.generate(
          last,
          (i) => versesMap[i + 1] ?? '',
        );
        chapters.add(chapter);
        totalVerses += chapter.where((v) => v.isNotEmpty).length;
      }

      if (chapters.isEmpty) continue;
      books.add({
        'id': meta.id,
        'name': meta.name,
        'abbreviation': meta.abbreviation,
        'testament': meta.testament,
        'order': books.length + 1,
        'chapters': chapters,
      });
    }

    if (books.isEmpty) {
      throw Exception('No supported books were found in this translation.');
    }

    return {
      'id': entry.id,
      'name': entry.name,
      'abbreviation': entry.abbreviation,
      'language': entry.language,
      'languageCode': entry.languageCode,
      'license': entry.license,
      'source': entry.source,
      'description': entry.description,
      'year': entry.year,
      'canon': entry.canon,
      'verseCount': totalVerses,
      'books': books,
    };
  }

  static void validateBundle(Map<String, dynamic> bundle) {
    final id = bundle['id'];
    final books = bundle['books'];
    if (id is! String || id.trim().isEmpty || books is! List || books.isEmpty) {
      throw const FormatException('Translation bundle has an invalid header');
    }
    for (final book in books.whereType<Map>()) {
      if (book['id'] is! String || book['chapters'] is! List) {
        throw const FormatException(
          'Translation bundle contains an invalid book',
        );
      }
    }
  }

  static String cleanText(String value) {
    var text = value
        .replaceAll(RegExp(r'[\u200b\ufeff]'), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
    const replacements = {
      '&amp;': '&',
      '&quot;': '"',
      '&#39;': "'",
      '&apos;': "'",
      '&lt;': '<',
      '&gt;': '>',
      '&nbsp;': ' ',
    };
    replacements.forEach((key, replacement) {
      text = text.replaceAll(key, replacement);
    });
    return text;
  }

  void dispose() => _client.close();
}
