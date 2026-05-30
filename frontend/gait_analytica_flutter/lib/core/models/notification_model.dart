class AppNotification {
  final int id;
  final String title;
  final String message;
  final String targetScreen;
  final String? targetId;
  bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id, required this.title, required this.message,
    required this.targetScreen, this.targetId, required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      targetScreen: json['target_screen'] ?? '',
      targetId: json['target_id']?.toString(),
      isRead: json['is_read'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}