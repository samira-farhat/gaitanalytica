import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';
import '../core/storage/token_storage.dart';
import '../core/theme/app_colors.dart';

class AiInterpretationScreen extends StatefulWidget {
  final int sessionId;

  const AiInterpretationScreen({super.key, required this.sessionId});

  @override
  State<AiInterpretationScreen> createState() => _AiInterpretationScreenState();
}

class _AiInterpretationScreenState extends State<AiInterpretationScreen> {
  String? _aiInterpretation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAiInterpretation();
  }

  Future<void> _fetchAiInterpretation() async {
    try {
      final token = await TokenStorage.getAccessToken();
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/interpret-current/?session_id=${widget.sessionId}"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedResponse = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _aiInterpretation = decodedResponse['ai_interpretation'];
            _isLoading = false;
          });
        }
      } else {
        throw Exception("Failed to load AI details");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiInterpretation = "Unable to process AI evaluation at this moment.";
          _isLoading = false;
        });
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
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.onyxCharcoal, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.skeletonBlue))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology_outlined, color: AppColors.midnightNavy, size: 28),
                const SizedBox(width: 10),
                const Text(
                  "GaitAnalytica AI Assessment",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.midnightNavy),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.skeletonBlue.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.skeletonBlue.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Text(
                _aiInterpretation ?? "No evaluation data returned.",
                style: const TextStyle(
                  color: AppColors.onyxCharcoal,
                  fontSize: 15,
                  height: 1.6,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}