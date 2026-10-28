import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../data/models.dart';

class AppDatabase {
  AppDatabase._(this.db);

  final Database db;
  static AppDatabase? _instance;

  static Future<AppDatabase> open() async {
    if (_instance != null) return _instance!;
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final support = await getApplicationSupportDirectory();
    final path = p.join(support.path, 'bible_ai.db');
    final database = await openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA journal_mode = WAL');
      },
      onCreate: _createSchema,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS import_log(id INTEGER PRIMARY KEY AUTOINCREMENT, translation_id TEXT NOT NULL, completed_at TEXT NOT NULL)',
          );
        }
      },
    );
    final instance = AppDatabase._(database);
    _instance = instance;
    await instance._ensureStarterBible();
    await instance.seedSamplesIfNeeded();
    return instance;
  }

  static Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE translations(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        abbreviation TEXT NOT NULL DEFAULT '',
        language TEXT NOT NULL DEFAULT '',
        language_code TEXT NOT NULL DEFAULT '',
        license TEXT NOT NULL DEFAULT '',
        source TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        verse_count INTEGER NOT NULL DEFAULT 0,
        bundled INTEGER NOT NULL DEFAULT 0,
        installed_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE books(
        translation_id TEXT NOT NULL,
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        abbreviation TEXT NOT NULL DEFAULT '',
        testament TEXT NOT NULL DEFAULT 'OT',
        book_order INTEGER NOT NULL DEFAULT 0,
        chapter_count INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY(translation_id, id)
      )
    ''');
    await db.execute('''
      CREATE TABLE verses(
        translation_id TEXT NOT NULL,
        book_id TEXT NOT NULL,
        chapter INTEGER NOT NULL,
        verse INTEGER NOT NULL,
        text TEXT NOT NULL,
        PRIMARY KEY(translation_id, book_id, chapter, verse)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_verses_chapter ON verses(translation_id, book_id, chapter)',
    );
    await db.execute('CREATE INDEX idx_verses_text ON verses(text)');
    await db.execute('''
      CREATE TABLE bookmarks(
        id TEXT PRIMARY KEY,
        translation_id TEXT NOT NULL,
        book_id TEXT NOT NULL,
        book_name TEXT NOT NULL,
        chapter INTEGER NOT NULL,
        verse INTEGER NOT NULL,
        text TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(translation_id, book_id, chapter, verse)
      )
    ''');
    await db.execute('''
      CREATE TABLE highlights(
        translation_id TEXT NOT NULL,
        book_id TEXT NOT NULL,
        book_name TEXT NOT NULL,
        chapter INTEGER NOT NULL,
        verse INTEGER NOT NULL,
        text TEXT NOT NULL,
        color INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY(translation_id, book_id, chapter, verse)
      )
    ''');
    await db.execute('''
      CREATE TABLE notes(
        id TEXT PRIMARY KEY,
        translation_id TEXT NOT NULL,
        book_id TEXT NOT NULL,
        book_name TEXT NOT NULL,
        chapter INTEGER NOT NULL,
        verse INTEGER NOT NULL,
        text TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_notes_ref ON notes(translation_id, book_id, chapter, verse)',
    );
    await db.execute('''
      CREATE TABLE history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        translation_id TEXT NOT NULL,
        book_id TEXT NOT NULL,
        book_name TEXT NOT NULL,
        chapter INTEGER NOT NULL,
        verse INTEGER NOT NULL,
        read_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_history_time ON history(read_at)');
    await db.execute('''
      CREATE TABLE plan_progress(
        plan_id TEXT NOT NULL,
        day INTEGER NOT NULL,
        completed_at TEXT NOT NULL,
        PRIMARY KEY(plan_id, day)
      )
    ''');
    await db.execute('''
      CREATE TABLE interpretations(
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        chapter INTEGER NOT NULL,
        verse_start INTEGER NOT NULL DEFAULT 1,
        verse_end INTEGER NOT NULL DEFAULT 999,
        perspective TEXT NOT NULL,
        label TEXT NOT NULL DEFAULT '',
        content TEXT NOT NULL,
        model TEXT NOT NULL DEFAULT '',
        scope TEXT NOT NULL DEFAULT 'chapter',
        source TEXT NOT NULL DEFAULT '',
        sample INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_interpretations_ref ON interpretations(book_id, chapter)',
    );
    await db.execute(
      'CREATE TABLE import_log(id INTEGER PRIMARY KEY AUTOINCREMENT, translation_id TEXT NOT NULL, completed_at TEXT NOT NULL)',
    );
  }

  Future<void> _ensureStarterBible() async {
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM translations'),
        ) ??
        0;
    if (count > 0) return;
    try {
      final data = await rootBundle.load('assets/bibles/en-kjv.json.gz');
      final bytes = gzip.decode(data.buffer.asUint8List());
      final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      await installBundle(map, bundled: true);
    } catch (error, stack) {
      // The app can still download a translation from the server, but make the
      // failure visible in debug builds.
      // ignore: avoid_print
      print('Could not seed bundled KJV: $error\n$stack');
    }
  }

  Future<void> seedSamplesIfNeeded() async {
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM interpretations WHERE sample = 1',
          ),
        ) ??
        0;
    if (count > 0) return;
    try {
      final raw = await rootBundle.loadString(
        'assets/data/sample_interpretations.json',
      );
      final list = jsonDecode(raw) as List<dynamic>;
      await saveInterpretations(
        list
            .whereType<Map>()
            .map((e) => Interpretation.fromMap(Map<String, Object?>.from(e)))
            .toList(),
      );
    } catch (_) {
      // Samples are optional.
    }
  }

  Future<void> installBundle(
    Map<String, dynamic> bundle, {
    bool bundled = false,
  }) async {
    final id = bundle['id'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Translation has no valid id');
    }
    final books = (bundle['books'] as List?) ?? const [];
    if (books.isEmpty) throw const FormatException('Translation has no books');
    for (final rawBook in books.whereType<Map>()) {
      if (rawBook['id'] is! String || rawBook['chapters'] is! List) {
        throw const FormatException('Translation contains an invalid book');
      }
    }
    final installedAt = DateTime.now().toUtc().toIso8601String();
    int verseCount = (bundle['verseCount'] as num?)?.toInt() ?? 0;
    if (verseCount == 0) {
      for (final book in books.whereType<Map>()) {
        for (final chapter in (book['chapters'] as List? ?? const [])) {
          if (chapter is List) {
            verseCount += chapter
                .where((v) => v is String && v.trim().isNotEmpty)
                .length;
          }
        }
      }
    }

    await db.transaction((txn) async {
      await txn.delete('verses', where: 'translation_id = ?', whereArgs: [id]);
      await txn.delete('books', where: 'translation_id = ?', whereArgs: [id]);
      await txn.delete('translations', where: 'id = ?', whereArgs: [id]);

      await txn.insert('translations', {
        'id': id,
        'name': (bundle['name'] as String?) ?? id,
        'abbreviation': (bundle['abbreviation'] as String?) ?? '',
        'language': (bundle['language'] as String?) ?? '',
        'language_code': (bundle['languageCode'] as String?) ?? '',
        'license': (bundle['license'] as String?) ?? '',
        'source': (bundle['source'] as String?) ?? '',
        'description': (bundle['description'] as String?) ?? '',
        'verse_count': verseCount,
        'bundled': bundled ? 1 : 0,
        'installed_at': installedAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final bookBatch = txn.batch();
      var order = 0;
      for (final rawBook in books.whereType<Map>()) {
        order += 1;
        final book = Map<String, dynamic>.from(rawBook);
        final chapters = (book['chapters'] as List?) ?? const [];
        bookBatch.insert('books', {
          'translation_id': id,
          'id': book['id'] as String,
          'name': (book['name'] as String?) ?? (book['id'] as String),
          'abbreviation': (book['abbreviation'] as String?) ?? '',
          'testament': (book['testament'] as String?) ?? 'OT',
          'book_order': (book['order'] as num?)?.toInt() ?? order,
          'chapter_count': chapters.length,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await bookBatch.commit(noResult: true);

      var batch = txn.batch();
      var pending = 0;
      var chapterNumber = 0;
      for (final rawBook in books.whereType<Map>()) {
        final book = Map<String, dynamic>.from(rawBook);
        final bookId = book['id'] as String;
        chapterNumber = 0;
        for (final rawChapter in (book['chapters'] as List? ?? const [])) {
          chapterNumber += 1;
          if (rawChapter is! List) continue;
          var verseNumber = 0;
          for (final rawVerse in rawChapter) {
            verseNumber += 1;
            final text = rawVerse is String ? rawVerse.trim() : '';
            if (text.isEmpty) continue;
            batch.insert('verses', {
              'translation_id': id,
              'book_id': bookId,
              'chapter': chapterNumber,
              'verse': verseNumber,
              'text': text,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
            pending += 1;
            if (pending >= 4000) {
              await batch.commit(noResult: true);
              batch = txn.batch();
              pending = 0;
            }
          }
        }
      }
      await batch.commit(noResult: true);
      await txn.insert('import_log', {
        'translation_id': id,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  Future<List<BibleTranslation>> getTranslations() async {
    final rows = await db.query(
      'translations',
      orderBy: 'bundled DESC, installed_at ASC',
    );
    return rows.map(BibleTranslation.fromMap).toList();
  }

  Future<BibleTranslation?> getTranslation(String id) async {
    final rows = await db.query(
      'translations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : BibleTranslation.fromMap(rows.first);
  }

  Future<bool> isInstalled(String id) async {
    final rows = await db.query(
      'translations',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> deleteTranslation(String id) async {
    await db.transaction((txn) async {
      await txn.delete('verses', where: 'translation_id = ?', whereArgs: [id]);
      await txn.delete('books', where: 'translation_id = ?', whereArgs: [id]);
      await txn.delete('translations', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> renameTranslation(
    String id,
    String name,
    String abbreviation,
  ) async {
    await db.update(
      'translations',
      {'name': name, 'abbreviation': abbreviation},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<BibleBook>> getBooks(String translationId) async {
    final rows = await db.query(
      'books',
      where: 'translation_id = ?',
      whereArgs: [translationId],
      orderBy: 'book_order ASC',
    );
    return rows.map(BibleBook.fromMap).toList();
  }

  Future<BibleBook?> getBook(String translationId, String bookId) async {
    final rows = await db.query(
      'books',
      where: 'translation_id = ? AND id = ?',
      whereArgs: [translationId, bookId],
      limit: 1,
    );
    return rows.isEmpty ? null : BibleBook.fromMap(rows.first);
  }

  Future<ChapterContent?> getChapter(
    String translationId,
    String bookId,
    int chapter,
  ) async {
    final book = await getBook(translationId, bookId);
    if (book == null) return null;
    final rows = await db.query(
      'verses',
      where: 'translation_id = ? AND book_id = ? AND chapter = ?',
      whereArgs: [translationId, bookId, chapter],
      orderBy: 'verse ASC',
    );
    return ChapterContent(
      translationId: translationId,
      bookId: bookId,
      bookName: book.name,
      chapter: chapter,
      verses: rows.map(Verse.fromMap).toList(),
    );
  }

  Future<Verse?> getVerse(
    String translationId,
    String bookId,
    int chapter,
    int verse,
  ) async {
    final rows = await db.query(
      'verses',
      where: 'translation_id = ? AND book_id = ? AND chapter = ? AND verse = ?',
      whereArgs: [translationId, bookId, chapter, verse],
      limit: 1,
    );
    return rows.isEmpty ? null : Verse.fromMap(rows.first);
  }

  Future<List<SearchHit>> search(
    String query, {
    String? translationId,
    String testament = 'all',
    int limit = 250,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];
    final args = <Object?>['%$trimmed%'];
    final where = StringBuffer('v.text LIKE ?');
    if (translationId != null) {
      where.write(' AND v.translation_id = ?');
      args.add(translationId);
    }
    if (testament == 'OT') where.write(" AND b.testament = 'OT'");
    if (testament == 'NT') where.write(" AND b.testament = 'NT'");
    args.add(limit);
    final rows = await db.rawQuery('''
      SELECT v.translation_id, t.name AS translation_name, v.book_id, b.name AS book_name,
             b.book_order, v.chapter, v.verse, v.text
      FROM verses v
      JOIN books b ON b.translation_id = v.translation_id AND b.id = v.book_id
      JOIN translations t ON t.id = v.translation_id
      WHERE $where
      ORDER BY b.book_order, v.chapter, v.verse
      LIMIT ?
    ''', args);
    return rows.map(SearchHit.fromMap).toList();
  }

  Future<Verse?> verseOfDay(String translationId, DateTime date) async {
    final day = date.difference(DateTime(date.year, 1, 1)).inDays;
    final reference = _dailyReferences[day % _dailyReferences.length];
    return getVerse(translationId, reference.$1, reference.$2, reference.$3);
  }

  Future<void> recordHistory(
    String translationId,
    String bookId,
    String bookName,
    int chapter,
    int verse,
  ) async {
    await db.insert('history', {
      'translation_id': translationId,
      'book_id': bookId,
      'book_name': bookName,
      'chapter': chapter,
      'verse': verse,
      'read_at': DateTime.now().toUtc().toIso8601String(),
    });
    await db.rawDelete(
      'DELETE FROM history WHERE id NOT IN (SELECT id FROM history ORDER BY read_at DESC LIMIT 500)',
    );
  }

  Future<List<HistoryEntry>> recentHistory({int limit = 8}) async {
    final rows = await db.rawQuery(
      '''
      SELECT translation_id, book_id, book_name, chapter, MAX(verse) AS verse, MAX(read_at) AS read_at
      FROM history
      GROUP BY translation_id, book_id, chapter
      ORDER BY read_at DESC
      LIMIT ?
    ''',
      [limit],
    );
    return rows.map(HistoryEntry.fromMap).toList();
  }

  Future<ReadingStats> readingStats() async {
    final chapters =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM (SELECT DISTINCT book_id, chapter FROM history)',
          ),
        ) ??
        0;
    final dates = (await db.rawQuery(
      "SELECT DISTINCT substr(read_at, 1, 10) AS day FROM history ORDER BY day DESC",
    )).map((row) => row['day'] as String).toList();
    var streak = 0;
    if (dates.isNotEmpty) {
      final today = DateTime.now().toUtc();
      var cursor = DateTime.utc(today.year, today.month, today.day);
      final set = dates.toSet();
      String key(DateTime d) => d.toIso8601String().substring(0, 10);
      if (!set.contains(key(cursor))) {
        cursor = cursor.subtract(const Duration(days: 1));
      }
      while (set.contains(key(cursor))) {
        streak += 1;
        cursor = cursor.subtract(const Duration(days: 1));
      }
    }
    final bookmarks =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM bookmarks'),
        ) ??
        0;
    final notes =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM notes'),
        ) ??
        0;
    final highlights =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM highlights'),
        ) ??
        0;
    return ReadingStats(
      chaptersRead: chapters,
      daysRead: dates.length,
      streak: streak,
      bookmarks: bookmarks,
      notes: notes,
      highlights: highlights,
    );
  }

  Future<void> clearHistory() async => db.delete('history');

  Future<bool> isBookmarked(
    String translationId,
    String bookId,
    int chapter,
    int verse,
  ) async {
    final rows = await db.query(
      'bookmarks',
      columns: ['id'],
      where: 'translation_id = ? AND book_id = ? AND chapter = ? AND verse = ?',
      whereArgs: [translationId, bookId, chapter, verse],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> toggleBookmarkFor(
    String translationId,
    Verse verse,
    String bookName,
  ) async {
    final rows = await db.query(
      'bookmarks',
      columns: ['id'],
      where: 'translation_id = ? AND book_id = ? AND chapter = ? AND verse = ?',
      whereArgs: [translationId, verse.bookId, verse.chapter, verse.verse],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      await db.delete(
        'bookmarks',
        where: 'id = ?',
        whereArgs: [rows.first['id']],
      );
      return false;
    }
    await db.insert('bookmarks', {
      'id': '${DateTime.now().microsecondsSinceEpoch}',
      'translation_id': translationId,
      'book_id': verse.bookId,
      'book_name': bookName,
      'chapter': verse.chapter,
      'verse': verse.verse,
      'text': verse.text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return true;
  }

  Future<List<Bookmark>> getBookmarks() async {
    final rows = await db.query('bookmarks', orderBy: 'created_at DESC');
    return rows.map(Bookmark.fromMap).toList();
  }

  Future<void> deleteBookmark(String id) async {
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setHighlight(
    String translationId,
    Verse verse,
    String bookName,
    int color,
  ) async {
    if (color == 0) {
      await removeHighlight(
        translationId,
        verse.bookId,
        verse.chapter,
        verse.verse,
      );
      return;
    }
    await db.insert('highlights', {
      'translation_id': translationId,
      'book_id': verse.bookId,
      'book_name': bookName,
      'chapter': verse.chapter,
      'verse': verse.verse,
      'text': verse.text,
      'color': color,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeHighlight(
    String translationId,
    String bookId,
    int chapter,
    int verse,
  ) async {
    await db.delete(
      'highlights',
      where: 'translation_id = ? AND book_id = ? AND chapter = ? AND verse = ?',
      whereArgs: [translationId, bookId, chapter, verse],
    );
  }

  Future<Map<int, int>> getHighlightsForChapter(
    String translationId,
    String bookId,
    int chapter,
  ) async {
    final rows = await db.query(
      'highlights',
      columns: ['verse', 'color'],
      where: 'translation_id = ? AND book_id = ? AND chapter = ?',
      whereArgs: [translationId, bookId, chapter],
    );
    return {
      for (final row in rows)
        (row['verse'] as num).toInt(): (row['color'] as num).toInt(),
    };
  }

  Future<List<Highlight>> getHighlights() async {
    final rows = await db.query('highlights', orderBy: 'created_at DESC');
    return rows.map(Highlight.fromMap).toList();
  }

  Future<Note?> getNoteForVerse(
    String translationId,
    String bookId,
    int chapter,
    int verse,
  ) async {
    final rows = await db.query(
      'notes',
      where: 'translation_id = ? AND book_id = ? AND chapter = ? AND verse = ?',
      whereArgs: [translationId, bookId, chapter, verse],
      limit: 1,
    );
    return rows.isEmpty ? null : Note.fromMap(rows.first);
  }

  Future<Note> saveNote({
    Note? existing,
    required String translationId,
    required Verse verse,
    required String bookName,
    required String body,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final note = Note(
      id: existing?.id ?? '${DateTime.now().microsecondsSinceEpoch}',
      translationId: translationId,
      bookId: verse.bookId,
      bookName: bookName,
      chapter: verse.chapter,
      verse: verse.verse,
      text: verse.text,
      body: body,
      createdAt: existing?.createdAt,
      updatedAt: DateTime.now(),
    );
    await db.insert('notes', {
      'id': note.id,
      'translation_id': note.translationId,
      'book_id': note.bookId,
      'book_name': note.bookName,
      'chapter': note.chapter,
      'verse': note.verse,
      'text': note.text,
      'body': note.body,
      'created_at': (existing?.createdAt ?? DateTime.now())
          .toUtc()
          .toIso8601String(),
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return note;
  }

  Future<List<Note>> getNotes() async {
    final rows = await db.query('notes', orderBy: 'updated_at DESC');
    return rows.map(Note.fromMap).toList();
  }

  Future<void> deleteNote(String id) async {
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveInterpretations(List<Interpretation> items) async {
    if (items.isEmpty) return;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        'interpretations',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<InterpretationsView> getInterpretations(
    String bookId,
    int chapter,
    int verse,
    List<String> perspectiveIds,
  ) async {
    final rows = await db.query(
      'interpretations',
      where: 'book_id = ? AND chapter = ?',
      whereArgs: [bookId, chapter],
      orderBy: 'verse_start ASC, perspective ASC',
    );
    final all = rows.map(Interpretation.fromMap).toList();
    final passage = all
        .where(
          (i) =>
              i.scope == 'passage' &&
              i.verseStart <= verse &&
              i.verseEnd >= verse,
        )
        .toList();
    final overview = all.where((i) => i.scope == 'chapter').toList();
    final available = <String>{
      ...passage.map((i) => i.perspective),
      ...overview.map((i) => i.perspective),
    }.toList();
    return InterpretationsView(
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      passage: passage,
      overview: overview,
      available: available,
      missing: perspectiveIds.where((id) => !available.contains(id)).toList(),
    );
  }

  Future<int> interpretationCount({bool includeSamples = true}) async {
    final where = includeSamples ? '' : ' WHERE sample = 0';
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM interpretations$where'),
        ) ??
        0;
  }

  Future<void> clearInterpretations({bool keepSamples = true}) async {
    if (keepSamples) {
      await db.delete('interpretations', where: 'sample = 0');
    } else {
      await db.delete('interpretations');
    }
  }

  Future<Set<int>> getPlanProgress(String planId) async {
    final rows = await db.query(
      'plan_progress',
      columns: ['day'],
      where: 'plan_id = ?',
      whereArgs: [planId],
    );
    return rows.map((row) => (row['day'] as num).toInt()).toSet();
  }

  Future<void> setPlanDayCompleted(
    String planId,
    int day,
    bool completed,
  ) async {
    if (completed) {
      await db.insert('plan_progress', {
        'plan_id': planId,
        'day': day,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.delete(
        'plan_progress',
        where: 'plan_id = ? AND day = ?',
        whereArgs: [planId, day],
      );
    }
  }

  Future<void> resetPlan(String planId) async {
    await db.delete('plan_progress', where: 'plan_id = ?', whereArgs: [planId]);
  }

  Future<Map<String, dynamic>> exportUserData() async {
    return {
      'bookmarks': await db.query('bookmarks'),
      'highlights': await db.query('highlights'),
      'notes': await db.query('notes'),
      'planProgress': await db.query('plan_progress'),
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<void> importUserData(
    Map<String, dynamic> data, {
    bool merge = true,
  }) async {
    await db.transaction((txn) async {
      if (!merge) {
        await txn.delete('bookmarks');
        await txn.delete('highlights');
        await txn.delete('notes');
        await txn.delete('plan_progress');
      }
      for (final table in [
        'bookmarks',
        'highlights',
        'notes',
        'plan_progress',
      ]) {
        final rows = data[table];
        if (rows is! List) continue;
        for (final row in rows.whereType<Map>()) {
          await txn.insert(
            table,
            Map<String, Object?>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Future<void> close() async {
    await db.close();
    _instance = null;
  }

  static const List<(String, int, int)> _dailyReferences = [
    ('jhn', 3, 16),
    ('psa', 23, 1),
    ('rom', 8, 28),
    ('php', 4, 13),
    ('jer', 29, 11),
    ('pro', 3, 5),
    ('isa', 40, 31),
    ('mat', 11, 28),
    ('jos', 1, 9),
    ('psa', 46, 1),
    ('eph', 2, 8),
    ('2ti', 1, 7),
    ('heb', 11, 1),
    ('jas', 1, 5),
    ('1co', 13, 4),
    ('psa', 119, 105),
    ('gal', 5, 22),
    ('1pe', 5, 7),
    ('lam', 3, 22),
    ('mic', 6, 8),
    ('jhn', 14, 6),
    ('psa', 27, 1),
    ('isa', 41, 10),
    ('mat', 6, 33),
    ('rom', 12, 2),
    ('2co', 5, 17),
    ('psa', 34, 8),
    ('col', 3, 23),
    ('1jn', 4, 19),
    ('rev', 21, 4),
  ];
}

class SearchHit {
  const SearchHit({
    required this.translationId,
    required this.translationName,
    required this.bookId,
    required this.bookName,
    required this.order,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  final String translationId;
  final String translationName;
  final String bookId;
  final String bookName;
  final int order;
  final int chapter;
  final int verse;
  final String text;

  String get reference => '$bookName $chapter:$verse';

  factory SearchHit.fromMap(Map<String, Object?> map) => SearchHit(
    translationId: map['translation_id'] as String,
    translationName: (map['translation_name'] as String?) ?? '',
    bookId: map['book_id'] as String,
    bookName: map['book_name'] as String,
    order: (map['book_order'] as num?)?.toInt() ?? 0,
    chapter: (map['chapter'] as num).toInt(),
    verse: (map['verse'] as num).toInt(),
    text: map['text'] as String,
  );
}
