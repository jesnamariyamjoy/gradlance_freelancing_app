import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientComplaintPage extends StatefulWidget {
  const ClientComplaintPage({super.key});

  @override
  State<ClientComplaintPage> createState() => _ClientComplaintPageState();
}

class _ClientComplaintPageState extends State<ClientComplaintPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  
  String _selectedCategory = 'Quality Issue';
  final List<String> _categories = [
    'Quality Issue',
    'Deadline Missed',
    'Communication Gap',
    'Payment Dispute',
    'Unprofessional Behavior',
    'Other'
  ];

  bool _isSubmitting = false;

  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final userId = supabase.auth.currentUser!.id;

      await supabase.from('tbl_complaints').insert({
        'complaint_category': _selectedCategory,
        'complaint_title': _titleController.text.trim(),
        'complaint_content': _contentController.text.trim(),
        'complaint_date': DateTime.now().toIso8601String(),
        'client_id': userId,
        'complaint_status': 'Pending', 
      });

      _showSnackBar("Complaint submitted successfully.", brandTeal);
      Future.delayed(const Duration(seconds: 1), () => Navigator.pop(context));
      
    } catch (e) {
      _showSnackBar("Submission failed: $e", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: brandNavy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Submit Complaint", style: GoogleFonts.poppins(color: brandNavy, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- CATEGORY ---
              _buildLabel("Category"),
              const SizedBox(height: 8),
              _buildDropdown(),
              
              const SizedBox(height: 24),

              // --- TITLE (SINGLE LINE) ---
              _buildLabel("Complaint Title"),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                maxLines: 1, // 🔹 Forces single line
                textInputAction: TextInputAction.next, // Moves to next field on "Enter"
                validator: (val) => val!.isEmpty ? "Please enter a title" : null,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _inputDecoration("e.g. Late submission for Project X"),
              ),

              const SizedBox(height: 24),

              // --- DESCRIPTION (MULTI LINE) ---
              _buildLabel("Detailed Description"),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contentController,
                maxLines: 5, // 🔹 Allows for detailed explanation
                keyboardType: TextInputType.multiline,
                validator: (val) => val!.isEmpty ? "Please provide full details" : null,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: _inputDecoration("Explain the situation in detail..."),
              ),

              const SizedBox(height: 40),

              // --- BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitComplaint,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandNavy,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : Text("Submit Report", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: brandNavy));
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: brandGrey, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          icon: const Icon(LucideIcons.chevronDown, size: 18),
          items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: GoogleFonts.poppins(fontSize: 14)))).toList(),
          onChanged: (val) => setState(() => _selectedCategory = val!),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
      filled: true,
      fillColor: brandGrey,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }
}
