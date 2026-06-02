import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:user/applied_work_list_page.dart';
import 'package:user/saved_jobs_page.dart';
import 'package:user/user_work_details_page.dart';

class UserAvailableWorksPage extends StatefulWidget {
  const UserAvailableWorksPage({super.key});

  @override
  State<UserAvailableWorksPage> createState() => _UserAvailableWorksPageState();
}

class _UserAvailableWorksPageState extends State<UserAvailableWorksPage> {
  final supabase = Supabase.instance.client;

  // 🎨 BRAND COLORS
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  List<Map<String, dynamic>> works = [];
  Set<int> appliedWorks = {};
  Set<int> savedWorks = {};
  bool isLoading = true;
  String searchText = '';

  @override
  void initState() {
    super.initState();
    fetchWorks();
  }

  Future<void> fetchWorks() async {
    try {
      // Fetch available works
      final res = await supabase.from('tbl_work').select('''
        *,
        tbl_client:client_id (client_name),
        tbl_jobtype (
          jobtype_name,
          tbl_category (category_name)
        )
      ''').eq('work_status', 'approved').order('work_id', ascending: false);

      // Fetch works already assigned/accepted to others to hide them
      final assignedRes = await supabase
          .from('tbl_application')
          .select('work_id')
          .eq('application_status', 'accepted');
          
      final assignedIds =
          assignedRes.map<int>((e) => e['work_id'] as int).toSet();

      if (mounted) {
        setState(() {
          works = List<Map<String, dynamic>>.from(res)
              .where((w) => !assignedIds.contains(w['work_id']))
              .toList();
        });
      }
      
      await fetchAppliedWorks();
      await fetchSavedWorks();
    } catch (e) {
      debugPrint("Fetch Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> fetchSavedWorks() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    
    final res = await supabase
        .from('tbl_saved_job')
        .select('work_id')
        .eq('user_id', user.id);
    
    if (mounted) {
      setState(() {
        savedWorks = res.map<int>((e) => e['work_id'] as int).toSet();
      });
    }
  }

  Future<void> fetchAppliedWorks() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final res = await supabase
        .from('tbl_application')
        .select('work_id')
        .eq('user_id', user.id);
        
    if (mounted) {
      setState(() {
        appliedWorks = res.map<int>((e) => e['work_id'] as int).toSet();
      });
    }
  }

  Future<void> toggleSave(int workId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      if (savedWorks.contains(workId)) {
        // Remove if already saved
        await supabase
            .from('tbl_saved_job')
            .delete()
            .eq('user_id', userId)
            .eq('work_id', workId);
        
        setState(() {
          savedWorks.remove(workId);
        });
        _showSnackBar("Project removed from saved", Colors.orange);
      } else {
        // Add to saved
        await supabase.from('tbl_saved_job').insert({
          'user_id': userId,
          'work_id': workId,
        });

        setState(() {
          savedWorks.add(workId);
        });
        _showSnackBar("Project saved to your list!", brandTeal);
      }
    } catch (e) {
      debugPrint("Error toggling save: $e");
      _showSnackBar("Action failed", Colors.redAccent);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<Map<String, dynamic>> get filteredWorks {
    if (searchText.isEmpty || searchText.toLowerCase() == "all") return works;
    return works.where((w) {
      final title = w['work_title'].toString().toLowerCase();
      final skills = (w['technical_skills'] ?? '').toString().toLowerCase();
      final category = (w['tbl_jobtype']?['tbl_category']?['category_name'] ?? '').toString().toLowerCase();
      
      return title.contains(searchText.toLowerCase()) ||
          skills.contains(searchText.toLowerCase()) ||
          category.contains(searchText.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brandGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        title: Text(
          "Available Works",
          style: GoogleFonts.poppins(
            color: brandNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border_rounded, color: brandNavy),
            tooltip: "Saved Jobs",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedJobsPage()),
              );
              fetchWorks(); // Refresh after coming back
            },
          ),
          IconButton(
            icon: const Icon(Icons.assignment_turned_in_outlined, color: brandNavy),
            tooltip: "Applied Jobs",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppliedWorkListPage()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: brandTeal))
          : RefreshIndicator(
              onRefresh: fetchWorks,
              color: brandTeal,
              child: Column(
                children: [
                  _buildSearchBar(),
                  _buildQuickFilters(),
                  Expanded(
                    child: filteredWorks.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredWorks.length,
                            itemBuilder: (_, i) => _buildWorkCard(filteredWorks[i]),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: brandNavy.withOpacity(0.05), blurRadius: 10),
                ],
              ),
              child: TextField(
                onChanged: (v) => setState(() => searchText = v),
                decoration: InputDecoration(
                  hintText: "Search skills or categories...",
                  hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: brandTeal),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: brandNavy,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilters() {
    final List<String> tags = ["All", "Web", "Design", "Mobile", "Writing"];
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: tags.length,
        itemBuilder: (context, index) {
          final isSelected = (searchText.isEmpty && index == 0) || 
                             (searchText.toLowerCase() == tags[index].toLowerCase());
          return GestureDetector(
            onTap: () => setState(() => searchText = (index == 0 ? '' : tags[index])),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? brandNavy : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? brandNavy : brandNavy.withOpacity(0.1),
                ),
              ),
              child: Center(
                child: Text(
                  tags[index],
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : brandNavy.withOpacity(0.6),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkCard(Map<String, dynamic> w) {
    final bool isApplied = appliedWorks.contains(w['work_id']);
    final bool isSaved = savedWorks.contains(w['work_id']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: brandNavy.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  w['work_title'] ?? 'No Title',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: brandNavy,
                  ),
                ),
              ),
              IconButton(
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: Icon(
                  isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: isSaved ? brandTeal : brandNavy.withOpacity(0.3),
                ),
                onPressed: () => toggleSave(w['work_id']),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.business_center_outlined, size: 14, color: brandTeal),
              const SizedBox(width: 5),
              Text(
                w['tbl_client']?['client_name'] ?? 'Unknown Client',
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
              ),
              const Spacer(),
              if (isApplied) _buildInfoBadge("Applied", Colors.green),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoBadge(w['tbl_jobtype']?['tbl_category']?['category_name'] ?? 'General', Colors.orange),
              const SizedBox(width: 8),
              _buildInfoBadge(w['tbl_jobtype']?['jobtype_name'] ?? 'Task', Colors.purple),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            w['work_content'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: brandNavy.withOpacity(0.7),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (w['technical_skills'] ?? '')
                .toString()
                .split(',')
                .where((s) => s.trim().isNotEmpty)
                .take(3)
                .map((skill) => _buildSkillTag(skill.trim()))
                .toList(),
          ),
          const SizedBox(height: 15),
          const Divider(height: 1),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Budget: ₹${w['budget'] ?? 'N/A'}",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: brandTeal,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    "Ends: ${w['work_lastdate'] ?? 'N/A'}",
                    style: GoogleFonts.poppins(
                      color: brandNavy.withOpacity(0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UserWorkDetailsPage(work: w)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text("View Details"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkillTag(String skill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: brandGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        skill,
        style: GoogleFonts.poppins(fontSize: 10, color: brandNavy.withOpacity(0.7)),
      ),
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
        style: GoogleFonts.poppins(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 60, color: brandNavy.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
            "No matching works found",
            style: GoogleFonts.poppins(color: brandNavy.withOpacity(0.4), fontSize: 14),
          ),
        ],
      ),
    );
  }
}