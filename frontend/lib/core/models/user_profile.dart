class UserProfile {
  final String id;
  final String email;
  final int dailyUsageLimit;
  final int usageToday;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.dailyUsageLimit,
    required this.usageToday,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      dailyUsageLimit: (json['dailyUsageLimit'] as num).toInt(),
      usageToday: (json['usageToday'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
