import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkSubmissionPage extends StatefulWidget {
  final int applicationId;
  final String projectTitle;

  const WorkSubmissionPage({
    super.key, 
    required this.applicationId, 
    required this.projectTitle
  });

  @override
  State<WorkSubmissionPage> createState() => _WorkSubmissionPageState();
}

class _WorkSubmissionPageState extends State<WorkSubmissionPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _linkController = TextEditingController();
  final _notesController = TextEditingController();
  bool isSubmitting = false;

  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);

  Future<void> _submitWork() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);

    try {
      // 1. Get work_id for this application
      final appData = await supabase
          .from('tbl_application')
          .select('work_id')
          .eq('application_id', widget.applicationId)
          .single();
      
      final workData = await supabase
          .from('tbl_work')
          .select('work_id, client_id, work_title')
          .eq('work_id', appData['work_id'])
          .single();
      
      final workId = workData['work_id'];
      final clientId = workData['client_id'];
      final workTitle = workData['work_title'] ?? 'Untitled Project';

      // 1.5 Get current student name
      final user = supabase.auth.currentUser;
      final studentData = await supabase
          .from('tbl_user')
          .select('user_name')
          .eq('id', user!.id)
          .single();
      final studentName = studentData['user_name'] ?? 'A student';

      // 2. Update tbl_work with the submission link
      await supabase
          .from('tbl_work')
          .update({
            'submitted_work_link': _linkController.text,
            'work_status': 'submitted'
          })
          .eq('work_id', workId);

      // 3. Update application status to 'submitted'
      await supabase
          .from('tbl_application')
          .update({'application_status': 'submitted'})
          .eq('application_id', widget.applicationId);

      // 4. Notify Client
      await supabase.from('notifications').insert({
        'user_id': clientId,
        'title': "Work Submitted",
        'message': "$studentName has submitted the work for '$workTitle'. Please review it.",
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: brandTeal, content: Text("Work submitted successfully!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
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
          icon: const Icon(Icons.close, color: brandNavy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Submission Form", 
          style: GoogleFonts.poppins(color: brandNavy, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Project:", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
              Text(widget.projectTitle, 
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: brandNavy)),
              
              const SizedBox(height: 30),
              
              Text("Work Link", style: _labelStyle()),
              const SizedBox(height: 8),
              _buildTextField(_linkController, "e.g. Google Drive or GitHub Link", Icons.link, (v) => v!.isEmpty ? "Link is required" : null),
              
              const SizedBox(height: 20),
              
              Text("Notes", style: _labelStyle()),
              const SizedBox(height: 8),
              _buildTextField(_notesController, "Any instructions for the client?", Icons.chat_bubble_outline, null, maxLines: 5),
              
              const SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandNavy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: isSubmitting ? null : _submitWork,
                  child: isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text("Finish Submission", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _labelStyle() => GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: brandNavy);

  Widget _buildTextField(TextEditingController ctrl, String hint, IconData icon, String? Function(String?)? validator, {int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: brandTeal, size: 20),
        filled: true,
        fillColor: const Color(0xFFF4F7F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
