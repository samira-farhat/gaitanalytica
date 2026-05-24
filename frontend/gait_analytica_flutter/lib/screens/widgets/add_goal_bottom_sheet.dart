import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/config/api_config.dart';
import '../../core/config/goal_config.dart';
import '../../core/storage/token_storage.dart';
import '../../core/theme/app_colors.dart';

class AddGoalBottomSheet extends StatefulWidget {
  final VoidCallback onGoalAdded;
  final Map<String, dynamic> latestValues;

  const AddGoalBottomSheet({
    super.key,
    required this.onGoalAdded,
    required this.latestValues
  });

  @override
  State<AddGoalBottomSheet> createState() => _AddGoalBottomSheetState();
}

class _AddGoalBottomSheetState extends State<AddGoalBottomSheet> {
  String? _selectedMetricKey;
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  bool _isSubmitting = false;
  String _errorMessage = "";
  bool _alreadyHasGoal = false; // New flag for the specific warning

  @override
  void dispose() {
    _targetController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateController.text.isNotEmpty
          ? DateTime.parse(_dateController.text)
          : DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.midnightNavy),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateController.text = picked.toString().split(' ')[0]);
    }
  }

  Future<void> _submitGoal() async {
    if (_selectedMetricKey == null || _targetController.text.isEmpty) {
      setState(() => _errorMessage = "Please fill in all fields");
      return;
    }

    final config = GoalConfigs.metrics[_selectedMetricKey]!;
    final double? targetVal = double.tryParse(_targetController.text);

    if (targetVal == null) {
      setState(() => _errorMessage = "Enter a valid number");
      return;
    }

    if (targetVal < config.minSafe || targetVal > config.maxSafe) {
      setState(() => _errorMessage = "Limit: ${config.minSafe}-${config.maxSafe}");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = "";
      _alreadyHasGoal = false;
    });

    try {
      final token = await TokenStorage.getAccessToken();
      final Map<String, dynamic> requestBody = {
        "metric_name": _selectedMetricKey,
        "target_value": targetVal,
        "end_date": _dateController.text.trim().isEmpty ? null : _dateController.text.trim(),
      };

      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/api/goals/create/"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(requestBody),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Brand new goal created!
        widget.onGoalAdded();
        if (mounted) Navigator.pop(context);
      } else if (response.statusCode == 200 && responseData['message'] == "Goal already exists") {
        // Backend caught the duplicate constraint
        setState(() {
          _alreadyHasGoal = true;
          _isSubmitting = false;
        });
      } else {
        setState(() => _errorMessage = responseData['error'] ?? "Failed to create goal");
      }
    } catch (e) {
      setState(() => _errorMessage = "Connection error. Try again.");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {

    final latest = double.tryParse(
      widget.latestValues[_selectedMetricKey]?.toString() ?? "",
    );

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 25,
        left: 25,
        right: 25,
        top: 25,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Set New Recovery Goal",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // DUPLICATE GOAL WARNING BOX
          if (_alreadyHasGoal)
            Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "An active goal already exists for this metric. Complete or cancel it first.",
                      style: TextStyle(fontSize: 13, color: Colors.brown, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: "Select Metric", border: OutlineInputBorder()),
            items: GoalConfigs.metrics.entries.map((e) =>
                DropdownMenuItem(value: e.key, child: Text(e.value.displayName))
            ).toList(),
            onChanged: (val) => setState(() {
              _selectedMetricKey = val!;
              _errorMessage = "";
              _alreadyHasGoal = false;
              _targetController.clear();
            }),
          ),

          const SizedBox(height: 15),

          if (_selectedMetricKey != null) ...[

            // Info Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.skeletonBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [


                  Text(
                    "Latest Value: ${latest?.toStringAsFixed(2) ?? 'N/A'}${GoalConfigs.metrics[_selectedMetricKey]!.unit}",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Aim for ${GoalConfigs.metrics[_selectedMetricKey]!.higherIsBetter ? 'higher' : 'lower'} (Safe: ${GoalConfigs.metrics[_selectedMetricKey]!.minSafe}-${GoalConfigs.metrics[_selectedMetricKey]!.maxSafe}).",
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _targetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: "Target Value",
                suffixText: GoalConfigs.metrics[_selectedMetricKey]!.unit,
                errorText: _errorMessage.isEmpty ? null : _errorMessage,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _dateController,
              readOnly: true,
              onTap: _selectDate,
              decoration: const InputDecoration(
                labelText: "Target Date",
                suffixIcon: Icon(Icons.calendar_today, size: 18),
                border: OutlineInputBorder(),
              ),
            ),
          ],

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitGoal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.midnightNavy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: _isSubmitting
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("CREATE GOAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}