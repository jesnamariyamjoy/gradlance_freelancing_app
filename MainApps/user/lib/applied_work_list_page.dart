import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:user/workdetails.dart';
import 'package:user/screens/chat_screen.dart';

class AppliedWorkListPage extends StatefulWidget {
  const AppliedWorkListPage({super.key});

  @override
  State<AppliedWorkListPage> createState() => _AppliedWorkListPageState();
}

class _AppliedWorkListPageState extends State<AppliedWorkListPage> {
  final supabase = Supabase.instance.client;

  // 🎨 BRAND COLORS
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  bool isLoading = true;
  List applications = [];
  RealtimeChannel? applicationChannel;

  @override
  void initState() {
    super.initState();
    fetchAppliedWorks();
    setupRealtime();
  }

  @override
  void dispose() {
    if (applicationChannel != null) {
      supabase.removeChannel(applicationChannel!);
    }
    super.dispose();
  }

  void setupRealtime() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    applicationChannel = supabase.channel('application_updates')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'tbl_application',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: user.id,
        ),
        callback: (payload) => fetchAppliedWorks(),
      )
      ..subscribe();
  }

  Future<void> fetchAppliedWorks() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => isLoading = true);
    try {
      final data = await supabase
          .from('tbl_application')
          .select('''
            application_id,
            application_status,
            created_at,
            bid_amount,
            work_progress,
            payment_status,
            tbl_work (
              work_id,
              work_title,
              work_content,
              work_lastdate,
              work_file,
              budget,
              tbl_client ( client_id, client_name )
            )
          ''')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          applications = data;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> cancelApplication(int applicationId) async {
    final confirmed = await _showCancelDialog();
    if (confirmed == true) {
      await supabase.from('tbl_application').delete().eq('application_id', applicationId);
      fetchAppliedWorks();
    }
  }

  Future<bool?> _showCancelDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Cancel Application?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to withdraw this application?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes, Withdraw", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Future<void> downloadFile(String url) async {
    if (url.isEmpty) return;
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Show error message if available
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Unable to open file. The file may not be accessible."),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error opening file: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted': return Colors.green;
      case 'rejected': return Colors.red;
      case 'completed': return brandNavy;
      case 'pending': return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brandGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: brandNavy, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Applied Works",
          style: GoogleFonts.poppins(color: brandNavy, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: brandTeal))
          : applications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: brandTeal,
                  onRefresh: fetchAppliedWorks,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: applications.length,
                    itemBuilder: (context, index) {
                      final app = applications[index];
                      final work = app['tbl_work'];
                      if (work == null) return const SizedBox();
                      
                      return _buildApplicationCard(
                        applicationId: app['application_id'],
                        title: work['work_title'] ?? '',
                        content: work['work_content'] ?? '',
                        deadline: work['work_lastdate'] ?? '',
                        file: work['work_file'] ?? '',
                        clientName: work['tbl_client']?['client_name'] ?? 'Unknown',
                        status: app['application_status'] ?? 'pending',
                        bidAmount: app['bid_amount'] ?? 0,
                        budget: work['budget'] ?? 0,
                        progress: app['work_progress'] ?? 0,
                        paymentStatus: app['payment_status'] ?? 'unpaid',
                        clientId: work['tbl_client']?['client_id'] ?? '', 
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildApplicationCard({
    required int applicationId,
    required String title,
    required String content,
    required String deadline,
    required String file,
    required String clientName,
    required String status,
    required dynamic bidAmount,
    required dynamic budget,
    required int progress,
    required String paymentStatus,
    required String clientId,
  }) {
    final statusColor = getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: brandNavy.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: brandNavy.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 17, color: brandNavy),
                ),
              ),
              _buildStatusBadge(status, statusColor),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.business_rounded, size: 14, color: brandTeal),
              const SizedBox(width: 6),
              Text(clientName, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined, size: 14, color: Colors.blueGrey),
              const SizedBox(width: 6),
              Text("Deadline: $deadline", style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87)),
              const Spacer(),
              Text("₹$bidAmount", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: brandTeal)),
            ],
          ),
          const SizedBox(height: 12),
          if (status.toLowerCase() == 'accepted' || status.toLowerCase() == 'submitted' || status.toLowerCase() == 'completed') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Work Progress", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)),
                Text("$progress%", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: brandTeal)),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 4,
                backgroundColor: brandTeal.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation(brandTeal),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Payment Status", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: paymentStatus == 'paid' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    paymentStatus.toUpperCase(),
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: paymentStatus == 'paid' ? Colors.green : Colors.orange),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandNavy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkDetailsPage(
                        title: title,
                        content: content,
                        deadline: deadline,
                        clientName: clientName,
                        file: file,
                      ),
                    ),
                  ),
                  child: const Text("Details"),
                ),
              ),
              const SizedBox(width: 10),
              if (file.isNotEmpty)
                IconButton.filledTonal(
                  style: IconButton.styleFrom(backgroundColor: brandTeal.withOpacity(0.1), foregroundColor: brandTeal),
                  onPressed: () => downloadFile(file),
                  icon: const Icon(Icons.download_rounded, size: 20),
                ),
              if (status.toLowerCase() == "accepted" || status.toLowerCase() == "submitted" || status.toLowerCase() == "completed")
                IconButton.filledTonal(
                  style: IconButton.styleFrom(backgroundColor: brandTeal.withOpacity(0.1), foregroundColor: brandTeal),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          receiverId: clientId,
                          receiverName: clientName,
                          isReceiverClient: true,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                ),
              if (status.toLowerCase() == "pending")
                IconButton.filledTonal(
                  style: IconButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.1), foregroundColor: Colors.red),
                  onPressed: () => cancelApplication(applicationId),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_late_outlined, size: 70, color: brandNavy.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text("No applications yet", style: GoogleFonts.poppins(color: brandNavy.withOpacity(0.4), fontSize: 16)),
        ],
      ),
    );
  }
}