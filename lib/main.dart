import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'data/api_client.dart';
import 'data/app_database.dart';
import 'data/audio_service.dart';
import 'data/models.dart';
import 'data/plan_service.dart';
import 'data/settings_service.dart';
import 'data/translation_downloader.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AppDatabase.open();
  final settings = await SettingsService.load();
  final state = AppState(
    db: database,
    settings: settings,
    api: ApiClient(settings.serverUrl),
    downloader: TranslationDownloader(),
  );
  await state.init();
  runApp(ChangeNotifierProvider.value(value: state, child: const BibleAiApp()));
}

class BibleAiApp extends StatelessWidget {
  const BibleAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      title: 'Bible AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(state.themeMode, state.settings.themeStyle),
      home: const AppShell(),
    );
  }
}

/// Kept as a compatibility entry point for existing integrations.
class MyApp extends BibleAiApp {
  const MyApp({super.key});
}

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pages = const [
      HomePage(),
      ReaderPage(),
      LibraryPage(),
      SettingsPage(),
    ];
    return Scaffold(
      body: IndexedStack(index: state.tabIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: state.tabIndex,
        onDestinationSelected: (index) => state.setTab(index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Read',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final palette = context.palette;
    final plan = state.activePlan;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bible AI',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                onPressed: () => state.setTab(3),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          if (!state.onboardingDone) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to Bible AI',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Read offline, save your own study notes, and explore interpretations from several traditions.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: state.completeOnboarding,
                      child: const Text('Get started'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [palette.heroStart, palette.heroEnd],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Continue reading',
                  style: TextStyle(color: Colors.white.withValues(alpha: .78)),
                ),
                const SizedBox(height: 8),
                Text(
                  state.reference,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Lora',
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: palette.primary,
                  ),
                  onPressed: () => state.setTab(1),
                  child: const Text('Open reader'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Today', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: palette.primary.withValues(alpha: .12),
                child: Icon(
                  Icons.auto_stories_outlined,
                  color: palette.primary,
                ),
              ),
              title: Text(plan == null ? 'Choose a reading plan' : plan.name),
              subtitle: Text(
                plan == null
                    ? 'Build a steady rhythm with a guided plan.'
                    : '${state.planPercent}% complete',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showPlans(context),
            ),
          ),
          const SizedBox(height: 24),
          Text('Your library', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatCard(
                label: 'Bookmarks',
                value: '${state.stats.bookmarks}',
                icon: Icons.bookmark_outline,
              ),
              const SizedBox(width: 10),
              _StatCard(
                label: 'Notes',
                value: '${state.stats.notes}',
                icon: Icons.edit_note_outlined,
              ),
              const SizedBox(width: 10),
              _StatCard(
                label: 'Highlights',
                value: '${state.stats.highlights}',
                icon: Icons.highlight_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> _showPlans(BuildContext context) async {
    final state = context.read<AppState>();
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Reading plans',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          ...statePlanTiles(state, context),
        ],
      ),
    );
  }

  static List<Widget> statePlanTiles(AppState state, BuildContext context) {
    return statePlanList(state)
        .map(
          (plan) => ListTile(
            title: Text(plan.name),
            subtitle: Text(plan.description),
            trailing: state.activePlan?.id == plan.id
                ? const Icon(Icons.check_circle)
                : null,
            onTap: () async {
              await state.startPlan(plan.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        )
        .toList();
  }

  static List<dynamic> statePlanList(AppState state) {
    return PlanService.plans;
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 5),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    ),
  );
}

class ReaderPage extends StatelessWidget {
  const ReaderPage({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SafeArea(
      child: FutureBuilder<List<Object?>>(
        future: state.currentChapterViewFuture(),
        builder: (context, snapshot) {
          final content = snapshot.hasData
              ? snapshot.data![0] as ChapterContent?
              : null;
          final highlights = snapshot.hasData
              ? snapshot.data![1] as Map<int, int>
              : const <int, int>{};
          return Column(
            children: [
              AppBar(
                toolbarHeight: 72,
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.currentBookName,
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.visible,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Chapter ${state.chapter}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    onPressed: () => _showSearch(context, state),
                    icon: const Icon(Icons.search),
                  ),
                  IconButton(
                    onPressed: () => _showAudioControls(context, state),
                    icon: const Icon(Icons.volume_up_outlined),
                  ),
                  IconButton(
                    onPressed: () => _chooseChapter(context, state),
                    icon: const Icon(Icons.list_alt_outlined),
                  ),
                  IconButton(
                    onPressed: () => state.goToPreviousChapter(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  IconButton(
                    onPressed: () => state.goToNextChapter(),
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (content == null)
                const Expanded(
                  child: Center(child: Text('This chapter is not available.')),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    itemCount: content.verses.length,
                    itemBuilder: (context, index) {
                      final verse = content.verses[index];
                      final focused = verse.verse == state.focusVerse;
                      final color = highlights[verse.verse];
                      final hasInterpretation = state.interpretationVerses
                          .contains(verse.verse);
                      return GestureDetector(
                        onTap: () => state.openChapter(
                          state.bookId,
                          state.chapter,
                          verse: verse.verse,
                        ),
                        onLongPress: () =>
                            _showVerseActions(context, state, verse),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: color == null
                                ? (focused
                                      ? context.palette.primary.withValues(
                                          alpha: .12,
                                        )
                                      : hasInterpretation
                                      ? context.palette.primary.withValues(
                                          alpha: .045,
                                        )
                                      : null)
                                : Color(color).withValues(alpha: .48),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                if (state.settings.showVerseNumbers)
                                  TextSpan(
                                    text: '${verse.verse}  ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.palette.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                TextSpan(
                                  text: verse.text,
                                  style: AppTheme.scripture(
                                    context,
                                    fontSize: state.settings.fontSize,
                                    lineHeight: state.settings.lineHeight,
                                    family: state.settings.fontFamily,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static Future<void> _chooseChapter(
    BuildContext context,
    AppState state,
  ) async {
    String? selectedBookId;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) {
          final selected = state.books
              .where((book) => book.id == selectedBookId)
              .firstOrNull;
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .8,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: selected == null
                    ? ListView(
                        children: [
                          Text(
                            'Choose book',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          ...state.books.map(
                            (book) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                book.name,
                                softWrap: true,
                              ),
                              subtitle: Text(
                                '${book.chapterCount} chapters',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => setState(
                                () => selectedBookId = book.id,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () =>
                                    setState(() => selectedBookId = null),
                                icon: const Icon(Icons.arrow_back),
                              ),
                              Expanded(
                                child: Text(
                                  selected.name,
                                  softWrap: true,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Choose chapter',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 5,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: 1.25,
                                  ),
                              itemCount: selected.chapterCount,
                              itemBuilder: (_, index) => OutlinedButton(
                                onPressed: () async {
                                  await state.openChapter(
                                    selected.id,
                                    index + 1,
                                  );
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                },
                                child: Text('${index + 1}'),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  static Future<void> _showVerseActions(
    BuildContext context,
    AppState state,
    Verse verse,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              title: Text(
                '${state.currentBookName} ${verse.chapter}:${verse.verse}',
              ),
              subtitle: Text(
                verse.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_add_outlined),
              title: const Text('Bookmark'),
              onTap: () async {
                await state.db.toggleBookmarkFor(
                  state.translationId,
                  verse,
                  state.currentBookName,
                );
                await state.refreshDashboard();
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.highlight_outlined),
              title: const Text('Highlight'),
              onTap: () async {
                await state.db.setHighlight(
                  state.translationId,
                  verse,
                  state.currentBookName,
                  AppTheme.highlightColors.first,
                );
                await state.refreshDashboard();
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_outlined),
              title: const Text('Add note'),
              onTap: () async {
                await _editNote(context, state, verse);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Study interpretations'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await _showInterpretations(context, state, verse);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _editNote(
    BuildContext context,
    AppState state,
    Verse verse,
  ) async {
    final existing = await state.db.getNoteForVerse(
      state.translationId,
      verse.bookId,
      verse.chapter,
      verse.verse,
    );
    if (!context.mounted) return;
    final controller = TextEditingController(text: existing?.body ?? '');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Note on ${state.currentBookName} ${verse.chapter}:${verse.verse}',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'Write a thought…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final body = controller.text.trim();
              if (body.isNotEmpty) {
                await state.db.saveNote(
                  existing: existing,
                  translationId: state.translationId,
                  verse: verse,
                  bookName: state.currentBookName,
                  body: body,
                );
                await state.refreshDashboard();
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  static Future<void> _showInterpretations(
    BuildContext context,
    AppState state,
    Verse verse,
  ) async {
    var view = await state.db.getInterpretations(
      state.bookId,
      state.chapter,
      verse.verse,
      state.perspectives.map((p) => p.id).toList(),
    );
    if (view.best.isEmpty && state.health.online) {
      try {
        view = await state.api.interpretations(
          bookId: state.bookId,
          chapter: state.chapter,
          verse: verse.verse,
        );
        await state.db.saveInterpretations([...view.passage, ...view.overview]);
      } catch (_) {}
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .72,
        maxChildSize: .95,
        builder: (_, controller) => StatefulBuilder(
          builder: (context, setState) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            children: [
              Text(
                'Study perspectives',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                '${state.currentBookName} ${verse.chapter}:${verse.verse}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (view.best.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'No saved interpretation is available for this passage yet.',
                        ),
                        if (state.health.online &&
                            state.health.liveGeneration) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: state.generating
                                ? null
                                : () async {
                                    await state.generateInterpretations(
                                      bookId: state.bookId,
                                      chapter: state.chapter,
                                      verseStart: verse.verse,
                                      verseEnd: verse.verse,
                                    );
                                    view = await state.db.getInterpretations(
                                      state.bookId,
                                      state.chapter,
                                      verse.verse,
                                      state.perspectives
                                          .map((p) => p.id)
                                          .toList(),
                                    );
                                    setState(() {});
                                  },
                            icon: state.generating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome),
                            label: Text(
                              state.generating
                                  ? 'Generating ${((state.generationJob?.progress ?? 0) * 100).round()}%'
                                  : 'Generate with Ollama',
                            ),
                          ),
                          if (state.generationError != null)
                            Text(
                              state.generationError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          if (state.generating)
                            TextButton(
                              onPressed: state.cancelGeneration,
                              child: const Text('Cancel generation'),
                            ),
                        ] else if (state.health.online) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Live generation is turned off on this server. '
                            'Interpretations are prepared in advance, so this '
                            'passage will appear once it has been generated.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                ...view.best.map(
                  (item) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(item.content),
                          if (item.model.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Model: ${item.model}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDuration(Duration value) {
    final total = value.inSeconds;
    final minutes = total ~/ 60;
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static Future<void> _showAudioControls(
    BuildContext context,
    AppState state,
  ) async {
    final loaded = await state.loadCurrentChapter();
    if (!context.mounted || loaded == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            state.audio.isSpeaking,
            state.audio.isPaused,
            state.audio.engine,
            state.audio.buffering,
            state.audio.position,
            state.audio.duration,
            state.audio.error,
          ]),
          builder: (context, _) {
            final speaking = state.audio.isSpeaking.value;
            final paused = state.audio.isPaused.value;
            final onServer =
                state.audio.engine.value == NarrationEngine.server;
            final duration = state.audio.duration.value;
            final position = state.audio.position.value;
            final errorText = state.audio.error.value;
            final source = state.settings.narrationSource;
            final hint = source == 'server'
                ? 'Recorded narration only.'
                : source == 'device'
                ? 'Device text-to-speech voice.'
                : 'Recorded narration when available, otherwise device voice.';
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Audio narration',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    onServer
                        ? '${loaded.reference} · recorded'
                        : loaded.reference,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'auto', label: Text('Auto')),
                      ButtonSegment(value: 'server', label: Text('Recorded')),
                      ButtonSegment(value: 'device', label: Text('Device')),
                    ],
                    selected: {source},
                    showSelectedIcon: false,
                    onSelectionChanged: (values) {
                      state.setNarrationSource(values.first);
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(hint, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          if (speaking) {
                            state.audio.stop();
                          } else {
                            state.playChapterAudio(loaded);
                          }
                        },
                        icon: Icon(speaking ? Icons.stop : Icons.play_arrow),
                        label: Text(speaking ? 'Stop' : 'Play'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: speaking
                            ? (paused ? state.audio.resume : state.audio.pause)
                            : null,
                        icon: Icon(
                          paused ? Icons.play_arrow : Icons.pause,
                        ),
                        label: Text(paused ? 'Resume' : 'Pause'),
                      ),
                    ],
                  ),
                  if (state.audio.buffering.value)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  if (onServer &&
                      duration != null &&
                      duration > Duration.zero) ...[
                    const SizedBox(height: 6),
                    Slider(
                      value: position.inMilliseconds
                          .clamp(0, duration.inMilliseconds)
                          .toDouble(),
                      max: duration.inMilliseconds.toDouble(),
                      onChanged: (value) => state.audio.seek(
                        Duration(milliseconds: value.round()),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(position),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          _formatDuration(duration),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        errorText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Text('Speed'),
                  Slider(
                    value: onServer
                        ? state.settings.audioRate.clamp(0.5, 1.0)
                        : state.settings.audioRate,
                    min: onServer ? 0.5 : 0.2,
                    max: 1,
                    divisions: onServer ? 5 : 8,
                    label: '${state.settings.audioRate.toStringAsFixed(1)}x',
                    onChanged: (value) async {
                      await state.setAudioRate(value);
                    },
                  ),
                  CheckboxListTile(
                    value: state.settings.audioAutoNext,
                    onChanged: (value) {
                      state.setAudioAutoNext(value ?? false);
                    },
                    title: const Text('Play next chapter'),
                    subtitle: const Text('Keep narrating when this ends'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                  if (!onServer && state.audio.voices.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: state.settings.audioVoice.isEmpty
                          ? null
                          : state.settings.audioVoice,
                      decoration: const InputDecoration(labelText: 'Voice'),
                      items: state.audio.voices
                          .map(
                            (voice) => DropdownMenuItem(
                              value: voice['name'],
                              child: Text(voice['name']!),
                            ),
                          )
                          .toList(),
                      onChanged: state.setAudioVoice,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static Future<void> _showSearch(BuildContext context, AppState state) async {
    final controller = TextEditingController();
    var results = const <SearchHit>[];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Search the Bible'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search at least 2 characters',
                  ),
                  onSubmitted: (_) async {
                    results = await state.db.search(
                      controller.text,
                      translationId: state.translationId,
                    );
                    setState(() {});
                  },
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: results
                        .map(
                          (hit) => ListTile(
                            title: Text(hit.reference),
                            subtitle: Text(
                              hit.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () async {
                              await state.openChapter(
                                hit.bookId,
                                hit.chapter,
                                verse: hit.verse,
                              );
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                results = await state.db.search(
                  controller.text,
                  translationId: state.translationId,
                );
                setState(() {});
              },
              child: const Text('Search'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }
}

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Library', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.bookmark_outline),
              title: const Text('Bookmarks'),
              trailing: Text('${state.stats.bookmarks}'),
              onTap: () => _showItems(
                context,
                'Bookmarks',
                state.db.getBookmarks(),
                (item) => item.reference,
                (item) => item.text,
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.highlight_outlined),
              title: const Text('Highlights'),
              trailing: Text('${state.stats.highlights}'),
              onTap: () => _showItems(
                context,
                'Highlights',
                state.db.getHighlights(),
                (item) => item.reference,
                (item) => item.text,
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit_note_outlined),
              title: const Text('Notes'),
              trailing: Text('${state.stats.notes}'),
              onTap: () => _showItems(
                context,
                'Notes',
                state.db.getNotes(),
                (item) => item.reference,
                (item) => item.body,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Installed translations',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          ...state.translations.map(
            (translation) => ListTile(
              title: Text(translation.name),
              subtitle: Text(
                '${translation.abbreviation} · ${translation.language}',
              ),
              trailing: state.translationId == translation.id
                  ? const Icon(Icons.check)
                  : null,
              onTap: () =>
                  state.setTranslation(translation.id, openReader: true),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Available downloads',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          ...state.catalog
              .where(
                (entry) => !state.translations.any(
                  (installed) => installed.id == entry.id,
                ),
              )
              .map(
                (entry) => ListTile(
                  title: Text(entry.name),
                  subtitle: Text(
                    '${entry.abbreviation} · ${entry.language} · ${entry.canon}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.download_outlined),
                    onPressed: () => _download(context, state, entry),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  static Future<void> _download(
    BuildContext context,
    AppState state,
    CatalogTranslation entry,
  ) async {
    var update = const DownloadUpdate(message: 'Preparing…');
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> start() async {
            try {
              final bundle = await state.downloader.download(
                entry,
                api: state.api,
                onUpdate: (value) {
                  update = value;
                  setState(() {});
                },
              );
              await state.installTranslation(bundle);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } catch (error) {
              update = DownloadUpdate(message: 'Download failed: $error');
              setState(() {});
            }
          }

          if (update.message == 'Preparing…') {
            WidgetsBinding.instance.addPostFrameCallback((_) => start());
          }
          return AlertDialog(
            title: Text('Downloading ${entry.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (update.fraction != null)
                  LinearProgressIndicator(value: update.fraction),
                const SizedBox(height: 12),
                Text(update.message),
              ],
            ),
            actions: [
              if (update.message.startsWith('Download failed'))
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
            ],
          );
        },
      ),
    );
  }

  static Future<void> _showItems<T>(
    BuildContext context,
    String title,
    Future<List<T>> future,
    String Function(T) reference,
    String Function(T) text,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (_, controller) => FutureBuilder<List<T>>(
          future: future,
          builder: (context, snapshot) {
            final items = snapshot.data ?? <T>[];
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const Text('Nothing saved yet.')
                else
                  ...items.map(
                    (item) => Card(
                      child: ListTile(
                        title: Text(reference(item)),
                        subtitle: Text(
                          text(item),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: state.settings.themeStyle,
            decoration: const InputDecoration(labelText: 'Appearance'),
            items: const [
              DropdownMenuItem(value: 'parchment', child: Text('Parchment')),
              DropdownMenuItem(value: 'white', child: Text('Clean white')),
              DropdownMenuItem(value: 'night', child: Text('Night')),
            ],
            onChanged: (value) {
              if (value != null) state.setThemeStyle(value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: state.settings.themeMode,
            decoration: const InputDecoration(labelText: 'Theme mode'),
            items: const ['system', 'light', 'dark']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) state.setThemeMode(value);
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            title: const Text('Verse numbers'),
            trailing: Switch(
              value: state.settings.showVerseNumbers,
              onChanged: state.setShowVerseNumbers,
            ),
          ),
          ListTile(
            title: const Text('Text size'),
            subtitle: Slider(
              value: state.settings.fontSize,
              min: 14,
              max: 30,
              divisions: 16,
              onChanged: state.setFontSize,
            ),
          ),
          const Divider(height: 32),
          ListTile(
            title: const Text('Server'),
            subtitle: Text(state.settings.serverUrl),
            onTap: () => _editServerUrl(context, state),
            trailing: Icon(
              state.health.online ? Icons.cloud_done : Icons.cloud_off,
            ),
          ),
          ListTile(
            title: const Text('Check server'),
            trailing: IconButton(
              onPressed: state.checkServer,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _editServerUrl(
    BuildContext context,
    AppState state,
  ) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _ServerUrlDialog(initialUrl: state.settings.serverUrl),
    );
    if (value == null || value.trim().isEmpty) return;
    await state.setServerUrl(value);
  }
}

class _ServerUrlDialog extends StatefulWidget {
  const _ServerUrlDialog({required this.initialUrl});

  final String initialUrl;

  @override
  State<_ServerUrlDialog> createState() => _ServerUrlDialogState();
}

class _ServerUrlDialogState extends State<_ServerUrlDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Backend server URL'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(hintText: 'http://192.168.1.10'),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
