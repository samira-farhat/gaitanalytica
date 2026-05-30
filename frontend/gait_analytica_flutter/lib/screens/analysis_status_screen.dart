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

  Future<void> _discardBadSession() async {
    try {
      final token = await TokenStorage.getAccessToken();
      await http.delete(
        Uri.parse("${ApiConfig.baseUrl}/api/sessions/${widget.sessionId}/discard/"),
        headers: {"Authorization": "Bearer $token"},
      );
    } catch (e) {
      debugPrint("Error discarding session: $e");
    }
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final token = await TokenStorage.getAccessToken();
        final response = await http.get(
          Uri.parse("${ApiConfig.baseUrl}/api/analysis_status/${widget.sessionId}/"),
          headers: {"Authorization": "Bearer $token"},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          String status = data['status'] ?? "Processing";

          if (mounted) setState(() => _status = status);

          if (status == "Completed") {
            timer.cancel();

            // --- START METRIC VALIDATION ---
            final metrics = data['analysis_results'];
            // Access nested metrics safely
            double rom = double.tryParse(metrics?['kinematics']?['avg_rom']?.toString() ?? '0') ?? 0;
            double cadence = double.tryParse(metrics?['temporal']?['cadence_bpm']?.toString() ?? '0') ?? 0;

            if (rom == 0 || cadence == 0) {
              await _discardBadSession(); // Remove from DB so it doesn't pollute history

              String errorTitle = "Low Quality Scan";
              String errorMsg = "The AI couldn't track your movement accurately.";

              if (rom == 0) {
                errorMsg = "We couldn't detect your leg joints clearly. Please ensure your full body is visible from the side in a well-lit area.";
              } else if (cadence == 0) {
                errorMsg = "We couldn't detect a steady walking rhythm. Please walk naturally at a steady pace for at least 15 seconds.";
              }

              if (mounted) _showQualityErrorDialog(errorTitle, errorMsg);
              return;
            }
            // --- END METRIC VALIDATION ---

            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => SessionDetailsScreen(sessionId: widget.sessionId)),
              );
            }
          } else if (status.toLowerCase().contains("failed")) {
            timer.cancel();
            _showErrorDialog(status);
          }
        } else {
          timer.cancel();
          _showErrorDialog("Connection error: ${response.statusCode}");
        }
      } catch (e) {
        timer.cancel();
        _showErrorDialog("Failed to connect to server.");
      }
    });
  }

  void _showQualityErrorDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Back to Home
            },
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.skeletonBlue),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Back to Home/Instructions
            },
            child: const Text("RE-SCAN", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Analysis Issue"),
        content: Text("The analysis could not be completed: \n\n$message"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
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
  Widget build(BuildContext context) {
    final List<String> steps = ["Processing", "Detecting Pose", "Extracting Features", "Completed"];
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
                        value: (displayStep + 1) / steps.length,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.skeletonBlue),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
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