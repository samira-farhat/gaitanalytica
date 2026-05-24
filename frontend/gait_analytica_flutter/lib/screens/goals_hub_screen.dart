import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';
import '../core/config/goal_config.dart';
import '../core/storage/token_storage.dart';
import '../core/theme/app_colors.dart';
import 'widgets/add_goal_bottom_sheet.dart';

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

  // helper to decide progress bar and text color based on goal status/percentage
  Color _getGoalColor(double progress, String status) {
    if (status == "Achieved") return Colors.green;
    if (progress < 0.3) return Colors.redAccent;
    if (progress < 0.7) return Colors.orangeAccent;
    return AppColors.skeletonBlue;
  }

  Future<void> _fetchGoals() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _goals = [];
    });

    try {
      final token = await TokenStorage.getAccessToken();
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/goals/?order=$_order"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> fetchedGoals = jsonDecode(response.body);

        final Map<String, dynamic> latestMap = {};
        for (var goal in fetchedGoals) {
          if (goal['latest_value'] != null) {
            latestMap[goal['metric_name']] = goal['latest_value'];
          }
        }

        setState(() {
          _goals = fetchedGoals;
          _latestMetricValues = latestMap;
        });
      }
    } catch (e) {
      debugPrint("Error fetching goals: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _getFilteredGoals(String status) {
    return _goals.where((g) {
      return g['status'].toString().trim().toLowerCase() == status.toLowerCase();
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pureWhite,
      appBar: AppBar(
        backgroundColor: AppColors.pureWhite,
        elevation: 0,
        title: const Text("Recovery Goals", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.onyxCharcoal)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.onyxCharcoal, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() => _order = _order == 'newest' ? 'oldest' : 'newest');
              _fetchGoals();
            },
            icon: Icon(Icons.sort, size: 16, color: AppColors.skeletonBlue),
            label: Text(
              _order.toUpperCase(),
              style: TextStyle(color: AppColors.skeletonBlue, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.skeletonBlue,
          indicatorColor: AppColors.skeletonBlue,
          unselectedLabelColor: Colors.grey,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Active"),
            Tab(text: "Achieved"),
            Tab(text: "Cancelled"),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.skeletonBlue))
          : TabBarView(
        controller: _tabController,
        children: [
          _buildGoalList("Active"),
          _buildGoalList("Achieved"),
          _buildGoalList("Cancelled"),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGoalSheet(),
        backgroundColor: AppColors.midnightNavy,
        child: const Icon(Icons.add, color: Colors.white),
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
            const SizedBox(height: 16),
            Text("No $status goals found.", style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final goal = filtered[index];
        final String rawMetric = goal['metric_name'].toString();
        final config = GoalConfigs.metrics[rawMetric];

        final String metricName = config?.displayName ?? rawMetric.replaceAll('_', ' ').toUpperCase();
        final String unit = config?.unit ?? "";

        final double target = double.tryParse(goal['target_value'].toString()) ?? 0.0;
        final double latest = double.tryParse(goal['latest_value']?.toString() ?? goal['starting_value']?.toString() ?? "0") ?? 0.0;
        final double start = double.tryParse(goal['starting_value']?.toString() ?? "0") ?? 0.0;

        bool higherIsBetter = config?.higherIsBetter ?? true;

        double progress = 0.0;
        if (higherIsBetter) {
          if (latest >= target) progress = 1.0;
          else if (latest <= start) progress = 0.0;
          else {
            final diff = target - start;
            progress = diff == 0 ? 0.0 : (latest - start) / diff;
          }
        } else {
          if (latest <= target) progress = 1.0;
          else if (latest >= start) progress = 0.0;
          else progress = (start - latest) / (start - target);
        }

        progress = progress.clamp(0.0, 1.0);
        int percentage = (progress * 100).toInt();
        Color statusColor = _getGoalColor(progress, status);

        return Card(
          margin: const EdgeInsets.only(bottom: 15),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade100),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              // TODO: Navigate to Goal Details
              debugPrint("Navigate to details for ${goal['id']}");
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(metricName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.skeletonBlue)),
                      Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Current: ${latest.toStringAsFixed(2)}$unit", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("Target: ${target.toStringAsFixed(2)}$unit", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.shade100,
                      color: statusColor,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text("$percentage% Completed", style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddGoalSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => AddGoalBottomSheet(
        onGoalAdded: _fetchGoals,
        latestValues: _latestMetricValues,
      ),
    );
  }
}