import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api_client.dart';
import '../data/app_database.dart';
import '../data/audio_service.dart';
import '../data/canonical_books.dart';
import '../data/models.dart';
import '../data/plan_service.dart';
import '../data/settings_service.dart';
import '../data/translation_downloader.dart';

class AppState extends ChangeNotifier {
  AppState({
    required this.db,
    required this.settings,
    required this.api,
    required this.downloader,
  });

  final AppDatabase db;
  final SettingsService settings;
  ApiClient api;
  final TranslationDownloader downloader;
  final AudioService audio = AudioService();

  List<BibleTranslation> translations = const [];
  List<CatalogTranslation> catalog = const [];
  bool catalogFromServer = false;
  List<BibleBook> books = const [];
  List<Perspective> perspectives = const [];

  String translationId = 'en-kjv';
  String bookId = 'jhn';
  int chapter = 1;
  int? focusVerse;
  int tabIndex = 0;

  HealthStatus health = HealthStatus.offline;
  bool checkingServer = false;
  int _serverCheckGeneration = 0;
  bool catalogLoading = true;
  GenerateJob? generationJob;
  bool generating = false;
  String? generationError;

  ReadingStats stats = ReadingStats.empty;
  List<HistoryEntry> recent = const [];
  Set<int> planProgress = const {};

  ChapterContent? _chapterCache;
  String? _chapterCacheKey;
  Future<List<Object?>>? _chapterViewFuture;

  /// Cached "is recorded narration available" probes. Negative results expire
  /// so newly generated chapters appear without restarting the app.
  final Map<String, _AudioProbe> _audioProbes = {};
  Set<int> interpretationVerses = const {};

  static const _fallbackPerspectives = <Perspective>[
    Perspective(
      id: 'catholic',
      label: 'Catholic',
      short: 'Sacramental & magisterial',
      description: 'Reads with the Catholic canon, sacraments and tradition.',
      color: Color(0xFF9A4A3A),
      icon: 'church',
    ),
    Perspective(
      id: 'protestant',
      label: 'Protestant / Reformed',
      short: 'Scripture, grace & covenant',
      description:
          'Reads through Reformation emphases on grace, faith and covenant.',
      color: Color(0xFF3E6B5A),
      icon: 'menu_book',
    ),
    Perspective(
      id: 'orthodox',
      label: 'Orthodox',
      short: 'Theosis & liturgy',
      description:
          'Reads within the Eastern Orthodox liturgical and patristic tradition.',
      color: Color(0xFF7A5C99),
      icon: 'auto_awesome',
    ),
    Perspective(
      id: 'historical_critical',
      label: 'Historical-critical',
      short: 'Context, sources & history',
      description:
          'Asks about historical setting, sources and the world behind the text.',
      color: Color(0xFF4B6178),
      icon: 'history_edu',
    ),
    Perspective(
      id: 'jewish',
      label: 'Jewish',
      short: 'Tanakh & Jewish reading',
      description:
          'Reads within Jewish scripture, interpretation and practice.',
      color: Color(0xFF2F6690),
      icon: 'star',
    ),
  ];

  Future<void> init() async {
    audio.onComplete = _handleNarrationComplete;
    await audio.setRate(settings.audioRate);
    await audio.setVoice(
      settings.audioVoice.isEmpty ? null : settings.audioVoice,
    );
    await _loadPerspectives();
    await refreshInstalled();
    await _restorePosition();
    await refreshDashboard();
    await _loadFallbackCatalog();
    unawaited(checkServer());
  }

  Future<void> _loadPerspectives() async {
    try {
      final raw = await rootBundle.loadString('shared/perspectives.json');
      final list = jsonDecode(raw) as List<dynamic>;
      perspectives = list
          .whereType<Map>()
          .map((e) => Perspective.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      perspectives = _fallbackPerspectives;
    }
    if (!perspectives.any((p) => p.id == settings.defaultPerspective)) {
      settings.defaultPerspective = perspectives.first.id;
    }
  }

  Future<void> _loadFallbackCatalog() async {
    try {
      catalog = await downloader.loadFallbackCatalog();
    } catch (_) {
      catalog = const [];
    }
    catalogLoading = false;
    notifyListeners();
  }

  Future<void> refreshInstalled() async {
    translations = await db.getTranslations();
    final ids = translations.map((t) => t.id).toSet();
    if (!ids.contains(translationId)) {
      translationId = translations.isNotEmpty
          ? translations.first.id
          : 'en-kjv';
    }
    await _loadBooks();
    _invalidateChapter();
    notifyListeners();
  }

  Future<void> _loadBooks() async {
    books = await db.getBooks(translationId);
    if (books.isEmpty) return;
    if (!books.any((b) => b.id == bookId)) {
      bookId = books.first.id;
      chapter = 1;
    }
  }

  Future<void> _restorePosition() async {
    final storedTranslation = settings.translationId;
    if (translations.any((t) => t.id == storedTranslation)) {
      translationId = storedTranslation;
    }
    await _loadBooks();
    if (books.isEmpty) return;
    final storedBook = settings.bookId;
    if (books.any((b) => b.id == storedBook)) {
      bookId = storedBook;
    }
    final book = currentBook;
    if (book != null) {
      chapter = settings.chapter.clamp(1, book.chapterCount);
    }
    focusVerse = settings.verse > 1 ? settings.verse : null;
  }

  Future<void> refreshDashboard() async {
    stats = await db.readingStats();
    recent = await db.recentHistory();
    final plan = activePlan;
    if (plan != null) {
      planProgress = await db.getPlanProgress(plan.id);
    } else {
      planProgress = const {};
    }
    notifyListeners();
  }

  Future<ChapterContent?> loadCurrentChapter({bool force = false}) async {
    final key = '$translationId:$bookId:$chapter';
    if (force) {
      _chapterCache = null;
      _chapterCacheKey = null;
      _chapterViewFuture = null;
    }
    if (!force && _chapterCacheKey == key) return _chapterCache;
    final loaded = await db.getChapter(translationId, bookId, chapter);
    _chapterCache = loaded;
    _chapterCacheKey = key;
    return loaded;
  }

  Future<List<Object?>> currentChapterViewFuture() {
    final key = '$translationId:$bookId:$chapter';
    if (_chapterViewFuture == null || _chapterCacheKey != key) {
      _chapterViewFuture = Future.wait<Object?>([
        loadCurrentChapter(),
        db.getHighlightsForChapter(translationId, bookId, chapter),
      ]);
    }
    return _chapterViewFuture!;
  }

  void _invalidateChapter() {
    _chapterCache = null;
    _chapterCacheKey = null;
    _chapterViewFuture = null;
  }

  BibleBook? get currentBook {
    for (final book in books) {
      if (book.id == bookId) return book;
    }
    return null;
  }

  BibleTranslation? get currentTranslation {
    for (final t in translations) {
      if (t.id == translationId) return t;
    }
    return null;
  }

  String get currentBookName =>
      currentBook?.name ?? canonicalBookById[bookId]?.name ?? bookId;

  String get reference =>
      '$currentBookName $chapter${focusVerse != null ? ':$focusVerse' : ''}';

  String get defaultPerspective => settings.defaultPerspective;

  Perspective? perspectiveById(String id) {
    for (final p in perspectives) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> setTab(int index) async {
    tabIndex = index;
    notifyListeners();
    if (index == 0) unawaited(refreshDashboard());
  }

  Future<void> openChapter(
    String newBookId,
    int newChapter, {
    int? verse,
    int tab = 1,
  }) async {
    final book = books.where((b) => b.id == newBookId).firstOrNull;
    if (book == null) return;
    bookId = newBookId;
    chapter = newChapter.clamp(1, book.chapterCount);
    focusVerse = verse;
    tabIndex = tab;
    _invalidateChapter();
    settings
      ..translationId = translationId
      ..bookId = bookId
      ..chapter = chapter
      ..verse = verse ?? 1;
    unawaited(
      db.recordHistory(translationId, bookId, book.name, chapter, verse ?? 1),
    );
    notifyListeners();
    unawaited(refreshInterpretationCoverage());
  }

  Future<void> refreshInterpretationCoverage() async {
    final targetBook = bookId;
    final targetChapter = chapter;
    var view = await db.getInterpretations(
      targetBook,
      targetChapter,
      1,
      perspectives.map((p) => p.id).toList(),
    );
    if (health.online) {
      try {
        final remote = await api.interpretations(
          bookId: targetBook,
          chapter: targetChapter,
          verse: 1,
        );
        await db.saveInterpretations([...remote.passage, ...remote.overview]);
        view = remote;
      } catch (_) {}
    }
    final content = await db.getChapter(translationId, targetBook, targetChapter);
    final covered = <int>{};
    for (final item in [...view.passage, ...view.overview]) {
      final start = item.scope == 'chapter' ? 1 : item.verseStart;
      final end = item.scope == 'chapter'
          ? content?.verses.length ?? item.verseEnd
          : item.verseEnd;
      for (var verse = start; verse <= end; verse++) {
        covered.add(verse);
      }
    }
    if (targetBook == bookId && targetChapter == chapter) {
      interpretationVerses = covered;
      notifyListeners();
    }
  }

  Future<void> goToNextChapter() async {
    final book = currentBook;
    if (book == null) return;
    if (chapter < book.chapterCount) {
      await openChapter(bookId, chapter + 1, tab: tabIndex);
      return;
    }
    final index = books.indexWhere((b) => b.id == bookId);
    if (index >= 0 && index + 1 < books.length) {
      final next = books[index + 1];
      await openChapter(next.id, 1, tab: tabIndex);
    }
  }

  Future<void> goToPreviousChapter() async {
    if (chapter > 1) {
      await openChapter(bookId, chapter - 1, tab: tabIndex);
      return;
    }
    final index = books.indexWhere((b) => b.id == bookId);
    if (index > 0) {
      final previous = books[index - 1];
      await openChapter(previous.id, previous.chapterCount, tab: tabIndex);
    }
  }

  void clearFocusVerse() {
    focusVerse = null;
    notifyListeners();
  }

  Future<void> setTranslation(String id, {bool openReader = false}) async {
    if (!translations.any((t) => t.id == id)) return;
    translationId = id;
    settings.translationId = id;
    await _loadBooks();
    final book = currentBook;
    if (book != null) chapter = chapter.clamp(1, book.chapterCount);
    _invalidateChapter();
    settings
      ..bookId = bookId
      ..chapter = chapter;
    if (openReader) tabIndex = 1;
    notifyListeners();
  }

  Future<void> installTranslation(
    Map<String, dynamic> bundle, {
    bool bundled = false,
  }) async {
    await db.installBundle(bundle, bundled: bundled);
    await refreshInstalled();
    await setTranslation(bundle['id'] as String);
    unawaited(checkServer());
    notifyListeners();
  }

  Future<void> deleteTranslation(String id) async {
    if (translations.length <= 1) {
      throw Exception('Keep at least one translation installed.');
    }
    await db.deleteTranslation(id);
    await refreshInstalled();
    if (translationId == id) {
      await setTranslation(translations.first.id);
    }
    notifyListeners();
  }

  Future<void> checkServer() async {
    final generation = ++_serverCheckGeneration;
    final client = api;
    checkingServer = true;
    notifyListeners();
    try {
      final nextHealth = await client.health();
      if (generation != _serverCheckGeneration) return;
      health = nextHealth;
      if (health.online) {
        try {
          final serverCatalog = await client.catalog();
          if (generation != _serverCheckGeneration) return;
          if (serverCatalog.isNotEmpty) {
            catalog = serverCatalog;
            catalogFromServer = true;
          }
          if (generation == _serverCheckGeneration && health.online) {
            unawaited(refreshInterpretationCoverage());
          }
        } catch (_) {}
      }
    } finally {
      if (generation == _serverCheckGeneration) {
        checkingServer = false;
        catalogLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> setServerUrl(String url) async {
    final normalized = url.trim();
    if (normalized.isEmpty || normalized == settings.serverUrl) return;
    settings.serverUrl = normalized;
    _audioProbes.clear();
    api = ApiClient(normalized);
    health = HealthStatus.offline;
    catalogFromServer = false;
    notifyListeners();
    await checkServer();
  }

  Future<void> setThemeMode(String value) async {
    settings.themeMode = value;
    notifyListeners();
  }

  Future<void> setThemeStyle(String value) async {
    settings.themeStyle = value;
    notifyListeners();
  }

  Future<void> setFontSize(double value) async {
    settings.fontSize = value.clamp(14, 30);
    notifyListeners();
  }

  Future<void> setLineHeight(double value) async {
    settings.lineHeight = value.clamp(1.2, 2.2);
    notifyListeners();
  }

  Future<void> setAudioRate(double value) async {
    settings.audioRate = value.clamp(0.2, 1.0);
    await audio.setRate(settings.audioRate);
    notifyListeners();
  }

  Future<void> setAudioVoice(String? value) async {
    settings.audioVoice = value ?? '';
    await audio.setVoice(value);
    notifyListeners();
  }

  String get narrationSource => settings.narrationSource;

  Future<void> setNarrationSource(String value) async {
    settings.narrationSource = value;
    notifyListeners();
  }

  Future<void> setAudioAutoNext(bool value) async {
    settings.audioAutoNext = value;
    notifyListeners();
  }

  /// Plays [content] using the recorded chapter when allowed, otherwise the
  /// device voice. Returns true when the server recording was started.
  Future<bool> playChapterAudio(ChapterContent content) async {
    if (settings.narrationSource != 'device') {
      final url = await _audioUrlFor(content);
      if (url != null) {
        audio.error.value = null;
        if (await audio.playRemote(url, reference: content.reference)) {
          return true;
        }
      }
      if (settings.narrationSource == 'server') {
        audio.error.value ??=
            'No recorded narration for ${content.reference} is available yet.';
        return false;
      }
    }
    await audio.speakChapter(
      content.verses,
      startVerse: focusVerse ?? 1,
      reference: content.reference,
    );
    return false;
  }

  Future<Uri?> _audioUrlFor(ChapterContent content) async {
    final key =
        '${content.translationId}:${content.bookId}:${content.chapter}';
    final cached = _audioProbes[key];
    final fresh =
        cached != null &&
        DateTime.now().difference(cached.checkedAt) <
            const Duration(minutes: 2);
    if (cached != null && (cached.url != null || fresh)) {
      return cached.url;
    }
    Uri? url;
    try {
      final info = await api.audioInfo(
        content.translationId,
        content.bookId,
        content.chapter,
        timeout: const Duration(seconds: 4),
      );
      final raw = (info['url'] as String?)?.trim() ?? '';
      if (info['available'] == true && raw.isNotEmpty) {
        url = api.resolveUrl(raw);
      }
    } catch (_) {
      url = null;
    }
    _audioProbes[key] = _AudioProbe(url, DateTime.now());
    return url;
  }

  void _handleNarrationComplete() {
    if (!settings.audioAutoNext) {
      notifyListeners();
      return;
    }
    unawaited(_advanceAfterNarration());
  }

  Future<void> _advanceAfterNarration() async {
    final before = '$bookId:$chapter';
    await goToNextChapter();
    if ('$bookId:$chapter' == before) {
      notifyListeners();
      return;
    }
    final next = await loadCurrentChapter();
    if (next == null) return;
    await playChapterAudio(next);
    notifyListeners();
  }

  Future<void> setFontFamily(String value) async {
    settings.fontFamily = value;
    notifyListeners();
  }

  Future<void> setShowVerseNumbers(bool value) async {
    settings.showVerseNumbers = value;
    notifyListeners();
  }

  Future<void> setDefaultPerspective(String id) async {
    settings.defaultPerspective = id;
    notifyListeners();
  }

  ThemeMode get themeMode {
    switch (settings.themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  ReadingPlan? get activePlan => PlanService.byId(settings.planId);

  DateTime get planStart => PlanService.parseStart(settings.planStartDate);

  int get planPercent {
    final plan = activePlan;
    if (plan == null) return 0;
    return PlanService.progressPercent(plan, planProgress);
  }

  PlanDay? get todayPlanDay {
    final plan = activePlan;
    if (plan == null) return null;
    return PlanService.today(plan, planStart, planProgress);
  }

  Future<void> startPlan(String planId) async {
    settings
      ..planId = planId
      ..planStartDate = DateTime.now().toIso8601String().substring(0, 10);
    final plan = PlanService.byId(planId);
    planProgress = plan == null ? {} : await db.getPlanProgress(plan.id);
    notifyListeners();
  }

  Future<void> setPlanDay(String planId, int day, bool completed) async {
    await db.setPlanDayCompleted(planId, day, completed);
    planProgress = await db.getPlanProgress(planId);
    notifyListeners();
  }

  Future<void> resetActivePlan() async {
    final plan = activePlan;
    if (plan == null) return;
    await db.resetPlan(plan.id);
    planProgress = const {};
    notifyListeners();
  }

  Future<void> syncNow() async {
    final userId = settings.userId;
    final data = await db.exportUserData();
    data['settings'] = {
      'translationId': translationId,
      'bookId': bookId,
      'chapter': chapter,
      'defaultPerspective': settings.defaultPerspective,
    };
    await api.sync(userId, data);
  }

  Future<bool> restoreFromSync() async {
    final data = await api.pullSync(settings.userId);
    if (data == null) return false;
    final settingsData = data['settings'];
    if (settingsData is Map) {
      final prefs = Map<String, dynamic>.from(settingsData);
      if (prefs['translationId'] is String &&
          translations.any((t) => t.id == prefs['translationId'])) {
        await setTranslation(prefs['translationId'] as String);
      }
      if (prefs['bookId'] is String && prefs['chapter'] is num) {
        await openChapter(
          prefs['bookId'] as String,
          (prefs['chapter'] as num).toInt(),
          tab: tabIndex,
        );
      }
    }
    await db.importUserData(data);
    await refreshDashboard();
    return true;
  }

  bool get onboardingDone => settings.onboardingDone;

  Future<void> completeOnboarding() async {
    settings.onboardingDone = true;
    notifyListeners();
  }

  Future<void> clearAiCache() async {
    await db.clearInterpretations();
    notifyListeners();
  }

  Future<GenerateJob?> generateInterpretations({
    required String bookId,
    required int chapter,
    required int verseStart,
    required int verseEnd,
  }) async {
    if (generating || !health.online) return null;
    if (!health.liveGeneration) {
      generationError =
          'Live generation is turned off on this server. '
          'Interpretations are prepared in advance.';
      notifyListeners();
      return null;
    }
    generating = true;
    generationError = null;
    notifyListeners();
    try {
      generationJob = await api.generate(
        bookId: bookId,
        chapter: chapter,
        verseStart: verseStart,
        verseEnd: verseEnd,
        perspectives: perspectives.map((p) => p.id).toList(),
        translationId: translationId,
      );
      notifyListeners();
      while (generationJob!.isRunning) {
        await Future<void>.delayed(const Duration(seconds: 2));
        generationJob = await api.job(generationJob!.id);
        notifyListeners();
      }

      if (generationJob!.isError) {
        generationError = generationJob!.error ?? generationJob!.message;
      } else if (generationJob!.notes.isNotEmpty) {
        await db.saveInterpretations(generationJob!.notes);
      }

      return generationJob;
    } catch (error) {
      generationError = '$error';
      return null;
    } finally {
      generating = false;
      notifyListeners();
    }
  }

  Future<void> cancelGeneration() async {
    final job = generationJob;
    if (job == null || !generating) return;
    await api.cancelJob(job.id);
    generationError = 'Generation cancelled.';
    generating = false;
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await db.clearHistory();
    await refreshDashboard();
  }

  @override
  void dispose() {
    audio.dispose();
    api.dispose();
    downloader.dispose();
    super.dispose();
  }
}

class _AudioProbe {
  const _AudioProbe(this.url, this.checkedAt);

  final Uri? url;
  final DateTime checkedAt;
}
