import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../storage/token_storage.dart';
import '../models/gait_session_model.dart';

class ApiService {

  // fetches the list of gait sessions
  static Future<List<GaitSession>> getSessions(String order) async {
    final token = await TokenStorage.getAccessToken();

    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/sessions/?order=$order"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => GaitSession.fromJson(json)).toList();
      } else {
        throw Exception("Failed to load sessions: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Error fetching sessions: $e");
    }
  }

  // fetches full session details
  static Future<Map<String, dynamic>> getSessionDetails(int sessionId) async {
    final token = await TokenStorage.getAccessToken();
    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/api/sessions/$sessionId/"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load session details");
    }
  }
}