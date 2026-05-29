import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/config/api_config.dart';
import '../core/storage/token_storage.dart';
import '../core/theme/app_colors.dart';
import 'session_details_screen.dart';

class AnalysisStatusScreen extends StatefulWidget {
  final int sessionId;
  const AnalysisStatusScreen({super.key, required this.sessionId});

  @override
  State<AnalysisStatusScreen> createState() => _AnalysisStatusScreenState();
}

class _AnalysisStatusScreenState extends State<AnalysisStatusScreen> {
  String _status = "Processing";
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try { // Added try-catch for the network request
        final token = await TokenStorage.getAccessToken();
        final response = await http.get(
          Uri.parse("${ApiConfig.baseUrl}/api/analysis_status/${widget.sessionId}/"),
          headers: {"Authorization": "Bearer $token"},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          // Use ?? to provide a fallback string
          String status = data['status'] ?? "Processing";

          if (mounted) setState(() => _status = status);

          if (status == "Completed") {
            timer.cancel();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => SessionDetailsScreen(sessionId: widget.sessionId)),
            );
          } else if (status.toLowerCase().contains("failed")) {
            timer.cancel();
            _showErrorDialog(status);
          }
        } else {
          // Handle non-200 responses
          timer.cancel();
          _showErrorDialog("Connection error: ${response.statusCode}");
        }
      } catch (e) {
        timer.cancel();
        _showErrorDialog("Failed to connect to server.");
      }
    });
  }

  // Add this dialog method to your _AnalysisStatusScreenState class
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false, // Force user to acknowledge
      builder: (context) => AlertDialog(
        title: const Text("Analysis Issue"),
        content: Text("The analysis could not be completed: \n\n$message"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to the previous screen (e.g., camera/home)
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    // Now including "Processing" in the UI steps list
    final List<String> steps = ["Processing", "Detecting Pose", "Extracting Features", "Completed"];

    // Find index, default to 0
    int currentStep = steps.indexOf(_status);
    int displayStep = currentStep == -1 ? 0 : currentStep;

    return Scaffold(
      backgroundColor: AppColors.pureWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Animated Pulse Icon
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.8, end: 1.2),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) => Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: AppColors.skeletonBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.analytics_outlined, size: 60, color: AppColors.skeletonBlue),
                    ),
                  ),
                  onEnd: () => setState(() {}),
                ),
                const SizedBox(height: 40),
                Text(
                  "Analyzing Gait",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.onyxCharcoal),
                ),
                const SizedBox(height: 10),
                Text(
                  "Our AI is processing your movement data.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppColors.terrainGrey),
                ),
                const SizedBox(height: 50),

                // Status Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: AppColors.midnightNavy,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Column(
                    children: [
                      Text(_status.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 15),
                      LinearProgressIndicator(
                        // progress is now currentStep + 1 / total steps
                        value: (displayStep + 1) / steps.length,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.skeletonBlue),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Full Step List including "Processing"
                ...List.generate(steps.length, (i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Icon(
                          i <= displayStep ? Icons.check_circle : Icons.circle_outlined,
                          color: i <= displayStep ? AppColors.skeletonBlue : Colors.grey.shade300,
                          size: 20
                      ),
                      const SizedBox(width: 15),
                      Text(
                          steps[i],
                          style: TextStyle(
                              color: i == currentStep ? AppColors.onyxCharcoal : (i < currentStep ? Colors.grey : Colors.grey.shade400),
                              fontWeight: i == currentStep ? FontWeight.bold : FontWeight.normal
                          )
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }
}