import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/config/api_config.dart';
import '../core/storage/token_storage.dart';
import '../core/theme/app_colors.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // state management
  bool _isLoading = true;
  bool _isEditing = false;
  Map<String, dynamic>? _profileData;

  // controllers for editable fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  String _selectedGender = 'Other';

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  // gets the profile data from django
  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final token = await TokenStorage.getAccessToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/profile/'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _profileData = data;
          // populate controllers with current data
          _firstNameController.text = data['user']['first_name'] ?? "";
          _lastNameController.text = data['user']['last_name'] ?? "";
          _middleNameController.text = data['middle_name'] ?? "";
          _ageController.text = data['age']?.toString() ?? "";
          _heightController.text = data['height_cm']?.toString() ?? "";
          _weightController.text = data['weight_kg']?.toString() ?? "";

          // CHANGE: Standardized gender casing to match Dropdown items (Capitalized)
          String genderFromBackend = data['gender'] ?? "Other";
          _selectedGender = genderFromBackend[0].toUpperCase() + genderFromBackend.substring(1).toLowerCase();
        });
      }
    } catch (e) {
      debugPrint("error fetching profile: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // sends partial update (patch) to django
  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final token = await TokenStorage.getAccessToken();

      // PREPARATION: Gather values and ensure numbers are parsed correctly
      final Map<String, dynamic> updateData = {
        "middle_name": _middleNameController.text.trim(),
        "age": int.tryParse(_ageController.text.trim()) ?? 0,
        "gender": _selectedGender,
        "height_cm": double.tryParse(_heightController.text.trim()) ?? 0,
        "weight_kg": double.tryParse(_weightController.text.trim()) ?? 0,
      };

      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/profile/update/'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        setState(() => _isEditing = false);
        _fetchProfile(); // refresh data to ensure UI is in sync with server
      } else {
        debugPrint("profile update failed: ${response.body}");
      }
    } catch (e) {
      debugPrint("error updating profile: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // POPUP: Confirmation dialog before logging out
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.pureWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "Logout",
            style: TextStyle(color: AppColors.onyxCharcoal, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Are you sure you want to log out of your account?",
            style: TextStyle(color: AppColors.terrainGrey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "CANCEL",
                style: TextStyle(color: AppColors.terrainGrey, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                await _performLogout(); // Execute logout
              },
              child: const Text(
                "LOGOUT",
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // LOGIC: Clear storage and reset navigation stack to Login
  Future<void> _performLogout() async {
    await TokenStorage.clearTokens();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
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
        title: Text(
          "My Profile",
          style: TextStyle(color: AppColors.onyxCharcoal, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          // BUTTON: Toggle between View and Edit mode
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit, color: AppColors.skeletonBlue),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.skeletonBlue))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Form(
          key: _formKey, // FORM KEY: Essential for triggering validation
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.midnightNavy.withOpacity(0.1),
                      child: Icon(Icons.person_outline, size: 50, color: AppColors.midnightNavy),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      "@${_profileData?['user']?['username'] ?? 'user'}",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.onyxCharcoal),
                    ),
                    Text(
                      "${_profileData?['user']?['email'] ?? 'email@test.com'}",
                      style: TextStyle(color: AppColors.terrainGrey, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 35),
              _buildSectionHeader("Personal Information"),

              // Fields using the shared validation logic
              _buildField("First Name", _firstNameController, Icons.person_outline, enabled: false),
              _buildField("Middle Name (Optional)", _middleNameController, Icons.person_outline, enabled: _isEditing),
              _buildField("Last Name", _lastNameController, Icons.person_outline, enabled: false),

              const SizedBox(height: 25),
              _buildSectionHeader("Body Metrics"),
              Row(
                children: [
                  Expanded(
                    child: _buildField("Age", _ageController, Icons.calendar_today, isNumber: true, enabled: _isEditing),
                  ),
                  const SizedBox(width: 15),
                  Expanded(child: _buildGenderDropdown()),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildField("Height (cm)", _heightController, Icons.height, isNumber: true, enabled: _isEditing),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildField("Weight (kg)", _weightController, Icons.monitor_weight_outlined, isNumber: true, enabled: _isEditing),
                  ),
                ],
              ),

              if (_isEditing) ...[
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      // VALIDATION: Only call API if all fields pass constraints
                      if (_formKey.currentState!.validate()) {
                        _updateProfile();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.skeletonBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: _showLogoutDialog,
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  label: const Text("LOGOUT", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.skeletonBlue, letterSpacing: 1),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Gender", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedGender,
          decoration: _inputDecoration(null),
          items: ['Male', 'Female', 'Other'].map((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
          onChanged: _isEditing ? (newValue) => setState(() => _selectedGender = newValue!) : null,
        ),
      ],
    );
  }

  // CHANGE: Fully integrated the robust buildField from RegisterScreen
  Widget _buildField(
      String label,
      TextEditingController controller,
      IconData icon, {
        bool isNumber = false,
        bool enabled = true,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onyxCharcoal)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            enabled: enabled,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            decoration: _inputDecoration(icon),
            style: TextStyle(color: enabled ? AppColors.onyxCharcoal : AppColors.terrainGrey),
            // VALIDATOR: Matches your registration screen constraints exactly
            validator: (v) {
              if (v == null || v.isEmpty) {
                if (label.toLowerCase().contains("optional")) return null;
                return "Required";
              }
              if (isNumber) {
                final number = double.tryParse(v);
                if (number == null) return "Enter a valid number";

                // Specific Body Metric constraints
                if (label.contains("Age") && (number < 1 || number > 120)) return "Age must be 1-120";
                if (label.contains("Height") && (number < 50 || number > 250)) return "Enter a realistic height";
                if (label.contains("Weight") && (number < 10 || number > 400)) return "Enter a realistic weight";
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(IconData? icon) {
    return InputDecoration(
      prefixIcon: icon != null ? Icon(icon, color: AppColors.skeletonBlue) : null,
      filled: true,
      fillColor: Colors.grey.shade50,
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade100),
      ),
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