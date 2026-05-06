import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/utils/date_utils.dart' as du;
import '../../../features/diary/domain/models/diary_entry.dart';

class HomepageData {
  final bool isExactDate;
  final Map<String, dynamic>? matchedDate;
  final List<DiaryListItem> entries;

  const HomepageData({
    required this.isExactDate,
    this.matchedDate,
    required this.entries,
  });

  factory HomepageData.fromJson(Map<String, dynamic> json) => HomepageData(
        isExactDate: json['is_exact_date'] as bool? ?? false,
        matchedDate: json['matched_date'] as Map<String, dynamic>?,
        entries: (json['entries'] as List? ?? [])
            .map((e) => DiaryListItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

final homepageProvider = FutureProvider<HomepageData?>((ref) async {
  final client = ref.watch(dioClientProvider);
  final config = ref.watch(serverConfigProvider);
  final db = ref.watch(appDatabaseProvider);

  if (config.isConfigured) {
    try {
      final res = await client.dio.get(config.endpoint('homepage'));
      final remote = HomepageData.fromJson(res.data as Map<String, dynamic>);
      return _hydrateLocalIds(db, remote);
    } catch (_) {
      // Fall back to local memories for offline and server-unreachable states.
    }
  }
  return _localHomepage(db);
});

Future<HomepageData> _hydrateLocalIds(AppDatabase db, HomepageData data) async {
  final entries = <DiaryListItem>[];
  for (final item in data.entries) {
    if (item.remoteId == null) {
      entries.add(item);
      continue;
    }
    final local = await db.getDiaryByRemoteId(item.remoteId!);
    entries.add(item.copyWith(localId: local?.id));
  }
  return HomepageData(
    isExactDate: data.isExactDate,
    matchedDate: data.matchedDate,
    entries: entries,
  );
}

Future<HomepageData> _localHomepage(AppDatabase db) async {
  final rows = await db.getAllDiaries();
  final today = DateTime.now();
  final pastRows = rows.where((row) {
    final date = du.DateUtils.fromApiFormat(row.date);
    return date != null && date.year < today.year;
  }).toList();

  if (pastRows.isEmpty) {
    return const HomepageData(isExactDate: false, entries: []);
  }

  final exact = pastRows.where((row) {
    final date = du.DateUtils.fromApiFormat(row.date)!;
    return date.month == today.month && date.day == today.day;
  }).toList();

  if (exact.isNotEmpty) {
    return HomepageData(
      isExactDate: true,
      matchedDate: {'month': today.month, 'day': today.day},
      entries: exact.map(_rowToListItem).toList(),
    );
  }

  final distinctDays = pastRows
      .map((row) => du.DateUtils.fromApiFormat(row.date)!)
      .map((date) => (month: date.month, day: date.day))
      .toSet()
      .toList()
    ..sort((a, b) {
      final aDistance =
          _calendarDistance(today.month, today.day, a.month, a.day);
      final bDistance =
          _calendarDistance(today.month, today.day, b.month, b.day);
      return aDistance.compareTo(bDistance);
    });

  final matched = distinctDays.first;
  final nearest = pastRows.where((row) {
    final date = du.DateUtils.fromApiFormat(row.date)!;
    return date.month == matched.month && date.day == matched.day;
  }).toList();

  return HomepageData(
    isExactDate: false,
    matchedDate: {'month': matched.month, 'day': matched.day},
    entries: nearest.map(_rowToListItem).toList(),
  );
}

DiaryListItem _rowToListItem(DiaryEntryData row) => DiaryListItem(
      localId: row.id,
      remoteId: row.remoteId,
      title: row.title,
      date: row.date,
      postType: PostTypeExt.fromString(row.postType),
    );

int _calendarDistance(int fromMonth, int fromDay, int toMonth, int toDay) {
  final base = DateTime(2000, fromMonth, fromDay);
  var target = DateTime(2000, toMonth, toDay);
  if (target.isBefore(base)) {
    target = DateTime(2001, toMonth, toDay);
  }
  return target.difference(base).inDays;
}
