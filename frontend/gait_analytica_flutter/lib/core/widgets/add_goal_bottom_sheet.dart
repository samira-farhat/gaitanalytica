import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../config/goal_config.dart';
import '../storage/token_storage.dart';
import '../theme/app_colors.dart';

class AddGoalBottomSheet extends StatefulWidget {
  final VoidCallback onGoalAdded;
  final Map<String, dynamic> latestValues;

  const AddGoalBottomSheet({super.key, required this.onGoalAdded, required this.latestValues});

  @override
  State<AddGoalBottomSheet> createState() => _AddGoalBottomSheetState();
}

class _AddGoalBottomSheetState extends State<AddGoalBottomSheet> {

  String? _selectedMetricKey;
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  bool _isSubmitting = false;
  String _targetError = "";
  String _dateError = "";
  String _formError = "";
  bool _alreadyHasGoal = false;

  @override
  void dispose() {
    _targetController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime now = DateTime.now();

    DateTime? picked = await showDatePicker(
      context: context,

      // always start from today OR selected valid value
      initialDate: now,

      firstDate: now, // HARD BLOCK past dates (u cant click on them)

      // allow up to 1 year
      lastDate: now.add(const Duration(days: 365)),

      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.midnightNavy,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _dateController.text = picked.toIso8601String().split('T')[0];
        _dateError = "";
        _formError = "";
        _targetError = "";
      });
    }
  }

  Future<void> _submitGoal() async {
    if (_selectedMetricKey == null) {
      setState(() {
        _formError = "Please select a metric";
        _targetError = "";
        _dateError = "";
      });
      return;
    }

    if (_targetController.text.isEmpty) {
      setState(() {
        _targetError = "Please enter a target value";
      });
      return;
    }

    final config = GoalConfigs.metrics[_selectedMetricKey]!;
    final double? targetVal = double.tryParse(_targetController.text);

    if (targetVal == null) {
      setState(() => _targetError = "Enter a valid number");
      return;
    }

    if (targetVal < config.minSafe || targetVal > config.maxSafe) {
      setState(() => _targetError = "Limit: ${config.minSafe}-${config.maxSafe}");
      return;
    }

    double? latest = double.tryParse(widget.latestValues[_selectedMetricKey]?.toString() ?? "");

    if (_selectedMetricKey == "stride_time_cv" && latest != null && latest < 1.0) {
      latest *= 100;
    }

    if (latest != null && latest > 0) {
      // Use ! to tell Dart latest is definitely not null here
      String latestString = latest.toStringAsFixed(_selectedMetricKey == 'avg_step_length_norm' ? 2 : 1);

      if (config.higherIsBetter) {
        if (targetVal <= latest) {
          setState(() => _targetError = "Target must be > current ($latestString)");
          return;
        }
      } else {
        if (targetVal >= latest) {
          setState(() => _targetError = "Target must be < current ($latestString)");
          return;
        }
      }
    }

    if (_dateController.text.isNotEmpty) {
      final selectedDate = DateTime.parse(_dateController.text);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final pickedDay = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );

      if (pickedDay.isBefore(today)) {
        _dateController.clear();
        setState(() {
          _dateError = "Target date cannot be in the past";
        });
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _targetError = "";
      _dateError = "";
      _alreadyHasGoal = false;
    });

    try {
      final token = await TokenStorage.getAccessToken();

      double finalValue = targetVal;
      if (_selectedMetricKey == "stride_time_cv") {
        finalValue = targetVal / 100;
      }

      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/api/goals/create/"),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: jsonEncode({
          "metric_name": _selectedMetricKey,
          "target_value": finalValue,
          "end_date": _dateController.text.isEmpty ? null : _dateController.text,
        }),
      );

      final data = jsonDecode(response.body);

      // alert check for duplicate goals
      if (response.statusCode == 201 || response.statusCode == 200) {
        if (data['message'] == "Goal already exists" || data['error'] == "Goal already exists") {
          setState(() {
            _alreadyHasGoal = true;
            _isSubmitting = false;
          });
        } else {
          widget.onGoalAdded();
          if (mounted) Navigator.pop(context);
        }
      } else {
        setState(() {
          _formError = data['error'] ?? "Error creating goal";
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _formError = "Connection error";
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String key = _selectedMetricKey ?? "";
    final config = GoalConfigs.metrics[key];

    double? latest = double.tryParse(widget.latestValues[key]?.toString() ?? "");
    if (key == "stride_time_cv" && latest != null && latest < 1.0) {
      latest *= 100;
    }

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 25, left: 25, right: 25, top: 25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text("Set New Recovery Goal",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold
              )
          ),

          SizedBox(height: 20),

          if (_alreadyHasGoal)
            Container(
              margin: EdgeInsets.only(bottom: 15),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber),

                  SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      "An active goal already exists for this metric. Complete or cancel it first.",
                      style: TextStyle(fontSize: 13, color: Colors.brown, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: "Select Metric", border: OutlineInputBorder()),
            items: GoalConfigs.metrics.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.displayName))).toList(),
            onChanged: (val) => setState(() {
              _selectedMetricKey = val;
              _alreadyHasGoal = false;
              _targetError = "";
              _dateError = "";
              _formError = "";
              _targetController.clear();
            }),
          ),

          if (_selectedMetricKey != null) ...[

            SizedBox(height: 15),

            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.skeletonBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: Text(
                config != null
                    ? "Latest Value: ${latest?.toStringAsFixed(1) ?? 'N/A'}${config.unit}\nAim for ${config.higherIsBetter ? 'higher' : 'lower'} (Safe: ${config.minSafe}-${config.maxSafe}${config.unit})"
                    : "Select a metric to see details.",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),

            SizedBox(height: 15),

            TextField(
              controller: _targetController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: "Target Value",
                suffixText: config?.unit,
                border: OutlineInputBorder(),
                errorText: _targetError.isEmpty ? null : _targetError,
              ),
              onChanged: (_) {
                if (_targetError.isNotEmpty || _formError.isNotEmpty) {
                  setState(() {
                    _targetError = "";
                    _formError = "";
                  });
                }
              },
            ),

            SizedBox(height: 15),

            TextField(
              controller: _dateController,
              readOnly: true,
              onTap: _selectedMetricKey == null ? null : _selectDate,
              decoration: InputDecoration(
                labelText: "Target Date",
                suffixIcon: Icon(Icons.calendar_today, size: 18),
                border: OutlineInputBorder(),
                errorText: _dateError.isEmpty ? null : _dateError,
              ),
            ),
          ],

          SizedBox(height: 20),

          if (_formError.isNotEmpty) ...[
            SizedBox(height: 10),

            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                border: Border.all(color: Colors.red.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 18),

                  SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      _formError,
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitGoal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.midnightNavy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: _isSubmitting
                  ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text("CREATE GOAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}