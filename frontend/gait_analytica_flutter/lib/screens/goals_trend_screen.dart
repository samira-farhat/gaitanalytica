import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import '../core/config/api_config.dart';
import '../core/config/goal_config.dart';
import '../core/storage/token_storage.dart';
import '../core/theme/app_colors.dart';

class GoalTrendScreen extends StatefulWidget {
  final Map<String, dynamic> goal;

  const GoalTrendScreen({super.key, required this.goal});

  @override
  State<GoalTrendScreen> createState() => _GoalTrendScreenState();
}

class _GoalTrendScreenState extends State<GoalTrendScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _trendData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTrendData();
  }

  Future<void> _fetchTrendData() async {
    try {
      final token = await TokenStorage.getAccessToken();
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/goals/${widget.goal['id']}/trend/"),
        headers: {"Authorization": "Bearer $token"},
      );

      final body = jsonDecode(response.body);

      final status = widget.goal['status'] ?? "";
      final invalidReason = widget.goal['invalid_reason'] ?? "";

      if (status == "Cancelled" && invalidReason == "session_deleted") {
        setState(() {
          _errorMessage =
          "No trend is available.\nThis goal was invalidated because the session that achieved it was deleted.";
          _isLoading = false;
        });
        return;
      }

      if (status == "Cancelled") {
        setState(() {
          _errorMessage = "This goal was cancelled. No trend is available.";
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _trendData = body;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to load trend data.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawMetric = widget.goal['metric_name'].toString();
    final config = GoalConfigs.metrics[rawMetric];
    if (config == null) {
      return Scaffold(body: Center(child: Text("Error: Metric not configured.")));
    }
    final isPercentage = rawMetric == 'stride_time_cv';
    final goalStatus = widget.goal['status'] ?? "Active";

    double displayTarget = double.parse(widget.goal['target_value'].toString());
    if (isPercentage) displayTarget *= 100;

    return Scaffold(
      backgroundColor: AppColors.pureWhite,
      appBar: AppBar(
        backgroundColor: AppColors.pureWhite,
        elevation: 0,
        centerTitle: true,
        title: Text("Performance Trend",
            style: TextStyle(color: AppColors.onyxCharcoal, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.onyxCharcoal),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorState()
          : SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusBadge(goalStatus),

            SizedBox(height: 16),

            Text(config.displayName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),

            Text("Target: ${displayTarget.toStringAsFixed(isPercentage ? 0 : 1)}${config.unit}",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),

            SizedBox(height: 40),
            _buildGraph(config, isPercentage, displayTarget, goalStatus),

            SizedBox(height: 40),
            if (goalStatus == "Achieved")
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(
                  child: Text(
                    "Goal achieved! Progress is now frozen at final session.",
                    style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            if (goalStatus == "Cancelled")
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(
                  child: Text(
                    "Goal cancelled. Trend is frozen at last recorded session.",
                    style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            SizedBox(height: 20),
            _buildTrendSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor = Colors.blue;
    if (status == "Achieved") badgeColor = Colors.green;
    if (status == "Cancelled") badgeColor = Colors.grey;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: badgeColor),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }


  Widget _buildGraph(dynamic config, bool isPercentage, double targetValue, String goalStatus) {

    if (_trendData == null || _trendData!['data_points'] == null) {
      return const SizedBox.shrink();
    }

    List<dynamic> points = (_trendData?['data_points'] ?? []);

    List<FlSpot> spots = [];
    double maxY = targetValue;

    bool isFinalGoal =
        goalStatus == "Achieved" || goalStatus == "Cancelled";

    double startingValue = (_trendData?['start_value'] ?? 0).toDouble();

    if(isPercentage){
      startingValue *= 100;
    }

    if (startingValue > maxY){
      maxY= startingValue;
    }

    spots.add(FlSpot(0, startingValue));

    for (int i = 0; i < points.length; i++) {
      double val = double.tryParse(points[i]['value']?.toString() ?? '0') ?? 0.0;
      if (isPercentage) val *= 100;
      spots.add(FlSpot((i + 1).toDouble(), val));
      if (val > maxY) maxY = val;
    }

    maxY = maxY * 1.3;

    return Container(
      height: 350,
      padding: EdgeInsets.only(right: 20, top: 10),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.05),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              axisNameWidget: Text("Value (${config.unit})",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onyxCharcoal)),
              axisNameSize: 30,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: (maxY / 5) > 0 ? (maxY / 5) : 1,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(0),
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: Text("Training Sessions",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onyxCharcoal
                  )
              ),
              axisNameSize: 30,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: points.length > 5 ? (points.length / 3).floorToDouble() : 1,
                getTitlesWidget: (value, meta) {
                  final int index = value.toInt();

                  if (index == 0) {
                    return Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text("Start", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    );
                  }

                  if (index == points.length) {
                    return Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text("S$index", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    );
                  }

                  if (index > 0 && index < points.length && index % meta.appliedInterval == 0) {
                    return Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text("S$index", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: targetValue,
                color: Colors.redAccent,
                strokeWidth: 2,
                dashArray: [5, 5],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  labelResolver: (line) => 'TARGET',
                  style: TextStyle(fontSize: 9, color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.midnightNavy,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) {

                  if (index == 0) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: Colors.orange,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  }

                  if (index == spots.length - 1 && isFinalGoal) {
                    return FlDotCirclePainter(
                      radius: 5,
                      color: goalStatus == "Achieved" ? Colors.green : Colors.grey,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  }

                  return FlDotCirclePainter(
                    radius: 3,
                    color: AppColors.midnightNavy,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [AppColors.midnightNavy.withOpacity(0.3), AppColors.midnightNavy.withOpacity(0.0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildTrendSummary() {
    final trend = _trendData?['trend']?.toString() ?? "stable";
    Color trendColor = trend == "improving" ? Colors.green
        : (trend == "worsening" ? Colors.red : Colors.orange);
    IconData trendIcon;

    if (trend == "improving") {
      trendIcon = Icons.trending_up;
    } else if (trend == "worsening") {
      trendIcon = Icons.trending_down;
    } else {
      trendIcon = Icons.trending_flat;
    }


    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(
            trendIcon,
            color: trendColor,
            size: 40,
          ),

          SizedBox(height: 8),

          Text(
            "Your progress is ${trend.toUpperCase()}",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: trendColor),
          ),

          SizedBox(height: 8),

          Text(
            "Track your recovery milestones. Consistency across sessions is key to hitting your target goals.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          )
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insights, size: 80, color: Colors.grey.shade300),

            SizedBox(height: 20),

            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}