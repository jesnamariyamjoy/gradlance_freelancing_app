import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:user/work_submission_page.dart';
import 'package:user/screens/chat_screen.dart';
import 'package:user/user_work_details_page.dart';
import 'package:user/task_list_page.dart';

class SubmissionListPage extends StatefulWidget {
  final String initialFilter; // Added to receive filter from Dashboard
  const SubmissionListPage({super.key, this.initialFilter = 'all'});

  @override
  State<SubmissionListPage> createState() => _SubmissionListPageState();
}

class _SubmissionListPageState extends State<SubmissionListPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List allWorks = []; // Store the master list
  List filteredWorks = []; // Store the list currently being displayed
  String activeFilter = 'all';
  RealtimeChannel? _subscription;

  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);

  @override
  void initState() {
    super.initState();
    activeFilter = widget.initialFilter;
    fetchAcceptedWorks();
    setupRealtime();
  }

  @override
  void dispose() {
    if (_subscription != null) {
      supabase.removeChannel(_subscription!);
    }
    super.dispose();
  }

  void setupRealtime() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _subscription = supabase.channel('user_submissions')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'tbl_application',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: user.id,
        ),
        callback: (payload) => fetchAcceptedWorks(),
      )
      ..subscribe();
  }

  Future<void> fetchAcceptedWorks() async {
    try {
      final user = supabase.auth.currentUser;
      final data = await supabase
          .from('tbl_application')
          .select('''
            application_id,
            application_status,
            created_at,
            work_progress,
            bid_amount,
            payment_status,
            rejected_reason,
            tbl_work (
              work_id,
              work_title,
              work_lastdate,
              client_id,
              budget,
              tbl_client ( client_name )
            )
          ''')
          .eq('user_id', user!.id);

      // Sort by recent applied date
      data.sort((a, b) {
        DateTime dateA = DateTime.parse(a['created_at']);
        DateTime dateB = DateTime.parse(b['created_at']);
        return dateB.compareTo(dateA);
      });

      setState(() {
        allWorks = data;
        _applyFilter(activeFilter); // Apply the initial filter
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => isLoading = false);
    }
  }

  void _applyFilter(String filter) {
    setState(() {
      activeFilter = filter;
      if (filter == 'all') {
        filteredWorks = allWorks;
      } else if (filter == 'active') {
        filteredWorks = allWorks.where((item) {
          final s = item['application_status'].toString().toLowerCase();
          return s == 'accepted' || s == 'verified' || s == 'submitted' || s == 'rejected';
        }).toList();
      } else if (filter == 'completed') {
        filteredWorks = allWorks
            .where(
              (item) =>
                  item['application_status'].toString().toLowerCase() == 'paid',
            )
            .toList();
      } else if (filter == 'pending') {
        filteredWorks = allWorks
            .where(
              (item) =>
                  item['application_status'].toString().toLowerCase() ==
                  'pending',
            )
            .toList();
      }
    });
  }

  DateTime _parseDate(String dateStr) {
    try {
      return DateFormat('dd-MM-yyyy').parse(dateStr);
    } catch (_) {
      return DateTime.now().add(const Duration(days: 365));
    }
  }

  String _getTimeRemaining(String deadlineStr) {
    final deadline = _parseDate(deadlineStr);
    final now = DateTime.now();
    final difference = deadline.difference(now);

    if (difference.isNegative) return "Overdue";
    if (difference.inDays > 0) return "${difference.inDays}d remaining";
    if (difference.inHours > 0) return "${difference.inHours}h remaining";
    return "${difference.inMinutes}m remaining";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: brandNavy,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Applied Works",
          style: GoogleFonts.poppins(
            color: brandNavy,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: brandTeal),
                  )
                : filteredWorks.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: fetchAcceptedWorks,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: filteredWorks.length,
                      itemBuilder: (context, index) {
                        final item = filteredWorks[index];
                        final work = item['tbl_work'];
                        final timeRemaining = _getTimeRemaining(
                          work['work_lastdate'],
                        );
                        final bool isOverdue = timeRemaining == "Overdue";

                        return _buildSubmissionCard(
                          item,
                          work,
                          timeRemaining,
                          isOverdue,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _filterChip("All", 'all'),
          _filterChip("Active", 'active'),
          _filterChip("Pending", 'pending'),
          _filterChip("Done", 'completed'),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String filterKey) {
    bool isSelected = activeFilter == filterKey;
    return GestureDetector(
      onTap: () => _applyFilter(filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? brandNavy : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmissionCard(
    dynamic item,
    dynamic work,
    String timeRemaining,
    bool isOverdue,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isOverdue ? Border.all(color: Colors.red.withOpacity(0.3)) : null,
        boxShadow: [
          BoxShadow(color: brandNavy.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserWorkDetailsPage(
                          work: work,
                        ),
                      ),
                    ).then((_) => fetchAcceptedWorks());
                  },
                  child: Text(
                    work['work_title'] ?? 'Untitled Work',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: brandNavy,
                    ),
                  ),
                ),
              ),
              if (item['application_status'] == 'accepted' || item['application_status'] == 'submitted')
                Text(
                  "${item['work_progress'] ?? 0}%",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: brandTeal,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.business_rounded, size: 14, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Text(
                work['tbl_client']?['client_name'] ?? 'Unknown Client',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined, size: 14, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Text(
                "Deadline: ${_formatDate(work['work_lastdate'])}",
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.currency_rupee_rounded, size: 14, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Text(
                "Bid Amount: ₹${item['bid_amount'] ?? 0}",
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: brandNavy),
              ),
              const Spacer(),
              _buildPaymentStatus(item['payment_status']),
            ],
          ),
          if (item['application_status'] == 'rejected' && item['rejected_reason'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                     "Rejection Reason:",
                     style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red),
                   ),
                   const SizedBox(height: 4),
                   Text(
                     item['rejected_reason'],
                     style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87, fontStyle: FontStyle.italic),
                   ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (item['application_status'] == 'accepted' || item['application_status'] == 'submitted') ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (item['work_progress'] ?? 0) / 100,
                minHeight: 8,
                backgroundColor: brandTeal.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation(brandTeal),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _getStatusColor(item['application_status']),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item['application_status'].toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _getStatusColor(item['application_status']),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (item['application_status'] == 'accepted' ||
                      item['application_status'] == 'verified' ||
                      item['application_status'] == 'submitted' ||
                      item['application_status'] == 'paid')
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              receiverId: work['client_id'],
                              receiverName: work['tbl_client']['client_name'],
                              isReceiverClient: true,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: brandTeal, size: 22),
                    ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (item['application_status'] == 'accepted' || item['application_status'] == 'verified')
                          ? brandNavy
                          : (item['application_status'] == 'submitted'
                              ? Colors.orange
                              : (item['application_status'] == 'paid' || item['application_status'] == 'completed'
                                  ? Colors.green
                                  : Colors.grey.shade300)),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      elevation: (item['application_status'] == 'accepted') ? 2 : 0,
                    ),
                    onPressed: (item['application_status'] == 'accepted' || item['application_status'] == 'verified' || item['application_status'] == 'rejected')
                        ? () {
                            if (item['application_status'] == 'rejected' || (item['work_progress'] ?? 0) >= 100) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WorkSubmissionPage(
                                    applicationId: item['application_id'],
                                    projectTitle: work['work_title'],
                                  ),
                                ),
                              ).then((_) => fetchAcceptedWorks());
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TaskListPage(
                                    workId: work['work_id'],
                                    workTitle: work['work_title'],
                                    applicationId: item['application_id'],
                                  ),
                                ),
                              ).then((_) => fetchAcceptedWorks());
                            }
                          }
                        : null,
                    child: Text(
                      _getButtonText(item),
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatus(String? status) {
    bool isPaid = status == 'paid';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isPaid ? "PAID" : "UNPAID",
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isPaid ? Colors.green : Colors.orange,
        ),
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null) return 'N/A';
    try {
      DateTime dt = DateTime.parse(date);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return date;
    }
  }

  Color _getStatusColor(String status) {
    status = status.toLowerCase();
    switch (status) {
      case 'accepted':
      case 'verified':
        return brandTeal;
      case 'submitted':
        return Colors.orange;
      case 'paid':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getButtonText(dynamic item) {
    final status = item['application_status'].toString().toLowerCase();
    if (status == 'accepted' || status == 'verified') {
      return (item['work_progress'] ?? 0) < 100 ? "milestones" : "Submit Work";
    } else if (status == 'submitted') {
      return "Work Submitted";
    } else if (status == 'paid') {
      return "Payment Received";
    } else if (status == 'rejected') {
      return "Resubmit Work";
    }
    return "Waiting Approval";
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_turned_in_outlined,
            size: 60,
            color: brandNavy.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            "No $activeFilter projects found",
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
