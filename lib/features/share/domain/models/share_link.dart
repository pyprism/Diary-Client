class ShareLink {
  final int id;
  final int? diaryId;
  final String token;
  final String shareType;
  final String excerpt;
  final String diaryTitle;
  final String expiresAt;
  final bool isExpired;
  final String publicUrl;
  final String createdAt;

  const ShareLink({
    required this.id,
    this.diaryId,
    required this.token,
    required this.shareType,
    required this.excerpt,
    required this.diaryTitle,
    required this.expiresAt,
    required this.isExpired,
    required this.publicUrl,
    required this.createdAt,
  });

  factory ShareLink.fromJson(Map<String, dynamic> json) => ShareLink(
        id: json['id'] as int,
        diaryId: _optionalInt(json['diary_id']),
        token: json['token'] as String,
        shareType: json['share_type'] as String,
        excerpt: json['excerpt'] as String? ?? '',
        diaryTitle: json['diary_title'] as String,
        expiresAt: json['expires_at'] as String,
        isExpired: json['is_expired'] as bool? ?? false,
        publicUrl: json['public_url'] as String,
        createdAt: json['created_at'] as String,
      );

  DateTime? get expiresAtDate => DateTime.tryParse(expiresAt);

  Duration? remainingUntilExpiry({DateTime? now}) {
    final expiry = expiresAtDate;
    if (expiry == null) return null;
    return expiry.difference(now ?? DateTime.now());
  }

  bool isExpiredAt({DateTime? now}) {
    if (isExpired) return true;

    final remaining = remainingUntilExpiry(now: now);
    if (remaining == null) return false;
    return remaining.isNegative || remaining == Duration.zero;
  }

  String expiryStatusLabel({DateTime? now}) {
    if (isExpiredAt(now: now)) return 'Expired';

    final remaining = remainingUntilExpiry(now: now);
    if (remaining == null) return 'Expires $expiresAt';

    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);

    if (days > 0) {
      final hourText = hours > 0 ? ' ${hours}h' : '';
      return 'Expires in ${days}d$hourText';
    }
    if (hours > 0) {
      final minuteText = minutes > 0 ? ' ${minutes}m' : '';
      return 'Expires in ${hours}h$minuteText';
    }
    if (minutes > 0) return 'Expires in ${minutes}m';
    return 'Expires in less than 1m';
  }
}

int? _optionalInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

class PublicShareData {
  final String shareType;
  final String diaryTitle;
  final String diaryDate;
  final dynamic content; // String or Map
  final String expiresAt;

  const PublicShareData({
    required this.shareType,
    required this.diaryTitle,
    required this.diaryDate,
    required this.content,
    required this.expiresAt,
  });

  factory PublicShareData.fromJson(Map<String, dynamic> json) =>
      PublicShareData(
        shareType: json['share_type'] as String,
        diaryTitle: json['diary_title'] as String,
        diaryDate: json['diary_date'] as String,
        content: json['content'],
        expiresAt: json['expires_at'] as String,
      );
}
