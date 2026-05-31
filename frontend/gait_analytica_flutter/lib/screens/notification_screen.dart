import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';
import '../core/storage/token_storage.dart';
import '../core/theme/app_colors.dart';
import 'session_details_screen.dart';
import 'goal_details_screen.dart';
import 'goals_hub_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final token = await TokenStorage.getAccessToken();
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/notifications/"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        setState(() => _notifications = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final token = await TokenStorage.getAccessToken();
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/api/notifications/mark-all-read/"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        _fetchNotifications();
      }
    } catch (e) {
      debugPrint("Error marking all read: $e");
    }
  }

  Future<void> _markSingleAsRead(int id) async {
    final token = await TokenStorage.getAccessToken();
    await http.post(
      Uri.parse("${ApiConfig.baseUrl}/api/notifications/$id/mark-read/"),
      headers: {"Authorization": "Bearer $token"},
    );
  }

  void _handleTap(Map<String, dynamic> notification) async {
    if (!notification['is_read']) {
      await _markSingleAsRead(notification['id']);
    }

    final String target = notification['target_screen'] ?? '';
    final String? targetId = notification['target_id']?.toString();

    if (!mounted) return;

    if (target == 'SessionDetail' && targetId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SessionDetailsScreen(sessionId: int.parse(targetId))),
      );
    }
    else if (target == 'GoalDetail' && targetId != null) {
      setState(() => _isLoading = true);
      try {
        final token = await TokenStorage.getAccessToken();
        final response = await http.get(
          Uri.parse("${ApiConfig.baseUrl}/api/goals/$targetId/"),
          headers: {"Authorization": "Bearer $token"},
        );

        if (response.statusCode == 200) {
          final goalData = jsonDecode(response.body);
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => GoalDetailsScreen(goal: goalData)),
          ).then((_) => _fetchNotifications());
        }
      } catch (e) {
        debugPrint("Error fetching goal for navigation: $e");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
    else if (target == 'GoalsPage') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const GoalsHubScreen()),
      );
    } else if (target == 'ScanInstructions') {
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      _fetchNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasUnread = _notifications.any((n) => n['is_read'] == false);

    return Scaffold(
      backgroundColor: AppColors.pureWhite,
      appBar: AppBar(
        backgroundColor: AppColors.pureWhite,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.onyxCharcoal, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Notifications", style: TextStyle(color: AppColors.onyxCharcoal, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.skeletonBlue))
          : _notifications.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 100),
        itemCount: _notifications.length,
        separatorBuilder: (context, index) => SizedBox(height: 12),
        itemBuilder: (context, index) {
          final n = _notifications[index];
          bool isRead = n['is_read'];

          return InkWell(
            onTap: () => _handleTap(n),
            borderRadius: BorderRadius.circular(15),
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isRead ? AppColors.pureWhite : AppColors.skeletonBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isRead ? Colors.grey.shade100 : AppColors.skeletonBlue.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIcon(n['notification_type'], isRead),
                  SizedBox(width: 15),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n['title'],
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.onyxCharcoal,
                          ),
                        ),

                        SizedBox(height: 4),

                        Text(
                          n['message'],
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: AppColors.midnightNavy, shape: BoxShape.circle),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: (_notifications.isNotEmpty && hasUnread)
          ? FloatingActionButton.extended(
        onPressed: _markAllAsRead,
        backgroundColor: AppColors.midnightNavy,
        elevation: 1,
        extendedIconLabelSpacing: 8,
        extendedPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        label: Text("MARK ALL AS READ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 12)),
        icon: Icon(Icons.done_all, color: Colors.white),
      )
          : null,
    );
  }

  Widget _buildIcon(String type, bool isRead) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case 'goal':
        iconData = Icons.flag_rounded;
        iconColor = isRead ? Colors.grey : Colors.orange;
        break;
      case 'session':
        iconData = Icons.directions_walk_rounded;
        iconColor = isRead ? Colors.grey : AppColors.skeletonBlue;
        break;
      case 'achievement':
        iconData = Icons.emoji_events_rounded;
        iconColor = isRead ? Colors.grey : Colors.amber;
        break;
      default:
        iconData = Icons.notifications_active_rounded;
        iconColor = isRead ? Colors.grey : AppColors.midnightNavy;
    }

    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isRead ? Colors.grey.shade100 : iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(iconData, color: iconColor, size: 22),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade200),

          SizedBox(height: 16),

          Text("All caught up!", style: TextStyle(color: AppColors.terrainGrey, fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}