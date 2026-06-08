import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/config/api_config.dart';
import '../core/storage/token_storage.dart';
import '../core/theme/app_colors.dart';
import 'home_screen.dart';

class ConsultationRequestScreen extends StatefulWidget {
  final Map consultant;
  const ConsultationRequestScreen({super.key, required this.consultant});

  @override
  State<ConsultationRequestScreen> createState() => _ConsultationRequestScreenState();
}

class _ConsultationRequestScreenState extends State<ConsultationRequestScreen> {
  final _formKey = GlobalKey<FormState>(); // Key to trigger validation
  final _concern = TextEditingController();
  final _notes = TextEditingController();
  String _scope = 'latest';
  bool _isChecked = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isChecked) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.skeletonBlue)),
    );

    try {
      final token = await TokenStorage.getAccessToken();
      final res = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/api/request-consultation/"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json"
        },
        body: jsonEncode({
          "consultant_id": widget.consultant['id'],
          "scope": _scope,
          "survey_data": {"concern": _concern.text.trim(), "notes": _notes.text.trim()}
        }),
      );

      if (mounted) Navigator.pop(context);

      if (res.statusCode == 202) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text("Request Initiated"),
              content: Text("Your data is being prepared for ${widget.consultant['name']}. You will be notified in the app once it has been sent."),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => HomeScreen()), (route) => false);
                  },
                  child: Text("OK"),
                )
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Request Consultation", style: TextStyle(color: AppColors.onyxCharcoal)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.midnightNavy),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(25),
        child: Form(
          key: _formKey, // Form wrapper
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Help ${widget.consultant['name']} understand your needs:", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),

              SizedBox(height: 20),

              TextFormField(
                controller: _concern,
                validator: (val) => val!.isEmpty ? "Please enter your primary concern" : null,
                decoration: InputDecoration(labelText: "Primary Concern", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),

              SizedBox(height: 15),

              TextFormField(
                controller: _notes,
                maxLines: 5,
                validator: (val) => val!.isEmpty ? "Please enter your notes/symptoms" : null,
                decoration: InputDecoration(labelText: "Additional Notes / Symptoms", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),

              SizedBox(height: 25),

              Text("Select Data Scope to Share:", style: TextStyle(fontWeight: FontWeight.bold)),

              RadioListTile(title: Text("Latest Session Only"), value: 'latest', groupValue: _scope, onChanged: (v) => setState(() => _scope = v!)),

              RadioListTile(title: Text("Full Historical Data"), value: 'all', groupValue: _scope, onChanged: (v) => setState(() => _scope = v!)),

              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text("I agree that GaitAnalytica can share my selected data with this consultant.", style: TextStyle(fontSize: 13, color: Colors.grey)),
                value: _isChecked,
                onChanged: (v) => setState(() => _isChecked = v!),
                controlAffinity: ListTileControlAffinity.leading,
              ),

              SizedBox(height: 20),

              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  onPressed: _isChecked ? _submit : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _isChecked ? AppColors.midnightNavy : Colors.grey.shade300,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                  child: Text("SUBMIT REQUEST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}