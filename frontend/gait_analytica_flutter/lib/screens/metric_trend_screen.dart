import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import '../core/config/api_config.dart';
import '../core/config/goal_config.dart';
import '../core/storage/token_storage.dart';
import '../core/theme/app_colors.dart';
import 'session_details_screen.dart';

class MetricTrendScreen extends StatefulWidget {
  final String metricKey;
  final int? sessionId;

  const MetricTrendScreen({
    super.key,
    required this.metricKey,
    this.sessionId,
  });

  @override
  State<MetricTrendScreen> createState() => _MetricTrendScreenState();
}

class _MetricTrendScreenState extends State<MetricTrendScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _trendData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMetricTrend();
  }

  Future<void> _fetchMetricTrend() async {
    try {
      final token = await TokenStorage.getAccessToken();
      final urlSuffix = widget.sessionId != null ? "?session_id=${widget.sessionId}" : "";
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/metrics/trend/${widget.metricKey}$urlSuffix"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _trendData = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        final body = jsonDecode(response.body);
        setState(() {
          _errorMessage = body['error'] ?? "Failed to load trend milestones.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Network error. Failed to communicate with backend analytics.";
        _isLoading = false;
      });
    }
  }

  String _getInsightText(String trend, String displayName) {
    if (trend == "improving") {
      return "Your $displayName has steadily optimized over training sessions. Continue maintaining form to solidify this physiological adaptation.";
    } else if (trend == "worsening") {
      return "A slight performance regression has been detected in $displayName. Focus on movement stability or slow down pacing to recover optimal kinematics.";
    } else {
      return "Your $displayName is currently stable. Consistency across testing sessions is a strong foundation for clinical baseline tracking.";
    }
  }

  Color _getTrendColor(String trend) {
    if (trend == "improving") return Colors.green;
    if (trend == "worsening") return Colors.red;
    return Colors.orange;
  }

  IconData _getTrendIcon(String trend) {
    if (trend == "improving") return Icons.trending_up;
    if (trend == "worsening") return Icons.trending_down;
    return Icons.trending_flat;
  }

  // Helper method returning exact text parameter profiles matching the session overview cards
  String _getMetricDefinition(String key) {
    switch (key) {
      case 'avg_rom':
        return "Measures the flexibility and movement range of your knee during steps.";
      case 'knee_symmetry_diff':
        return "Compares the movement between left and right legs. Lower is better.";
      case 'cadence_bpm':
        return "Your steps per minute. Indicates your overall walking rhythm.";
      case 'stride_time_cv':
        return "How stable your walking pattern is. Higher percentages indicate instability.";
      case 'avg_step_length_norm':
        return "Your normalized step distance relative to your height.";
      default:
        return "Parameter history tracking details over time.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = GoalConfigs.metrics[widget.metricKey];
    if (config == null) {
      return Scaffold(body: Center(child: Text("Error: Metric profile configuration missing.")));
    }

    final isPercentage = widget.metricKey == 'stride_time_cv';

    return Scaffold(
      backgroundColor: AppColors.pureWhite,
      appBar: AppBar(
        backgroundColor: AppColors.pureWhite,
        elevation: 0,
        centerTitle: true,
        title: Text("Metric Timeline", // Updated Title text
            style: TextStyle(color: AppColors.onyxCharcoal, fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.onyxCharcoal, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.skeletonBlue))
          : _errorMessage != null
          ? _buildErrorState()
          : _buildContent(config, isPercentage),
    );
  }

  Widget _buildContent(dynamic config, bool isPercentage) {
    final trend = _trendData?['trend']?.toString() ?? "stable";
    final currentRaw = double.tryParse(_trendData?['current_value']?.toString() ?? '0') ?? 0.0;
    final changeRaw = double.tryParse(_trendData?['change']?.toString() ?? '0') ?? 0.0;

    final displayCurrent = isPercentage ? currentRaw * 100 : currentRaw;
    final displayChange = isPercentage ? changeRaw * 100 : changeRaw;

    final trendColor = _getTrendColor(trend);
    final signText = displayChange >= 0 ? "+" : "";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Context Header Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.displayName,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.midnightNavy),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getMetricDefinition(widget.metricKey), // Updated Subtitle definition display logic
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(trend.toUpperCase(), trendColor),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                displayCurrent.toStringAsFixed(widget.metricKey == 'avg_step_length_norm' ? 2 : 1),
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.onyxCharcoal),
              ),
              const SizedBox(width: 4),
              Text(
                config.unit,
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 16),
              Text(
                "$signText${displayChange.toStringAsFixed(widget.metricKey == 'avg_step_length_norm' ? 2 : 1)} from baseline",
                style: TextStyle(color: trendColor, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Centerpiece Trend Graph Section
          _buildGraph(isPercentage),
          const SizedBox(height: 32),

          // Insight Card Section
          _buildInsightCard(trend, config.displayName, trendColor),
          const SizedBox(height: 32),

          Text(
            "Historical Breakdown",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onyxCharcoal),
          ),
          const SizedBox(height: 12),

          // Historical Sessions Breakdown List
          _buildHistoricalList(isPercentage, config.unit),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildGraph(bool isPercentage) {
    List<dynamic> points = _trendData?['data_points'] ?? [];
    if (points.isEmpty) return const SizedBox.shrink();

    List<FlSpot> spots = [];
    double maxY = 0.0;

    for (int i = 0; i < points.length; i++) {
      double val = double.tryParse(points[i]['value']?.toString() ?? '0') ?? 0.0;
      if (isPercentage) val *= 100;
      spots.add(FlSpot(i.toDouble(), val));
      if (val > maxY) maxY = val;
    }

    maxY = maxY == 0 ? 10.0 : maxY * 1.35;

    return Container(
      height: 260,
      padding: const EdgeInsets.only(right: 16, top: 12),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.06),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: (maxY / 4) > 0 ? (maxY / 4) : 1,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(0),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false), // Kept x-axis completely empty
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.2,
              color: AppColors.midnightNavy,
              barWidth: 3.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) {
                  bool isLast = (index == spots.length - 1);
                  return FlDotCirclePainter(
                    radius: isLast ? 6 : 3,
                    color: isLast ? AppColors.skeletonBlue : AppColors.midnightNavy,
                    strokeWidth: isLast ? 2 : 0,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [AppColors.midnightNavy.withOpacity(0.18), AppColors.midnightNavy.withOpacity(0.0)],
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

  Widget _buildInsightCard(String trend, String displayName, Color trendColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_getTrendIcon(trend), color: trendColor, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Analysis Insight",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.midnightNavy),
                ),
                const SizedBox(height: 4),
                Text(
                  _getInsightText(trend, displayName),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricalList(bool isPercentage, String unit) {
    List<dynamic> points = List.from(_trendData?['data_points'] ?? []);

    // Created a reversed list of map entries that contains both the item object and its sequential chronological index
    List<Map<String, dynamic>> indexedPoints = [];
    for (int i = 0; i < points.length; i++) {
      indexedPoints.add({
        'data': points[i],
        'displayNumber': i + 1, // User session numbering starts clean from #1, #2...
      });
    }
    List<Map<String, dynamic>> reversedIndexedPoints = indexedPoints.reversed.toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reversedIndexedPoints.length,
      itemBuilder: (context, index) {
        final item = reversedIndexedPoints[index];
        final node = item['data'];
        final int userSessionNum = item['displayNumber']; // Sequential order layout label
        final int sessionId = node['session_id']; // Main database identifier key kept safe for API requests

        final double rawVal = double.tryParse(node['value']?.toString() ?? '0') ?? 0.0;
        final displayVal = isPercentage ? rawVal * 100 : rawVal;

        String dateStr = node['date']?.toString() ?? "";
        if (dateStr.length > 10) dateStr = dateStr.substring(0, 10);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.directions_walk, color: AppColors.midnightNavy, size: 20),
            ),
            title: Text("Session #$userSessionNum", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(dateStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${displayVal.toStringAsFixed(widget.metricKey == 'avg_step_length_norm' ? 2 : 1)} $unit",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.onyxCharcoal, fontSize: 14),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SessionDetailsScreen(sessionId: sessionId),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline_rounded, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}