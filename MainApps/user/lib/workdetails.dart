import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkDetailsPage extends StatefulWidget {
  final String title;
  final String content;
  final String deadline;
  final String clientName;
  final String file;

  const WorkDetailsPage({
    super.key,
    required this.title,
    required this.content,
    required this.deadline,
    required this.clientName,
    required this.file,
  });

  @override
  State<WorkDetailsPage> createState() => _WorkDetailsPageState();
}

class _WorkDetailsPageState extends State<WorkDetailsPage> {

  // 🎨 BRAND COLORS
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: brandNavy, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Project Details",
          style: GoogleFonts.poppins(color: brandNavy, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER SECTION ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: brandGrey,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: brandNavy,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildQuickInfoGrid(),
                ],
              ),
            ),

            // --- CONTENT SECTION ---
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Description",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: brandNavy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.content,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: brandNavy.withOpacity(0.7),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // --- ATTACHMENT CARD ---
                  if (widget.file.isNotEmpty) _buildAttachmentCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickInfoGrid() {
    return Row(
      children: [
        _infoTile(Icons.business_rounded, "Client", widget.clientName),
        const SizedBox(width: 20),
        _infoTile(Icons.timer_outlined, "Deadline", widget.deadline),
      ],
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: brandNavy.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: brandTeal),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13, 
                fontWeight: FontWeight.w600, 
                color: brandNavy
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: brandTeal.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: brandTeal.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.description_outlined, color: brandTeal),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Project Brief / Files",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: brandNavy,
                  ),
                ),
                Text(
                  "Tap to download resources",
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => downloadFile(widget.file),
            icon: const Icon(Icons.download_for_offline_rounded, color: brandTeal, size: 30),
          ),
        ],
      ),
    );
  }
}