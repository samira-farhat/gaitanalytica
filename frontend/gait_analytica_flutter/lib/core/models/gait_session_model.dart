class GaitSession {
  final int id;
  final int userId;
  final String username;
  final DateTime date;
  final String videoPath;
  final String? thumbnailPath;

  GaitSession({
    required this.id,
    required this.userId,
    required this.username,
    required this.date,
    required this.videoPath,
    this.thumbnailPath,
  });

  factory GaitSession.fromJson(Map<String, dynamic> json) {
    return GaitSession(
      id: json['id'],
      // Correctly parsing nested user data from your Django response
      userId: json['user']?['id'] ?? 0,
      username: json['user']?['username'] ?? "Unknown",
      date: DateTime.parse(json['session_date'] ?? DateTime.now().toIso8601String()),
      videoPath: json['video_path'] ?? '',
      thumbnailPath: json['thumbnail_path'],
    );
  }
}