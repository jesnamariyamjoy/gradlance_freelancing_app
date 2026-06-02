import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:user/notifications_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:user/user_profile_page.dart';
import 'package:user/submission_list_page.dart';
import 'package:user/user_available_works_page.dart';
import 'package:user/screens/user_chat_list_page.dart';
import 'package:user/services/notification_service.dart';
import 'package:user/subscription_page.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _selectedIndex = 0;
  final supabase = Supabase.instance.client;

  // 🔹 User Data State
  String studentName = "Loading...";
  String? profileImageUrl;
  bool isLoadingData = true;
  List<dynamic> recentApplications = [];
  bool isPremium = false;
  Map<String, dynamic>? activeSub;

  // 🔹 Stats State
  int activeCount = 0;
  int completedCount = 0;
  double totalEarnings = 0;
  double userRating = 0;

  // 🎨 BRAND COLORS
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchStats();
    _fetchRecentApplications();
  }

  // 🔹 FETCH USER DATA FROM SUPABASE
 Future<void> _fetchUserData() async {
  try {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final data = await supabase
        .from('tbl_user')
        .select('user_name, user_photo, rating')
        .eq('id', user.id)
        .single();

    if (mounted) {
      setState(() {
        studentName = data['user_name'] ?? "User";
        profileImageUrl = data['user_photo'];
        userRating = (data['rating'] as num?)?.toDouble() ?? 0;
        isLoadingData = false;
      });
    }

      // Fetch active subscription
      final subRes = await supabase
          .from('tbl_subscription')
          .select('*, tbl_subscription_plan(*)')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .maybeSingle();

      if (mounted) {
        setState(() {
          activeSub = subRes;
          isPremium = subRes != null;
        });
      }
    } catch (e) {
      debugPrint("Error fetching user: $e");
      if (mounted) {
        setState(() {
          studentName = "Guest";
          isLoadingData = false;
        });
      }
    }
  }

  // 🔹 FETCH STATS
  Future<void> _fetchStats() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await supabase
          .from('tbl_application')
          .select('application_status, bid_amount')
          .eq('user_id', user.id);

      int active = 0;
      int completed = 0;
      double earnings = 0;

      for (var app in response) {
        final status = app['application_status']?.toString().toLowerCase();
        if (status == 'accepted' ||
            status == 'verified' ||
            status == 'submitted') {
          active++;
        } else if (status == 'completed' || status == 'paid') {
          completed++;
          earnings += (app['bid_amount'] ?? 0).toDouble();
        }
      }

      if (mounted) {
        setState(() {
          activeCount = active;
          completedCount = completed;
          totalEarnings = earnings;
        });
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    }
  }

  // 🔹 FETCH RECENT APPLICATIONS
  Future<void> _fetchRecentApplications() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await supabase
          .from('tbl_application')
          .select('''
            application_id,
            application_status,
            created_at,
            tbl_work (
              work_title,
              work_lastdate
            )
          ''')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          recentApplications = response as List<dynamic>;
        });
      }
    } catch (e) {
      debugPrint("Error fetching applications: $e");
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F14) : brandGrey,
    appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF102030) : Colors.white,
        leading: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Image.asset('assets/gradlance.png'),
        ),
        title: Text(
          "Gradlance",
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : brandNavy,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          // 1. Notification Icon (with Badge logic)
          _buildNotificationIcon(),

          // 2. Refresh Icon
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: isDark ? Colors.white : brandNavy),
            onPressed: () async {
              // This triggers the same logic as the pull-to-refresh
              await Future.wait([
                _fetchUserData(),
                _fetchStats(),
                _fetchRecentApplications(),
              ]);
            },
          ),
          
          const SizedBox(width: 8), // Padding at the end
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeContent(),
          const UserAvailableWorksPage(),
          const ChatListPage(isClientApp: false), // Messages Page
          const ProfileScreen(), // Ensure this class exists in myprofile.dart
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHomeContent() {
    return RefreshIndicator(
      color: brandTeal,
      backgroundColor: Colors.white,
      onRefresh: () async {
        // Trigger all fetch functions simultaneously
        await Future.wait([
          _fetchUserData(),
          _fetchStats(),
          _fetchRecentApplications(),
        ]);
      },
      child: SingleChildScrollView(
        // IMPORTANT: Always set physics to AlwaysScrollableScrollPhysics 
        // so the refresh works even if the content is short.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 👋 GREETING & PROFILE IMAGE
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Hello, $studentName 👋",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : brandNavy,
                      ),
                    ),
                    Text(
                      "Ready for your next project?",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _onItemTapped(3),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: brandNavy.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 25,
                      backgroundColor: brandNavy,
                      backgroundImage: profileImageUrl != null
                          ? NetworkImage(profileImageUrl!)
                          : null,
                      child: profileImageUrl == null
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            if (!isPremium) _buildUpgradeBanner(),

            // 📊 STATS GRID
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.4,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const SubmissionListPage(initialFilter: 'upcoming'),
                      ),
                    );
                  },
                  child: _statCard(
                    "Active Tasks",
                    activeCount.toString(),
                    Icons.timer_outlined,
                    Colors.orange,
                  ),
                ),
                _statCard(
                  "Earnings",
                  "₹${totalEarnings.toInt()}",
                  Icons.account_balance_wallet_outlined,
                  Colors.green,
                ),
                _statCard(
                  "Completed",
                  completedCount.toString(),
                  Icons.task_alt_rounded,
                  brandTeal,
                ),
                _statCard(
                  "Rating",
                  userRating > 0 ? userRating.toStringAsFixed(1) : "None",
                  Icons.star_border_rounded,
                  Colors.amber,
                ),
              ],
            ),

            const SizedBox(height: 30),

            // ⚡ QUICK ACTIONS
            Text(
              "Quick Actions",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: brandNavy,
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                _actionCard(
                  title: "Find Projects",
                  icon: Icons.search_rounded,
                  color: brandNavy,
                  onTap: () => _onItemTapped(1),
                ),
                const SizedBox(width: 15),
                _actionCard(
                  title: "Applied Works",
                  icon: Icons.assignment_turned_in_outlined,
                  color: brandTeal,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const SubmissionListPage(initialFilter: 'all'),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 30),

            // 🕒 RECENT PROJECTS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Applied Projects",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : brandNavy,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const SubmissionListPage(initialFilter: 'all'),
                      ),
                    );
                  },
                  child: const Text(
                    "See All",
                    style: TextStyle(color: brandTeal),
                  ),
                ),
              ],
            ),
            if (recentApplications.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    "No applied projects yet",
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                ),
              )
            else
              ...recentApplications.map((app) {
                final work = app['tbl_work'];
                final status = app['application_status'] ?? 'pending';
                Color statusColor = Colors.orange;
                if (status == 'accepted' || status == 'verified')
                  statusColor = brandTeal;
                if (status == 'rejected') statusColor = Colors.red;

                return _projectTile(
                  work['work_title'] ?? 'Untitled',
                  status.toUpperCase(),
                  statusColor,
                  "Applied: ${DateFormat('MMM dd').format(DateTime.parse(app['created_at']))}",
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  // -------------------- UI COMPONENTS --------------------

  Widget _buildNotificationIcon() {
    return Consumer<NotificationService>(
      builder: (context, notificationService, child) {
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.notifications_none_rounded,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : brandNavy,
                  size: 28,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                ),
              ),
              if (notificationService.unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: brandTeal,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Center(
                      child: Text(
                        notificationService.unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: brandNavy.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF102030) : Colors.white,
        selectedItemColor: brandTeal,
        unselectedItemColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : brandNavy).withOpacity(0.4),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline_rounded),
            label: 'Projects',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF102030) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (isDark ? Colors.white : brandNavy).withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : brandNavy,
                ),
              ),
              Text(
                title,
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _projectTile(
    String title,
    String status,
    Color statusColor,
    String deadline,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF102030) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (isDark ? Colors.white : brandNavy).withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: brandGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.description_outlined,
              color: brandNavy.withOpacity(0.7),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : brandNavy,
                  ),
                ),
                Text(
                  deadline,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [brandNavy, Color(0xFF1B2E44)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: brandNavy.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: brandTeal.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.crown, color: brandTeal, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Go Premium",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "Apply to 10+ projects daily and unlock pro badges.",
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionPage()),
            ),
            style: TextButton.styleFrom(
              backgroundColor: brandTeal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              "Join Now",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
