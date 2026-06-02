import 'package:client/client_complaint_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';

class ClientComplaintStatusPage extends StatefulWidget {
  const ClientComplaintStatusPage({super.key});

  @override
  State<ClientComplaintStatusPage> createState() => _ClientComplaintStatusPageState();
}

class _ClientComplaintStatusPageState extends State<ClientComplaintStatusPage> {
  final supabase = Supabase.instance.client;
  
  // Brand Colors
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  late Future<List<Map<String, dynamic>>> _complaintsFuture;

  @override
  void initState() {
    super.initState();
    _fetchComplaints();
  }

  void _fetchComplaints() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() {
      _complaintsFuture = supabase
          .from('tbl_complaints')
          .select()
          .eq('client_id', userId) // Using client_id for this module
          .order('complaint_date', ascending: false)
          .then((data) => List<Map<String, dynamic>>.from(data));
    });
  }

  // --- DELETE LOGIC ---
  Future<void> _deleteComplaint(int id) async {
    try {
      await supabase.from('tbl_complaints').delete().eq('complaint_id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ticket cancelled successfully"), backgroundColor: brandTeal),
        );
        _fetchComplaints(); 
      }
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Cancel Ticket?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: brandNavy)),
        content: Text("Are you sure you want to remove this pending support request?", style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Back", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteComplaint(id);
            },
            child: const Text("Confirm Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: brandNavy, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Support History", 
          style: GoogleFonts.poppins(color: brandNavy, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _complaintsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: brandTeal));
          }
          if (snapshot.hasError) {
            return Center(child: Text("Connection Error. Please try again.", style: GoogleFonts.poppins()));
          }

          final complaints = snapshot.data ?? [];
          if (complaints.isEmpty) return _buildEmptyState();

          return RefreshIndicator(
            onRefresh: () async => _fetchComplaints(),
            color: brandTeal,
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: complaints.length,
              itemBuilder: (context, index) => _buildComplaintCard(complaints[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> data) {
    final bool hasReply = data['complaint_reply'] != null && data['complaint_reply'].toString().isNotEmpty;
    final bool isPending = !hasReply; // Using logic from your previous card
    final int id = data['complaint_id'];
    
    String formattedDate = "N/A";
    if (data['complaint_date'] != null) {
      formattedDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(data['complaint_date']));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: brandNavy.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          trailing: isPending 
            ? IconButton(
                icon: const Icon(LucideIcons.trash2, size: 20, color: Colors.redAccent),
                onPressed: () => _confirmDelete(id),
              )
            : const Icon(Icons.keyboard_arrow_down_rounded, color: brandNavy),
          title: Text(data['complaint_title'] ?? "Support Request", 
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: brandNavy)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                _statusBadge(!isPending),
                const SizedBox(width: 12),
                Text(formattedDate, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 15),
                  _detailRow("Category", data['complaint_category'] ?? "General"),
                  const SizedBox(height: 12),
                  Text("Details:", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: brandNavy)),
                  const SizedBox(height: 4),
                  Text(data['complaint_content'] ?? "", style: GoogleFonts.poppins(fontSize: 13, color: Colors.blueGrey, height: 1.5)),
                  
                  if (hasReply) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: brandTeal.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: brandTeal.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.messageSquareQuote, size: 16, color: brandTeal),
                              const SizedBox(width: 8),
                              Text("Admin Response", 
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: brandTeal)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(data['complaint_reply'], 
                            style: GoogleFonts.poppins(fontSize: 13, color: brandNavy, height: 1.4)),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 15),
                    Text("⏳ Waiting for admin to review your request.", 
                      style: GoogleFonts.poppins(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.orange[800])),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(bool resolved) {
    final Color color = resolved ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(resolved ? "RESOLVED" : "PENDING", 
        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _detailRow(String label, String value) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(fontSize: 13, color: brandNavy),
        children: [
          TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: value, style: const TextStyle(color: Colors.blueGrey)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(color: brandTeal.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(LucideIcons.ticket, size: 50, color: brandTeal),
            ),
            const SizedBox(height: 25),
            Text("No Active Tickets", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: brandNavy)),
            const SizedBox(height: 10),
            Text(
              "You haven't raised any complaints yet. Need help with a project or account?",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.blueGrey, height: 1.5),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ClientComplaintPage()));
              },
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: Text("Raise a Complaint", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}