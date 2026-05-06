class Tag {
  final int? localId;
  final int? remoteId;
  final String name;

  const Tag({this.localId, this.remoteId, required this.name});

  factory Tag.fromJson(Map<String, dynamic> json) =>
      Tag(remoteId: json['id'] as int?, name: json['name'] as String);
}

class TagEntrySummary {
  final int? localId;
  final int? remoteId;
  final String title;

  const TagEntrySummary({this.localId, this.remoteId, required this.title});

  factory TagEntrySummary.fromJson(Map<String, dynamic> json) =>
      TagEntrySummary(
        remoteId: json['pk'] as int? ?? json['id'] as int?,
        title: json['title'] as String? ?? 'Untitled entry',
      );

  TagEntrySummary copyWith({int? localId, int? remoteId, String? title}) =>
      TagEntrySummary(
        localId: localId ?? this.localId,
        remoteId: remoteId ?? this.remoteId,
        title: title ?? this.title,
      );
}
