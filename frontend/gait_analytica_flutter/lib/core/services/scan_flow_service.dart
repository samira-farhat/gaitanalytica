import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../storage/token_storage.dart';

class ScanService {
  static Future<int?> uploadVideo(File videoFile) async {
    final token = await TokenStorage.getAccessToken();
    final uri = Uri.parse("${ApiConfig.baseUrl}/api/analyze_video/");

    var request = http.MultipartRequest('POST', uri);
    request.headers.addAll({"Authorization": "Bearer $token"});
    request.files.add(await http.MultipartFile.fromPath('video', videoFile.path));

    final response = await request.send();

    if (response.statusCode == 202) {
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);
      return data['session_id']; // Return ID to navigate to status screen
    }

    return null;
  }
}