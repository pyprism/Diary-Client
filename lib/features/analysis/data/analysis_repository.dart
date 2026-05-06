import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/server_config.dart';
import '../../../../core/storage/app_database.dart';
import '../domain/models/diary_analysis.dart';

class AnalysisRepository {
  final AppDatabase _db;
  final DioClient _client;
  final ServerConfig _config;

  AnalysisRepository(this._db, this._client, this._config);

  String _url(int diaryRemoteId) =>
      _config.endpoint('diaries/$diaryRemoteId/analyze');

  Future<DiaryAnalysis?> getAnalysis(
      int diaryLocalId, int diaryRemoteId) async {
    final local = await _db.getAnalysisByDiaryLocalId(diaryLocalId);
    if (local != null && _fromLocal(local).isDone) {
      return _fromLocal(local);
    }
    try {
      final res = await _client.dio.get(_url(diaryRemoteId));
      final analysis = _analysisFromResponse(res);
      await _saveLocally(diaryLocalId, analysis);
      return analysis;
    } catch (_) {
      if (local != null) return _fromLocal(local);
      return null;
    }
  }

  Stream<DiaryAnalysis?> watchAnalysis(int diaryLocalId) =>
      _db.watchAnalysisByDiaryLocalId(diaryLocalId).map(
            (e) => e != null ? _fromLocal(e) : null,
          );

  Future<DiaryAnalysis> triggerAnalysis(
      int diaryLocalId, int diaryRemoteId) async {
    final res = await _client.dio.post(_url(diaryRemoteId), data: const {});
    final analysis = _analysisFromResponse(res);
    await _saveLocallyBestEffort(diaryLocalId, analysis);
    return analysis;
  }

  Future<void> pollUntilDone(
    int diaryLocalId,
    int diaryRemoteId, {
    Duration? initialDelay,
  }) async {
    int retries = 0;
    var delay = initialDelay ?? AppConstants.analysisPollInterval;
    while (retries < AppConstants.analysisMaxRetries) {
      await Future.delayed(delay);
      try {
        final res = await _client.dio.get(_url(diaryRemoteId));
        final analysis = _analysisFromResponse(res);
        final terminal = analysis.isDone || analysis.isFailed;
        await _saveLocallyBestEffort(diaryLocalId, analysis);
        if (terminal) return;
        delay = _pollDelayFor(analysis);
      } catch (e) {
        if (e is DioException && e.response?.statusCode != null) {
          final status = e.response!.statusCode!;
          // Stop polling on unrecoverable client errors.
          if (status >= 400 && status < 500 && status != 429) {
            return;
          }
        }
      }
      retries++;
    }
  }

  Future<void> _saveLocallyBestEffort(
      int diaryLocalId, DiaryAnalysis analysis) async {
    try {
      await _saveLocally(diaryLocalId, analysis);
    } catch (_) {
      // The network response is still authoritative for polling decisions.
      // Existing local databases may contain stale duplicate analysis rows.
    }
  }

  Future<void> _saveLocally(int diaryLocalId, DiaryAnalysis analysis) async {
    await _db.upsertAnalysis(DiaryAnalysesCompanion(
      diaryLocalId: drift.Value(diaryLocalId),
      status: drift.Value(analysis.status),
      mood: drift.Value(analysis.mood),
      summary: drift.Value(analysis.summary),
      banglaContentJson: drift.Value(
        analysis.banglaContent == null
            ? null
            : jsonEncode(analysis.banglaContent),
      ),
      taskId: drift.Value(analysis.taskId),
      error: drift.Value(analysis.error),
      updatedAt: drift.Value(DateTime.now()),
    ));
  }

  DiaryAnalysis _fromLocal(DiaryAnalysisData d) => DiaryAnalysis(
        status: d.status,
        mood: d.mood,
        summary: d.summary,
        banglaContent: _decodeBanglaContent(d.banglaContentJson),
        taskId: d.taskId,
        error: d.error,
        updatedAt: d.updatedAt,
      );

  Map<String, dynamic>? _decodeBanglaContent(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonString);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  DiaryAnalysis _analysisFromResponse(Response<dynamic> res) {
    final analysis = DiaryAnalysis.fromJson(res.data as Map<String, dynamic>);
    final headerRetry = _parseRetryAfterHeader(res);
    if (headerRetry == null || analysis.retryAfterSeconds != null) {
      return analysis;
    }
    return DiaryAnalysis(
      status: analysis.status,
      mood: analysis.mood,
      summary: analysis.summary,
      banglaContent: analysis.banglaContent,
      taskId: analysis.taskId,
      error: analysis.error,
      retryAfterSeconds: headerRetry,
      updatedAt: analysis.updatedAt,
    );
  }

  int? _parseRetryAfterHeader(Response<dynamic> res) {
    final raw = res.headers.value('retry-after');
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  Duration _pollDelayFor(DiaryAnalysis analysis) {
    final seconds = analysis.retryAfterSeconds;
    if (seconds == null || seconds <= 0) {
      return AppConstants.analysisPollInterval;
    }
    return Duration(seconds: seconds);
  }
}
