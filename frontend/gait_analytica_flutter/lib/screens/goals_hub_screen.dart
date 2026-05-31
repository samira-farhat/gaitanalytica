import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';
import '../core/config/goal_config.dart';
import '../core/storage/token_storage.dart';
import '../core/theme/app_colors.dart';
import 'goal_details_screen.dart';
import '../core/widgets/add_goal_bottom_sheet.dart';

class GoalsHubScreen extends StatefulWidget {
  const GoalsHubScreen({super.key});

  @override
  State<GoalsHubScreen> createState() => _GoalsHubScreenState();
}

class _GoalsHubScreenState extends State<GoalsHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _goals = [];
  Map<String, dynamic> _latestMetricValues = {};
  String _order = 'newest';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchGoals();
  }

  Color _getGoalColor(double progress, String status) {
    if (status == "Achieved") return Colors.green;
    if (progress < 0.3) return Colors.redAccent;
    if (progress < 0.7) return Colors.orangeAccent;
    return Colors.teal;
  }

  Future<void> _fetchGoals() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final token = await TokenStorage.getAccessToken();

      final results = await Future.wait([
        http.get(Uri.parse("${ApiConfig.baseUrl}/api/goals/?order=$_order"),
            headers: {"Authorization": "Bearer $token"}),
        http.get(Uri.parse("${ApiConfig.baseUrl}/api/sessions/"),
            headers: {"Authorization": "Bearer $token"}),
      ]);

      final Map<String, dynamic> latestMap = {};

      if (results[1].statusCode == 200) {
        final List<dynamic> sessions = jsonDecode(results[1].body);
        if (sessions.isNotEmpty) {
          final latestId = sessions.first['id'];

          final detailRes = await http.get(
            Uri.parse("${ApiConfig.baseUrl}/api/sessions/$latestId/"),
            headers: {"Authorization": "Bearer $token"},
          );

          if (detailRes.statusCode == 200) {
            final detailData = jsonDecode(detailRes.body);

            if (detailData['kinematics'] != null) {
              latestMap['avg_rom'] = detailData['kinematics']['avg_rom'];
              latestMap['knee_symmetry_diff'] = detailData['kinematics']['knee_symmetry_diff'];
            }
            if (detailData['spatial'] != null) {
              latestMap['avg_step_length_norm'] = detailData['spatial']['avg_step_length_norm'];
            }
            if (detailData['temporal'] != null) {
              latestMap['cadence_bpm'] = detailData['temporal']['cadence_bpm'];
              latestMap['stride_time_cv'] = detailData['temporal']['stride_time_cv'];
            }
          }
        }
      }

      if (results[0].statusCode == 200) {
        final List<dynamic> fetchedGoals = jsonDecode(results[0].body);
        for (var goal in fetchedGoals) {
          // to only map latest values for Active goals to avoid overwriting logic
          if (goal['status'] == 'Active') {
            latestMap[goal['metric_name'].toString()] = goal['latest_value'] ?? goal['starting_value'];
          }
        }
        setState(() {
          _goals = fetchedGoals;
          _latestMetricValues = latestMap;
        });
      }
    } catch (e) {
      debugPrint("Error fetching metrics: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _getFilteredGoals(String status) {
    return _goals.where((g) => g['status'].toString().trim().toLowerCase() == status.toLowerCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pureWhite,
      appBar: AppBar(
        backgroundColor: AppColors.pureWhite,
        elevation: 0,
        title: Text("Recovery Goals",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.onyxCharcoal
            )
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: AppColors.onyxCharcoal,
              size: 20
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() => _order = _order == 'newest' ? 'oldest' : 'newest');
              _fetchGoals();
            },
            icon: Icon(Icons.sort, size: 16, color: AppColors.skeletonBlue),
            label: Text(_order.toUpperCase(), style: TextStyle(color: AppColors.skeletonBlue, fontSize: 12, fontWeight: FontWeight.bold)),
          ),

          SizedBox(width: 8),

        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.skeletonBlue,
          indicatorColor: AppColors.skeletonBlue,
          tabs: [Tab(text: "Active"), Tab(text: "Achieved"), Tab(text: "Cancelled")],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.skeletonBlue))
          : TabBarView(
        controller: _tabController,
        children: [_buildGoalList("Active"), _buildGoalList("Achieved"), _buildGoalList("Cancelled")],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGoalSheet(),
        backgroundColor: AppColors.midnightNavy,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildGoalList(String status) {
    final filtered = _getFilteredGoals(status);

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag_outlined, size: 64, color: Colors.grey[300]),

            SizedBox(height: 16),

            Text("No $status goals found.", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(20),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final goal = filtered[index];
        final String rawMetric = goal['metric_name'].toString();
        final config = GoalConfigs.metrics[rawMetric];

        double target = double.tryParse(goal['target_value'].toString()) ?? 0.0;

        double latest;

        final goalStatus = goal['status'].toString().trim().toLowerCase();

        if (goalStatus == "active") {

          latest = double.tryParse(
            _latestMetricValues[rawMetric]?.toString() ??
                goal['latest_value']?.toString() ??
                goal['starting_value'].toString(),
          ) ?? 0.0;

        }
        else {

          // achieved OR cancelled
          latest = double.tryParse(
            goal['achieved_value']?.toString() ??
                goal['latest_value']?.toString() ??
                goal['starting_value'].toString(),
          ) ?? 0.0;

        }

        if (rawMetric == "stride_time_cv") {
          if (target < 1.0) target *= 100;
          if (latest < 1.0) latest *= 100;
        }

        bool higherIsBetter = config?.higherIsBetter ?? true;
        double progress = 0.0;
        if (target != 0.0) {
          progress = higherIsBetter ? (latest / target) : (target / latest);
        }
        progress = progress.clamp(0.0, 1.0);

        return Card(
          margin: EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade100)),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => GoalDetailsScreen(goal: goal)),
              ).then((_) => _fetchGoals());
            },
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        config?.displayName ?? rawMetric,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.skeletonBlue,
                        ),
                      ),

                      if (goalStatus == "cancelled")
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "CANCELLED",
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),

                  SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        goalStatus == "active"
                            ? "Current: ${latest.toStringAsFixed(2)}${config?.unit ?? ''}"
                            : "Final: ${latest.toStringAsFixed(2)}${config?.unit ?? ''}",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text("Target: ${target.toStringAsFixed(2)}${config?.unit ?? ''}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),

                  SizedBox(height: 12),

                  LinearProgressIndicator(value: progress, color: _getGoalColor(progress, status), backgroundColor: Colors.grey.shade100),

                  SizedBox(height: 8),

                  Text("${(progress * 100).toInt()}% Completed", style: TextStyle(color: _getGoalColor(progress, status), fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddGoalSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => AddGoalBottomSheet(onGoalAdded: _fetchGoals, latestValues: _latestMetricValues),
    );
  }
}