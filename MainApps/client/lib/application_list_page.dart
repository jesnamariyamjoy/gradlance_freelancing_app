import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Ensure these paths match your project structure
import 'package:client/payment_page.dart';
import 'package:client/screens/chat_screen.dart';
import 'package:client/rate_user_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:client/screens/student_profile_view_page.dart';

class ClientApplicationsPage extends StatefulWidget {
  final int? workId;
  const ClientApplicationsPage({super.key, this.workId});

  @override
  State<ClientApplicationsPage> createState() => _ClientApplicationsPageState();
}

class _ClientApplicationsPageState extends State<ClientApplicationsPage> {
  final supabase = Supabase.instance.client;

  // Theme Constants
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);
  static const Color accentOrange = Color(0xFFFF9F43);

  bool isLoading = true;
  List<dynamic> applications = [];
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    fetchApplications();
    setupRealtime();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      supabase.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  void setupRealtime() {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    _realtimeChannel = supabase.channel('client_applications')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'tbl_application',
        callback: (payload) => fetchApplications(),
      )
      ..subscribe();
  }

  /// 1. FETCH DATA WITH ERROR LOGGING
  Future<void> fetchApplications() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        debugPrint("DEBUG: No authenticated user found.");
        return;
      }

      debugPrint("DEBUG: Fetching applications for Client: ${currentUser.id}");

      final response = await supabase
          .from('tbl_application')
          .select('''
            *,
            tbl_work!inner (work_id, work_title, client_id, submitted_work_link, work_file),
            tbl_user (id, user_name, user_photo, college)
          ''')
          .eq('tbl_work.client_id', currentUser.id)
          .order('created_at', ascending: false);

      debugPrint("DEBUG: Response from DB: $response");

      if (mounted) {
        setState(() {
          applications = response as List<dynamic>;
          isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint("-----------------------------------------");
      debugPrint("CRITICAL ERROR FETCHING DATA: $e");
      debugPrint("STACKTRACE: $stack");
      debugPrint("-----------------------------------------");
      if (mounted) {
        setState(() => isLoading = false);
        _showSnackBar(
          "Connection Error: Check console for details",
          Colors.redAccent,
        );
      }
    }
  }

  /// 2. UPDATE STATUS HELPER
  Future<void> updateStatus(int appId, String newStatus) async {
    try {
      final app = applications.firstWhere((a) => a['application_id'] == appId);
      final studentId = app['tbl_user']['id'];
      final workTitle = app['tbl_work']['work_title'] ?? 'your job application';

      await supabase
          .from('tbl_application')
          .update({'application_status': newStatus})
          .eq('application_id', appId);

      if (newStatus == 'accepted') {
        // Also update tbl_work to 'assigned' and link to this student
        await supabase
            .from('tbl_work')
            .update({'work_status': 'assigned', 'assigned_user_id': studentId})
            .eq('work_id', app['work_id']);

        // Reject all other pending applications for this work
        await supabase
            .from('tbl_application')
            .update({'application_status': 'rejected'})
            .eq('work_id', app['work_id'])
            .filter('application_id', 'neq', appId)
            .eq('application_status', 'pending');
      }

      await supabase.from('notifications').insert({
        'user_id': studentId,
        'title': newStatus == 'accepted'
            ? "Application Approved"
            : "Application Rejected",
        'message': newStatus == 'accepted'
            ? "Your application for '$workTitle' has been approved! You can now start working. Chat is now enabled."
            : "Your application for '$workTitle' was not accepted at this time.",
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
        'type': 'application_status',
        'target_id': app['work_id'].toString(),
      });

      _showSnackBar("Status updated to $newStatus", brandTeal);
      fetchApplications();
    } catch (e) {
      debugPrint("DEBUG: Update Error: $e");
      _showSnackBar("Update failed", Colors.redAccent);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: brandGrey,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            "Manage Requests",
            style: GoogleFonts.poppins(
              color: brandNavy,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                LucideIcons.refreshCw,
                color: brandNavy,
                size: 20,
              ),
              onPressed: fetchApplications,
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: brandTeal,
            unselectedLabelColor: Colors.grey,
            indicatorColor: brandTeal,
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: "Pending"),
              Tab(text: "In Progress"),
              Tab(text: "Completed"),
              Tab(text: "Rejected"),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: brandTeal))
            : TabBarView(
                children: [
                  _buildApplicationList('pending'),
                  _buildApplicationList('accepted'), // For In Progress
                  _buildApplicationList('completed'), // For Completed
                  _buildApplicationList('rejected'),
                ],
              ),
      ),
    );
  }

  /// 3. FILTER LOGIC FIX (Matching your CSV Data)
  Widget _buildApplicationList(String filterStatus) {
    final filtered = applications.where((app) {
      final String status = (app['application_status'] ?? 'pending')
          .toString()
          .toLowerCase();
      final int progress = app['work_progress'] ?? 0;

      // In Progress: Database status is 'accepted' but progress is NOT 100%
      if (filterStatus == 'accepted') {
        return status == 'accepted' && progress < 100;
      }

      // Completed: Database status is 'completed' OR status is 'accepted' with 100% progress
      if (filterStatus == 'completed') {
        return status == 'completed' ||
            status == 'submitted' ||
            status == 'verified' ||
            status == 'paid' ||
            (status == 'accepted' && progress >= 100);
      }

      // Standard matching for Pending and Rejected
      return status == filterStatus;
    }).toList();

    if (filtered.isEmpty) return _buildEmptyState(filterStatus);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildApplicationCard(filtered[index]),
    );
  }

  Widget _buildApplicationCard(dynamic app) {
    final user = app['tbl_user'] ?? {};
    final work = app['tbl_work'] ?? {};
    final status = (app['application_status'] ?? 'pending')
        .toString()
        .toLowerCase();
    final int progress = app['work_progress'] ?? 0;
    final int appId = app['application_id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: brandNavy.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        work['work_title'] ?? 'Job Request',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: brandNavy,
                        ),
                      ),
                    ),
                    if (status == 'accepted' || status == 'completed')
                      Text(
                        "$progress%",
                        style: GoogleFonts.poppins(
                          color: brandTeal,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildUserRow(user),
                const SizedBox(height: 12),
                Text(
                  "Bid Amount: ₹${app['bid_amount']}",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _buildActionButtons(app, user, status, progress, appId),
        ],
      ),
    );
  }

  Widget _buildUserRow(dynamic user) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudentProfileViewPage(studentId: user['id']),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundImage: user['user_photo'] != null
                ? NetworkImage(user['user_photo'])
                : null,
            child: user['user_photo'] == null
                ? const Icon(LucideIcons.user, size: 14)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            user['user_name'] ?? 'Freelancer',
            style: GoogleFonts.poppins(
              fontSize: 13,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    dynamic app,
    dynamic user,
    String status,
    int progress,
    int appId,
  ) {
    final bool isPaid = app['payment_status'] == 'paid';
    final work = app['tbl_work'] ?? {};
    final String? submissionLink = work['submitted_work_link'];

    return Container(
      decoration: BoxDecoration(
        color: brandGrey.withOpacity(0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                isPaid
                    ? "PAID"
                    : (status == 'accepted'
                          ? "ASSIGNED"
                          : status.toUpperCase()),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isPaid
                      ? Colors.green
                      : (status == 'accepted' ? brandTeal : Colors.blueGrey),
                ),
              ),
              if (submissionLink != null && submissionLink.isNotEmpty) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: "View Submission",
                  icon: const Icon(
                    LucideIcons.externalLink,
                    size: 16,
                    color: brandTeal,
                  ),
                  onPressed: () async {
                    final uri = Uri.parse(submissionLink);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    } else {
                      _showSnackBar("Cannot open link", Colors.orange);
                    }
                  },
                ),
              ],
            ],
          ),
          Row(
            children: [
              if (status == 'pending') ...[
                TextButton(
                  onPressed: () => updateStatus(appId, 'rejected'),
                  child: const Text(
                    "Reject",
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => updateStatus(appId, 'accepted'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandTeal,
                    elevation: 0,
                  ),
                  child: const Text(
                    "Approve",
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ],
              if (status != 'pending' && status != 'rejected') ...[
                IconButton(
                  icon: const Icon(
                    LucideIcons.messageSquare,
                    size: 18,
                    color: brandNavy,
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        receiverId: user['id'],
                        receiverName: user['user_name'],
                        isReceiverClient: false,
                      ),
                    ),
                  ),
                ),
                if ((status == 'submitted' ||
                        status == 'verified' ||
                        progress >= 100) &&
                    !isPaid)
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentPage(
                          applicationId: appId,
                          amount: app['bid_amount'],
                          devName: user['user_name'],
                        ),
                      ),
                    ).then((_) => fetchApplications()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentOrange,
                      elevation: 0,
                    ),
                    child: const Text(
                      "Pay",
                      style: TextStyle(fontSize: 11, color: Colors.white),
                    ),
                  ),
                if (isPaid)
                  IconButton(
                    icon: const Icon(
                      LucideIcons.star,
                      color: accentOrange,
                      size: 18,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RateUserPage(
                          workData: app['tbl_work'],
                          userData: app['tbl_user'],
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String filter) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.folderX,
            size: 40,
            color: brandNavy.withOpacity(0.1),
          ),
          const SizedBox(height: 8),
          Text(
            "No $filter applications found",
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
