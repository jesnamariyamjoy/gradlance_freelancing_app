import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserComplaintPage extends StatefulWidget {
  const UserComplaintPage({super.key});

  @override
  State<UserComplaintPage> createState() => _UserComplaintPageState();
}

class _UserComplaintPageState extends State<UserComplaintPage> {
  final supabase = Supabase.instance.client;
  
  // Controllers
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  
  String _selectedCategory = 'Technical Issue';
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Technical Issue',
    'Payment Problem',
    'Client Dispute',
    'Project Delay',
    'Account Security',
    'Other'
  ];

  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);

  // --- DATABASE LOGIC ---
  Future<void> _submitComplaint() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      _showSnackBar("Please fill in all fields", Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = supabase.auth.currentUser;
      
      // Inserting into tbl_complaint using your exact column names
      await supabase.from('tbl_complaints').insert({
        'user_id': user!.id,
        'complaint_title': title,
        'complaint_category': _selectedCategory,
        'complaint_content': content,
        'complaint_date': DateTime.now().toIso8601String(),
        'complaint_status': 'Pending',
        'complaint_reply': null, // Remains null until Admin updates it
      });

      if (mounted) {
        _titleController.clear();
        _contentController.clear();
        _showSuccessDialog();
      }
    } catch (e) {
      debugPrint("Submission Error: $e");
      _showSnackBar("Submission failed. Please try again.", Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text("Support Center", 
          style: GoogleFonts.poppins(color: brandNavy, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: brandNavy),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Submit a Complaint", 
              style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: brandNavy)),
            const SizedBox(height: 8),
            Text("Give us the details and we'll get to work.", 
              style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14)),
            
            const SizedBox(height: 32),
            _buildLabel("Category"),
            _buildCategoryDropdown(),

            const SizedBox(height: 20),
            _buildLabel("Complaint Title"),
            _buildTextField(_titleController, "e.g., Payment milestone not released", maxLines: 1),

            const SizedBox(height: 20),
            _buildLabel("Detailed Description"),
            _buildTextField(_contentController, "Explain your issue in detail...", maxLines: 6),

            const SizedBox(height: 40),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, 
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: brandNavy, fontSize: 14)),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          items: _categories.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value, style: GoogleFonts.poppins(fontSize: 14)),
            );
          }).toList(),
          onChanged: (newValue) => setState(() => _selectedCategory = newValue!),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF4F7F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: brandTeal, width: 1.5), 
          borderRadius: BorderRadius.circular(12)
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandNavy,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        onPressed: _isSubmitting ? null : _submitComplaint,
        child: _isSubmitting 
          ? const CircularProgressIndicator(color: Colors.white)
          : Text("Submit Ticket", 
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating)
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 60, color: brandTeal),
            const SizedBox(height: 20),
            Text("Submitted Successfully", 
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Text("We'll review your complaint and get back to you soon.", 
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: brandNavy),
                onPressed: () => Navigator.pop(context), 
                child: const Text("Done"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
