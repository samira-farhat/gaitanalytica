import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/config/api_config.dart';
import '../core/theme/app_colors.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _serverError;
  String _selectedGender = 'Other';

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> registerUser() async {
    setState(() {
      _isLoading = true;
      _serverError = null;
    });

    try {
      final Map<String, dynamic> userData = {
        "first_name": _firstNameController.text.trim(),
        "last_name": _lastNameController.text.trim(),
        "middle_name": _middleNameController.text.trim().isEmpty ? null : _middleNameController.text.trim(),
        "age": int.tryParse(_ageController.text.trim()) ?? 0,
        "gender": _selectedGender,
        "height_cm": double.tryParse(_heightController.text.trim()) ?? 0,
        "weight_kg": double.tryParse(_weightController.text.trim()) ?? 0,
        "username": _usernameController.text.trim(),
        "email": _emailController.text.trim(),
        "password": _passwordController.text.trim(),
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/register/'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(userData),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OtpScreen(email: _emailController.text.trim()),
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        String errorMessage = "Registration failed";

        if (errorData is Map) {
          if (errorData.containsKey('error')) {
            errorMessage = errorData['error'].toString();
          } else {
            // Join validation errors into a readable string
            errorMessage = errorData.entries
                .map((e) => "${e.key.replaceAll('_', ' ')}: ${(e.value is List) ? (e.value as List).join(', ') : e.value}")
                .join("\n");
          }
        }
        setState(() => _serverError = errorMessage);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _serverError = "Connection error. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(

              padding: EdgeInsets.symmetric(horizontal: 24),

              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // logo section
                    Center(
                      child: Image.asset(
                        'assets/skeleton_clear_bk.png',
                        height: 110,
                      ),
                    ),

                    Text(
                      "Join GaitAnalytica",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onyxCharcoal,
                      ),
                    ),

                    SizedBox(height: 8),

                    Text(
                      "Let's set up your profile for accurate gait tracking.",
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.terrainGrey,
                      ),
                    ),

                    SizedBox(height: 30),

                    // section 1: personal info
                    _buildSectionHeader("Personal Information"),
                    _buildField("First Name", _firstNameController,
                        Icons.person_outline),
                    _buildField("Middle Name (Optional)",
                        _middleNameController, Icons.person_outline),
                    _buildField(
                        "Last Name", _lastNameController, Icons.person_outline),

                    SizedBox(height: 25),

                    // section 2: body metrics
                    _buildSectionHeader("Body Metrics"),
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            "Age",
                            _ageController,
                            Icons.calendar_today,
                            isNumber: true,
                          ),
                        ),

                        SizedBox(width: 15),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Gender",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),

                              SizedBox(height: 8),

                              DropdownButtonFormField<String>(
                                value: _selectedGender,
                                decoration: _inputDecoration(null),
                                items: ['Male', 'Female', 'Other']
                                    .map((String value) {
                                  return DropdownMenuItem<String>(
                                      value: value, child: Text(value));
                                }).toList(),
                                onChanged: (newValue) => setState(
                                        () => _selectedGender = newValue!),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            "Height (cm)",
                            _heightController,
                            Icons.height,
                            isNumber: true,
                          ),
                        ),

                        SizedBox(width: 15),

                        Expanded(
                          child: _buildField(
                            "Weight (kg)",
                            _weightController,
                            Icons.monitor_weight_outlined,
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 25),

                    // section 3: account details
                    _buildSectionHeader("Account Details"),
                    _buildField(
                        "Username", _usernameController, Icons.badge_outlined),
                    _buildField(
                        "Email Address", _emailController, Icons.email_outlined),
                    _buildField("Password", _passwordController,
                        Icons.lock_outlined,
                        isPassword: true),

                    if (_serverError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          _serverError!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],

                    SizedBox(height: 40),

                    // register button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                          if (_formKey.currentState!.validate()) {
                            registerUser();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.skeletonBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          "CREATE ACCOUNT",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 30),
                  ],
                ),
              ),
            ),

            // loading overlay (fixed structure)
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.2),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // section header helper
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.skeletonBlue,
          letterSpacing: 1,
        ),
      ),
    );
  }

  // text field helper
  Widget _buildField(
      String label,
      TextEditingController controller,
      IconData icon, {
        bool isPassword = false,
        bool isNumber = false,
      }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.onyxCharcoal,
            ),
          ),

          SizedBox(height: 8),

          TextFormField(
            controller: controller,
            obscureText: isPassword && !_isPasswordVisible,
            keyboardType:
            isNumber ? TextInputType.number : TextInputType.text,
            decoration: _inputDecoration(
              icon,
              suffix: isPassword
                  ? IconButton(
                icon: Icon(_isPasswordVisible
                    ? Icons.visibility
                    : Icons.visibility_off),
                onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible),
              )
                  : null,
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                // allow optional fields (like middle name)
                if (label.toLowerCase().contains("optional")) {
                  return null;
                }
                return "Required";
              }

              // email validation
              if (label.toLowerCase().contains("email")) {
                final emailRegex = RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                );

                if (!emailRegex.hasMatch(v)) {
                  return "Enter a valid email address";
                }
              }

              if (isPassword) {
                if (v.length < 8 ||
                    !RegExp(r'[A-Z]').hasMatch(v) ||
                    !RegExp(r'[0-9]').hasMatch(v)) {
                  return "Password must be 8+ chars, include uppercase & number";
                }
              }

              if (isNumber) {
                final number = double.tryParse(v);

                if (number == null) {
                  return "Enter a valid number";
                }

                // age validation
                if (label.contains("Age")) {
                  if (number < 1 || number > 120) {
                    return "Age must be between 1 and 120";
                  }
                }

                // height validation
                if (label.contains("Height")) {
                  if (number < 50 || number > 250) {
                    return "Enter a realistic height";
                  }
                }

                // weight validation
                if (label.contains("Weight")) {
                  if (number < 10 || number > 400) {
                    return "Enter a realistic weight";
                  }
                }
              }

              return null;
            },
          ),
        ],
      ),
    );
  }

  // decoration helper
  InputDecoration _inputDecoration(IconData? icon, {Widget? suffix}) {
    return InputDecoration(
      prefixIcon:
      icon != null ? Icon(icon, color: AppColors.skeletonBlue) : null,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.grey.shade50,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: AppColors.skeletonBlue),
      ),
    );
  }
}