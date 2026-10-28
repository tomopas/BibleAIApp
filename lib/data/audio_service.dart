import 'package:audioplayers/audioplayers.dart' as audio;
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../data/canonical_books.dart';
import '../data/models.dart';

/// Where the current narration audio comes from.
enum NarrationEngine { server, device }

/// Narrates chapters either with a recorded MP3 streamed from the Bible server
/// or with the device text-to-speech engine.
class AudioService {
  AudioService() {
    _player.onPositionChanged.listen((value) => position.value = value);
    _player.onDurationChanged.listen((value) => duration.value = value);
    _player.onPlayerComplete.listen((_) => _handleRemoteComplete());
  }

  final FlutterTts _tts = FlutterTts();
  final audio.AudioPlayer _player = audio.AudioPlayer();

  final ValueNotifier<int?> currentVerse = ValueNotifier<int?>(null);
  final ValueNotifier<bool> isSpeaking = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isPaused = ValueNotifier<bool>(false);
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);
  final ValueNotifier<String?> nowPlaying = ValueNotifier<String?>(null);
  final ValueNotifier<NarrationEngine?> engine =
      ValueNotifier<NarrationEngine?>(null);
  final ValueNotifier<bool> buffering = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> position = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<Duration?> duration = ValueNotifier<Duration?>(null);

  /// Called when a chapter finishes without being stopped by the user. Used for
  /// the "play next chapter" setting.
  VoidCallback? onComplete;

  bool _initialized = false;
  bool _stopRequested = false;
  bool _remote = false;
  List<Verse> _lastVerses = const [];
  String _lastReference = '';
  String _lastLanguageCode = 'en';
  double _rate = 0.5;
  String? _voiceName;
  List<Map<String, String>> _voices = const [];

  List<Map<String, String>> get voices => _voices;

  /// True while the recorded chapter is the active source.
  bool get isRemote => _remote;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await _tts.setSpeechRate(_rate);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      final raw = await _tts.getVoices;
      if (raw is List) {
        _voices = raw
            .whereType<Map>()
            .map(
              (voice) => {
                'name': '${voice['name'] ?? ''}',
                'locale': '${voice['locale'] ?? voice['language'] ?? ''}',
              },
            )
            .where((voice) => voice['name']!.isNotEmpty)
            .toList();
      }
      if (_voiceName != null) {
        await setVoice(_voiceName);
      }
      _initialized = true;
    } catch (err) {
      error.value = 'Text-to-speech is not available: $err';
    }
  }

  Future<void> setRate(double value) async {
    _rate = value.clamp(0.2, 1.0);
    try {
      await _tts.setSpeechRate(_rate);
    } catch (_) {}
    try {
      // Recorded audio is already at natural speed, so this scales playback
      // rather than speech synthesis. Players accept 0.5x - 2.0x.
      await _player.setPlaybackRate(_rate.clamp(0.5, 1.0));
    } catch (_) {}
  }

  Future<void> setVoice(String? name) async {
    _voiceName = name;
    if (name == null || name.isEmpty) return;
    try {
      for (final voice in _voices) {
        if (voice['name'] == name) {
          await _tts.setVoice({
            'name': voice['name']!,
            'locale': voice['locale']!,
          });
          return;
        }
      }
    } catch (_) {}
  }

  /// Streams a recorded chapter from [url]. Returns false when playback could
  /// not be started so the caller can fall back to device speech.
  Future<bool> playRemote(Uri url, {required String reference}) async {
    await stop();
    _stopRequested = false;
    _remote = true;
    error.value = null;
    engine.value = NarrationEngine.server;
    buffering.value = true;
    nowPlaying.value = reference;
    _lastReference = reference;
    try {
      await _player.setReleaseMode(audio.ReleaseMode.stop);
      await _player.play(audio.UrlSource(url.toString()));
      await setRate(_rate);
      isSpeaking.value = true;
      isPaused.value = false;
      return true;
    } catch (err) {
      _remote = false;
      engine.value = null;
      nowPlaying.value = null;
      isSpeaking.value = false;
      error.value = 'Recorded narration could not be played: $err';
      return false;
    } finally {
      buffering.value = false;
    }
  }

  Future<void> speakChapter(
    List<Verse> verses, {
    int startVerse = 1,
    String languageCode = 'en',
    required String reference,
  }) async {
    if (verses.isEmpty) return;
    error.value = null;
    await init();
    if (error.value != null) return;
    await stop();
    _lastVerses = verses;
    _lastReference = reference;
    _lastLanguageCode = languageCode;
    _stopRequested = false;
    await _tts.setLanguage(ttsLocales[languageCode] ?? 'en-US');
    await setRate(_rate);
    await setVoice(_voiceName);
    engine.value = NarrationEngine.device;
    isSpeaking.value = true;
    isPaused.value = false;
    nowPlaying.value = reference;
    var completed = false;
    try {
      final start = verses.indexWhere((v) => v.verse >= startVerse);
      final list = start >= 0 ? verses.sublist(start) : verses;
      for (final verse in list) {
        if (_stopRequested) break;
        currentVerse.value = verse.verse;
        final text = verse.text.trim();
        if (text.isEmpty) continue;
        await _tts.speak(text);
      }
      completed = !_stopRequested;
    } catch (err) {
      error.value = 'Narration failed: $err';
    } finally {
      currentVerse.value = null;
      isSpeaking.value = false;
      isPaused.value = false;
      nowPlaying.value = null;
      if (!_remote) engine.value = null;
    }
    if (completed) onComplete?.call();
  }

  Future<void> stop() async {
    _stopRequested = true;
    try {
      await _tts.stop();
    } catch (_) {}
    _remote = false;
    try {
      await _player.stop();
    } catch (_) {}
    position.value = Duration.zero;
    duration.value = null;
    currentVerse.value = null;
    isSpeaking.value = false;
    isPaused.value = false;
    nowPlaying.value = null;
    engine.value = null;
  }

  Future<void> pause() async {
    try {
      if (!isSpeaking.value || isPaused.value) return;
      if (_remote) {
        await _player.pause();
      } else {
        await _tts.pause();
      }
      isPaused.value = true;
    } catch (_) {}
  }

  Future<void> resume() async {
    if (!isPaused.value) return;
    if (_remote) {
      try {
        await _player.resume();
        isPaused.value = false;
      } catch (_) {}
      return;
    }
    if (_lastVerses.isEmpty) return;
    final verse = currentVerse.value ?? _lastVerses.first.verse;
    await speakChapter(
      _lastVerses,
      startVerse: verse,
      languageCode: _lastLanguageCode,
      reference: _lastReference,
    );
  }

  /// Seeks within the recorded chapter. Ignored for device speech.
  Future<void> seek(Duration value) async {
    if (!_remote) return;
    try {
      await _player.seek(value);
      position.value = value;
    } catch (_) {}
  }

  void _handleRemoteComplete() {
    if (!_remote) return;
    _remote = false;
    position.value = Duration.zero;
    duration.value = null;
    currentVerse.value = null;
    isSpeaking.value = false;
    isPaused.value = false;
    nowPlaying.value = null;
    engine.value = null;
    onComplete?.call();
  }

  void dispose() {
    _tts.stop();
    _player.dispose();
    currentVerse.dispose();
    isSpeaking.dispose();
    isPaused.dispose();
    error.dispose();
    nowPlaying.dispose();
    engine.dispose();
    buffering.dispose();
    position.dispose();
    duration.dispose();
  }
}
