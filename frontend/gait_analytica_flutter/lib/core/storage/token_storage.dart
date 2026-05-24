import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {

  // save tokens after login
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  // get access token
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // clear tokens (logout later)
  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}