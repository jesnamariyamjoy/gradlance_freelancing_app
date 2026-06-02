import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentProfileViewPage extends StatefulWidget {
  final String studentId;

  const StudentProfileViewPage({super.key, required this.studentId});

  @override
  State<StudentProfileViewPage> createState() => _StudentProfileViewPageState();
}

class _StudentProfileViewPageState extends State<StudentProfileViewPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;

  Map<String, dynamic>? studentBasic;
  Map<String, dynamic>? studentDetails;
  List<dynamic> pastWorks = [];
  List<String> technicalSkills = [];
  List<String> softSkills = [];
  List<String> languages = [];
  double averageRating = 0.0;
  List<Map<String, dynamic>> userReviews = [];

  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
  }

  Future<void> _fetchStudentData() async {
    try {
      // Basic User Data
      studentBasic = await supabase
          .from('tbl_user')
          .select()
          .eq('id', widget.studentId)
          .single();

      // Complete Profile Details
      try {
        studentDetails = await supabase
            .from('tbl_user_details')
            .select()
            .eq('user_id', widget.studentId)
            .maybeSingle();
      } catch (_) {}

      // Skill Fetching
      try {
        final techResp = await supabase
            .from('tbl_user_technicalskill')
            .select('tbl_technicalskill(technicalskill_name)')
            .eq('user_id', widget.studentId);
        final softResp = await supabase
            .from('tbl_user_softskill')
            .select('tbl_softskill(softskill_name)')
            .eq('user_id', widget.studentId);
        final langResp = await supabase
            .from('tbl_user_language')
            .select('tbl_language(language_name)')
            .eq('user_id', widget.studentId);

        technicalSkills = (techResp as List)
            .map<String>(
              (e) => e['tbl_technicalskill']['technicalskill_name'].toString(),
            )
            .toList();
        softSkills = (softResp as List)
            .map<String>((e) => e['tbl_softskill']['softskill_name'].toString())
            .toList();
        languages = (langResp as List)
            .map<String>((e) => e['tbl_language']['language_name'].toString())
            .toList();
      } catch (e) {
        debugPrint("Error fetching skills: $e");
      }

      // Past Works
      try {
        final applications = await supabase.from('tbl_application').select('work_id').eq('user_id', widget.studentId).eq('application_status', 'accepted');
        final workIds = applications.map((e) => e['work_id']).toList();
        
        if (workIds.isNotEmpty) {
           pastWorks = await supabase.from('tbl_work').select().inFilter('work_id', workIds).eq('work_status', 'completed');
        }
      } catch (_) {}

      // Fetch Ratings and Calculate Average
      try {
        final ratingData = await supabase
            .from('tbl_rating')
            .select('ratig_value, rating_content')
            .eq('user_id', widget.studentId);
        
        if (ratingData.isNotEmpty) {
          double total = 0;
          for (var r in ratingData) {
            total += double.tryParse(r['ratig_value'].toString()) ?? 0.0;
          }
          averageRating = total / ratingData.length;
          userReviews = List<Map<String, dynamic>>.from(ratingData);
        }
      } catch (e) {
        debugPrint("Error fetching ratings: $e");
      }
      
      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _launchURL(String? urlString) async {
    if (urlString == null || urlString.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No URL provided')));
      return;
    }
    final Uri url = Uri.parse(
      urlString.startsWith('http') ? urlString : 'https://$urlString',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: brandGrey,
        body: Center(child: CircularProgressIndicator(color: brandTeal)),
      );
    }

    if (studentBasic == null) {
      return Scaffold(
        backgroundColor: brandGrey,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: const Center(child: Text("Student profile not found.")),
      );
    }

    return Scaffold(
      backgroundColor: brandGrey,
      appBar: AppBar(
        title: Text(
          "Freelancer Profile",
          style: GoogleFonts.poppins(
            color: brandNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: brandNavy),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 25),

            _buildSectionCard("About & Contact", [
              _infoTile(
                "Email",
                studentBasic?['user_email'] ?? "N/A",
                LucideIcons.mail,
              ),
              _infoTile(
                "Contact",
                studentBasic?['user_contact'] ?? "N/A",
                LucideIcons.phone,
              ),
              _infoTile(
                "College",
                studentBasic?['college'] ?? "Not Specified",
                LucideIcons.building,
              ),
              if (studentDetails != null) ...[
                _infoTile(
                  "Course",
                  studentDetails?['course'] ?? "N/A",
                  LucideIcons.book,
                ),
                _infoTile(
                  "Hourly Rate",
                  "₹${studentDetails?['hourly_rate'] ?? 0}/hr",
                  LucideIcons.wallet,
                ),
                _infoTile(
                  "Work Pref",
                  studentDetails?['work_preference'] ?? "Any",
                  LucideIcons.briefcase,
                ),
              ],
            ]),

            const SizedBox(height: 20),

            if (studentDetails != null) ...[
              _buildSectionCard("Academic Highlights", [
                _infoTile(
                  "Current Year",
                  studentDetails?['current_year'] ?? "N/A",
                  LucideIcons.calendar,
                ),
                _infoTile(
                  "Academic Year",
                  studentDetails?['expected_graduation'] ?? "N/A",
                  LucideIcons.graduationCap,
                ),
                _infoTile(
                  "Date of Birth",
                  studentDetails?['dob'] ?? "N/A",
                  LucideIcons.calendarDays,
                ),
                _infoTile(
                  "Gender",
                  studentDetails?['gender'] ?? "N/A",
                  LucideIcons.user,
                ),
              ]),
              const SizedBox(height: 20),

              _buildSectionCard("Location", [
                _infoTile(
                  "Nationality",
                  studentDetails?['nationality'] ?? "N/A",
                  LucideIcons.flag,
                ),
                _infoTile(
                  "State",
                  studentDetails?['state'] ?? "N/A",
                  LucideIcons.map,
                ),
                _infoTile(
                  "District",
                  studentDetails?['district'] ?? "N/A",
                  LucideIcons.mapPin,
                ),
                _infoTile(
                  "Place/Area",
                  studentDetails?['area'] ?? "N/A",
                  LucideIcons.mapPin,
                ),
                _infoTile(
                  "Pincode",
                  studentDetails?['pincode'] ?? "N/A",
                  LucideIcons.pin,
                ),
              ]),
              const SizedBox(height: 20),
            ],

            _buildSectionCard("Documents & Links", [
              if (studentDetails?['resume_url'] != null)
                ListTile(
                  onTap: () => _launchURL(studentDetails!['resume_url']),
                  leading: const Icon(LucideIcons.fileText, color: brandTeal),
                  title: Text(
                    "View Official Resume",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: brandTeal,
                    ),
                  ),
                  subtitle: Text(
                    "AI-Generated or Uploaded PDF",
                    style: GoogleFonts.poppins(fontSize: 11),
                  ),
                  trailing: const Icon(
                    LucideIcons.externalLink,
                    size: 16,
                    color: brandTeal,
                  ),
                ),
              if (studentDetails?['linkedin_url'] != null)
                _linkTile(
                  "LinkedIn Profile",
                  studentDetails!['linkedin_url'],
                  LucideIcons.linkedin,
                ),
              if (studentDetails?['github_url'] != null)
                _linkTile(
                  "GitHub Profile",
                  studentDetails!['github_url'],
                  LucideIcons.github,
                ),

              if (studentDetails?['resume_url'] == null &&
                  studentDetails?['github_url'] == null &&
                  studentDetails?['linkedin_url'] == null)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("No documents or links provided"),
                ),
            ]),

            const SizedBox(height: 20),

            // Enhanced Skills Section
            if (technicalSkills.isNotEmpty ||
                softSkills.isNotEmpty ||
                languages.isNotEmpty) ...[
              _buildSectionCard("Skills & Expertise", [
                if (technicalSkills.isNotEmpty)
                  _buildSkillCategory(
                    "Technical Skills",
                    technicalSkills,
                    Colors.blue,
                  ),
                if (softSkills.isNotEmpty)
                  _buildSkillCategory("Soft Skills", softSkills, Colors.orange),
                if (languages.isNotEmpty)
                  _buildSkillCategory("Languages", languages, Colors.green),
                if (studentDetails?['interests'] != null &&
                    studentDetails!['interests'].toString().isNotEmpty)
                  _buildSkillCategory(
                    "Other Interests",
                    studentDetails!['interests'].toString().split(','),
                    Colors.grey,
                  ),
              ]),
              const SizedBox(height: 20),
            ],

            const SizedBox(height: 20),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Completed Work Gallery",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: brandNavy,
                ),
              ),
            ),
            const SizedBox(height: 12),

            pastWorks.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          LucideIcons.imageOff,
                          color: Colors.grey,
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "No completed projects yet.",
                          style: GoogleFonts.poppins(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pastWorks.length,
                    itemBuilder: (context, index) {
                      final work = pastWorks[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: brandGrey),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: brandTeal.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.briefcase,
                              color: brandTeal,
                              size: 16,
                            ),
                          ),
                          title: Text(
                            work['work_title'] ?? 'Untitled Task',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            "Completed",
                            style: GoogleFonts.poppins(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            
            if (userReviews.isNotEmpty) ...[
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text("Client Reviews", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: brandNavy)),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: userReviews.length,
                itemBuilder: (context, index) {
                  final review = userReviews[index];
                  final val = double.tryParse(review['ratig_value'].toString()) ?? 0.0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: List.generate(5, (i) => Icon(
                            Icons.star_rounded, 
                            size: 14, 
                            color: i < val ? Colors.orange : Colors.grey[300]
                          )),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          review['rating_content'] ?? 'No feedback provided.',
                          style: GoogleFonts.poppins(fontSize: 13, color: brandNavy.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: brandNavy.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 45,
            backgroundColor: brandTeal.withOpacity(0.1),
            backgroundImage: studentBasic?['user_photo'] != null
                ? NetworkImage(studentBasic?['user_photo'])
                : null,
            child: studentBasic?['user_photo'] == null
                ? const Icon(LucideIcons.user, size: 40, color: brandTeal)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            studentBasic?['user_name'] ?? 'Unknown User',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: brandNavy,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Colors.orange, size: 18),
                const SizedBox(width: 4),
                Text(
                  "${averageRating.toStringAsFixed(1)} / 5.0",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.withOpacity(0.6)),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
          ),
          const Spacer(),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: brandNavy,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkTile(String title, String url, IconData icon) {
    return ListTile(
      onTap: () => _launchURL(url),
      leading: Icon(icon, color: brandNavy),
      title: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(LucideIcons.externalLink, size: 14),
    );
  }

  Widget _buildSkillCategory(String title, List<String> skills, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.8),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: skills
                .map(
                  (s) => Chip(
                    label: Text(
                      s.trim(),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    backgroundColor: color.withOpacity(0.1),
                    side: BorderSide.none,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
