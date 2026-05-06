class DiaryAnalysis {
  static const pending = 'PENDING';
  static const processing = 'PROCESSING';
  static const done = 'DONE';
  static const failed = 'FAILED';

  final String status; // PENDING, PROCESSING, DONE, FAILED
  final String? mood;
  final String? summary;
  final Map<String, dynamic>? banglaContent;
  final String? taskId;
  final String? error;
  final int? retryAfterSeconds;
  final DateTime? updatedAt;

  const DiaryAnalysis({
    required this.status,
    this.mood,
    this.summary,
    this.banglaContent,
    this.taskId,
    this.error,
    this.retryAfterSeconds,
    this.updatedAt,
  });

  factory DiaryAnalysis.fromJson(Map<String, dynamic> json) {
    final banglaContent = _asStringMap(json['bangla_content']);
    final summary = json['summary'] as String?;
    final mood = json['mood'] as String?;
    final error = json['error'] as String?;
    final status = _normalizeStatusCandidates(
      [json['task_status'], json['state'], json['status']],
      hasResult: banglaContent != null || summary != null || mood != null,
      hasError: error != null && error.isNotEmpty,
    );

    return DiaryAnalysis(
      status: status,
      mood: mood,
      summary: summary,
      banglaContent: banglaContent,
      taskId: json['task_id'] as String?,
      error: error,
      retryAfterSeconds: _asInt(json['retry_after_seconds']),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  bool get isDone => status == done;
  bool get isFailed => status == failed;
  bool get isPending => status == pending || status == processing;

  static Map<String, dynamic>? _asStringMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String _normalizeStatusCandidates(
    List<Object?> rawValues, {
    required bool hasResult,
    required bool hasError,
  }) {
    if (hasError) return failed;

    final values = rawValues
        .whereType<Object>()
        .map((raw) => raw.toString().trim().toUpperCase().replaceAll('-', '_'))
        .where((value) => value.isNotEmpty)
        .toList();

    if (values.any(_isDoneStatus)) return done;
    if (values.any(_isFailedStatus)) return failed;
    if (values.any(_isProcessingStatus)) return processing;
    if (values.any(_isPendingStatus)) return pending;
    if (hasResult) return done;
    return pending;
  }

  static bool _isDoneStatus(String value) {
    switch (value) {
      case 'DONE':
      case 'SUCCESS':
      case 'SUCCEEDED':
      case 'COMPLETE':
      case 'COMPLETED':
      case 'FINISHED':
        return true;
    }
    return false;
  }

  static bool _isFailedStatus(String value) {
    switch (value) {
      case 'FAILED':
      case 'FAILURE':
      case 'ERROR':
      case 'ERRORED':
        return true;
    }
    return false;
  }

  static bool _isProcessingStatus(String value) {
    switch (value) {
      case 'PROCESSING':
      case 'STARTED':
      case 'RUNNING':
      case 'IN_PROGRESS':
        return true;
    }
    return false;
  }

  static bool _isPendingStatus(String value) {
    switch (value) {
      case 'PENDING':
      case 'QUEUED':
      case 'RECEIVED':
      case 'SCHEDULED':
        return true;
    }
    return false;
  }
}
