import 'package:drift/drift.dart';

@DataClassName('DiaryEntryData')
class DiaryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get remoteId => integer().nullable()();
  TextColumn get title => text().withLength(max: 100)();
  TextColumn get date => text()(); // DD-MM-YYYY
  TextColumn get postType => text().withDefault(const Constant('LONG'))();
  TextColumn get contentJson => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {remoteId},
  ];
}

@DataClassName('DiaryTagData')
class DiaryTags extends Table {
  IntColumn get diaryLocalId =>
      integer().references(DiaryEntries, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagLocalId =>
      integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {diaryLocalId, tagLocalId};
}

@DataClassName('TagData')
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get remoteId => integer().nullable()();
  TextColumn get name => text().withLength(max: 50)();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {remoteId},
    {name},
  ];
}

@DataClassName('DiaryAnalysisData')
class DiaryAnalyses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get diaryLocalId =>
      integer().references(DiaryEntries, #id, onDelete: KeyAction.cascade)();
  TextColumn get status => text().withDefault(const Constant('PENDING'))();
  TextColumn get mood => text().nullable()();
  TextColumn get summary => text().nullable()();
  TextColumn get banglaContentJson => text().nullable()();
  TextColumn get taskId => text().nullable()();
  TextColumn get error => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {diaryLocalId},
  ];
}

@DataClassName('SyncQueueData')
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()(); // 'diary', 'tag'
  IntColumn get entityLocalId => integer()();
  TextColumn get operation => text()(); // 'create', 'update', 'delete'
  TextColumn get payloadJson => text().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
