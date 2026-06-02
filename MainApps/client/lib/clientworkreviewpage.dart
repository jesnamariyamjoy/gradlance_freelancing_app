import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:client/rate_user_page.dart';
import 'package:client/screens/student_profile_view_page.dart';

class ClientWorkReviewPage extends StatefulWidget {
  const ClientWorkReviewPage({super.key});

  @override
  State<ClientWorkReviewPage> createState() => _ClientWorkReviewPageState();
}

class _ClientWorkReviewPageState extends State<ClientWorkReviewPage> {
  final supabase = Supabase.instance.client;

  // 🎨 GRADLANCE BRAND COLORS
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);
  static const Color accentOrange = Color(0xFFFF9F43);

  bool isLoading = true;
  List submissions = [];

  @override
  void initState() {
    super.initState();
    fetchStudentSubmissions();
  }

  Future<void> fetchStudentSubmissions() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final clientId = supabase.auth.currentUser!.id;

      // Adjusted query for typical Supabase relational structure
      final response = await supabase
          .from('tbl_work')
          .select('''
             work_id, 
            work_title, 
            work_file, 
            submitted_work_link,
            work_lastdate, 
            work_status,
            tbl_application (
              application_status,
              work_progress,
              user:tbl_user (
                id,
                user_name,
                user_photo
              )
            )
          ''')
          .eq('client_id', clientId)
          .order('work_lastdate', ascending: true);

      setState(() {
        submissions = response;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showSnackBar("Error fetching data: $e", Colors.redAccent);
      }
    }
  }

  Future<void> updateStatus(int workId, String status) async {
    try {
      await supabase
          .from('tbl_work')
          .update({'work_status': status})
          .eq('work_id', workId);

      fetchStudentSubmissions();
      _showSnackBar("Work $status successfully", brandTeal);
    } catch (e) {
      _showSnackBar("Update failed: $e", Colors.redAccent);
    }
  }



  Future<void> openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar("Could not open file", Colors.orange);
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

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return brandTeal;
      case 'rejected':
        return Colors.redAccent;
      default:
        return accentOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brandGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          "My Works",
          style: GoogleFonts.poppins(
            color: brandNavy,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: brandTeal))
          : submissions.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              color: brandTeal,
              onRefresh: fetchStudentSubmissions,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: submissions.length,
                itemBuilder: (context, index) {
                  final submission = submissions[index];
                  // Extract the accepted student from applications
                  final List apps = submission['tbl_application'] ?? [];
                  final acceptedApp = apps.firstWhere(
                    (a) =>
                        a['application_status'] == 'accepted' ||
                        a['application_status'] == 'submitted' ||
                        a['application_status'] == 'verified' ||
                        a['application_status'] == 'paid',
                    orElse: () => null,
                  );
                  final student = acceptedApp != null
                      ? acceptedApp['user']
                      : {};
                  final studentName = student['user_name'] ?? 'Freelancer';
                  DateTime parsedDate;
                  try {
                    parsedDate = DateTime.parse(submission['work_lastdate']);
                  } catch (e) {
                    try {
                      parsedDate = DateFormat(
                        'dd-MM-yyyy',
                      ).parse(submission['work_lastdate']);
                    } catch (e) {
                      try {
                        parsedDate = DateFormat(
                          'MM-dd-yyyy',
                        ).parse(submission['work_lastdate']);
                      } catch (e) {
                        parsedDate = DateTime.now(); // Fallback
                      }
                    }
                  }
                  final dueDate = DateFormat('dd MMM yyyy').format(parsedDate);
                  final status = (submission['work_status'] ?? 'pending')
                      .toString()
                      .toLowerCase();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: brandNavy.withOpacity(0.05)),
                      boxShadow: [
                        BoxShadow(
                          color: brandNavy.withOpacity(0.03),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Work title & Date
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      submission['work_title'] ??
                                          'Untitled Task',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: brandNavy,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    dueDate,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Student identity section
                              GestureDetector(
                                onTap: () {
                                  if (student['id'] != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => StudentProfileViewPage(
                                          studentId: student['id'],
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: brandTeal.withOpacity(
                                        0.1,
                                      ),
                                      child: const Icon(
                                        LucideIcons.user,
                                        size: 14,
                                        color: brandTeal,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      studentName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.blueGrey,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                    const Spacer(),
                                    // Status Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: getStatusColor(
                                          status,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: GoogleFonts.poppins(
                                          color: getStatusColor(status),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Progress Section
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Progress", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: brandNavy)),
                                  Text("${acceptedApp?['work_progress'] ?? 0}%", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: brandTeal)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: (acceptedApp?['work_progress'] ?? 0) / 100,
                                  minHeight: 6,
                                  backgroundColor: brandTeal.withOpacity(0.1),
                                  valueColor: const AlwaysStoppedAnimation(brandTeal),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Bottom Action Bar
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: brandGrey.withOpacity(0.5),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                          ),
                          child: Row(
                            children: [
                                if ((submission['work_file'] != null && submission['work_file'].toString().isNotEmpty) || (submission['submitted_work_link'] != null && submission['submitted_work_link'].toString().isNotEmpty))
                                  TextButton.icon(
                                    icon: const Icon(
                                      LucideIcons.paperclip,
                                      size: 18,
                                    ),
                                    label: Text(
                                      "View Work File/Link",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    onPressed: () {
                                      if (status == 'paid' || status == 'completed') {
                                        openFile(submission['work_file'] ?? submission['submitted_work_link']);
                                      } else {
                                        _showSnackBar("Please complete payment to view the file", Colors.orange);
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: brandTeal,
                                    ),
                                  )
                                else
                                  Text(
                                    "No file attached",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                const Spacer(),
                                if (status != 'approved') ...[
                                  TextButton(
                                    onPressed: () => updateStatus(
                                      submission['work_id'],
                                      'rejected',
                                    ),
                                    child: Text(
                                      "Reject",
                                      style: GoogleFonts.poppins(
                                        color: Colors.redAccent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (acceptedApp != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => RateUserPage(
                                              workData: submission,
                                              userData: student,
                                            ),
                                          ),
                                        ).then((_) => fetchStudentSubmissions());
                                      } else {
                                        _showSnackBar("No accepted application for this work", Colors.orange);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: brandNavy,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                    ),
                                    child: Text(
                                      "Approve & Pay",
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.fileX, size: 64, color: brandNavy.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
            "No submissions to review",
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
