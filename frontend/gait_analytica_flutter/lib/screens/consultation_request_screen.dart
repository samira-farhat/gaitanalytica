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
  final _concern = TextEditingController();
  final _notes = TextEditingController();
  String _scope = 'latest';

  void _showConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Share Consultation Data?"),
        content: Text("By confirming, your data is being prepared for ${widget.consultant['name']}. You will receive a notification in the app once it has been sent."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submit();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.midnightNavy),
            child: Text("Confirm & Send", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
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
          "survey_data": {"concern": _concern.text, "notes": _notes.text}
        }),
      );

      if (mounted) Navigator.pop(context); // Close loading dialog

      // 202 Accepted means the task was successfully queued in the background
      if (res.statusCode == 202) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text("Request Initiated"),
              content: const Text("We are preparing your session data. You will be notified in the app once it's sent to the consultant."),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => const HomeScreen()), (route) => false);
                  },
                  child: const Text("OK"),
                )
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error initiating request. Please try again.")));
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error: $e");
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
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Help ${widget.consultant['name']} understand your needs:", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            TextFormField(controller: _concern, decoration: InputDecoration(labelText: "Primary Concern", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 15),
            TextFormField(controller: _notes, maxLines: 5, decoration: InputDecoration(labelText: "Additional Notes / Symptoms", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 25),
            const Text("Select Data Scope to Share:", style: TextStyle(fontWeight: FontWeight.bold)),
            RadioListTile(title: const Text("Latest Session Only"), value: 'latest', groupValue: _scope, onChanged: (v) => setState(() => _scope = v!)),
            RadioListTile(title: const Text("Full Historical Data"), value: 'all', groupValue: _scope, onChanged: (v) => setState(() => _scope = v!)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                onPressed: _showConfirmation,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.midnightNavy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: const Text("SUBMIT REQUEST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}