import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// screens
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // check if user is already logged in (token stored)
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('access_token');

  runApp(MyApp(isLoggedIn: token != null));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'GaitAnalytica',

      // decide starting screen based on login state
      home: isLoggedIn ? const HomeScreen() : const WelcomeScreen(),
    );
  }
}