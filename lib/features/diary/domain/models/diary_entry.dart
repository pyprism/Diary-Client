import '../../../../core/utils/content_utils.dart';

enum PostType { short, long }

extension PostTypeExt on PostType {
  String get value => this == PostType.short ? 'SHORT' : 'LONG';
  static PostType fromString(String s) =>
      s == 'SHORT' ? PostType.short : PostType.long;
}

class DiaryTag {
  final int id;
  final String name;

  const DiaryTag({required this.id, required this.name});

  factory DiaryTag.fromJson(Map<String, dynamic> json) =>
      DiaryTag(id: json['id'] as int, name: json['name'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class DiaryEntry {
  final int? localId;
  final int? remoteId;
  final String title;
  final String date;
  final PostType postType;
  final DiaryContent content;
  final List<DiaryTag> tags;
  final String syncStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DiaryEntry({
    this.localId,
    this.remoteId,
    required this.title,
    required this.date,
    required this.postType,
    required this.content,
    this.tags = const [],
    this.syncStatus = 'synced',
    this.createdAt,
    this.updatedAt,
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(
        remoteId: json['id'] as int?,
        title: json['title'] as String,
        date: json['date'] as String,
        postType:
            PostTypeExt.fromString(json['post_type'] as String? ?? 'LONG'),
        content: json['content'] != null
            ? DiaryContent.fromJson(json['content'] as Map<String, dynamic>)
            : DiaryContent.empty(),
        tags: (json['tags'] as List? ?? [])
            .map((t) => DiaryTag.fromJson(t as Map<String, dynamic>))
            .toList(),
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'] as String)
            : null,
      );

  DiaryEntry copyWith({
    int? localId,
    int? remoteId,
    String? title,
    String? date,
    PostType? postType,
    DiaryContent? content,
    List<DiaryTag>? tags,
    String? syncStatus,
  }) =>
      DiaryEntry(
        localId: localId ?? this.localId,
        remoteId: remoteId ?? this.remoteId,
        title: title ?? this.title,
        date: date ?? this.date,
        postType: postType ?? this.postType,
        content: content ?? this.content,
        tags: tags ?? this.tags,
        syncStatus: syncStatus ?? this.syncStatus,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

class DiaryListItem {
  final int? localId;
  final int? remoteId;
  final String title;
  final String date;
  final PostType postType;

  const DiaryListItem({
    this.localId,
    this.remoteId,
    required this.title,
    required this.date,
    required this.postType,
  });

  factory DiaryListItem.fromJson(Map<String, dynamic> json) => DiaryListItem(
        remoteId: json['id'] as int?,
        title: json['title'] as String,
        date: json['date'] as String,
        postType:
            PostTypeExt.fromString(json['post_type'] as String? ?? 'LONG'),
      );

  DiaryListItem copyWith({
    int? localId,
    int? remoteId,
    String? title,
    String? date,
    PostType? postType,
  }) =>
      DiaryListItem(
        localId: localId ?? this.localId,
        remoteId: remoteId ?? this.remoteId,
        title: title ?? this.title,
        date: date ?? this.date,
        postType: postType ?? this.postType,
      );
}
