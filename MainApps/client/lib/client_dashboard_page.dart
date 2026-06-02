import 'package:client/add_work_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:client/application_list_page.dart';
import 'package:client/screens/chat_list_page.dart';
import 'package:client/work_list_page.dart';
import 'screens/notification_page.dart';
import 'client_profile_page.dart';
import 'package:provider/provider.dart';
import 'package:client/services/notification_service.dart';
import 'package:client/subscription_page.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PremiumClientDashboard extends StatefulWidget {
  const PremiumClientDashboard({super.key});

  @override
  State<PremiumClientDashboard> createState() => _PremiumClientDashboardState();
}

class _PremiumClientDashboardState extends State<PremiumClientDashboard>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  // ── EXACT ORIGINAL BRAND COLORS ──────────────────────────────────────────
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);
  static const Color accentOrange = Color(0xFFFF9F43);
  static const Color accentGreen = Color(0xFF1DD1A1);
  static const Color accentRed = Color(0xFFFF6B6B);

  // ── STATE ─────────────────────────────────────────────────────────────────
  bool isLoading = true;
  String? clientName;
  String? clientLogo;
  bool isProfileIncomplete = false;
  String clientStatus = 'pending';

  int totalProjects = 0;
  int activeProjects = 0;
  int completedProjects = 0;

  int totalApplications = 0;
  int pendingApplications = 0;
  int approvedApplications = 0;
  int rejectedApplications = 0;

  List<Map<String, dynamic>> upcomingDeadlines = [];
  List<Map<String, dynamic>> recentWorks = [];
  Map<String, dynamic>? activeSub;
  bool isPremium = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    fetchDashboardData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── DATA ──────────────────────────────────────────────────────────────────

  Future<void> fetchDashboardData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    _fadeCtrl.reset();

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => isLoading = false);
        return;
      }

      final clientProfile = await supabase
          .from('tbl_client')
          .select(
            'client_name, client_address, client_contact, client_logo, client_proof, client_status',
          )
          .eq('client_id', user.id)
          .single();

      clientName = clientProfile['client_name'];
      clientLogo = clientProfile['client_logo'];
      clientStatus =
          clientProfile['client_status']?.toString().toLowerCase() ?? 'pending';
      isProfileIncomplete =
          (clientProfile['client_address'] == null ||
              clientProfile['client_address'].toString().trim().isEmpty) ||
          (clientProfile['client_contact'] == null ||
              clientProfile['client_contact'].toString().trim().isEmpty) ||
          (clientProfile['client_logo'] == null) ||
          (clientProfile['client_proof'] == null);

      final works = await supabase
          .from('tbl_work')
          .select()
          .eq('client_id', user.id)
          .order('created_at', ascending: false);

      totalProjects = works.length;
      activeProjects = works.where((e) {
        final s = e['work_status']?.toString().toLowerCase();
        return s == 'active' || s == 'assigned';
      }).length;
      completedProjects = works.where((e) {
        final s = e['work_status']?.toString().toLowerCase();
        return s == 'completed' || s == 'paid';
      }).length;

      recentWorks = works.take(3).toList();

      final workIds = works.map((e) => e['work_id']).toList();
      if (workIds.isNotEmpty) {
        final applications = await supabase
            .from('tbl_application')
            .select()
            .inFilter('work_id', workIds);

        totalApplications = applications.length;
        pendingApplications = applications
            .where((e) => e['application_status'] == 'pending')
            .length;
        approvedApplications = applications
            .where((e) => e['application_status'] == 'approved')
            .length;
        rejectedApplications = applications
            .where((e) => e['application_status'] == 'rejected')
            .length;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      upcomingDeadlines = works.where((e) {
        try {
          final d = DateTime.parse(e['work_lastdate']);
          return !DateTime(d.year, d.month, d.day).isBefore(today);
        } catch (_) {
          return false;
        }
      }).toList();

      upcomingDeadlines.sort(
        (a, b) => DateTime.parse(
          a['work_lastdate'],
        ).compareTo(DateTime.parse(b['work_lastdate'])),
      );
      if (upcomingDeadlines.length > 3)
        upcomingDeadlines = upcomingDeadlines.sublist(0, 3);

      // Fetch active subscription
      final subRes = await supabase
          .from('tbl_subscription')
          .select('*, tbl_subscription_plan(*)')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .maybeSingle();

      activeSub = subRes;
      isPremium = subRes != null;

      if (mounted) {
        setState(() => isLoading = false);
        _fadeCtrl.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Dashboard Error: $e"),
            backgroundColor: Colors.redAccent,
            action: SnackBarAction(
              label: "Retry",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClientProfilePage()),
                );
              },
            ),
          ),
        );
      }
    }
  }

  void _showLimitDialog(String title, String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: _p(w: FontWeight.bold)),
        content: Text(msg, style: _p()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Maybe Later"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionPage()),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: brandTeal),
            child: const Text(
              "Upgrade Now",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── TYPE HELPERS ──────────────────────────────────────────────────────────

  TextStyle _p({double s = 14, FontWeight w = FontWeight.normal, Color? c}) =>
      GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c ?? brandNavy);

  // ── HERO CARD ─────────────────────────────────────────────────────────────

  Widget _heroCard() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning 👋'
        : hour < 17
        ? 'Good Afternoon 👋'
        : 'Good Evening 👋';

    final statusColor = clientStatus == 'approved'
        ? accentGreen
        : clientStatus == 'rejected'
        ? accentRed
        : accentOrange;
    final statusLabel = clientStatus == 'approved'
        ? 'Verified'
        : clientStatus == 'rejected'
        ? 'Rejected'
        : 'Pending Review';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1B2A), Color(0xFF102030), Color(0xFF143040)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: brandNavy.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative circles
          Positioned(
            right: -14,
            top: -18,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brandTeal.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            right: 26,
            top: 16,
            child: Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brandTeal.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            left: -6,
            bottom: -10,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentOrange.withOpacity(0.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: status badge + avatar
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: _p(s: 11, w: FontWeight.w600, c: statusColor),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Avatar circle
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: brandTeal.withOpacity(0.5),
                        width: 2,
                      ),
                      color: brandNavy,
                    ),
                    child: clientLogo != null
                        ? ClipOval(
                            child: Image.network(
                              clientLogo!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.business_rounded,
                                color: brandTeal,
                                size: 20,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.business_rounded,
                            color: brandTeal,
                            size: 20,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(greeting, style: _p(s: 13, c: Colors.white54)),
              const SizedBox(height: 4),
              Text(
                clientName ?? 'Business Partner',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 22),
              // Divider
              Divider(color: Colors.white.withOpacity(0.1), height: 1),
              const SizedBox(height: 20),
              // Stats row
              Row(
                children: [
                  _heroStat(
                    totalProjects.toString(),
                    'Total Posts',
                    Icons.work_outline_rounded,
                  ),
                  _heroDiv(),
                  _heroStat(
                    activeProjects.toString(),
                    'Active',
                    Icons.bolt_rounded,
                  ),
                  _heroDiv(),
                  _heroStat(
                    totalApplications.toString(),
                    'Applicants',
                    Icons.people_outline_rounded,
                  ),
                  _heroDiv(),
                  _heroStat(
                    completedProjects.toString(),
                    'Done',
                    Icons.check_circle_outline_rounded,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String v, String l, IconData icon) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(l, style: _p(s: 9, c: Colors.white38)),
      ],
    ),
  );

  Widget _heroDiv() => Container(
    width: 1,
    height: 32,
    color: Colors.white.withOpacity(0.1),
    margin: const EdgeInsets.symmetric(horizontal: 2),
  );

  // ── SECTION HEADER ────────────────────────────────────────────────────────

  Widget _sectionHeader(
    String title, {
    String? action,
    VoidCallback? onAction,
  }) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 14),
    child: Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: brandTeal,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: _p(s: 16, w: FontWeight.w700)),
        const Spacer(),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: brandTeal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                action,
                style: _p(s: 12, w: FontWeight.w600, c: brandTeal),
              ),
            ),
          ),
      ],
    ),
  );

  // ── QUICK ACTION CARDS ───────────────────────────────────────────────────

  Widget _quickActions() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _quickAction(
            icon: Icons.add_circle_outline_rounded,
            label: 'Post Work',
            color: brandTeal,
            onTap: () {
              if (isProfileIncomplete || clientStatus != 'approved') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isProfileIncomplete
                          ? "Complete your profile first"
                          : "Account pending verification",
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              // LIMIT CHECK
              if (!isPremium && totalProjects >= 1) {
                _showLimitDialog(
                  "Work Post Limit Reached",
                  "Free accounts are limited to 1 work post. Upgrade to premium for unlimited posts!",
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WorkPage()),
              ).then((_) => fetchDashboardData());
            },
          ),
          const SizedBox(width: 12),
          _quickAction(
            icon: Icons.people_alt_outlined,
            label: 'Applications',
            color: accentOrange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ClientApplicationsPage(),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          _quickAction(
            icon: Icons.work_history_outlined,
            label: 'Work List',
            color: accentGreen,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WorkListPage()),
              ).then((_) => fetchDashboardData());
            },
          ),
          const SizedBox(width: 12),
          _quickAction(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Messages',
            color: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChatListPage(isClientApp: true),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 110,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: brandNavy.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(label, style: _p(s: 11, w: FontWeight.w600)),
        ],
      ),
    ),
  );

  // ── ALERT BANNER ─────────────────────────────────────────────────────────

  Widget _alertBanner({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: _p(s: 13, w: FontWeight.w700, c: color),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: _p(s: 11, c: color.withOpacity(0.75))),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: color.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }

  // ── APPLICATION SUMMARY CARDS ────────────────────────────────────────────

  Widget _applicationSummary() {
    if (totalApplications == 0) {
      return _emptyState(
        icon: Icons.inbox_outlined,
        title: 'No applications yet',
        subtitle: 'Hang tight! Students will apply soon.',
      );
    }

    return _applicationPieChart();
  }

  // ── PIE CHART ─────────────────────────────────────────────────────────────

  Widget _applicationPieChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: brandNavy.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: brandNavy.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            height: 140,
            width: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    value: pendingApplications.toDouble(),
                    color: accentOrange,
                    title: '',
                    radius: 42,
                  ),
                  PieChartSectionData(
                    value: approvedApplications.toDouble(),
                    color: accentGreen,
                    title: '',
                    radius: 42,
                  ),
                  PieChartSectionData(
                    value: rejectedApplications.toDouble(),
                    color: accentRed,
                    title: '',
                    radius: 42,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalApplications',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: brandNavy,
                  ),
                ),
                Text(
                  'Total Applicants',
                  style: _p(s: 11, c: Colors.grey[400]!),
                ),
                const SizedBox(height: 24),
                if (!isPremium)
                  _alertBanner(
                    icon: LucideIcons.crown,
                    title: "Upgrade to Premium",
                    subtitle:
                        "Get unlimited work posts and direct chat access.",
                    color: const Color(0xFFFF9F43),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SubscriptionPage(),
                      ),
                    ),
                  ),
                _pieLegend(accentOrange, 'Pending', pendingApplications),
                const SizedBox(height: 10),
                _pieLegend(accentGreen, 'Approved', approvedApplications),
                const SizedBox(height: 10),
                _pieLegend(accentRed, 'Rejected', rejectedApplications),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pieLegend(Color color, String label, int count) {
    final pct = totalApplications > 0
        ? (count / totalApplications * 100).toStringAsFixed(0)
        : '0';
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: _p(s: 12, c: Colors.grey[500]!)),
        ),
        Text('$count', style: _p(s: 13, w: FontWeight.w700)),
        const SizedBox(width: 4),
        Text('($pct%)', style: _p(s: 10, c: Colors.grey[400]!)),
      ],
    );
  }

  // ── RECENT WORK CARDS ─────────────────────────────────────────────────────

  Widget _recentWorkCard(Map<String, dynamic> work) {
    final status = work['work_status']?.toString() ?? 'Unknown';
    final statusColor =
        (status.toLowerCase() == 'active' || status.toLowerCase() == 'assigned')
        ? accentGreen
        : (status.toLowerCase() == 'completed' ||
              status.toLowerCase() == 'paid')
        ? brandTeal
        : accentOrange;

    DateTime? deadline;
    try {
      deadline = DateTime.parse(work['work_lastdate']);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: brandNavy.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: brandNavy.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.work_outline_rounded,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  work['work_title'] ?? 'Untitled',
                  style: _p(s: 13, w: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                if (deadline != null)
                  Text(
                    'Due ${DateFormat('MMM d, yyyy').format(deadline)}',
                    style: _p(s: 11, c: Colors.grey[400]!),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
            ),
            child: Text(
              status,
              style: _p(s: 10, w: FontWeight.w700, c: statusColor),
            ),
          ),
        ],
      ),
    );
  }

  // ── DEADLINE CARD ─────────────────────────────────────────────────────────

  Widget _deadlineCard(Map<String, dynamic> work) {
    final date = DateTime.parse(work['work_lastdate']);
    final daysLeft = date.difference(DateTime.now()).inDays;
    final isUrgent = daysLeft <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent
              ? accentOrange.withOpacity(0.4)
              : brandTeal.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: brandNavy.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isUrgent
                  ? accentOrange.withOpacity(0.1)
                  : brandTeal.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('dd').format(date),
                  style: _p(
                    s: 16,
                    w: FontWeight.w700,
                    c: isUrgent ? accentOrange : brandTeal,
                  ),
                ),
                Text(
                  DateFormat('MMM').format(date).toUpperCase(),
                  style: _p(
                    s: 9,
                    w: FontWeight.w600,
                    c: isUrgent ? accentOrange : brandTeal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  work['work_title'],
                  style: _p(s: 13, w: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: isUrgent ? accentOrange : Colors.grey[400],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      daysLeft == 0
                          ? 'Due today!'
                          : daysLeft == 1
                          ? 'Due tomorrow'
                          : 'In $daysLeft days',
                      style: _p(
                        s: 11,
                        c: isUrgent ? accentOrange : Colors.grey[400]!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isUrgent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: accentOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Urgent',
                style: _p(s: 10, w: FontWeight.w700, c: accentOrange),
              ),
            )
          else
            Icon(
              Icons.chevron_right_rounded,
              color: brandNavy.withOpacity(0.2),
            ),
        ],
      ),
    );
  }

  // ── EMPTY STATE ───────────────────────────────────────────────────────────

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: brandNavy.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: brandGrey,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: brandNavy.withOpacity(0.2)),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: _p(
              s: 13,
              w: FontWeight.w600,
              c: brandNavy.withOpacity(0.45),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: _p(s: 12, c: Colors.grey[400]!),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── APP BAR BUTTON ────────────────────────────────────────────────────────

  Widget _appBarBtn(
    IconData icon,
    VoidCallback onTap, {
    Color? iconColor,
    bool hasBadge = false,
  }) => GestureDetector(
    onTap: onTap,
    child: Stack(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: brandGrey,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: brandNavy.withOpacity(0.07)),
          ),
          child: Icon(icon, color: iconColor ?? brandNavy, size: 18),
        ),
        if (hasBadge)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: accentRed,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    ),
  );

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final blocked = isProfileIncomplete || clientStatus != 'approved';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: brandGrey,

        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: brandNavy,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Padding(
                           padding: EdgeInsets.all(8.0),
                           child: Image(image: AssetImage('assets/gradlance.png')),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Gradlance',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: brandNavy,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    Consumer<NotificationService>(
                      builder: (context, notificationService, _) {
                        return _appBarBtn(
                          Icons.notifications_none_rounded,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationPage(),
                            ),
                          ),
                          hasBadge: notificationService.unreadCount > 0,
                        );
                      },
                    ),

                    const SizedBox(width: 8),
                    
                    _appBarBtn(
                      Icons.chat_bubble_outline_rounded,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChatListPage(isClientApp: true),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _appBarBtn(Icons.refresh_rounded, fetchDashboardData),
                  ],
                ),
              ),
            ),
          ),
        ),

        floatingActionButton: GestureDetector(
          onTap: () {
            if (isProfileIncomplete) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Complete your profile first (Logo, Proof, Address)",
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            if (clientStatus != 'approved') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Your account is pending Admin verification."),
                  backgroundColor: Colors.redAccent,
                ),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WorkPage()),
            ).then((_) => fetchDashboardData());
          },
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: blocked ? Colors.grey[300] : brandTeal,
              borderRadius: BorderRadius.circular(16),
              boxShadow: blocked
                  ? []
                  : [
                      BoxShadow(
                        color: brandTeal.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  color: blocked ? Colors.white60 : Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Post Work',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: blocked ? Colors.white60 : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),

        body: isLoading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: brandTeal,
                      strokeWidth: 2.5,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading dashboard…',
                      style: _p(s: 13, c: Colors.grey[400]!),
                    ),
                  ],
                ),
              )
            : FadeTransition(
                opacity: _fadeAnim,
                child: RefreshIndicator(
                  onRefresh: fetchDashboardData,
                  color: brandTeal,
                  backgroundColor: Colors.white,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── HERO ──────────────────────────────────────
                        _heroCard(),
                        const SizedBox(height: 20),

                        // ── ALERTS ────────────────────────────────────
                        if (isProfileIncomplete)
                          _alertBanner(
                            icon: Icons.warning_amber_rounded,
                            title: 'Profile Incomplete',
                            subtitle:
                                'Add contact, address, logo & proof to unlock posting.',
                            color: Colors.redAccent,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ClientProfilePage(),
                                ),
                              );
                            },
                          )
                        else if (clientStatus != 'approved')
                          _alertBanner(
                            icon: Icons.admin_panel_settings_rounded,
                            title: 'Pending Verification',
                            subtitle:
                                'Your profile is under admin review. Almost there!',
                            color: accentOrange,
                          ),

                        // ── QUICK ACTIONS ─────────────────────────────
                        _sectionHeader('Quick Actions'),
                        _quickActions(),

                        // ── APPLICATIONS ──────────────────────────────
                        _sectionHeader('Application Overview'),
                        _applicationSummary(),

                        // ── RECENT WORKS ──────────────────────────────
                        if (recentWorks.isNotEmpty) ...[
                          _sectionHeader(
                            'Recent Works',
                            action: 'View All',
                            onAction: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const WorkListPage(),
                              ),
                            ),
                          ),
                          ...recentWorks.map(_recentWorkCard).toList(),
                        ],

                        // ── DEADLINES ─────────────────────────────────
                        _sectionHeader(
                          'Approaching Deadlines',
                          action: 'View All →',
                        ),
                        if (upcomingDeadlines.isEmpty)
                          _emptyState(
                            icon: Icons.event_available_rounded,
                            title: 'All caught up!',
                            subtitle: 'No approaching deadlines right now.',
                          )
                        else
                          ...upcomingDeadlines.map(_deadlineCard).toList(),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
