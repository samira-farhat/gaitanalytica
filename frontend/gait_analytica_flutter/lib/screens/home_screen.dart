import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gait_analytica_flutter/screens/profile_screen.dart';
import 'package:gait_analytica_flutter/screens/session_details_screen.dart';
import 'package:gait_analytica_flutter/screens/session_history_screen.dart';
import 'package:gait_analytica_flutter/screens/analysis_status_screen.dart';
import 'package:gait_analytica_flutter/screens/scan_instructions_screen.dart';
import 'package:http/http.dart' as http;

import '../core/config/api_config.dart';
import '../core/config/goal_config.dart';
import '../core/storage/token_storage.dart';
import '../core/theme/app_colors.dart';
import '../core/services/insight_service.dart';
import 'consultants_list_screen.dart';
import 'goal_details_screen.dart';
import 'goals_hub_screen.dart';
import 'notification_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _userProfile;
  List<dynamic> _recentSessions = [];
  List<dynamic> _recentGoals = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final token = await TokenStorage.getAccessToken();
      if (token == null) return;

      final headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      };

      final responses = await Future.wait([
        http.get(Uri.parse("${ApiConfig.baseUrl}/api/profile/"), headers: headers),
        http.get(Uri.parse("${ApiConfig.baseUrl}/api/sessions/"), headers: headers),
        http.get(Uri.parse("${ApiConfig.baseUrl}/api/goals/"), headers: headers),
        http.get(Uri.parse("${ApiConfig.baseUrl}/api/notifications/"), headers: headers), // Fetch notifications
      ]);

      if (responses[0].statusCode == 200 && responses[0].body.isNotEmpty) {
        _userProfile = jsonDecode(responses[0].body);
      }
      if (responses[1].statusCode == 200 && responses[1].body.isNotEmpty) {
        _recentSessions = jsonDecode(responses[1].body);
      }

      if (responses[2].statusCode == 200) {
        List allGoals = jsonDecode(responses[2].body);
        List filteredGoals = allGoals.where((goal) => goal['status'] == 'Active').toList();
        _recentGoals = filteredGoals.take(3).toList();
      }

      if (responses[3].statusCode == 200) {
        List notifs = jsonDecode(responses[3].body);
        _unreadCount = notifs.where((n) => n['is_read'] == false).length;
      }
    } catch (e) {
      debugPrint("dashboard error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToInstructions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScanInstructionsScreen(
          onSourceSelected: (source) {
            Navigator.pop(context);
            _performUpload(source);
          },
        ),
      ),
    );
  }

  Future<void> _performUpload(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: source);

    if (video == null) return;

    final token = await TokenStorage.getAccessToken();
    final uri = Uri.parse("${ApiConfig.baseUrl}/api/analyze/");

    final bytes = await video.readAsBytes();

    var request = http.MultipartRequest('POST', uri);
    request.headers.addAll({"Authorization": "Bearer $token"});

    request.files.add(http.MultipartFile.fromBytes(
      'video',
      bytes,
      filename: video.name,
    ));

    final response = await request.send();
    if (response.statusCode == 202) {
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AnalysisStatusScreen(sessionId: data['session_id'])),
        );
        _fetchDashboardData();
      }
    } else {
      debugPrint("Upload failed with status: ${response.statusCode}");
    }
  }

  Color _getGoalColor(double progress, String status) {
    if (status == "Achieved") return Colors.green;
    if (progress < 0.3) return Colors.redAccent;
    if (progress < 0.7) return Colors.orangeAccent;
    return Colors.teal;
  }

  @override
  Widget build(BuildContext context) {
    final String displayName = _userProfile?['user']?['username'] ?? "User";
    bool isNewUser = _recentSessions.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.pureWhite,
      body: RefreshIndicator(
        onRefresh: _fetchDashboardData,
        color: AppColors.skeletonBlue,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppColors.skeletonBlue))
            : CustomScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(displayName),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),

                    _buildHeroCard(isNewUser),

                    SizedBox(height: 35),

                    _buildSectionHeader("Recovery Progress", "View All", () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => GoalsHubScreen()),
                      ).then((_) => _fetchDashboardData());
                    }),

                    _buildGoalsList(),

                    SizedBox(height: 35),

                    _buildSectionHeader("Recent Sessions", "View All", () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SessionHistoryScreen()),
                      ).then((_) => _fetchDashboardData());
                    }),

                    _buildSessionsList(),

                    SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: isNewUser ? null : FloatingActionButton.extended(
        onPressed: _navigateToInstructions,
        backgroundColor: AppColors.midnightNavy,
        label: Text("NEW SCAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: Icon(Icons.add_a_photo, color: Colors.white),
      ),
    );
  }

  Widget _buildAppBar(String name) {
    final String? profilePicPath = _userProfile?['profile_pic'];
    return SliverAppBar(
      floating: true,
      backgroundColor: AppColors.pureWhite,
      elevation: 0,
      centerTitle: true,
      title: Image.asset('assets/logo0_clear_bk.png', height: 40, fit: BoxFit.contain),
      leading: Padding(
        padding: EdgeInsets.only(left: 15),
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileScreen()),
                ).then((_) => _fetchDashboardData());
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.skeletonBlue.withOpacity(0.1),
                backgroundImage: profilePicPath != null
                    ? NetworkImage("${ApiConfig.baseUrl}$profilePicPath")
                    : null,
                child: profilePicPath == null
                    ? Icon(Icons.person_outline, color: AppColors.midnightNavy, size: 25)
                    : null,
              ),
            ),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: 15),
          child: IconButton(
            icon: Badge(
              label: Text(_unreadCount.toString()),
              isLabelVisible: _unreadCount > 0,
              backgroundColor: Colors.redAccent,
              child: Icon(Icons.notifications_none, color: AppColors.midnightNavy, size: 25),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => NotificationsScreen()),
              ).then((_) => _fetchDashboardData());
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(bool isNewUser) {
    String description = InsightService.getLatestInsight(_recentSessions);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.midnightNavy.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isNewUser ? "Ready for your walk?" : "Daily Insight",
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(description, style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),

          SizedBox(height: 20),

          if (isNewUser)
            ElevatedButton(
              onPressed: _navigateToInstructions,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.skeletonBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text("START ANALYSIS", style: TextStyle(fontWeight: FontWeight.bold)),
            )
          else
          // This is your new Consultants button
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: Offset(0, 4)),
                ],
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ConsultantsListScreen()),
                  );
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text("Chat with Consultants", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGoalsList() {
    if (_recentGoals.isEmpty) return _buildEmptyState("No active goals found.");
    return Column(
      children: _recentGoals.map((goal) {
        final String status = goal['status'] ?? "Active";
        final String rawMetric = goal['metric_name'].toString();
        final config = GoalConfigs.metrics[rawMetric];
        final String metricName = config?.displayName ?? rawMetric.replaceAll('_', ' ').toUpperCase();
        double latest = double.tryParse(goal['latest_value']?.toString() ?? goal['starting_value']?.toString() ?? "0") ?? 0.0;
        double start = double.tryParse(goal['starting_value']?.toString() ?? latest.toString()) ?? latest;
        double target = double.tryParse(goal['target_value']?.toString() ?? "0") ?? 0.0;
        if (rawMetric == "stride_time_cv") {
          if (target < 1.0) target *= 100;
          if (latest < 1.0) latest *= 100;
          if (start < 1.0) start *= 100;
        }
        bool higherIsBetter = config?.higherIsBetter ?? true;

        double progress = 0.0;
        if (target == 0.0) {

          if (start != target) {
            progress = (start - latest) / (start - target);
          } else {
            progress = 1.0;
          }
        } else {
          progress = higherIsBetter ? (latest / target) : (target / latest);
        }
        progress = progress.clamp(0.0, 1.0);


        Color statusColor = _getGoalColor(progress, status);
        return Card(
          margin: EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade100)),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => GoalDetailsScreen(goal: goal))).then((_) => _fetchDashboardData());
            },
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(metricName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.skeletonBlue)),

                  SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Current: ${latest.toStringAsFixed(2)}${config?.unit ?? ''}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("Target: ${target.toStringAsFixed(2)}${config?.unit ?? ''}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),

                  SizedBox(height: 12),

                  LinearProgressIndicator(value: progress, color: statusColor, backgroundColor: Colors.grey.shade100),

                  SizedBox(height: 8),

                  Text("${(progress * 100).round()}% Completed", style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSessionsList() {
    if (_recentSessions.isEmpty) return _buildEmptyState("Record your first walk to see results.");
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _recentSessions.length > 3 ? 3 : _recentSessions.length,
      itemBuilder: (context, index) {
        final session = _recentSessions[index];
        String formattedDate = "Unknown Date";
        String formattedTime = "";
        try {
          final DateTime sessionDate = DateTime.parse(session['session_date']).toLocal();
          final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
          formattedDate = "${weekdays[sessionDate.weekday - 1]}, ${months[sessionDate.month - 1]} ${sessionDate.day}";
          int hour = sessionDate.hour > 12 ? sessionDate.hour - 12 : (sessionDate.hour == 0 ? 12 : sessionDate.hour);
          String period = sessionDate.hour >= 12 ? "PM" : "AM";
          String minute = sessionDate.minute.toString().padLeft(2, '0');
          formattedTime = "Recorded at $hour:$minute $period";
        } catch (e) {
          formattedDate = "Invalid Date";
          formattedTime = "N/A";
        }
        return Card(
          margin: EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade100)),
          elevation: 0,
          child: ListTile(
            contentPadding: EdgeInsets.all(15),
            leading: Container(
              width: 50, height: 50,
              decoration: BoxDecoration(color: AppColors.skeletonBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
              child: Icon(Icons.directions_walk, color: AppColors.skeletonBlue),
            ),
            title: Text(formattedDate, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.onyxCharcoal, fontSize: 16)),
            subtitle: Text(formattedTime, style: TextStyle(color: Colors.grey, fontSize: 13)),
            trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SessionDetailsScreen(sessionId: session['id'])),
              ).then((_) => _fetchDashboardData());
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text(message, style: TextStyle(color: AppColors.terrainGrey, fontStyle: FontStyle.italic)),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String action, VoidCallback onActionTap) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onyxCharcoal)),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onActionTap,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Text(action, style: TextStyle(color: AppColors.skeletonBlue, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}