import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class HealthStatus {
  const HealthStatus({
    required this.online,
    required this.storage,
    required this.ollamaOnline,
    required this.models,
    required this.interpretations,
    required this.liveGeneration,
  });

  final bool online;
  final String storage;
  final bool ollamaOnline;
  final List<String> models;
  final int interpretations;

  /// Whether the server allows on-demand Ollama jobs. Servers that serve only
  /// pre-generated interpretations report false.
  final bool liveGeneration;

  static const offline = HealthStatus(
    online: false,
    storage: '',
    ollamaOnline: false,
    models: [],
    interpretations: 0,
    liveGeneration: false,
  );
}

class GenerateJob {
  const GenerateJob({
    required this.id,
    required this.status,
    required this.progress,
    required this.message,
    this.error,
    this.notes = const [],
  });

  final String id;
  final String status;
  final double progress;
  final String message;
  final String? error;
  final List<Interpretation> notes;

  bool get isDone => status == 'done';
  bool get isError => status == 'error';
  bool get isRunning => status == 'running' || status == 'queued';

  factory GenerateJob.fromJson(Map<String, dynamic> json) {
    final result = json['result'];
    final notes = <Interpretation>[];
    if (result is Map && result['notes'] is List) {
      for (final item in result['notes']) {
        if (item is Map) {
          notes.add(Interpretation.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return GenerateJob(
      id: (json['id'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'unknown',
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      message: (json['message'] as String?) ?? '',
      error: json['error'] as String?,
      notes: notes,
    );
  }
}

class ApiClient {
  ApiClient(String baseUrl, {http.Client? client})
    : baseUrl = _normalize(baseUrl),
      _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static String _normalize(String value) {
    var url = value.trim();
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<HealthStatus> health() async {
    try {
      final response = await _client
          .get(_uri('/api/health'))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return HealthStatus.offline;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final ollama = json['ollama'];
      final models = <String>[];
      var ollamaOnline = false;
      if (ollama is Map) {
        ollamaOnline = ollama['online'] == true;
        final raw = ollama['models'];
        if (raw is List) models.addAll(raw.whereType<String>());
      }
      return HealthStatus(
        online: true,
        storage: (json['storage'] as String?) ?? '',
        ollamaOnline: ollamaOnline,
        models: models,
        interpretations: (json['interpretations'] as num?)?.toInt() ?? 0,
        liveGeneration: json['liveGeneration'] == true,
      );
    } catch (_) {
      return HealthStatus.offline;
    }
  }

  Future<List<CatalogTranslation>> catalog() async {
    final response = await _client
        .get(_uri('/api/catalog'))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw ApiException(
        'Catalog request failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = (json['translations'] as List?) ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => CatalogTranslation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> downloadBundle(
    String translationId, {
    void Function(double progress, int received, int total)? onProgress,
  }) async {
    final request = http.Request(
      'GET',
      _uri('/api/translations/$translationId/bundle'),
    );
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw ApiException(
        'Download failed (${response.statusCode}). Is the server running?',
        statusCode: response.statusCode,
      );
    }
    final total = response.contentLength ?? 0;
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
      if (total > 0) {
        onProgress?.call(bytes.length / total, bytes.length, total);
      }
    }
    onProgress?.call(1, bytes.length, total);
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw ApiException('The server returned an invalid translation bundle');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<InterpretationsView> interpretations({
    required String bookId,
    required int chapter,
    required int verse,
  }) async {
    final response = await _client
        .get(
          _uri('/api/interpretations', {
            'book': bookId,
            'chapter': '$chapter',
            'verse': '$verse',
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw ApiException(
        'Could not load study notes (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    return InterpretationsView.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<GenerateJob> generate({
    required String bookId,
    required int chapter,
    required int verseStart,
    required int verseEnd,
    required List<String> perspectives,
    String translationId = 'en-kjv',
    int words = 90,
    bool force = false,
  }) async {
    final response = await _client
        .post(
          _uri('/api/generate'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'book': bookId,
            'chapter': chapter,
            'verseStart': verseStart,
            'verseEnd': verseEnd,
            'perspectives': perspectives,
            'translation': translationId,
            'words': words,
            'force': force,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      String detail = response.body;
      try {
        final json = jsonDecode(response.body);
        if (json is Map && json['detail'] != null) detail = '${json['detail']}';
      } catch (_) {}
      throw ApiException(detail, statusCode: response.statusCode);
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return GenerateJob(
      id: (json['jobId'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'queued',
      progress: 0,
      message: 'Queued',
    );
  }

  Future<GenerateJob> job(String jobId) async {
    final response = await _client
        .get(_uri('/api/jobs/$jobId'))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw ApiException(
        'Job status failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    return GenerateJob.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> cancelJob(String jobId) async {
    final response = await _client
        .post(_uri('/api/jobs/$jobId/cancel'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw ApiException(
        'Could not cancel generation (${response.statusCode})',
      );
    }
  }

  /// Turns an audio URL from the API into an absolute URI. The server normally
  /// returns an absolute RustFS/Nginx URL, but a relative path is accepted so
  /// self-hosted setups can reuse the API host.
  Uri resolveUrl(String value) {
    final uri = Uri.parse(value);
    if (uri.hasScheme) return uri;
    return Uri.parse(baseUrl).resolveUri(uri);
  }

  Future<Map<String, dynamic>> audioInfo(
    String translationId,
    String bookId,
    int chapter, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final response = await _client
        .get(_uri('/api/audio/info/$translationId/$bookId/$chapter'))
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw ApiException(
        'Audio info failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String audioUrl(String translationId, String bookId, int chapter) =>
      '$baseUrl/api/audio/$translationId/$bookId/$chapter.mp3';

  Future<Map<String, dynamic>> coverage() async {
    final response = await _client
        .get(_uri('/api/interpretations/coverage'))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw ApiException(
        'Coverage request failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> sync(String userId, Map<String, dynamic> data) async {
    final response = await _client
        .post(
          _uri('/api/sync', {'user_id': userId}),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'data': data}),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw ApiException(
        'Sync failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>?> pullSync(String userId) async {
    final response = await _client
        .get(_uri('/api/sync/$userId'))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw ApiException(
        'Sync pull failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  void dispose() => _client.close();
}
