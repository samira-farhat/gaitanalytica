import 'package:flutter/material.dart';
import 'package:gait_analytica_flutter/screens/session_details_screen.dart';
import '../core/models/gait_session_model.dart';
import '../core/services/api_service.dart';
import '../core/theme/app_colors.dart';

class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  bool isDescending = true;
  List<GaitSession>? _sessions;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSessions();
  }

  Future<void> _fetchSessions() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final data = await ApiService.getSessions(isDescending ? 'newest' : 'oldest');
      if (!mounted) return;
      setState(() {
        _sessions = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint("Error fetching sessions: $e");
      setState(() => _isLoading = false);
    }
  }

  void _toggleSort() {
    setState(() => isDescending = !isDescending);
    _fetchSessions();
  }

  // Manual Date Formatter (No intl package)
  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return "${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}";
  }

  String _formatTime(DateTime date) {
    int hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    String period = date.hour >= 12 ? "PM" : "AM";
    String minute = date.minute.toString().padLeft(2, '0');
    return "$hour:$minute $period";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pureWhite,
      appBar: AppBar(
        backgroundColor: AppColors.pureWhite,
        elevation: 0,
        title: Text(
          "Session History",
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.onyxCharcoal),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.onyxCharcoal, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: _toggleSort,
            icon: Icon(Icons.sort, size: 16, color: AppColors.skeletonBlue),
            label: Text(
              isDescending ? "NEWEST" : "OLDEST",
              style: TextStyle(color: AppColors.skeletonBlue, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.skeletonBlue))
          : (_sessions == null || _sessions!.isEmpty)
          ? _buildEmptyState()
          : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: _sessions!.length,
        itemBuilder: (context, index) {
          return _buildSessionCard(_sessions![index]);
        },
      ),
    );
  }

  Widget _buildSessionCard(GaitSession session) {
    final DateTime localDate = session.date.toLocal();

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.skeletonBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(Icons.directions_walk, color: AppColors.skeletonBlue),
        ),
        title: Text(
          _formatDate(localDate),
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.onyxCharcoal, fontSize: 16),
        ),
        subtitle: Text(
          "Recorded at ${_formatTime(localDate)}",
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SessionDetailsScreen(sessionId: session.id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("No sessions recorded yet.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}