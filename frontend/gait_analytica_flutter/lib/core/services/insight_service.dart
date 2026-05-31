import 'dart:math';

class InsightService {
  static String getLatestInsight(List<dynamic> sessions) {

    if (sessions.isEmpty) {
      return "Welcome! Start your first analysis to begin monitoring your journey.";
    }

    bool isSessionComplete(dynamic s) {
      return s['cadence_bpm'] != null &&
          s['avg_rom'] != null &&
          s['knee_symmetry_diff'] != null &&
          s['stride_time_cv'] != null;
    }

    // only keep sessions that have all metrics present
    List<dynamic> completeSessions = sessions.where(isSessionComplete).toList();

    if (completeSessions.length < 2) {
      return "Keep recording! We need at least two complete sessions to analyze your progress.";
    }

    // 1. prepare Data
    final latest = sessions[0];
    final previous = sessions[1];

    double latCadence = _toDouble(latest['cadence_bpm']);
    double preCadence = _toDouble(previous['cadence_bpm']);
    double latRom = _toDouble(latest['avg_rom']);
    double preRom = _toDouble(previous['avg_rom']);
    double latSymm = _toDouble(latest['knee_symmetry_diff']);
    double preSymm = _toDouble(previous['knee_symmetry_diff']);
    double latCV = _toDouble(latest['stride_time_cv']);
    double preCV = _toDouble(previous['stride_time_cv']);

    if (latCadence == 0.0 || preCadence == 0.0) {
      return "Keep recording! We need more data to provide insights on your walking rhythm.";
    }

    // 2. build a list of possible "Smart" insights
    List<String> validInsights = [];

    // Knee Symmetry (lower is generally a tighter sync)
    if ((latSymm - preSymm).abs() > 1.5) {
      if (latSymm < preSymm) {
        validInsights.add("Your knee symmetry improved by ${(preSymm - latSymm).toStringAsFixed(1)}%. Your legs are moving more in sync today!");
      } else {
        validInsights.add("We noticed a ${(latSymm - preSymm).abs().toStringAsFixed(1)}% shift in knee symmetry. Consistency in posture can help stabilize this.");
      }
    }

    // Range of Motion (increase is usually the goal in rehab)
    if ((latRom - preRom).abs() > 3.0) {
      if (latRom > preRom) {
        validInsights.add("Great flexibility! Your knee Range of Motion (ROM) increased by ${(latRom - preRom).toStringAsFixed(1)}° since last time.");
      } else {
        validInsights.add("Your knee ROM was slightly more limited this session (${latRom.toStringAsFixed(1)}°). Make sure to warm up properly.");
      }
    }

    // Cadence / Rhythm
    if ((latCadence - preCadence).abs() > 4.0) {
      String feel = latCadence > preCadence ? "faster walking pace" : "slower walking pace";
      validInsights.add("You found a $feel today. Your cadence changed by ${(latCadence - preCadence).abs().toStringAsFixed(1)} BPM.");
    }

    // Stability (CV - lower is more stable)
    if ((latCV - preCV).abs() > 0.05) {
      if (latCV < preCV) {
        validInsights.add("Your gait was more stable today! We detected a decrease in stride variability.");
      }
    }

    // Habit & Milestone insights

    if (sessions.length % 5 == 0) {
      validInsights.add("Milestone reached! You've completed ${sessions.length} sessions. Every scan builds a better picture of your progress.");
    }

    DateTime latestDate = DateTime.parse(latest['session_date'] ?? latest['session']?['session_date'] ?? DateTime.now().toIso8601String());
    int daysSince = DateTime.now().difference(latestDate).inDays;
    if (daysSince > 3) {
      validInsights.add("Welcome back! It's been $daysSince days. Recording regularly helps keep your recovery data accurate.");
    }

    // Fallbacks (always valid) ---
    validInsights.addAll([
      "You've recorded ${sessions.length} sessions. Keep building that history to see long-term trends!",
      "Tip: Try to record your sessions in the same environment for the most consistent data tracking.",
      "Analysis complete. Your latest gait metrics have been added to your recovery log.",
      "Small steps lead to big progress. You're doing great by keeping track of your movement!",
      "Did you know? Consistent recording helps identify subtle changes in your walking pattern over time."
    ]);

    // 3. shuffle and return
    validInsights.shuffle();
    return validInsights.first;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}