import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:user/user_work_details_page.dart';

class SavedJobsPage extends StatefulWidget {
  const SavedJobsPage({super.key});

  @override
  State<SavedJobsPage> createState() => _SavedJobsPageState();
}

class _SavedJobsPageState extends State<SavedJobsPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> savedJobs = [];
  bool isLoading = true;

  // 🎨 GRADLANCE BRAND THEME
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  @override
  void initState() {
    super.initState();
    fetchSavedJobs();
  }

  // --- FETCH DATA ---
  Future<void> fetchSavedJobs() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      // Removed 'saved_id' from the select statement
      final res = await supabase
          .from('tbl_saved_job')
          .select('''
      work_id,
      tbl_work!inner (*) 
    ''')
          .eq('user_id', user.id);

      if (mounted) {
        setState(() {
          savedJobs = List<Map<String, dynamic>>.from(res);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching saved jobs: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- DELETE ALL ---
  Future<void> clearAllSaved() async {
    final uid = supabase.auth.currentUser!.id;
    try {
      await supabase.from('tbl_saved_job').delete().eq('user_id', uid);
      if (mounted) {
        setState(() => savedJobs.clear());
        _showSnackBar("All saved projects cleared", brandNavy);
      }
    } catch (e) {
      debugPrint("Error clearing jobs: $e");
    }
  }

  // --- DELETE SINGLE ---
  Future<void> removeSaved(int workId) async {
    final uid = supabase.auth.currentUser!.id;
    try {
      // Optimistic UI Update: Remove locally first for instant feedback
      setState(() {
        savedJobs.removeWhere((item) => item['work_id'] == workId);
      });

      await supabase
          .from('tbl_saved_job')
          .delete()
          .eq('user_id', uid)
          .eq('work_id', workId);

      if (mounted) {
        _showSnackBar("Removed from saved", brandTeal);
      }
    } catch (e) {
      debugPrint("Error removing job: $e");
      fetchSavedJobs(); // Reload if the delete failed
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          "Clear All?",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: brandNavy,
          ),
        ),
        content: Text(
          "Remove all projects from your saved list?",
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              clearAllSaved();
            },
            child: const Text("Clear All"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brandGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: brandNavy,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Saved Projects",
          style: GoogleFonts.poppins(
            color: brandNavy,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        actions: [
          if (savedJobs.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.delete_sweep_rounded,
                color: Colors.redAccent,
                size: 22,
              ),
              onPressed: _showClearConfirmation,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: brandTeal,
                strokeWidth: 3,
              ),
            )
          : RefreshIndicator(
              onRefresh: fetchSavedJobs,
              color: brandTeal,
              child: savedJobs.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      itemCount: savedJobs.length,
                      itemBuilder: (_, i) {
                        final job = savedJobs[i]['tbl_work'];
                        if (job == null) return const SizedBox.shrink();
                        return _buildJobCard(job);
                      },
                    ),
            ),
    );
  }

  Widget _buildJobCard(dynamic job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: brandNavy.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: brandNavy.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job['work_title'] ?? "Untitled",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: brandNavy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            job['tbl_client']?['client_name'] ??
                                'Unknown Client',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: brandNavy.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.bookmark_rounded,
                        color: brandTeal,
                        size: 26,
                      ),
                      onPressed: () => removeSaved(job['work_id']),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildInfoBadge(
                      job['tbl_jobtype']?['tbl_category']?['category_name'] ??
                          'General',
                      Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoBadge(
                      job['tbl_jobtype']?['jobtype_name'] ?? 'Task',
                      Colors.purple,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  job['work_content'] ?? "",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: brandNavy.withOpacity(0.6),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSkillTags(job['technical_skills']),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: brandNavy.withOpacity(0.02),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "₹${job['budget'] ?? '0'}",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: brandTeal,
                    fontSize: 14,
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserWorkDetailsPage(work: job),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        "Details",
                        style: GoogleFonts.poppins(
                          color: brandNavy,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: brandNavy,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillTags(dynamic skillsData) {
    if (skillsData == null || skillsData.toString().isEmpty)
      return const SizedBox.shrink();
    final skills = skillsData.toString().split(',').take(3);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: skills
          .map(
            (skill) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: brandGrey,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: brandNavy.withOpacity(0.05)),
              ),
              child: Text(
                skill.trim(),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: brandNavy.withOpacity(0.7),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildInfoBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_add_outlined,
            size: 70,
            color: brandNavy.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          Text(
            "Your list is empty",
            style: GoogleFonts.poppins(
              color: brandNavy,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Bookmark projects to track them here.",
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
