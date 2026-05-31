import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';
import '../core/config/goal_config.dart';
import '../core/storage/token_storage.dart';
import '../core/theme/app_colors.dart';
import 'goals_trend_screen.dart';

class GoalDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> goal;

  const GoalDetailsScreen({super.key, required this.goal});

  @override
  State<GoalDetailsScreen> createState() => _GoalDetailsScreenState();
}

class _GoalDetailsScreenState extends State<GoalDetailsScreen> {
  late Map<String, dynamic> _currentGoal;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentGoal = widget.goal;
    _checkTargetDateStatus();
  }

  Color _getGoalColor(double progress, String status) {
    if (status == "Achieved") return Colors.green;
    if (progress < 0.3) return Colors.redAccent;
    if (progress < 0.7) return Colors.orangeAccent;
    return Colors.teal;
  }

  String _formatToSql(DateTime date) =>
      "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  String _formatReadable(DateTime date) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  void _checkTargetDateStatus() {
    if (_currentGoal['end_date'] == null) return;
    if (_currentGoal['status'] == 'Active' && _currentGoal['end_date'] != null) {
      DateTime endDate = DateTime.parse(_currentGoal['end_date']);
      DateTime today = DateTime.now();
      // Alert if today is the target date or if it has passed
      if (endDate.year == today.year && endDate.month == today.month && endDate.day == today.day || endDate.isBefore(today)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showTargetDateReachedAlert());
      }
    }
  }

  Future<void> _updateGoal(double target, DateTime date) async {
    setState(() => _isLoading = true);
    try {
      final token = await TokenStorage.getAccessToken();
      final response = await http.patch(
        Uri.parse("${ApiConfig.baseUrl}/api/goals/${_currentGoal['id']}/update/"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json"
        },
        body: jsonEncode({
          "target_value": target,
          "end_date": _formatToSql(date),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _currentGoal = data['goal']);
      }
    } catch (e) {
      debugPrint("Update error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelGoal() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Goal?"),
        content: const Text("This will stop tracking this progress. You cannot undo this."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final token = await TokenStorage.getAccessToken();
      final response = await http.patch(
        Uri.parse("${ApiConfig.baseUrl}/api/goals/${_currentGoal['id']}/cancel/"),
        headers: {"Authorization": "Bearer $token"},
      );

      print(response.statusCode);
      print(response.body);

      if (response.statusCode == 200) {
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Cancel error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showTargetDateReachedAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Target Date Reached"),
        content: const Text("You haven't reached your goal yet. Would you like to extend the target date or cancel the goal?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Later")),
          TextButton(onPressed: () { Navigator.pop(context); _cancelGoal(); }, child: const Text("Cancel Goal", style: TextStyle(color: Colors.red))),
          ElevatedButton(onPressed: () { Navigator.pop(context); _showEditBottomSheet(); }, child: const Text("Extend Date")),
        ],
      ),
    );
  }

  void _showEditBottomSheet() {
    final rawMetric = _currentGoal['metric_name'].toString();
    final config = GoalConfigs.metrics[rawMetric];

    if (config == null) {
      return;
    }

    double initialValue = double.tryParse(_currentGoal['target_value'].toString()) ?? 0.0;
    if (rawMetric == "stride_time_cv" && initialValue <= 1.0) initialValue *= 100;

    final TextEditingController controller = TextEditingController(text: initialValue.toStringAsFixed(rawMetric == "stride_time_cv" ? 1 : 1));

    DateTime? selectedDate = _currentGoal['end_date'] != null
        ? DateTime.parse(_currentGoal['end_date'])
        : null;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Edit Goal Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),

              SizedBox(height: 20),

              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Target Value (${config.unit})",
                  errorText: errorText,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onChanged: (v) {
                  // Clear error as user types to be less annoying
                  if (errorText != null) setSheetState(() => errorText = null);
                },
              ),

              SizedBox(height: 20),

              ListTile(
                title: Text("Target Date"),
                subtitle: Text(
                  selectedDate == null
                      ? "Not set"
                      : _formatReadable(selectedDate!),
                ),
                trailing: Icon(Icons.calendar_today, color: AppColors.midnightNavy),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(Duration(days: 365)),
                  );
                  if (picked != null) setSheetState(() => selectedDate = picked);
                },
              ),

              SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final val = double.tryParse(controller.text);
                    if (val == null) {
                      setSheetState(() => errorText = "Enter a valid number");
                      return;
                    }

                    final bool isStride = rawMetric == 'stride_time_cv';
                    final bool isStep = rawMetric == 'avg_step_length_norm';

                    if (val < config.minSafe || val > config.maxSafe) {
                      String safeMin = config.minSafe.toStringAsFixed(isStep ? 2 : 1);
                      String safeMax = config.maxSafe.toStringAsFixed(1);

                      setSheetState(() => errorText = "Limit: $safeMin - $safeMax${config.unit}");
                      return;
                    }

                    double currentLatest = double.tryParse(_currentGoal['latest_value']?.toString() ?? _currentGoal['starting_value'].toString()) ?? 0.0;

                    if (isStride && currentLatest < 1.0) currentLatest *= 100;

                    if (config.higherIsBetter) {
                      if (val <= currentLatest) {
                        setSheetState(() => errorText = "Must be > current (${currentLatest.toStringAsFixed(isStep ? 2 : 1)})");
                        return;
                      }
                    } else {
                      if (val >= currentLatest) {
                        setSheetState(() => errorText = "Must be < current (${currentLatest.toStringAsFixed(isStep ? 2 : 1)})");
                        return;
                      }
                    }

                    Navigator.pop(context);

                    double finalValue = val;
                    if (isStride) finalValue = val / 100;

                    _updateGoal(finalValue, selectedDate ?? DateTime.now());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.midnightNavy,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text("SAVE CHANGES", style: TextStyle(color: Colors.white)),
                ),
              ),

              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _getAchievementMessage() {
    if (_currentGoal['status'] != 'Achieved') return "";

    DateTime? end = _currentGoal['end_date'] != null ? DateTime.parse(_currentGoal['end_date']) : null;
    DateTime today = DateTime.now();

    if (end != null) {
      if (today.isBefore(end)) {
        return "Incredible! You reached this goal earlier than planned. Your recovery is progressing faster than expected!";
      } else if (today.year == end.year && today.month == end.month && today.day == end.day) {
        return "Goal achieved right on time! Fantastic consistency in your recovery journey.";
      }
    }
    return "Goal achieved! Your hard work is paying off.";
  }

  String _getCancelledMessage() {
    return "This goal has been cancelled and is no longer being tracked.";
  }

  @override
  Widget build(BuildContext context) {
    final status = _currentGoal['status'];
    final rawMetric = _currentGoal['metric_name'].toString();
    final config = GoalConfigs.metrics[rawMetric];
    if (config == null) {
      return Scaffold(body: Center(child: Text("Error: Goal metric configuration not found.")));
    }

    double target = double.tryParse(_currentGoal['target_value'].toString()) ?? 0.0;
    String goalStatus = _currentGoal['status'].toString().trim().toLowerCase();

    double latest;
    if (goalStatus == "active") {
      latest = double.tryParse(_currentGoal['latest_value']?.toString() ?? _currentGoal['starting_value'].toString()) ?? 0.0;
    } else {
      latest = double.tryParse(_currentGoal['achieved_value']?.toString() ?? _currentGoal['latest_value']?.toString() ?? _currentGoal['starting_value'].toString()) ?? 0.0;
    }

    double starting = double.tryParse(
        _currentGoal['starting_value']?.toString() ?? "0"
    ) ?? 0.0;


    if (rawMetric == "stride_time_cv") {
      if (target < 1.0) target *= 100;
      if (latest < 1.0) latest *= 100;
      if (starting < 1.0) starting *= 100;
    }

    bool higherIsBetter = config.higherIsBetter;
    double progress = 0.0;
    if (target != 0.0) {
      progress = higherIsBetter ? (latest / target) : (target / latest);
    }
    progress = progress.clamp(0.0, 1.0);

    final Color progressColor = _getGoalColor(progress, status);

    final bool isStride = rawMetric == 'stride_time_cv';
    final bool isStep = rawMetric == 'avg_step_length_norm';

    final String targetDisp = isStride
        ? "${target.toStringAsFixed(1)}%"
        : "${target.toStringAsFixed(isStep ? 2 : 2)}${config.unit}";

    final String currentDisp = isStride
        ? "${latest.toStringAsFixed(1)}%"
        : "${latest.toStringAsFixed(isStep ? 2 : 2)}${config.unit}";

    final String startingDisp = isStride
        ? "${starting.toStringAsFixed(1)}%"
        : "${starting.toStringAsFixed(isStep ? 2 : 2)}${config.unit}";

    return Scaffold(
      backgroundColor: AppColors.pureWhite,
      appBar: AppBar(
        backgroundColor: AppColors.pureWhite,
        elevation: 0,
        title: Text(config.displayName, style: TextStyle(color: AppColors.onyxCharcoal, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: AppColors.onyxCharcoal), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading ? Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 160, width: 160,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 12,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),

                  Column(
                    children: [
                      Text("${(progress * 100).toStringAsFixed(progress < 1.0 && progress > 0.99 ? 1 : 0)}%", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.onyxCharcoal)),
                      Text(status.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: progressColor)),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 40),

            if (status == "Achieved")
              Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(15)),
                child: Text(_getAchievementMessage(), style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ),

            if (status == "Cancelled")
              Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  _getCancelledMessage(),
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0, color: Colors.grey.shade50,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildInfoRow("Current Value", currentDisp),
                    Divider(height: 30),

                    _buildInfoRow("Starting Value", startingDisp),
                    Divider(height: 30),

                    _buildInfoRow("Target Value", targetDisp),
                    Divider(height: 30),

                    _buildInfoRow("Target Date", _currentGoal['end_date'] != null
                        ? _formatReadable(DateTime.parse(_currentGoal['end_date']))
                        : "Not set"),
                  ],
                ),
              ),
            ),

            SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GoalTrendScreen(goal: _currentGoal),
                    ),
                  );
                },
                icon: Icon(Icons.show_chart),
                label: Text("VIEW PROGRESS TRENDS"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.midnightNavy, foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
            if (status == "Active") ...[

              SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: _showEditBottomSheet,
                          icon: Icon(Icons.edit),
                          label: Text("EDIT"),
                          style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15)
                              )
                          )
                      )
                  ),

                  SizedBox(width: 12),

                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: _cancelGoal,
                          icon: Icon(Icons.cancel),
                          label: Text("CANCEL"),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: BorderSide(color: Colors.red),
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                          )
                      )
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.onyxCharcoal)),
      ],
    );
  }
}