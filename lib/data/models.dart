import 'package:flutter/material.dart';

class BibleTranslation {
  const BibleTranslation({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.language,
    required this.languageCode,
    required this.license,
    required this.source,
    required this.description,
    required this.verseCount,
    required this.bundled,
    this.installedAt,
  });

  final String id;
  final String name;
  final String abbreviation;
  final String language;
  final String languageCode;
  final String license;
  final String source;
  final String description;
  final int verseCount;
  final bool bundled;
  final DateTime? installedAt;

  factory BibleTranslation.fromMap(Map<String, Object?> map) {
    return BibleTranslation(
      id: map['id'] as String,
      name: map['name'] as String,
      abbreviation: (map['abbreviation'] as String?) ?? '',
      language: (map['language'] as String?) ?? '',
      languageCode: (map['language_code'] as String?) ?? '',
      license: (map['license'] as String?) ?? '',
      source: (map['source'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      verseCount: (map['verse_count'] as num?)?.toInt() ?? 0,
      bundled: ((map['bundled'] as num?)?.toInt() ?? 0) == 1,
      installedAt: DateTime.tryParse((map['installed_at'] as String?) ?? ''),
    );
  }
}

class BibleBook {
  const BibleBook({
    required this.id,
    required this.translationId,
    required this.name,
    required this.abbreviation,
    required this.testament,
    required this.order,
    required this.chapterCount,
  });

  final String id;
  final String translationId;
  final String name;
  final String abbreviation;
  final String testament;
  final int order;
  final int chapterCount;

  bool get isNewTestament => testament == 'NT';
  bool get isDeuterocanon => testament == 'DC';

  factory BibleBook.fromMap(Map<String, Object?> map) {
    return BibleBook(
      id: map['id'] as String,
      translationId: map['translation_id'] as String,
      name: map['name'] as String,
      abbreviation: (map['abbreviation'] as String?) ?? '',
      testament: (map['testament'] as String?) ?? 'OT',
      order: (map['book_order'] as num?)?.toInt() ?? 0,
      chapterCount: (map['chapter_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class Verse {
  const Verse({
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  final String bookId;
  final int chapter;
  final int verse;
  final String text;

  factory Verse.fromMap(Map<String, Object?> map) {
    return Verse(
      bookId: map['book_id'] as String,
      chapter: (map['chapter'] as num).toInt(),
      verse: (map['verse'] as num).toInt(),
      text: map['text'] as String,
    );
  }
}

class ChapterContent {
  const ChapterContent({
    required this.translationId,
    required this.bookId,
    required this.bookName,
    required this.chapter,
    required this.verses,
  });

  final String translationId;
  final String bookId;
  final String bookName;
  final int chapter;
  final List<Verse> verses;

  String get reference => '$bookName $chapter';
}

class CatalogTranslation {
  const CatalogTranslation({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.language,
    required this.languageCode,
    required this.license,
    required this.source,
    required this.sourceFile,
    required this.description,
    required this.canon,
    required this.year,
    required this.bundled,
    required this.cached,
    this.verseCount = 0,
  });

  final String id;
  final String name;
  final String abbreviation;
  final String language;
  final String languageCode;
  final String license;
  final String source;
  final String sourceFile;
  final String description;
  final String canon;
  final String year;
  final bool bundled;
  final bool cached;
  final int verseCount;

  factory CatalogTranslation.fromJson(Map<String, dynamic> json) {
    return CatalogTranslation(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? json['id'] as String,
      abbreviation: (json['abbreviation'] as String?) ?? '',
      language: (json['language'] as String?) ?? '',
      languageCode: (json['languageCode'] as String?) ?? '',
      license: (json['license'] as String?) ?? '',
      source: (json['source'] as String?) ?? '',
      sourceFile: (json['sourceFile'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      canon: (json['canon'] as String?) ?? 'protestant',
      year: (json['year'] as String?) ?? '',
      bundled: json['bundled'] == true,
      cached: json['cached'] == true,
      verseCount: (json['verseCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class Perspective {
  const Perspective({
    required this.id,
    required this.label,
    required this.short,
    required this.description,
    required this.color,
    required this.icon,
  });

  final String id;
  final String label;
  final String short;
  final String description;
  final Color color;
  final String icon;

  factory Perspective.fromJson(Map<String, dynamic> json) {
    final raw = (json['color'] as String?) ?? '#8C3B2E';
    return Perspective(
      id: json['id'] as String,
      label: (json['label'] as String?) ?? json['id'] as String,
      short: (json['short'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      color: _parseHexColor(raw),
      icon: (json['icon'] as String?) ?? 'menu_book',
    );
  }

  IconData get iconData {
    switch (icon) {
      case 'church':
        return Icons.church_outlined;
      case 'auto_awesome':
        return Icons.auto_awesome_outlined;
      case 'history_edu':
        return Icons.history_edu_outlined;
      case 'star':
        return Icons.star_outline;
      case 'local_fire_department':
        return Icons.local_fire_department_outlined;
      case 'account_balance':
        return Icons.account_balance_outlined;
      case 'gavel':
        return Icons.gavel_outlined;
      case 'water_drop':
        return Icons.water_drop_outlined;
      case 'groups':
        return Icons.groups_outlined;
      case 'bolt':
        return Icons.bolt_outlined;
      case 'wb_sunny':
        return Icons.wb_sunny_outlined;
      case 'balance':
        return Icons.balance_outlined;
      case 'diversity_3':
        return Icons.diversity_3_outlined;
      case 'format_quote':
        return Icons.format_quote_outlined;
      case 'psychology':
        return Icons.psychology_outlined;
      case 'self_improvement':
        return Icons.self_improvement_outlined;
      default:
        return Icons.menu_book_outlined;
    }
  }
}

class Interpretation {
  const Interpretation({
    required this.bookId,
    required this.chapter,
    required this.verseStart,
    required this.verseEnd,
    required this.perspective,
    required this.label,
    required this.content,
    required this.model,
    required this.scope,
    required this.source,
    required this.sample,
    required this.createdAt,
  });

  final String bookId;
  final int chapter;
  final int verseStart;
  final int verseEnd;
  final String perspective;
  final String label;
  final String content;
  final String model;
  final String scope;
  final String source;
  final bool sample;
  final DateTime? createdAt;

  bool get isChapterOverview => scope == 'chapter';

  String get id => '$bookId:$chapter:$verseStart:$verseEnd:$perspective';

  factory Interpretation.fromMap(Map<String, Object?> map) {
    return Interpretation(
      bookId: map['book_id'] as String,
      chapter: (map['chapter'] as num).toInt(),
      verseStart: (map['verse_start'] as num?)?.toInt() ?? 1,
      verseEnd: (map['verse_end'] as num?)?.toInt() ?? 999,
      perspective: map['perspective'] as String,
      label: (map['label'] as String?) ?? map['perspective'] as String,
      content: map['content'] as String,
      model: (map['model'] as String?) ?? '',
      scope: (map['scope'] as String?) ?? 'chapter',
      source: (map['source'] as String?) ?? '',
      sample: ((map['sample'] as num?)?.toInt() ?? 0) == 1,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? ''),
    );
  }

  factory Interpretation.fromJson(Map<String, dynamic> json) {
    return Interpretation(
      bookId: (json['book'] as String?) ?? '',
      chapter: (json['chapter'] as num?)?.toInt() ?? 1,
      verseStart: (json['verseStart'] as num?)?.toInt() ?? 1,
      verseEnd: (json['verseEnd'] as num?)?.toInt() ?? 999,
      perspective: (json['perspective'] as String?) ?? '',
      label:
          (json['label'] as String?) ?? (json['perspective'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      model: (json['model'] as String?) ?? '',
      scope: (json['scope'] as String?) ?? 'chapter',
      source: (json['source'] as String?) ?? '',
      sample: json['sample'] == true || json['sample'] == 1,
      createdAt: DateTime.tryParse(
        (json['createdAt'] as String?) ?? (json['created_at'] as String?) ?? '',
      ),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'chapter': chapter,
      'verse_start': verseStart,
      'verse_end': verseEnd,
      'perspective': perspective,
      'label': label,
      'content': content,
      'model': model,
      'scope': scope,
      'source': source,
      'sample': sample ? 1 : 0,
      'created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
    };
  }
}

class InterpretationsView {
  const InterpretationsView({
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.passage,
    required this.overview,
    required this.available,
    required this.missing,
  });

  final String bookId;
  final int chapter;
  final int? verse;
  final List<Interpretation> passage;
  final List<Interpretation> overview;
  final List<String> available;
  final List<String> missing;

  List<Interpretation> get best => passage.isNotEmpty ? passage : overview;

  Interpretation? forPerspective(String id, {bool preferPassage = true}) {
    final lists = preferPassage ? [passage, overview] : [overview, passage];
    for (final list in lists) {
      for (final item in list) {
        if (item.perspective == id) return item;
      }
    }
    return null;
  }

  bool hasPerspective(String id) => forPerspective(id) != null;

  static InterpretationsView fromJson(Map<String, dynamic> json) {
    List<Interpretation> parse(String key) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Interpretation.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final available =
        (json['available'] as List?)?.whereType<String>().toList() ?? const [];
    final missing =
        (json['missing'] as List?)?.whereType<String>().toList() ?? const [];
    return InterpretationsView(
      bookId: (json['book'] as String?) ?? '',
      chapter: (json['chapter'] as num?)?.toInt() ?? 1,
      verse: (json['verse'] as num?)?.toInt(),
      passage: parse('passage'),
      overview: parse('chapterOverview'),
      available: available,
      missing: missing,
    );
  }
}

class Bookmark {
  const Bookmark({
    required this.id,
    required this.translationId,
    required this.bookId,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String translationId;
  final String bookId;
  final String bookName;
  final int chapter;
  final int verse;
  final String text;
  final DateTime? createdAt;

  String get reference => '$bookName $chapter:$verse';

  factory Bookmark.fromMap(Map<String, Object?> map) => Bookmark(
    id: map['id'] as String,
    translationId: map['translation_id'] as String,
    bookId: map['book_id'] as String,
    bookName: map['book_name'] as String,
    chapter: (map['chapter'] as num).toInt(),
    verse: (map['verse'] as num).toInt(),
    text: map['text'] as String,
    createdAt: DateTime.tryParse((map['created_at'] as String?) ?? ''),
  );
}

class Highlight {
  const Highlight({
    required this.translationId,
    required this.bookId,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.color,
    required this.createdAt,
  });

  final String translationId;
  final String bookId;
  final String bookName;
  final int chapter;
  final int verse;
  final String text;
  final int color;
  final DateTime? createdAt;

  String get reference => '$bookName $chapter:$verse';

  factory Highlight.fromMap(Map<String, Object?> map) => Highlight(
    translationId: map['translation_id'] as String,
    bookId: map['book_id'] as String,
    bookName: map['book_name'] as String,
    chapter: (map['chapter'] as num).toInt(),
    verse: (map['verse'] as num).toInt(),
    text: map['text'] as String,
    color: (map['color'] as num).toInt(),
    createdAt: DateTime.tryParse((map['created_at'] as String?) ?? ''),
  );
}

class Note {
  const Note({
    required this.id,
    required this.translationId,
    required this.bookId,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String translationId;
  final String bookId;
  final String bookName;
  final int chapter;
  final int verse;
  final String text;
  final String body;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get reference => '$bookName $chapter:$verse';

  factory Note.fromMap(Map<String, Object?> map) => Note(
    id: map['id'] as String,
    translationId: map['translation_id'] as String,
    bookId: map['book_id'] as String,
    bookName: map['book_name'] as String,
    chapter: (map['chapter'] as num).toInt(),
    verse: (map['verse'] as num).toInt(),
    text: map['text'] as String,
    body: map['body'] as String,
    createdAt: DateTime.tryParse((map['created_at'] as String?) ?? ''),
    updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? ''),
  );
}

class HistoryEntry {
  const HistoryEntry({
    required this.translationId,
    required this.bookId,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.readAt,
  });

  final String translationId;
  final String bookId;
  final String bookName;
  final int chapter;
  final int verse;
  final DateTime? readAt;

  String get reference => '$bookName $chapter';

  factory HistoryEntry.fromMap(Map<String, Object?> map) => HistoryEntry(
    translationId: map['translation_id'] as String,
    bookId: map['book_id'] as String,
    bookName: map['book_name'] as String,
    chapter: (map['chapter'] as num).toInt(),
    verse: (map['verse'] as num?)?.toInt() ?? 1,
    readAt: DateTime.tryParse((map['read_at'] as String?) ?? ''),
  );
}

class ReadingStats {
  const ReadingStats({
    required this.chaptersRead,
    required this.daysRead,
    required this.streak,
    required this.bookmarks,
    required this.notes,
    required this.highlights,
  });

  final int chaptersRead;
  final int daysRead;
  final int streak;
  final int bookmarks;
  final int notes;
  final int highlights;

  static const empty = ReadingStats(
    chaptersRead: 0,
    daysRead: 0,
    streak: 0,
    bookmarks: 0,
    notes: 0,
    highlights: 0,
  );
}

class PlanBookRef {
  const PlanBookRef({
    required this.bookId,
    required this.bookName,
    required this.startChapter,
    required this.endChapter,
  });

  final String bookId;
  final String bookName;
  final int startChapter;
  final int endChapter;

  String get label => startChapter == endChapter
      ? '$bookName $startChapter'
      : '$bookName $startChapter–$endChapter';
}

class PlanDay {
  const PlanDay({required this.day, required this.readings});

  final int day;
  final List<PlanBookRef> readings;

  String get summary => readings.map((r) => r.label).join(' · ');
}

class ReadingPlan {
  const ReadingPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.days,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final String description;
  final List<PlanDay> days;
  final IconData icon;
  final Color color;

  int get length => days.length;
}

Color _parseHexColor(String value) {
  var hex = value.replaceAll('#', '').trim();
  if (hex.length == 6) hex = 'FF$hex';
  final parsed = int.tryParse(hex, radix: 16);
  return Color(parsed ?? 0xFF8C3B2E);
}
