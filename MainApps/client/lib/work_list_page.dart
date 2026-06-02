import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'application_list_page.dart';
import 'clientworkreviewpage.dart';

class WorkListPage extends StatefulWidget {
  const WorkListPage({super.key});

  @override
  State<WorkListPage> createState() => _WorkListPageState();
}

class _WorkListPageState extends State<WorkListPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<Map<String, dynamic>> works = [];

  // 🎨 BRAND COLORS
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  @override
  void initState() {
    super.initState();
    fetchWorks();
  }

  Future<void> fetchWorks() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('tbl_work')
          .select('''
            *,
            tbl_jobtype(
              jobtype_name,
              tbl_category(category_name)
            ),
            tbl_work_technicalskill(tbl_technicalskill(technicalskill_name)),
            tbl_work_softskill(tbl_softskill(softskill_name)),
            tbl_work_language(tbl_language(language_name)),
            tbl_application(application_status)
          ''')
          .eq('client_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          works = List<Map<String, dynamic>>.from(response);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Fetch works error: $e");
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error fetching works: $e")));
      }
    }
  }

  Future<void> openFile(String? url) async {
    if (url == null || url.isEmpty) return;
    final lowerUrl = url.toLowerCase();

    if (lowerUrl.endsWith('.png') ||
        lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.gif')) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      );
    } else if (lowerUrl.endsWith('.pdf')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text("PDF Viewer")),
            body: SfPdfViewer.network(url),
          ),
        ),
      );
    } else {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Cannot open file")));
      }
    }
  }

  Widget buildChipsList(List<String> items, Color color) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items
          .map(
            (e) =>
                Chip(label: Text(e, style: const TextStyle(fontSize: 11)), backgroundColor: color.withOpacity(0.1)),
          )
          .toList(),
    );
  }

  Widget _infoBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brandGrey,
      appBar: AppBar(
        title: Text(
          "My Posted Works",
          style: TextStyle(fontWeight: FontWeight.bold, color: brandNavy),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : works.isEmpty
          ? const Center(child: Text("No works found"))
          : RefreshIndicator(
              onRefresh: fetchWorks,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: works.length,
                itemBuilder: (context, index) {
                  final work = works[index];
                  String formattedDate = '';
                  final lastDateStr = work['work_lastdate'] ?? '';
                  try {
                    final lastDate = DateFormat(
                      'dd-MM-yyyy',
                    ).parse(lastDateStr);
                    formattedDate = DateFormat('dd MMM yyyy').format(lastDate);
                  } catch (_) {
                    formattedDate = lastDateStr;
                  }

                  final List techSkills =
                      (work['tbl_work_technicalskill'] as List?)
                          ?.map(
                            (e) =>
                                e['tbl_technicalskill']['technicalskill_name']
                                    .toString(),
                          )
                          .toList() ??
                      [];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: brandNavy.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: brandTeal.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.work_outline_rounded,
                                  color: brandTeal,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      work['work_title'] ?? "Untitled Work",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: brandNavy,
                                      ),
                                    ),
                                    Text(
                                      "Posted on ${DateFormat('dd MMM yyyy').format(DateTime.parse(work['created_at']))}",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (work['work_status'] == 'completed'
                                              ? Colors.green
                                              : brandTeal)
                                          .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  (work['work_status'] ?? 'Active')
                                      .toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: work['work_status'] == 'completed'
                                        ? Colors.green
                                        : brandTeal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            work['work_content'] ?? "",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                              height: 1.5,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _infoBadge(work['tbl_jobtype']?['tbl_category']?['category_name'] ?? 'N/A', Colors.orange),
                              const SizedBox(width: 8),
                              _infoBadge(work['tbl_jobtype']?['jobtype_name'] ?? 'N/A', Colors.purple),
                              const Spacer(),
                              Text(
                                "₹${work['budget'] ?? '0'}",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: brandTeal, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (techSkills.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: buildChipsList(
                                techSkills.cast<String>(),
                                Colors.blue,
                              ),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Deadline: $formattedDate",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              if (work['work_file'] != null)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: const Icon(Icons.attach_file, size: 16),
                                  label: const Text(
                                    "View File",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () => openFile(work['work_file']),
                                ),
                            ],
                          ),
                          const Divider(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ClientApplicationsPage(
                                          workId: work['work_id'],
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: brandNavy,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text(
                                    "View Applications",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (work['tbl_application'] != null &&
                                  (work['tbl_application'] as List).any(
                                    (a) =>
                                        a['application_status'] == 'accepted',
                                  ))
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const ClientWorkReviewPage(),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.indigo,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    child: const Text(
                                      "Manage Submission",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
