import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class NotificationService extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  int _unreadCount = 0;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;
  StreamSubscription? _subscription;

  int get unreadCount => _unreadCount;
  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;

  NotificationService() {
    _init();
  }

  void _init() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    fetchUnreadCount();
    _subscribeToNotifications();
  }

  Future<void> fetchUnreadCount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final res = await _supabase
          .from('notifications')
          .select('notification_id')
          .eq('user_id', user.id)
          .eq('is_read', false);
      
      _unreadCount = res.length;
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching unread count: $e");
    }
  }

  void _subscribeToNotifications() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _subscription = _supabase
        .from('notifications')
        .stream(primaryKey: ['notification_id'])
        .eq('user_id', user.id)
        .listen((data) {
          _notifications = List<Map<String, dynamic>>.from(data);
          _unreadCount = data.where((n) => n['is_read'] == false).length;
          notifyListeners();
        });
  }

  Future<void> markAsRead(int id) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('notification_id', id);
      fetchUnreadCount();
    } catch (e) {
      debugPrint("Error marking as read: $e");
    }
  }

  Future<void> markAllAsRead() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);
      fetchUnreadCount();
    } catch (e) {
      debugPrint("Error marking all as read: $e");
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
