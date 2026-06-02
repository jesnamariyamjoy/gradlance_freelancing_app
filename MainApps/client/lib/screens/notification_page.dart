import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List notifications = [];

  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final data = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      setState(() {
        notifications = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _markAsRead(int id) async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('notification_id', id);
      _fetchNotifications();
    } catch (e) {
      debugPrint("Error marks as read: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brandGrey,
      appBar: AppBar(
        title: Text("Notifications", style: GoogleFonts.poppins(color: brandNavy, fontWeight: FontWeight.bold)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: brandTeal))
          : notifications.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                    final isRead = item['is_read'] ?? false;
                    
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      color: isRead ? Colors.white : brandTeal.withOpacity(0.05),
                      child: ListTile(
                        onTap: () => _markAsRead(item['notification_id']),
                        leading: CircleAvatar(
                          backgroundColor: isRead ? brandGrey : brandTeal,
                          child: Icon(
                            isRead ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                            color: isRead ? brandNavy : Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          item['message'] ?? 'New notification',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                            color: brandNavy,
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('dd MMM, hh:mm a').format(DateTime.parse(item['created_at'])),
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                        ),
                        trailing: !isRead 
                          ? Container(width: 8, height: 8, decoration: const BoxDecoration(color: brandTeal, shape: BoxShape.circle))
                          : null,
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
          Icon(Icons.notifications_off_rounded, size: 64, color: brandNavy.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text("No notifications yet", style: GoogleFonts.poppins(color: Colors.grey)),
        ],
      ),
    );
  }
}
