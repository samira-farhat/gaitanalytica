import 'package:flutter/material.dart';

class GoalMetricConfig {
  final String displayName;
  final String unit;
  final bool higherIsBetter;
  final double minSafe;
  final double maxSafe;
  final IconData icon;

  GoalMetricConfig({
    required this.displayName,
    required this.unit,
    required this.higherIsBetter,
    required this.minSafe,
    required this.maxSafe,
    required this.icon,
  });
}

class GoalConfigs {
  static Map<String, GoalMetricConfig> metrics = {
    'avg_rom': GoalMetricConfig(
      displayName: "Knee Range of Motion",
      unit: "°",
      higherIsBetter: true,
      minSafe: 50.0,
      maxSafe: 140.0,
      icon: Icons.accessibility_new,
    ),
    'knee_symmetry_diff': GoalMetricConfig(
      displayName: "Knee Symmetry",
      unit: "°",
      higherIsBetter: false, // Lower difference is closer to perfect symmetry
      minSafe: 0.0,
      maxSafe: 15.0,
      icon: Icons.balance,
    ),
    'avg_step_length_norm': GoalMetricConfig(
      displayName: "Step Efficiency",
      unit: "ratio", // Normalized but usually represents distance ratio
      higherIsBetter: true,
      minSafe: 0.25,
      maxSafe: 0.9,
      icon: Icons.straighten,
    ),
    'cadence_bpm': GoalMetricConfig(
      displayName: "Walking Cadence",
      unit: "steps/min",
      higherIsBetter: true,
      minSafe: 70.0,
      maxSafe: 130.0,
      icon: Icons.speed,
    ),
    'stride_time_cv': GoalMetricConfig(
      displayName: "Stride Consistency",
      unit: "%",
      higherIsBetter: false, // Lower variability means more consistent gait
      minSafe: 1.0,
      maxSafe: 15.0,
      icon: Icons.reorder,
    ),
  };
}