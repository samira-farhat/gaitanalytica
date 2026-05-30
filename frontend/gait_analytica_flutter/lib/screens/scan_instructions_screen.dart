import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme/app_colors.dart';

class ScanInstructionsScreen extends StatelessWidget {
  final Function(ImageSource) onSourceSelected;

  const ScanInstructionsScreen({super.key, required this.onSourceSelected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Guidelines"), backgroundColor: Colors.white, foregroundColor: Colors.black),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  _buildGuidelineItem(Icons.timer, "Recommended Length", "Record between 15 and 30 seconds for the most accurate gait analysis."),
                  _buildGuidelineItem(Icons.camera_alt, "Side View (90°)", "Position camera at a 90° angle, capturing your full body from the side."),
                  _buildGuidelineItem(Icons.cleaning_services, "Clean Background", "Use a clutter-free area so the AI can track your movements clearly."),
                  _buildGuidelineItem(Icons.accessibility_new, "Full Frame", "Ensure your head and feet are visible throughout the entire walk."),
                  _buildGuidelineItem(Icons.trip_origin, "Stable Camera", "Use a tripod or steady surface to prevent shaky, blurred footage."),
                  _buildGuidelineItem(Icons.lightbulb_outline, "Bright Lighting", "Avoid backlighting. Ensure the side facing the camera is well-lit."),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.midnightNavy,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showSourcePicker(context),
              child: const Text("I'M READY - START SCAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidelineItem(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: AppColors.skeletonBlue, size: 30),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
    );
  }

  void _showSourcePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text("Record New Video"),
            onTap: () { Navigator.pop(context); onSourceSelected(ImageSource.camera); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text("Choose from Gallery"),
            onTap: () { Navigator.pop(context); onSourceSelected(ImageSource.gallery); },
          ),
        ],
      ),
    );
  }
}