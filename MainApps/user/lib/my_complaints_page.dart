import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:user/complaint.dart';

class MyComplaintsPage extends StatefulWidget {
  const MyComplaintsPage({super.key});

  @override
  State<MyComplaintsPage> createState() => _MyComplaintsPageState();
}

class _MyComplaintsPageState extends State<MyComplaintsPage> {
  final supabase = Supabase.instance.client;
  
  // Brand Colors
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);

  // --- FUTURE LOGIC ---
  late Future<List<Map<String, dynamic>>> _complaintsFuture;

  @override
  void initState() {
    super.initState();
    _fetchComplaints();
  }
void _fetchComplaints() {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      setState(() {
        // Simply remove .execute(). The query itself returns the data directly.
        _complaintsFuture = supabase
            .from('tbl_complaints')
            .select()
            .eq('user_id', user.id)
            .order('complaint_date', ascending: false)
            .then((data) {
              // In the new SDK, 'data' is the list of results directly.
              // No need to check for response.error; errors are caught in the catch block.
              return List<Map<String, dynamic>>.from(data);
            });
      });
      print("Fetch initiated for user: ${user.id}");
    } catch (e) {
      debugPrint("Fetch Error: $e");
    }
  }

  // --- DELETE LOGIC ---
  Future<void> _deleteComplaint(int id) async {
    try {
      // Standardized table name to 'tbl_complaint'
      await supabase.from('tbl_complaints').delete().eq('complaint_id', id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Complaint removed"), backgroundColor: brandTeal),
        );
        _fetchComplaints(); // Refresh the list after deletion
      }
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Delete Ticket?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to remove this pending complaint?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Keep it")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteComplaint(id);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text("Support History", 
          style: GoogleFonts.poppins(color: brandNavy, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: brandNavy),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _complaintsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: brandTeal));
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error fetching data. Check connection."));
          }

          final complaints = snapshot.data ?? [];

          if (complaints.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async => _fetchComplaints(),
            color: brandTeal,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: complaints.length,
              itemBuilder: (context, index) {
                final data = complaints[index];
                return _buildComplaintCard(data);
              },
            ),
          );
        },
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildComplaintCard(Map<String, dynamic> data) {
    final bool isPending = data['complaint_status'].toString().toLowerCase() == 'pending';
    final int id = data['complaint_id'];
    
    // Safety check for date parsing
    String formattedDate = "N/A";
    if (data['complaint_date'] != null) {
      formattedDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(data['complaint_date']));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          trailing: isPending 
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _confirmDelete(id),
              )
            : const Icon(Icons.keyboard_arrow_down_rounded),
          
          title: Text(data['complaint_title'] ?? "No Title", 
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: brandNavy)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                _buildStatusBadge(data['complaint_status'] ?? "Unknown"),
                const SizedBox(width: 10),
                Text(formattedDate, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  _detailRow("Category", data['complaint_category'] ?? "General"),
                  const SizedBox(height: 12),
                  Text("Your Message:", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(data['complaint_content'] ?? "", style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700])),
                  
                  if (data['complaint_reply'] != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: brandTeal.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: brandTeal.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.reply_all_rounded, size: 16, color: brandTeal),
                              const SizedBox(width: 6),
                              Text("Admin Response", 
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: brandTeal)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(data['complaint_reply'], 
                            style: GoogleFonts.poppins(fontSize: 13, color: brandNavy)),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    Text("⏳ Our team is currently reviewing this ticket.", 
                      style: GoogleFonts.poppins(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.orange.shade700)),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = status.toLowerCase() == 'resolved' ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), 
        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        Text("$label: ", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(value, style: GoogleFonts.poppins(fontSize: 13)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: brandTeal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.assignment_turned_in_rounded, size: 60, color: brandTeal),
            ),
            const SizedBox(height: 24),
            Text("All Clear!", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: brandNavy)),
            const SizedBox(height: 8),
            Text(
              "You haven't filed any complaints yet. If you're facing an issue, let us know!",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => UserComplaintPage())
                );
                _fetchComplaints(); // Refresh when returning from the form
              },
              icon: const Icon(Icons.add_comment_rounded, size: 18),
              label: const Text("File a Complaint"),
              style: ElevatedButton.styleFrom(
                backgroundColor: brandNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}