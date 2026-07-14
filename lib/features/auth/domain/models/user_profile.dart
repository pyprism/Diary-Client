class UserProfile {
  final int id;
  final String email;
  final bool isActive;
  final String webBaseUrl;
  final String createdAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.isActive,
    required this.webBaseUrl,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as int,
    email: json['email'] as String,
    isActive: json['is_active'] as bool? ?? true,
    webBaseUrl: json['web_base_url'] as String? ?? '',
    createdAt: json['created_at'] as String? ?? '',
  );
}
