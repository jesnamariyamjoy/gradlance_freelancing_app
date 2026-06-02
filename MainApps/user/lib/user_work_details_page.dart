import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:user/proposal_submission_page.dart';
import 'package:url_launcher/url_launcher.dart';

class UserWorkDetailsPage extends StatefulWidget {
  final Map<String, dynamic> work;

  const UserWorkDetailsPage({super.key, required this.work});

  @override
  State<UserWorkDetailsPage> createState() => _UserWorkDetailsPageState();
}

class _UserWorkDetailsPageState extends State<UserWorkDetailsPage> {
  final supabase = Supabase.instance.client;

  // 🎨 BRAND COLORS
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  bool isApplied = false;
  bool isAssigned = false;
  bool isLoading = true;
  bool isProfileComplete = false;

  List<String> technical = [];
  List<String> soft = [];
  List<String> languages = [];

  @override
  void initState() {
    super.initState();
    fetchDetails();
  }

  bool isVerified = false;

  Future<void> fetchDetails() async {
    final workId = widget.work['work_id'];
    final uid = supabase.auth.currentUser!.id;

    try {
      // ✅ CHECK USER STATUS
      final userData = await supabase
          .from('tbl_user')
          .select('user_status')
          .eq('id', uid)
          .maybeSingle();
      isVerified = userData?['user_status'] == 'verified';

      // ✅ CHECK APPLICATION STATUS
      final app = await supabase
          .from('tbl_application')
          .select('application_id')
          .eq('work_id', workId)
          .eq('user_id', uid);

      isApplied = app.isNotEmpty;

      // ✅ CHECK IF WORK IS ASSIGNED (to anyone)
      final assignedCheck = await supabase
          .from('tbl_application')
          .select('application_id')
          .eq('work_id', workId)
          .eq('application_status', 'accepted');

      isAssigned = assignedCheck.isNotEmpty;

      // ✅ CHECK PROFILE COMPLETION
      final profile = await supabase
          .from('tbl_user_details')
          .select('profile_completed')
          .eq('user_id', uid)
          .maybeSingle();

      isProfileComplete =
          profile != null && profile['profile_completed'] == true;

      // 🛠 FETCH SKILLS & LANGUAGES PARALLEL
      final results = await Future.wait([
        supabase
            .from('tbl_work_technicalskill')
            .select('tbl_technicalskill(technicalskill_name)')
            .eq('work_id', workId),
        supabase
            .from('tbl_work_softskill')
            .select('tbl_softskill(softskill_name)')
            .eq('work_id', workId),
        supabase
            .from('tbl_work_language')
            .select('tbl_language(language_name)')
            .eq('work_id', workId),
      ]);

      technical = (results[0] as List)
          .map<String>(
            (e) =>
                e['tbl_technicalskill']?['technicalskill_name']?.toString() ??
                '',
          )
          .where((s) => s.isNotEmpty)
          .toList();
      soft = (results[1] as List)
          .map<String>(
            (e) => e['tbl_softskill']?['softskill_name']?.toString() ?? '',
          )
          .where((s) => s.isNotEmpty)
          .toList();
      languages = (results[2] as List)
          .map<String>(
            (e) => e['tbl_language']?['language_name']?.toString() ?? '',
          )
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint("Error fetching details: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> handleApply() async {
    if (!isVerified) {
      _showSnackBar("Account pending verification by Admin.", Colors.orange);
      return;
    }
    if (!isProfileComplete) {
      _showSnackBar("Please complete your profile first.", Colors.orange);
      return;
    }

    if (isApplied) {
      _showSnackBar("You have already applied for this project.", brandNavy);
      return;
    }

    // Navigate to ProposalSubmitPage
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProposalSubmitPage(workId: widget.work['work_id']),
      ),
    );

    if (result == true) {
      fetchDetails(); // Refresh status
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.work;

    return Scaffold(
      backgroundColor: brandGrey,
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
          "Work Details",
          style: GoogleFonts.poppins(
            color: brandNavy,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: brandTeal))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderCard(w),
                        const SizedBox(height: 25),
                        _buildSectionTitle("Description"),
                        const SizedBox(height: 8),
                        Text(
                          w['work_content']?.toString() ??
                              "No description provided.",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: brandNavy.withOpacity(0.7),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 25),
                        _buildSkillSection(
                          "Technical Expertise",
                          technical,
                          brandTeal,
                        ),
                        _buildSkillSection("Soft Skills", soft, Colors.orange),
                        _buildSkillSection(
                          "Languages",
                          languages,
                          Colors.green,
                        ),
                        const SizedBox(height: 10),
                        if (w['work_file'] != null &&
                            w['work_file'].toString().trim().isNotEmpty)
                          _buildAttachmentSection(w['work_file'].toString()),
                      ],
                    ),
                  ),
                ),
                _buildBottomAction(),
              ],
            ),
    );
  }

  Widget _buildHeaderCard(Map<String, dynamic> w) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: brandNavy.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: brandTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.work_rounded, color: brandTeal),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w['work_title'],
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: brandNavy,
                      ),
                    ),
                    Text(
                      w['tbl_client']?['client_name'] ?? 'Unknown Client',
                      style: GoogleFonts.poppins(
                        color: brandTeal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildInfoBadge(
                w['tbl_jobtype']?['tbl_category']?['category_name'] ??
                    'General',
                Colors.orange,
              ),
              const SizedBox(width: 8),
              _buildInfoBadge(
                w['tbl_jobtype']?['jobtype_name'] ?? 'Task',
                Colors.purple,
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem(
                Icons.calendar_today_rounded,
                "Deadline",
                w['work_lastdate'] ?? 'N/A',
              ),
              _buildInfoItem(
                Icons.payments_rounded,
                "Budget",
                "₹${w['budget'] ?? '0'}",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: brandNavy,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSkillSection(String title, List<String> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        const SizedBox(height: 12),
        items.isEmpty
            ? Text(
                "No skills specified",
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
              )
            : Wrap(
                spacing: 10,
                runSpacing: 10,
                children: items
                    .map(
                      (e) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withOpacity(0.2)),
                        ),
                        child: Text(
                          e,
                          style: GoogleFonts.poppins(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
        const SizedBox(height: 25),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: brandNavy,
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: brandNavy.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          onPressed: (isApplied || isAssigned) ? null : handleApply,
          style: ElevatedButton.styleFrom(
            backgroundColor: brandNavy,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Text(
            isAssigned
                ? "Work Assigned"
                : (isApplied ? "Already Applied" : "Apply for Project"),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentSection(String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Project Attachment"),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final trimmedUrl = url.trim();
            final isImage = ['.jpg', '.jpeg', '.png', '.webp', '.gif']
                .any((ext) => trimmedUrl.toLowerCase().contains(ext));

            if (isImage) {
              _showImageViewer(trimmedUrl);
            } else {
              _launchFileUrl(trimmedUrl);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: brandTeal.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: brandTeal.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.file_present_rounded, color: brandTeal),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "View Reference File",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: brandNavy,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 25),
      ],
    );
  }

  void _showImageViewer(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                        child: CircularProgressIndicator(color: Colors.white));
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.white,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 40),
                        const SizedBox(height: 12),
                        Text("Unable to load image",
                            style: GoogleFonts.poppins(color: brandNavy)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchFileUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          _showSnackBar(
              "Could not launch file. You may need a specific app to open this file type.",
              Colors.orange);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("Error opening file: $e", Colors.redAccent);
      }
    }
  }
}
