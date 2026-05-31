import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gait_analytica_flutter/screens/forgot_password_screen.dart';
import 'package:gait_analytica_flutter/screens/register_screen.dart';
import 'package:http/http.dart' as http;

import '../core/config/api_config.dart';
import '../core/theme/app_colors.dart';
import '../core/storage/token_storage.dart';
import '../core/utils/api_response_handler.dart';

import 'home_screen.dart';
import 'otp_screen.dart';



class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;

  String? _errorMessage;

  String? _unverifiedEmail;

  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> loginUser() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final body = {
        "username": _usernameController.text.trim(),
        "password": _passwordController.text.trim(),
      };

      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/api/token/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (!mounted) return;

      final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};

      if (response.statusCode == 200) {
        await TokenStorage.saveTokens(
          accessToken: data['access'],
          refreshToken: data['refresh'],
        );

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => HomeScreen()),
              (route) => false,
        );
      } else {
        setState(() {
          _errorMessage = ApiResponseHandler.handleError(data, response.statusCode);
          _unverifiedEmail = (data["error"] == "Account not verified") ? data["email"] : null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ApiResponseHandler.handleError({"error": e.toString()}, 500);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pureWhite,

      appBar: AppBar(
        backgroundColor: AppColors.pureWhite,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
              Icons.arrow_back_ios_new,
              color: AppColors.onyxCharcoal,
              size: 20
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 30),

          child: Form(
            key: _formKey,

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                SizedBox(height: 20),

                // logo section
                Center(
                  child: Image.asset(
                    'assets/skeleton_clear_bk.png',
                    height: 110,
                  ),
                ),

                SizedBox(height: 10),

                // title
                Text(
                  "Welcome Back",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onyxCharcoal,
                  ),
                ),

                SizedBox(height: 8),

                Text(
                  "Sign in to continue your gait analysis and track your progress.",
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.terrainGrey,
                  ),
                ),

                SizedBox(height: 40),

                _buildLabel("Username"),

                SizedBox(height: 8),

                TextFormField(
                  controller: _usernameController,
                  decoration: _inputDecoration(
                    hint: "Enter your username",
                    icon: Icons.person_outline,
                  ),
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() {
                        _errorMessage = null;
                      });
                    }
                  },
                  validator: (value) =>
                  value == null || value.isEmpty ? "Enter username" : null,
                ),

                SizedBox(height: 24),

                _buildLabel("Password"),

                SizedBox(height: 8),

                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: _inputDecoration(
                    hint: "Enter your password",
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: AppColors.terrainGrey,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() {
                        _errorMessage = null;
                      });
                    }
                  },
                  validator: (value) =>
                  value == null || value.isEmpty ? "Enter password" : null,
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ForgotPasswordScreen()
                        ),
                      );
                    },
                    child: Text(
                      "Forgot Password?",
                      style: TextStyle(
                        color: AppColors.skeletonBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(

                    onPressed: _isLoading
                        ? null
                        : () {
                      if (_formKey.currentState!.validate()) {
                        loginUser();
                      }
                    },

                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.skeletonBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),

                    child: _isLoading
                        ? CircularProgressIndicator(
                      color: Colors.white,
                    )
                        : Text(
                      "LOG IN",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 10),

                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                if (_unverifiedEmail != null)

                  TextButton(
                    onPressed: () {

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OtpScreen(
                            email: _unverifiedEmail!,
                          ),
                        ),
                      );
                    },

                    child: Text(
                      "Verify Account",
                      style: TextStyle(
                        color: AppColors.skeletonBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),


                SizedBox(height: 30),

                Center(
                  child: RichText(
                    text: TextSpan(
                      text: "Don't have an account? ",
                      style: TextStyle(
                        color: AppColors.terrainGrey,
                        fontSize: 15,
                      ),
                      children: [
                        TextSpan(
                          text: "Register",
                          style: TextStyle(
                            color: AppColors.skeletonBlue,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RegisterScreen(),
                                ),
                              );
                            },
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // label widget
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.onyxCharcoal,
      ),
    );
  }

  // input decoration
  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.skeletonBlue),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: EdgeInsets.symmetric(vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
      ),
    );
  }
}