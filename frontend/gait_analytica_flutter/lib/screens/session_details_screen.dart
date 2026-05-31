import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../core/config/api_config.dart';
import '../core/config/goal_config.dart';
import '../core/services/api_service.dart';
import '../core/storage/token_storage.dart';
import '../core/theme/app_colors.dart';

class SessionDetailsScreen extends StatefulWidget {
  final int sessionId;
  const SessionDetailsScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await ApiService.getSessionDetails(widget.sessionId);

      if (!mounted) return;

      setState(() {
        _data = data;
        _isLoading = false;
      });

      if (mounted) {
        final videoPath = data['session']['video_path'];

        if (videoPath != null &&
            videoPath.toString().isNotEmpty) {
          _initVideo(videoPath);
        }
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSession() async {
    try {
      final token = await TokenStorage.getAccessToken();

      final response = await http.delete(
        Uri.parse(
          "${ApiConfig.baseUrl}/api/sessions/${widget.sessionId}/discard/",
        ),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to delete session");
      }
    } catch (e) {
      debugPrint("Error discarding session: $e");
      rethrow;
    }
  }

  void _initVideo(String videoPath) {
    if (!mounted) return;

    final fullUrl = "${ApiConfig.baseUrl}$videoPath";
    _videoController = VideoPlayerController.networkUrl(Uri.parse(fullUrl));

    _videoController!.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: false,
          looping: false,
          aspectRatio: 16 / 9,
          allowFullScreen: true,
        );
      });
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Widget _getStatusBadge(double value, String metricKey) {
    final config = GoalConfigs.metrics[metricKey];
    if (config == null) return Container();
    if (value <= 0.0) return _buildBadge("INVALID", Colors.grey);

    String label = "NEEDS WORK";
    Color statusColor = Colors.red;
    double margin = (metricKey.contains('rom') || metricKey.contains('cadence')) ? 10.0 :
    (metricKey.contains('step_length')) ? 0.05 :
    (metricKey.contains('symmetry')) ? 5.0 : 3.0;

    if (config.higherIsBetter) {
      if (value >= config.minSafe) {
        label = "HEALTHY";
        statusColor = Colors.green;
      } else if (value >= (config.minSafe - margin)) {
        label = "CAUTION";
        statusColor = Colors.orange;
      }
    } else {
      if (value <= config.maxSafe) {
        label = "HEALTHY";
        statusColor = Colors.green;
      } else if (value <= (config.maxSafe + margin)) {
        label = "CAUTION";
        statusColor = Colors.orange;
      }
    }
    return _buildBadge(label, statusColor);
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _showInfoDialog(String title, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: TextStyle(color: AppColors.midnightNavy, fontWeight: FontWeight.bold)),
        content: Text(description, style: TextStyle(height: 1.5)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("Got it"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _data == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.skeletonBlue)));
    }

    final analysis = _data!['analysis'] as Map<String, dynamic>?;
    final status = analysis?['processing_status']?.toString() ?? "";

    if (status.startsWith("Failed")) {
      return Scaffold(
        appBar: AppBar(title: Text("Analysis Results")),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red),

                SizedBox(height: 20),

                Text("Analysis could not be completed", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),

                SizedBox(height: 10),

                Text(status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),

                SizedBox(height: 30),

                ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Back to History"))
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.pureWhite,
      appBar: AppBar(
        backgroundColor: AppColors.pureWhite,
        elevation: 0,
        title: Text(
          "Analysis Results",
          style: TextStyle(
            color: AppColors.onyxCharcoal,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: AppColors.onyxCharcoal,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: Colors.red[700],
            ),
            onPressed: () async {
              final shouldDelete = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Text("Delete Session"),
                  content: Text(
                    "Are you sure you want to delete this session? This action cannot be undone.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text("Cancel"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        "Delete",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );

              if (shouldDelete != true) return;

              await _deleteSession();

              if (!mounted) return;

              Navigator.pop(context, true);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(24)),
              clipBehavior: Clip.antiAlias,
              child: _chewieController != null ? Chewie(controller: _chewieController!) : const Center(child: CircularProgressIndicator()),
            ),

            SizedBox(height: 30),

            Text("Kinematic Performance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onyxCharcoal)),

            SizedBox(height: 15),

            _buildMetricCard("avg_rom", _data!['kinematics']['avg_rom'], "Knee Range of Motion", "Measures the flexibility and movement range of your knee during steps."),
            _buildMetricCard("knee_symmetry_diff", _data!['kinematics']['knee_symmetry_diff'], "Knee Symmetry", "Compares the movement between left and right legs. Lower is better."),

            SizedBox(height: 25),

            Text("Spatial & Rhythm", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onyxCharcoal)),

            SizedBox(height: 15),

            _buildMetricCard("cadence_bpm", _data!['temporal']['cadence_bpm'], "Walking Cadence", "Your steps per minute. Indicates your overall walking rhythm."),
            _buildMetricCard("stride_time_cv", _data!['temporal']['stride_time_cv'] * 100, "Stride Consistency", "How stable your walking pattern is. Higher percentages indicate instability."),
            _buildMetricCard("avg_step_length_norm", _data!['spatial']['avg_step_length_norm'], "Step Efficiency", "Your normalized step distance relative to your height."),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String key, dynamic value, String friendlyName, String definition) {
    final config = GoalConfigs.metrics[key];
    double? rawValue = value == null ? null : double.tryParse(value.toString());

    if (rawValue == null) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text("No data available"),
        ),
      );
    }

    if (rawValue == 0.0) {
      return Card(
        margin: EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.shade100),
        ),
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.grey),

              SizedBox(width: 10),

              Text("Invalid / No reliable data detected"),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade100)),
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(config?.displayName ?? friendlyName, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.midnightNavy)),

                    SizedBox(width: 4),

                    GestureDetector(
                      onTap: () => _showInfoDialog(config?.displayName ?? friendlyName, definition),
                      child: Icon(Icons.info_outline, size: 16, color: AppColors.skeletonBlue),
                    ),
                  ],
                ),
                _getStatusBadge(rawValue, key),
              ],
            ),

            SizedBox(height: 12),

            Row(
              children: [
                Text(rawValue.toStringAsFixed(key == 'avg_step_length_norm' ? 2 : 1), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),

                SizedBox(width: 4),

                Text(config?.unit ?? "", style: TextStyle(color: AppColors.terrainGrey, fontSize: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}