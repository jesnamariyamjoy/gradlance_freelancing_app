import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ViewSubmissionsPage extends StatefulWidget {
  const ViewSubmissionsPage({super.key});

  @override
  State<ViewSubmissionsPage> createState() => _ViewSubmissionsPageState();
}

class _ViewSubmissionsPageState extends State<ViewSubmissionsPage> {
  final supabase = Supabase.instance.client;

  String selectedStatus = 'All';
  bool isLoading = true;
  List<Map<String, dynamic>> submissions = [];
  String searchQuery = '';

  // 🎨 BRAND COLORS
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  @override
  void initState() {
    super.initState();
    _fetchSubmissions();
  }

  Future<void> _fetchSubmissions() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final clientId = supabase.auth.currentUser!.id;

      // Get all works created by client along with applications
      final works = await supabase
          .from('tbl_work')
          .select('''
            work_id,
            work_title,
            work_lastdate,
            work_status,
            payment_status,
            budget,
            client_id,
            submitted_work_link,
            tbl_application (
              application_id,
              application_status,
              bid_amount,
              user_id,
              created_at,
              rejected_reason,
              tbl_user:user_id (
                user_name,
                user_photo,
                tbl_bank_details (
                  account_holder_name,
                  bank_name,
                  account_number,
                  ifsc_code
                )
              )
            )
          ''')
          .eq('client_id', clientId)
          .order('created_at', ascending: false);

      // Flatten the data
      final List<Map<String, dynamic>> allSubmissions = [];
      for (var work in works) {
        final applications = work['tbl_application'] as List? ?? [];
        for (var app in applications) {
          if (app['application_status'] == 'submitted' ||
              app['application_status'] == 'completed' ||
              app['application_status'] == 'payment_pending' ||
              app['application_status'] == 'paid') {
            allSubmissions.add({
              'work_id': work['work_id'],
              'application_id': app['application_id'],
              'work_title': work['work_title'],
              'work_lastdate': work['work_lastdate'],
              'work_status': work['work_status'],
              'payment_status': work['payment_status'],
              'budget': work['budget'],
              'application_status': app['application_status'],
              'bid_amount': app['bid_amount'],
              'user_id': app['user_id'],
              'user_name': app['tbl_user']?['user_name'] ?? 'Unknown',
              'user_photo': app['tbl_user']?['user_photo'],
              'submitted_date': app['created_at'],
              'submitted_work_link': work['submitted_work_link'],
              'rejected_reason': app['rejected_reason'],
              'bank_details': app['tbl_user']?['tbl_bank_details'],
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          submissions = allSubmissions;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showSnackBar("Error loading submissions: $e", Colors.red);
      }
    }
  }

  List<Map<String, dynamic>> getFilteredSubmissions() {
    List<Map<String, dynamic>> filtered = submissions;

    // Filter by status
    if (selectedStatus != 'All') {
      filtered = filtered
          .where((s) => _statusLabel(s['application_status']) == selectedStatus)
          .toList();
    }

    // Filter by search
    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (s) =>
                s['user_name'].toString().toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ||
                s['work_title'].toString().toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ),
          )
          .toList();
    }

    return filtered;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'submitted':
        return 'Pending Review';
      case 'rejected':
        return 'Rejected';
      case 'completed':
        return 'Approved';
      case 'payment_pending':
        return 'Payment Pending';
      case 'paid':
        return 'Completed & Paid';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'submitted':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.green;
      case 'payment_pending':
        return Colors.blue;
      case 'paid':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Future<void> _approveSubmission(Map<String, dynamic> submission) async {
    try {
      // Update application status
      await supabase
          .from('tbl_application')
          .update({'application_status': 'completed'})
          .eq('application_id', submission['application_id']);

      // Update work status
      await supabase
          .from('tbl_work')
          .update({'work_status': 'completed'})
          .eq('work_id', submission['work_id']);

      _showSnackBar("Work approved! Ready for payment.", Colors.green);

      // Notify Student
      try {
        await supabase.from('notifications').insert({
          'user_id': submission['user_id'],
          'title': "Submission Approved!",
          'message':
              "Your submission for '${submission['work_title']}' has been approved. Payment is pending.",
          'type': 'work_status',
          'target_id': submission['work_id'].toString(),
        });
      } catch (_) {}

      _fetchSubmissions();
    } catch (e) {
      _showSnackBar("Error updating status: $e", Colors.red);
    }
  }

  Future<void> _rejectSubmission(Map<String, dynamic> submission) async {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Reject Submission",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Please specify why you are rejecting this work. This will be sent to the user.",
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Reason for rejection...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                _showSnackBar("Please provide a reason", Colors.orange);
                return;
              }
              Navigator.pop(context);

              try {
                // Update application status to rejected
                await supabase
                    .from('tbl_application')
                    .update({
                      'application_status': 'rejected',
                      'rejected_reason': reasonController.text.trim(),
                    })
                    .eq('application_id', submission['application_id']);

                _showSnackBar("Submission rejected.", Colors.red);

                // Notify Student
                await supabase.from('notifications').insert({
                  'user_id': submission['user_id'],
                  'title': "Submission Rejected",
                  'message':
                      "Your submission for '${submission['work_title']}' was rejected. Reason: ${reasonController.text.trim()}",
                  'type': 'work_status',
                  'target_id': submission['work_id'].toString(),
                });

                _fetchSubmissions();
              } catch (e) {
                _showSnackBar("Error rejecting submission: $e", Colors.red);
              }
            },
            child: const Text("Reject", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _processPayment(Map<String, dynamic> submission) async {
    final bank = submission['bank_details'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Payment Details",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: bank == null
            ? const Text(
                "User has not added bank details yet. Please ask them to update Payout Settings.",
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Student: ${submission['user_name']}"),
                  const SizedBox(height: 8),
                  Text(
                    "Amount to Pay: ₹${submission['bid_amount']}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 24),
                  _bankDetailRow("Account Holder", bank['account_holder_name']),
                  _bankDetailRow("Bank Name", bank['bank_name']),
                  _bankDetailRow("Account Number", bank['account_number']),
                  _bankDetailRow("IFSC Code", bank['ifsc_code']),
                  const SizedBox(height: 16),
                  const Text(
                    "Once you have transferred the amount via your bank, click confirm below to release the work.",
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          if (bank != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: brandTeal),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  // Create payment record
                  await supabase.from('tbl_payment').insert({
                    'work_id': submission['work_id'],
                    'user_id': submission['user_id'],
                    'client_id': supabase.auth.currentUser!.id,
                    'amount': submission['bid_amount'],
                    'payment_status': 'completed',
                  });

                  // Update application status to paid
                  await supabase
                      .from('tbl_application')
                      .update({'application_status': 'paid'})
                      .eq('application_id', submission['application_id']);

                  // Update work payment status
                  await supabase
                      .from('tbl_work')
                      .update({
                        'payment_status': true,
                      }) // Schema says BOOLEAN DEFAULT FALSE
                      .eq('work_id', submission['work_id']);

                  _showSnackBar(
                    "Payment confirmed! Work marked as paid.",
                    Colors.green,
                  );

                  // Notify Student
                  await supabase.from('notifications').insert({
                    'user_id': submission['user_id'],
                    'title': "Payment Released!",
                    'message':
                        "Client has released the payment for '${submission['work_title']}'.",
                    'type': 'payment',
                    'target_id': submission['work_id'].toString(),
                  });

                  _fetchSubmissions();
                } catch (e) {
                  _showSnackBar("Error processing payment: $e", Colors.red);
                }
              },
              child: const Text(
                "Confirm Payment",
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bankDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "$label:",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = getFilteredSubmissions();

    return Scaffold(
      backgroundColor: brandGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'View Submissions',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: brandNavy,
            fontSize: 18,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: brandTeal))
          : Column(
              children: [
                _buildSearchAndFilters(),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No submissions found',
                            style: GoogleFonts.poppins(color: Colors.grey[400]),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return SubmissionCard(
                              data: filtered[index],
                              onApprove: _approveSubmission,
                              onReject: _rejectSubmission,
                              onPayment: _processPayment,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            onChanged: (val) => setState(() => searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search by student, project or file',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: brandGrey,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                [
                      'All',
                      'Pending Review',
                      'Rejected',
                      'Approved',
                      'Payment Pending',
                    ]
                    .map(
                      (status) => ChoiceChip(
                        label: Text(status),
                        selected: selectedStatus == status,
                        selectedColor: brandTeal,
                        onSelected: (_) {
                          setState(() => selectedStatus = status);
                        },
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }
}

class SubmissionCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(Map<String, dynamic>) onApprove;
  final Function(Map<String, dynamic>) onReject;
  final Function(Map<String, dynamic>) onPayment;

  const SubmissionCard({
    super.key,
    required this.data,
    required this.onApprove,
    required this.onReject,
    required this.onPayment,
  });

  @override
  State<SubmissionCard> createState() => _SubmissionCardState();
}

class _SubmissionCardState extends State<SubmissionCard> {
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);

  String _statusLabel(String status) {
    switch (status) {
      case 'submitted':
        return 'Pending Review';
      case 'rejected':
        return 'Rejected';
      case 'completed':
        return 'Approved';
      case 'payment_pending':
        return 'Payment Pending';
      case 'paid':
        return 'Completed & Paid';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'submitted':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.green;
      case 'payment_pending':
        return Colors.blue;
      case 'paid':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final submittedDate = widget.data['submitted_date'] != null
        ? dateFormat.format(DateTime.parse(widget.data['submitted_date']))
        : 'N/A';
    final deadline = widget.data['work_lastdate'] ?? 'No deadline';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: brandTeal.withOpacity(0.2),
                  backgroundImage: widget.data['user_photo'] != null
                      ? NetworkImage(widget.data['user_photo'])
                      : null,
                  child: widget.data['user_photo'] == null
                      ? Text(
                          widget.data['user_name'][0].toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: brandTeal,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.data['work_title'] ?? 'Unknown Project',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        widget.data['user_name'] ?? 'Unknown',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(
                      widget.data['application_status'],
                    ).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(widget.data['application_status']),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _statusColor(widget.data['application_status']),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // DETAILS
            Row(
              children: [
                Expanded(child: _detailItem('Submitted', submittedDate)),
                Expanded(child: _detailItem('Deadline', deadline)),
                Expanded(
                  child: _detailItem(
                    'Bid Amount',
                    '₹${widget.data['bid_amount']?.toString() ?? 'N/A'}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ACTIONS
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: brandNavy,
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    final status = widget.data['application_status'];
    final workLink = widget.data['submitted_work_link'];

    return Column(
      children: [
        if (status == 'rejected' && widget.data['rejected_reason'] != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "Reason: ${widget.data['rejected_reason']}",
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),

        if (workLink != null && status != 'rejected')
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(workLink);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Could not open file link."),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text("View Submitted Work"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: brandTeal,
                  side: const BorderSide(color: brandTeal),
                ),
              ),
            ),
          ),

        if (status == 'submitted')
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.onReject(widget.data),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: Text(
                    'Reject',
                    style: GoogleFonts.poppins(color: Colors.red, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => widget.onApprove(widget.data),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: Text(
                    'Approve',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          )
        else if (status == 'completed')
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onPayment(widget.data),
              style: ElevatedButton.styleFrom(backgroundColor: brandTeal),
              child: Text(
                'Process Payment',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Status: ${_statusLabel(status)}',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
