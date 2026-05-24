import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gait_analytica_flutter/screens/profile_screen.dart';
import 'package:http/http.dart' as http;

import '../core/config/api_config.dart';
import '../core/config/goal_config.dart'; // Added for metric naming consistency
import '../core/storage/token_storage.dart';
import '../core/theme/app_colors.dart';
import '../core/services/insight_service.dart';
import 'goals_hub_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // state variables to hold loading status and api data
  bool _isLoading = true;
  Map<String, dynamic>? _userProfile;
  List<dynamic> _recentSessions = [];
  List<dynamic> _recentGoals = [];

  @override
  void initState() {
    super.initState();
    // trigger data fetch as soon as the screen is initialized
    _fetchDashboardData();
  }

  // fetches profile, sessions, and goals simultaneously
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

      // concurrent api calls to reduce waiting time
      final responses = await Future.wait([
        http.get(Uri.parse("${ApiConfig.baseUrl}/api/profile/"), headers: headers),
        http.get(Uri.parse("${ApiConfig.baseUrl}/api/sessions/"), headers: headers),
        http.get(Uri.parse("${ApiConfig.baseUrl}/api/goals/"), headers: headers),
      ]);

      // decode responses only if status code is 200 (ok)
      if (responses[0].statusCode == 200) _userProfile = jsonDecode(responses[0].body);
      if (responses[1].statusCode == 200) _recentSessions = jsonDecode(responses[1].body);

      if (responses[2].statusCode == 200) {
        List allGoals = jsonDecode(responses[2].body);
        setState(() {
          // only take the 3 most recent goals for the dashboard display
          _recentGoals = allGoals.take(3).toList();
        });
      }
    } catch (e) {
      debugPrint("dashboard error: $e");
    } finally {
      // ensures loading stops even if an error occurs
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // helper to decide progress bar and text color based on goal status/percentage
  Color _getGoalColor(double progress, String status) {
    if (status == "Achieved") return Colors.green;
    if (progress < 0.3) return Colors.redAccent;
    if (progress < 0.7) return Colors.orangeAccent;
    return AppColors.skeletonBlue;
  }

  @override
  Widget build(BuildContext context) {
    // pulls the username from nested profile data, defaulting to 'user'
    final String displayName = _userProfile?['user']?['username'] ?? "User";
    // used to show/hide specific ui elements for first-time users
    bool isNewUser = _recentSessions.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.pureWhite,
      body: RefreshIndicator(
        // allows user to pull down to refresh dashboard data
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
                    // hero card displays dynamic insights or a welcome message
                    _buildHeroCard(isNewUser),
                    SizedBox(height: 35),

                    _buildSectionHeader("Recovery Progress", "View All", () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => GoalsHubScreen()),
                      ).then((_) => _fetchDashboardData()); // Refresh dashboard when coming back
                    }),
                    _buildGoalsList(),

                    SizedBox(height: 35),

                    _buildSectionHeader("Recent Sessions", "View All", () {
                      // TODO
                      debugPrint("Navigate to Sessions History");
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

      // show fab only if user has existing sessions
      floatingActionButton: isNewUser ? null : FloatingActionButton.extended(
        onPressed: () {
          // TODO
          debugPrint("Navigate to Instructions Screen");
        },
        backgroundColor: AppColors.powderBlue,
        label: Text("NEW SCAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: Icon(Icons.add_a_photo, color: Colors.white),
      ),
    );
  }

  // custom app bar with profile icon and greeting
  Widget _buildAppBar(String name) {
    // NEW: Check if profile picture exists in the fetched data
    final String? profilePicPath = _userProfile?['profile_pic'];

    return SliverAppBar(
      floating: true,
      backgroundColor: AppColors.pureWhite,
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          Material(
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
                backgroundColor: AppColors.skeletonBlue.withOpacity(0.1),
                // use NetworkImage if path exists (to show profile pic), otherwise show default icon
                backgroundImage: profilePicPath != null
                    ? NetworkImage("${ApiConfig.baseUrl}$profilePicPath")
                    : null,
                child: profilePicPath == null
                    ? Icon(Icons.person_outline, color: AppColors.skeletonBlue)
                    : null,
              ),
            ),
          ),

          SizedBox(width: 12),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Welcome back,", style: TextStyle(color: AppColors.terrainGrey, fontSize: 12)),
              Text(name, style: TextStyle(color: AppColors.onyxCharcoal, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),

          Spacer(),

          // logo
          Image.asset(
            'assets/logo0_clear_bk.png',
            height: 45,
            fit: BoxFit.contain,
          ),

        ],
      ),
    );
  }

  // hero section that uses insightservice to provide personalized feedback
  Widget _buildHeroCard(bool isNewUser) {
    // get random or trend-based insight from our external service
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

          if (isNewUser) ...[
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                debugPrint("Navigate to Instructions Screen");
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.skeletonBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text("START ANALYSIS", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  // renders a list of active goals with progress bars
  Widget _buildGoalsList() {
    if (_recentGoals.isEmpty) {
      return _buildEmptyState("No active goals. Set one in profile.");
    }

    return Column(
      children: _recentGoals.map((goal) {
        final String status = goal['status'] ?? "Active";
        final String rawMetric = goal['metric_name'].toString();

        // Use GoalConfigs to get the clean display name (e.g., "Knee ROM")
        final String metricName = GoalConfigs.metrics[rawMetric]?.displayName ?? rawMetric.replaceAll('_', ' ').toUpperCase();

        final double target = double.tryParse(goal['target_value'].toString()) ?? 1.0;
        final double latest = double.tryParse(goal['latest_value']?.toString() ?? goal['starting_value']?.toString() ?? "0") ?? 0.0;
        final double start = double.tryParse(goal['starting_value']?.toString() ?? "0") ?? 0.0;

        // logic: determine if lower is better for this specific metric from config
        bool higherIsBetter = GoalConfigs.metrics[rawMetric]?.higherIsBetter ?? true;

        double progress = 0.0;

        if (higherIsBetter) {
          if (latest >= target) {
            progress = 1.0;
          } else if (latest <= start) {
            progress = 0.0;
          } else {
            // Journey formula for increasing values
            progress = (latest - start) / (target - start);
          }
        } else {
          // Lower is better logic (e.g., Stride CV)
          if (latest <= target) {
            progress = 1.0;
          } else if (latest >= start) {
            progress = 0.0;
          } else {
            // Journey formula for decreasing values
            progress = (start - latest) / (start - target);
          }
        }

        // clamp between 0.0 and 1.0 for the progress bar
        progress = progress.clamp(0.0, 1.0);
        int percentage = (progress * 100).toInt();
        Color statusColor = _getGoalColor(progress, status);

        return Card(
          margin: EdgeInsets.only(bottom: 15),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade100),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              // TODO
              debugPrint("Navigate to Goal Details");
            },
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(metricName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.skeletonBlue)),
                      Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Current: ${latest.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("Target: ${target.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.shade100,
                      color: statusColor,
                      minHeight: 8,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text("$percentage% Completed", style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // renders the history of gait analysis sessions
  Widget _buildSessionsList() {
    if (_recentSessions.isEmpty) {
      return _buildEmptyState("Record your first walk to see results.");
    }

    // calculates absolute session number based on total count from database
    final int totalUserSessions = _recentSessions.length;

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      // limits the view to the 3 most recent sessions
      itemCount: _recentSessions.length > 3 ? 3 : _recentSessions.length,
      itemBuilder: (context, index) {
        final session = _recentSessions[index];

        // session 1 is the oldest, session N is the latest
        int sessionDisplayNum = totalUserSessions - index;

        // extracts just the date part of the timestamp
        String displayDate = session['session_date']?.toString().split('T')[0] ?? "Recent";

        return Card(
          margin: EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: Colors.grey.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.grey.shade100),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () {
              // TODO
              debugPrint("Navigate to Session Details");
            },
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.skeletonBlue.withOpacity(0.1),
                child: Text("$sessionDisplayNum", style: TextStyle(color: AppColors.skeletonBlue, fontWeight: FontWeight.bold)),
              ),
              title: Text("Gait Analysis", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Date: $displayDate"),
              trailing: Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.terrainGrey),
            ),
          ),
        );
      },
    );
  }

  // simple centered text placeholder for when lists are empty
  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text(message, style: TextStyle(color: AppColors.terrainGrey, fontStyle: FontStyle.italic)),
      ),
    );
  }

  // standardized header for each major section (progress, sessions)
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