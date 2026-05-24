import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/config/api_config.dart';
import '../core/theme/app_colors.dart';
import 'otp_screen.dart';

class ResetRequestResult {
  final bool success;
  final String? message;

  ResetRequestResult({required this.success, this.message});
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // form key for validation
  final _formKey = GlobalKey<FormState>();

  // controller for the email field
  final TextEditingController _emailController = TextEditingController();

  // loading state
  bool _isLoading = false;

  String? _errorMessage; // FIX: clean error handling (no snackbars)

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // function to request reset code from django
  Future<ResetRequestResult> requestReset() async {
    setState(() => _isLoading = true);
    _errorMessage = null;

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/api/password-reset-request/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": _emailController.text.trim()}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ResetRequestResult(
          success: true,
          message: data['message'] ?? "code sent to email",
        );
      } else {
        return ResetRequestResult(
          success: false,
          message: data['error'] ?? "email does not exist",
        );
      }
    } catch (e) {
      return ResetRequestResult(
        success: false,
        message: "connection error",
      );
    } finally {
      setState(() => _isLoading = false);
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
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.onyxCharcoal, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20),

                Text(
                  "Forgot Password?",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.onyxCharcoal),
                ),

                SizedBox(height: 10),

                Text(
                  "enter your email address and we'll send you a 6-digit code to reset your password.",
                  style: TextStyle(fontSize: 16, color: AppColors.terrainGrey),
                ),

                SizedBox(height: 40),

                _buildLabel("Email Address"),

                SizedBox(height: 8),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) {
                    setState(() {});
                  },
                  decoration: _inputDecoration(
                    hint: "enter your email",
                    icon: Icons.email_outlined,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "enter email";

                    final emailRegex = RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    );

                    if (!emailRegex.hasMatch(v)) {
                      return "enter a valid email address";
                    }

                    return null;
                  },
                ),

                SizedBox(height: 40),

                if (_errorMessage != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),

                // send code button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                      if (_formKey.currentState!.validate()) {
                        final result = await requestReset();

                        if (result.success) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OtpScreen(
                                email: _emailController.text.trim(),
                                isPasswordReset: true,
                              ),
                            ),
                          );
                        } else {
                          setState(() {
                            _errorMessage = result.message;
                          });
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.skeletonBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(
                      "SEND CODE",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  InputDecoration _inputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.skeletonBlue),
      suffixIcon: _emailController.text.isNotEmpty
          ? IconButton(
        icon: Icon(Icons.clear, color: AppColors.terrainGrey),
        onPressed: () => setState(() => _emailController.clear()),
      )
          : null,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: EdgeInsets.symmetric(vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
    );
  }
}