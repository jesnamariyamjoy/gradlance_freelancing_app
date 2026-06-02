import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkPage extends StatefulWidget {
  const WorkPage({super.key});

  @override
  State<WorkPage> createState() => _WorkPageState();
}

class _WorkPageState extends State<WorkPage> {
  final _formKey = GlobalKey<FormState>();

  // 🎨 GRADLANCE BRAND COLORS
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  final titleController = TextEditingController();
  final contentController = TextEditingController();
  final dateController = TextEditingController();
  final budgetController = TextEditingController();

  File? selectedFile;
  bool isLoading = false;
  bool isAIGenerating = false;

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> technicalSkills = [];
  List<Map<String, dynamic>> softSkills = [];
  List<Map<String, dynamic>> languages = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> jobTypes = [];

  final Set<int> selectedTech = {};
  final Set<int> selectedSoft = {};
  final Set<int> selectedLang = {};
  String? selectedCategoryId;
  String? selectedJobTypeId;

  @override
  void initState() {
    super.initState();
    fetchSkills();
  }

  Future<void> fetchSkills() async {
    technicalSkills = List<Map<String, dynamic>>.from(await supabase.from('tbl_technicalskill').select());
    softSkills = List<Map<String, dynamic>>.from(await supabase.from('tbl_softskill').select());
    languages = List<Map<String, dynamic>>.from(await supabase.from('tbl_language').select());
    categories = List<Map<String, dynamic>>.from(await supabase.from('tbl_category').select());
    if (mounted) setState(() {});
  }

  Future<void> fetchJobTypes(String categoryId) async {
    jobTypes = List<Map<String, dynamic>>.from(
      await supabase.from('tbl_jobtype').select().eq('category_id', categoryId)
    );
    if (mounted) setState(() => selectedJobTypeId = null);
  }

  Future<bool> isClientApproved() async {
    final res = await supabase
        .from('tbl_client')
        .select('client_status, is_active')
        .eq('client_id', supabase.auth.currentUser!.id)
        .single();

    return res['client_status'] == 'approved' && res['is_active'] == true;
  }

  Future<void> _generateAIDescription() async {
    if (titleController.text.trim().isEmpty) {
      _showSnackBar("Please enter a Project Title first for AI context.", Colors.orange);
      return;
    }
    setState(() => isAIGenerating = true);
    await Future.delayed(const Duration(seconds: 2)); // Simulate API call to Gemini
    
    final title = titleController.text.trim();
    // Prompt structure template
    final aiDraft = '''
Looking for a skilled professional to assist with "$title". 
The ideal candidate should have strong problem-solving abilities and a history of delivering high-quality results on time.

Key Responsibilities:
- Execute tasks related to $title with precision.
- Maintain clear communication regarding progress and roadblocks.
- Deliver the final structured output by the expected deadline.

If you have experience in this domain, we encourage you to apply and attach your portfolio/relevant past work.
'''.trim();

    setState(() {
      contentController.text = aiDraft;
      isAIGenerating = false;
    });
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: brandTeal, onPrimary: Colors.white, onSurface: brandNavy),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      dateController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      selectedFile = File(result.files.single.path!);
      setState(() {});
    }
  }

  Future<void> submitWork() async {
    final approved = await isClientApproved();
    if (!approved) {
      _showSnackBar("Your account is not approved by admin yet", Colors.redAccent);
      return;
    }
    if (!_formKey.currentState!.validate() ||
        selectedFile == null ||
        selectedTech.isEmpty ||
        selectedSoft.isEmpty ||
        selectedLang.isEmpty ||
        selectedCategoryId == null ||
        selectedJobTypeId == null) {
      _showSnackBar("Please complete all fields and selections", Colors.orangeAccent);
      return;
    }

    setState(() => isLoading = true);

    try {
      // 1. Check Approval
      final approved = await isClientApproved();
      if (!approved) {
        _showSnackBar("Contact Admin: Your account is pending verification.", Colors.orange);
        setState(() => isLoading = false);
        return;
      }

      // 2. Check Subscription
      final userId = supabase.auth.currentUser!.id;
      final sub = await supabase
          .from('tbl_subscription')
          .select('*, tbl_subscription_plan(*)')
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();

      if (sub == null) {
        _showSnackBar("Active subscription required to post work.", Colors.redAccent);
        setState(() => isLoading = false);
        return;
      }

      final plan = sub['tbl_subscription_plan'];
      final maxPosts = plan['max_count'] as int;

      if (maxPosts != 0) { // 0 means unlimited
        final posRes = await supabase
            .from('tbl_work')
            .select('work_id')
            .eq('client_id', userId)
            .neq('work_status', 'rejected');
        
        if (posRes.length >= maxPosts) {
          _showSnackBar("Post limit reached for '${plan['plan_name']}'. Please upgrade.", Colors.orange);
          setState(() => isLoading = false);
          return;
        }
      }

      // 3. Continue with upload
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${selectedFile!.path.split('/').last}';
      await supabase.storage.from('work_files').upload(fileName, selectedFile!);
      final fileUrl = supabase.storage.from('work_files').getPublicUrl(fileName);

      final work = await supabase.from('tbl_work').insert({
        'client_id': supabase.auth.currentUser!.id,
        'work_title': titleController.text.trim(),
        'work_content': contentController.text.trim(),
        'work_lastdate': dateController.text,
        'work_file': fileUrl,
        'work_status': 'pending', // Default status
        'jobtype_id': int.tryParse(selectedJobTypeId ?? '') ?? 0,
        'budget': double.tryParse(budgetController.text.trim()) ?? 0,
      }).select().single();

      final workId = work['work_id'];

      await supabase.from('tbl_work_technicalskill').insert(
          selectedTech.map((e) => {'work_id': workId, 'technicalskill_id': e}).toList());
      await supabase.from('tbl_work_softskill').insert(
          selectedSoft.map((e) => {'work_id': workId, 'softskill_id': e}).toList());
      await supabase.from('tbl_work_language').insert(
          selectedLang.map((e) => {'work_id': workId, 'language_id': e}).toList());

      _showSnackBar("Work published successfully", brandTeal);
      _clearForm();
    } catch (e) {
      _showSnackBar("Error: $e", Colors.redAccent);
    }
    if (mounted) setState(() => isLoading = false);
  }

  void _clearForm() {
    titleController.clear();
    contentController.clear();
    dateController.clear();
    budgetController.clear();
    selectedFile = null;
    selectedTech.clear();
    selectedSoft.clear();
    selectedLang.clear();
    selectedCategoryId = null;
    selectedJobTypeId = null;
    jobTypes = [];
    setState(() {});
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: brandNavy.withOpacity(0.5), fontSize: 14),
      prefixIcon: Icon(icon, color: brandNavy, size: 20),
      filled: true,
      fillColor: brandGrey,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: brandTeal, width: 1.5)),
    );
  }

  Widget buildChips(String title, List<Map<String, dynamic>> data, Set<int> selected, String labelKey, String idKey) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: brandNavy)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: data.map((item) {
            final id = item[idKey];
            final isSelected = selected.contains(id);
            return FilterChip(
              label: Text(item[labelKey]),
              labelStyle: GoogleFonts.poppins(
                fontSize: 12,
                color: isSelected ? Colors.white : brandNavy,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              selected: isSelected,
              onSelected: (v) => setState(() => v ? selected.add(id) : selected.remove(id)),
              selectedColor: brandTeal,
              checkmarkColor: Colors.white,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: isSelected ? brandTeal : brandNavy.withOpacity(0.1)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: brandNavy, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Post New Work", style: GoogleFonts.poppins(color: brandNavy, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: brandNavy.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: titleController,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: _inputStyle("Project Title", Icons.title_rounded),
                      validator: (v) => v!.isEmpty ? "Title is required" : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Project Description", style: GoogleFonts.poppins(color: brandNavy, fontSize: 13, fontWeight: FontWeight.w600)),
                        TextButton.icon(
                          onPressed: isAIGenerating ? null : _generateAIDescription,
                          icon: isAIGenerating 
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: brandTeal))
                            : const Icon(Icons.auto_awesome, color: brandTeal, size: 16),
                          label: Text("AI Suggestion", style: GoogleFonts.poppins(color: brandTeal, fontWeight: FontWeight.bold, fontSize: 13)),
                        )
                      ],
                    ),
                    TextFormField(
                      controller: contentController,
                      maxLines: 5,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Describe the requirements, deliverables, and expectations...",
                        hintStyle: GoogleFonts.poppins(color: brandNavy.withOpacity(0.4), fontSize: 13),
                        filled: true,
                        fillColor: brandGrey,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: brandTeal, width: 1.5)),
                      ),
                      validator: (v) => v!.isEmpty ? "Description is required" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: dateController,
                      readOnly: true,
                      onTap: pickDate,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: _inputStyle("Application Deadline", Icons.calendar_month_outlined),
                      validator: (v) => v!.isEmpty ? "Deadline is required" : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategoryId,
                      style: GoogleFonts.poppins(fontSize: 14, color: brandNavy),
                      decoration: _inputStyle("Category", Icons.category_rounded),
                      items: categories.map((cat) {
                        return DropdownMenuItem(
                          value: cat['category_id'].toString(),
                          child: Text(cat['category_name']),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedCategoryId = val;
                          fetchJobTypes(val!);
                        });
                      },
                      validator: (v) => v == null ? "Category is required" : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedJobTypeId,
                      style: GoogleFonts.poppins(fontSize: 14, color: brandNavy),
                      decoration: _inputStyle("Job Type", Icons.work_history_rounded),
                      items: jobTypes.map((jt) {
                        return DropdownMenuItem(
                          value: jt['jobtype_id'].toString(),
                          child: Text(jt['jobtype_name']),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => selectedJobTypeId = val);
                      },
                      validator: (v) => v == null ? "Job type is required" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: budgetController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: _inputStyle("Budget / Amount (₹)", Icons.payments_rounded),
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Budget is required";
                        final n = num.tryParse(v);
                        if (n == null || n <= 0) return "Enter a valid amount";
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    buildChips("Technical Skills Required", technicalSkills, selectedTech, 'technicalskill_name', 'technicalskill_id'),
                    buildChips("Soft Skills Required", softSkills, selectedSoft, 'softskill_name', 'softskill_id'),
                    buildChips("Languages Required", languages, selectedLang, 'language_name', 'language_id'),
                    
                    // File Picker UI
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: brandGrey,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: brandNavy.withOpacity(0.05)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.description_rounded, color: brandNavy),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selectedFile == null ? "Attach Project Brief (PDF/DOC)" : selectedFile!.path.split('/').last,
                              style: GoogleFonts.poppins(fontSize: 13, color: brandNavy.withOpacity(0.7)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: pickFile,
                            child: Text(selectedFile == null ? "Browse" : "Change", style: const TextStyle(color: brandTeal, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : submitWork,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandNavy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text("Publish Project", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
