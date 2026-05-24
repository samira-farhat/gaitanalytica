import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

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
  bool _isRemovingImage = false; // to track if user wants to delete image
  Map<String, dynamic>? _profileData;

  String? _errorMessage;

  // image picking state
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

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
          _firstNameController.text = data['user']['first_name'] ?? "";
          _lastNameController.text = data['user']['last_name'] ?? "";
          _middleNameController.text = data['middle_name'] ?? "";
          _ageController.text = data['age']?.toString() ?? "";
          _heightController.text = data['height_cm']?.toString() ?? "";
          _weightController.text = data['weight_kg']?.toString() ?? "";

          String genderFromBackend = data['gender'] ?? "Other";
          _selectedGender = genderFromBackend[0].toUpperCase() + genderFromBackend.substring(1).toLowerCase();

          _selectedImage = null;
          _isRemovingImage = false;
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

  // image logic
  void _viewFullImage() {
    final imageProvider = _getImageProvider();
    if (imageProvider == null) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: IconThemeData(color: Colors.white),
          title: Text("Profile Photo", style: TextStyle(color: Colors.white)),
        ),
        body: Center(
          child: Hero(
            tag: 'profile_avatar',
            child: Image(image: imageProvider, fit: BoxFit.contain),
          ),
        ),
      );
    }));
  }

  // bottom sheet menu (WhatsApp style) for profile pic
  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10),

            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),

            SizedBox(height: 10),

            ListTile(
              leading: Icon(Icons.fullscreen, color: AppColors.skeletonBlue),
              title: Text("View Profile Photo"),
              onTap: () {
                Navigator.pop(context);
                _viewFullImage();
              },
            ),
            if (_isEditing) ...[
              ListTile(
                leading: Icon(Icons.photo_library, color: AppColors.skeletonBlue),
                title: Text("Choose from Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              if (_selectedImage != null || _profileData?['profile_pic'] != null)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: Text("Remove Photo", style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedImage = null;
                      _isRemovingImage = true;
                    });
                  },
                ),
            ],

            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (image != null) {
      setState(() {
        _selectedImage = image;
        _isRemovingImage = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final token = await TokenStorage.getAccessToken();
      var request = http.MultipartRequest(
        'PATCH',
        Uri.parse('${ApiConfig.baseUrl}/api/profile/update/'),
      );

      request.headers.addAll({"Authorization": "Bearer $token"});
      request.fields['middle_name'] = _middleNameController.text.trim();
      request.fields['age'] = _ageController.text.trim();
      request.fields['gender'] = _selectedGender;
      request.fields['height_cm'] = _heightController.text.trim();
      request.fields['weight_kg'] = _weightController.text.trim();

      // handle removal vs upload
      if (_isRemovingImage) {
        request.fields['remove_profile_pic'] = "true"; // tells backend to clear field
      } else if (_selectedImage != null) {
        if (kIsWeb) {
          final bytes = await _selectedImage!.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes('profile_pic', bytes, filename: _selectedImage!.name));
        } else {
          request.files.add(await http.MultipartFile.fromPath('profile_pic', _selectedImage!.path));
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        setState(() {
          _isEditing = false;
          _errorMessage = null;
        });
        _fetchProfile();
      } else {
        debugPrint("profile update failed: ${response.body}");
        setState(() {
          _errorMessage = "Failed to update profile. Please try again.";
        });
      }
    } catch (e) {
      debugPrint("error updating profile: $e");
      setState(() {
        _errorMessage = "Network error. Check your connection.";
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // helper to determine which image to show
  ImageProvider? _getImageProvider() {
    if (_isRemovingImage) return null;
    if (_selectedImage != null) {
      return kIsWeb ? NetworkImage(_selectedImage!.path) : FileImage(File(_selectedImage!.path));
    }
    if (_profileData?['profile_pic'] != null) {
      return NetworkImage("${ApiConfig.baseUrl}${_profileData?['profile_pic']}");
    }
    return null;
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.pureWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Logout", style: TextStyle(color: AppColors.onyxCharcoal, fontWeight: FontWeight.bold)),
          content: Text("Are you sure you want to log out of your account?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCEL")),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _performLogout();
              },
              child: Text("LOGOUT", style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout() async {
    await TokenStorage.clearTokens();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = _getImageProvider();

    return Scaffold(
      backgroundColor: AppColors.pureWhite,
      appBar: AppBar(
        backgroundColor: AppColors.pureWhite,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.onyxCharcoal, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("My Profile", style: TextStyle(color: AppColors.onyxCharcoal, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit, color: AppColors.skeletonBlue),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
                if (!_isEditing) {
                  _selectedImage = null;
                  _isRemovingImage = false;
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.skeletonBlue))
          : SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _showImageOptions,
                      child: Stack(
                        children: [

                          Hero(
                            tag: 'profile_avatar',
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: AppColors.midnightNavy.withOpacity(0.1),
                              backgroundImage: imageProvider,
                              child: imageProvider == null ? Icon(Icons.person_outline, size: 50, color: AppColors.midnightNavy) : null,
                            ),
                          ),
                          if (_isEditing)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.skeletonBlue,
                                child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),

                    SizedBox(height: 15),

                    Text("@${_profileData?['user']?['username'] ?? 'user'}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.onyxCharcoal)),

                    Text("${_profileData?['user']?['email'] ?? 'email@test.com'}", style: TextStyle(color: AppColors.terrainGrey, fontSize: 14)),
                  ],
                ),
              ),

              SizedBox(height: 35),

              _buildSectionHeader("Personal Information"),
              _buildField("First Name", _firstNameController, Icons.person_outline, enabled: false),
              _buildField("Middle Name (Optional)", _middleNameController, Icons.person_outline, enabled: _isEditing),
              _buildField("Last Name", _lastNameController, Icons.person_outline, enabled: false),

              SizedBox(height: 25),
              _buildSectionHeader("Body Metrics"),

              Row(
                children: [
                  Expanded(child: _buildField("Age", _ageController, Icons.calendar_today, isNumber: true, enabled: _isEditing)),
                  SizedBox(width: 15),
                  Expanded(child: _buildGenderDropdown()),
                ],
              ),

              Row(
                children: [
                  Expanded(child: _buildField("Height (cm)", _heightController, Icons.height, isNumber: true, enabled: _isEditing)),
                  SizedBox(width: 15),
                  Expanded(child: _buildField("Weight (kg)", _weightController, Icons.monitor_weight_outlined, isNumber: true, enabled: _isEditing)),
                ],
              ),
              if (_isEditing) ...[
                SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) _updateProfile();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.skeletonBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    child: Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],

              SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: _showLogoutDialog,
                  icon: Icon(Icons.logout, color: Colors.redAccent),
                  label: Text("LOGOUT", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                ),
              ),

              SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.skeletonBlue, letterSpacing: 1)),
  );

  Widget _buildGenderDropdown() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text("Gender", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),

      SizedBox(height: 8),

      DropdownButtonFormField<String>(
        value: _selectedGender,
        decoration: _inputDecoration(null),
        items: ['Male', 'Female', 'Other'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: _isEditing ? (v) => setState(() => _selectedGender = v!) : null,
      ),
    ],
  );

  Widget _buildField(String label, TextEditingController controller, IconData icon, {bool isNumber = false, bool enabled = true}) => Padding(
    padding: EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onyxCharcoal)),

        SizedBox(height: 8),

        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: _inputDecoration(icon),
          style: TextStyle(color: enabled ? AppColors.onyxCharcoal : AppColors.terrainGrey),
          validator: (v) {
            if (v == null || v.isEmpty) return label.toLowerCase().contains("optional") ? null : "Required";
            if (isNumber) {
              final n = double.tryParse(v);
              if (n == null) return "Invalid number";
              if (label.contains("Age") && (n < 1 || n > 120)) return "Age 1-120";
              if (label.contains("Height") && (n < 50 || n > 250)) return "Invalid height";
              if (label.contains("Weight") && (n < 10 || n > 400)) return "Invalid weight";
            }
            return null;
          },
        ),
      ],
    ),
  );

  InputDecoration _inputDecoration(IconData? icon) => InputDecoration(
    prefixIcon: icon != null ? Icon(icon, color: AppColors.skeletonBlue) : null,
    filled: true,
    fillColor: Colors.grey.shade50,
    disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade100)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: AppColors.skeletonBlue)),
  );
}