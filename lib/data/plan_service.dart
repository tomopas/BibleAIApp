import 'package:flutter/material.dart';

import 'canonical_books.dart';
import 'models.dart';

class PlanService {
  static final List<ReadingPlan> plans = _buildPlans();

  static ReadingPlan? byId(String id) {
    for (final plan in plans) {
      if (plan.id == id) return plan;
    }
    return null;
  }

  static DateTime parseStart(String value) =>
      DateTime.tryParse(value) ?? DateTime.now();

  static int dayOfPlan(ReadingPlan plan, DateTime start, Set<int> completed) {
    final elapsed =
        DateTime.now()
            .difference(DateTime(start.year, start.month, start.day))
            .inDays +
        1;
    var day = elapsed.clamp(1, plan.length);
    // If the scheduled day is already complete, offer the next unfinished day.
    if (completed.contains(day)) {
      for (var i = day + 1; i <= plan.length; i++) {
        if (!completed.contains(i)) return i;
      }
    }
    return day;
  }

  static int progressPercent(ReadingPlan plan, Set<int> completed) {
    if (plan.length == 0) return 0;
    return ((completed.length / plan.length) * 100).round().clamp(0, 100);
  }

  static PlanDay? today(ReadingPlan plan, DateTime start, Set<int> completed) {
    final day = dayOfPlan(plan, start, completed);
    if (day < 1 || day > plan.days.length) return null;
    return plan.days[day - 1];
  }

  static List<ReadingPlan> _buildPlans() {
    final bible = canonicalBooks.where((b) => !b.isDeuterocanon).toList();
    final nt = bible.where((b) => b.isNewTestament).toList();
    final psalms = canonicalBookById['psa']!;
    final proverbs = canonicalBookById['pro']!;
    final gospels = [
      'mat',
      'mrk',
      'luk',
      'jhn',
    ].map((id) => canonicalBookById[id]!).toList();

    return [
      ReadingPlan(
        id: 'bible-year',
        name: 'Bible in a Year',
        description: 'Every chapter of the Bible, about 3–4 chapters a day.',
        days: _splitChapters(bible, 365),
        icon: Icons.auto_stories_outlined,
        color: const Color(0xFF8C3B2E),
      ),
      ReadingPlan(
        id: 'nt-90',
        name: 'New Testament in 90 Days',
        description: 'The whole New Testament in three months.',
        days: _splitChapters(nt, 90),
        icon: Icons.menu_book_outlined,
        color: const Color(0xFF3E6B5A),
      ),
      ReadingPlan(
        id: 'gospels-60',
        name: 'Four Gospels in 60 Days',
        description: 'Walk through Matthew, Mark, Luke and John.',
        days: _splitChapters(gospels, 60),
        icon: Icons.auto_awesome_outlined,
        color: const Color(0xFF7A5C99),
      ),
      ReadingPlan(
        id: 'psalms-30',
        name: 'Psalms in 30 Days',
        description: 'Five psalms a day for a month of prayer.',
        days: _splitChapters([psalms], 30),
        icon: Icons.music_note_outlined,
        color: const Color(0xFFA67C2E),
      ),
      ReadingPlan(
        id: 'proverbs-31',
        name: 'Proverbs in 31 Days',
        description: 'One chapter of wisdom for each day of the month.',
        days: _splitChapters([proverbs], 31),
        icon: Icons.lightbulb_outline,
        color: const Color(0xFF4B6178),
      ),
    ];
  }

  static List<PlanDay> _splitChapters(List<CanonicalBook> books, int days) {
    final flat = <(CanonicalBook, int)>[];
    for (final book in books) {
      for (var chapter = 1; chapter <= book.chapterCount; chapter++) {
        flat.add((book, chapter));
      }
    }
    if (flat.isEmpty) return const [];
    final result = <PlanDay>[];
    for (var day = 0; day < days; day++) {
      final start = (day * flat.length / days).floor();
      final end = (((day + 1) * flat.length / days).ceil() - 1).clamp(
        start,
        flat.length - 1,
      );
      final refs = <PlanBookRef>[];
      for (var i = start; i <= end; i++) {
        final (book, chapter) = flat[i];
        if (refs.isNotEmpty &&
            refs.last.bookId == book.id &&
            refs.last.endChapter == chapter - 1) {
          final last = refs.removeLast();
          refs.add(
            PlanBookRef(
              bookId: last.bookId,
              bookName: last.bookName,
              startChapter: last.startChapter,
              endChapter: chapter,
            ),
          );
        } else {
          refs.add(
            PlanBookRef(
              bookId: book.id,
              bookName: book.name,
              startChapter: chapter,
              endChapter: chapter,
            ),
          );
        }
      }
      result.add(PlanDay(day: day + 1, readings: refs));
    }
    return result;
  }
}
