import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:user/workdetails.dart';

class WorkListPage extends StatefulWidget {
  const WorkListPage({super.key});

  @override
  State<WorkListPage> createState() => _WorkListPageState();
}

class _WorkListPageState extends State<WorkListPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List works = [];

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
  try {
    setState(() => isLoading = true);

    final response = await supabase
        .from('tbl_work')
        .select('*, tbl_client:client_id (client_name)')
        .order('work_lastdate', ascending: true);

    print("Fetched works length: ${response.length}");
    print("Fetched works data: $response");

    if (mounted) {
      setState(() {
        works = response ?? [];
        isLoading = false;
      });
    }
  } catch (e) {
    print("Error fetching works: $e");
    if (mounted) setState(() => isLoading = false);
    _showSnackBar("Error fetching works", Colors.red);
  }
}
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> openFile(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar("Cannot open file link", brandNavy);
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
          "Available Opportunities",
          style: GoogleFonts.poppins(
            color: brandNavy,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: fetchWorks,
            icon: const Icon(Icons.refresh_rounded, color: brandNavy),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: brandTeal))
          : works.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              color: brandTeal,
              onRefresh: fetchWorks,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                itemCount: works.length,
                itemBuilder: (context, index) {
                  final work = works[index];
                  return _buildWorkCard(work);
                },
              ),
            ),
    );
  }

  Widget _buildWorkCard(Map<String, dynamic> work) {
    // Date parsing
    String formattedDate = '';
    final lastDateStr = work['work_lastdate'] ?? '';
    try {
      final lastDate = DateFormat('dd-MM-yyyy').parse(lastDateStr);
      formattedDate = DateFormat('dd MMM yyyy').format(lastDate);
    } catch (_) {
      formattedDate = lastDateStr;
    }

    final clientName = work['tbl_client']?['client_name'] ?? 'Unknown Client';
    final hasFile = work['work_file'] != null && work['work_file'].toString().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: brandTeal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.work_outline_rounded,
                          color: brandTeal,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              work['work_title'] ?? "Untitled Work",
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: brandNavy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.business_rounded, size: 14, color: brandTeal),
                                const SizedBox(width: 6),
                                Text(
                                  clientName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.calendar_month_outlined, size: 14, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  "Deadline: $formattedDate",
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    work['work_content'] ?? "",
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: brandNavy.withOpacity(0.6),
                      height: 1.5,
                    ),
                  ),
                  if (hasFile) ...[
                    const SizedBox(height: 16),
                    _buildAttachmentPreview(work['work_file']),
                  ],
                ],
              ),
            ),
            _buildActionRow(work, clientName),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview(String fileUrl) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: brandTeal.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: brandTeal.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: brandTeal.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.description_outlined, color: brandTeal, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Project Files Available",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: brandNavy,
                  ),
                ),
                Text(
                  "Tap to view/download resources",
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => openFile(fileUrl),
            icon: const Icon(Icons.download_rounded, color: brandTeal, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(Map<String, dynamic> work, String clientName) {
    final bool hasFile =
        work['work_file'] != null && work['work_file'].toString().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: brandNavy.withOpacity(0.02),
        border: Border(top: BorderSide(color: brandNavy.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkDetailsPage(
                    title: work['work_title'] ?? 'Untitled Work',
                    content: work['work_content'] ?? '',
                    deadline: work['work_lastdate'] ?? '',
                    clientName: clientName,
                    file: work['work_file'] ?? '',
                  ),
                ),
              );
            },
            child: Text(
              "View Details",
              style: GoogleFonts.poppins(
                color: brandTeal,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          if (hasFile)
            IconButton(
              tooltip: "Download File",
              onPressed: () => openFile(work['work_file']),
              icon: const Icon(
                Icons.download_rounded,
                color: brandNavy,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 80,
            color: brandNavy.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          Text(
            "No works found at the moment",
            style: GoogleFonts.poppins(
              color: brandNavy.withOpacity(0.4),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
