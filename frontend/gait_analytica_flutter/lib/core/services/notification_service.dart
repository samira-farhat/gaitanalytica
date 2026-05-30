import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/notification_model.dart';


class NotificationService {
  Future<List<AppNotification>> fetchNotifications(String token) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/notifications/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      List data = json.decode(response.body);
      return data.map((n) => AppNotification.fromJson(n)).toList();
    }
    return [];
  }

  Future<void> markAllAsRead(String token) async {
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/notifications/mark-all-read/'),
      headers: {'Authorization': 'Token $token'},
    );
  }
}