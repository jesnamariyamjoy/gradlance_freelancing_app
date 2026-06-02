import 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_dashboard_page.dart';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CompleteProfilePortfolio extends StatefulWidget {
  const CompleteProfilePortfolio({super.key});

  @override
  State<CompleteProfilePortfolio> createState() =>
      _CompleteProfilePortfolioState();
}

class _CompleteProfilePortfolioState extends State<CompleteProfilePortfolio> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  // 🎨 THEME CONSTANTS
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);
  static const int maxLinks = 10;
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyCkdXf1BwhRp_l1LrqwtLZ76F3skF2crOE',
  );

  // AI STATES
  bool _isGeneratingAI = false;
  String? _generatedResumeText;
  final TextEditingController _resumeDisplayController =
      TextEditingController();

  // USER DATA FOR AI
  Map<String, dynamic>? _userBasic;
  Map<String, dynamic>? _userDetails;
  List<String> _techSkills = [];
  List<String> _softSkills = [];
  List<String> _languages = [];
  List<String> _prevWorks = [];

  // STATES
  PlatformFile? _resumeFile;
  String? _resumeUrl;
  bool _isUploading = false;
  bool _recordExists = false;
  final TextEditingController _linkedinController = TextEditingController();
  final TextEditingController _githubController = TextEditingController();
  final List<TextEditingController> _otherLinksControllers = [
    TextEditingController(),
  ];

  @override
  void initState() {
    super.initState();
    _fetchFullUserData();
  }

  Future<void> _fetchFullUserData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final responses = await Future.wait<dynamic>([
        supabase.from('tbl_user').select().eq('id', user.id).maybeSingle(),
        supabase
            .from('tbl_user_details')
            .select(
              '*, tbl_places(place_name, tbl_district(district_name, tbl_states(states_name, tbl_country(country_name))))',
            )
            .eq('user_id', user.id)
            .maybeSingle(),
        supabase
            .from('tbl_user_technicalskill')
            .select('tbl_technicalskill(technicalskill_name)')
            .eq('user_id', user.id),
        supabase
            .from('tbl_user_softskill')
            .select('tbl_softskill(softskill_name)')
            .eq('user_id', user.id),
        supabase
            .from('tbl_user_language')
            .select('tbl_language(language_name)')
            .eq('user_id', user.id),
        supabase
            .from('tbl_application')
            .select('tbl_work(work_title)')
            .eq('user_id', user.id)
            .eq('application_status', 'accepted'),
      ]);

      setState(() {
        _userBasic = responses[0] as Map<String, dynamic>?;
        _userDetails = responses[1] as Map<String, dynamic>?;

        if (_userDetails != null) {
          _recordExists = true;
        }

        _techSkills = (responses[2] as List)
            .map(
              (e) =>
                  e['tbl_technicalskill']?['technicalskill_name']?.toString() ??
                  '',
            )
            .where((s) => s.isNotEmpty)
            .toList();
        _softSkills = (responses[3] as List)
            .map((e) => e['tbl_softskill']?['softskill_name']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        _languages = (responses[4] as List)
            .map((e) => e['tbl_language']?['language_name']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        _prevWorks = (responses[5] as List)
            .map((e) => e['tbl_work']?['work_title']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      });
    } catch (e) {
      debugPrint("Data Fetch Error: $e");
    }
  }

  String _buildAIPromptContext() {
    final name = _userBasic?['user_name'] ?? 'Freelancer';
    final email = _userBasic?['user_email'] ?? 'Not provided';
    final phone = _userBasic?['user_contact'] ?? 'Not provided';
    final course = _userDetails?['course'] ?? 'their course';
    final college = _userBasic?['college'] ?? 'their university';
    final tech = _techSkills.join(', ');
    final soft = _softSkills.join(', ');
    final lang = _languages.join(', ');
    final works = _prevWorks.isEmpty
        ? 'Entry-level professional'
        : _prevWorks.join(', ');
    final year = _userDetails?['current_year'] ?? '';
    final grad = _userDetails?['expected_graduation'] ?? '';

    // Location context (Reconstructed from Relational Joins)
    final placeData = _userDetails?['tbl_places'];
    String location = 'Not provided';
    if (placeData != null) {
      final pName = placeData['place_name'] ?? '';
      final dName = placeData['tbl_district']?['district_name'] ?? '';
      final sName =
          placeData['tbl_district']?['tbl_states']?['states_name'] ?? '';
      final cName =
          placeData['tbl_district']?['tbl_states']?['tbl_country']?['country_name'] ??
          '';
      location = "$pName, $dName, $sName, $cName"
          .replaceAll(RegExp(r', ,'), ',')
          .trim();
      if (location.endsWith(','))
        location = location.substring(0, location.length - 1);
    }

    return '''
PRIMARY INFO:
Name: $name
Email: $email
Phone: $phone
Location: $location

EDUCATION:
Degree/Course: $course
Institution: $college
Current Status: $year
Proposed Graduation: $grad

EXPERTISE:
Technical Skills: $tech
Soft Skills: $soft
Languages: $lang

PROFESSIONAL EXPERIENCE:
Key Projects/Works: $works
''';
  }

  Future<void> _createAIResume() async {
    setState(() => _isGeneratingAI = true);
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash-lite',
        apiKey: geminiApiKey,
      );
      final prompt =
          '''
Create a professional, ATS-friendly textual resume based on this data:
${_buildAIPromptContext()}

Guidelines:
1. Format with clear headings (Profile, Education, Skills, Experience).
2. Use professional language and bullet points.
3. Ensure it looks clean when rendered as text.
4. Output ONLY the resume content. No chatty intro or outro.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      if (response.text != null) {
        setState(() {
          _generatedResumeText = response.text!.trim();
          _resumeDisplayController.text = _generatedResumeText!;
        });
        _showResumePreviewDialog();
      }
    } catch (e) {
      _showSnackBar("AI Generation failed: $e", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isGeneratingAI = false);
    }
  }

  Future<pw.Document> _generatePdfDocument(String content) async {
    final pdf = pw.Document();
    final name = _userBasic?['user_name'] ?? 'Freelancer';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    name.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey900,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Divider(thickness: 2, color: PdfColors.blueGrey900),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(content, style: const pw.TextStyle(fontSize: 12)),
          ];
        },
      ),
    );
    return pdf;
  }

  void _showResumePreviewDialog() async {
    if (_generatedResumeText == null) return;

    // Generate PDF bytes for preview
    final pdfDoc = await _generatePdfDocument(_generatedResumeText!);
    final bytes = await pdfDoc.save();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "ATS Resume Preview",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: brandNavy,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PdfPreview(
                build: (format) => bytes,
                useActions: false,
                allowPrinting: false,
                allowSharing: false,
                canChangePageFormat: false,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showManualEditDialog();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Edit Content"),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _saveGeneratedResume(bytes);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandTeal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Confirm & Upload",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualEditDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Resume Content"),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: _resumeDisplayController,
            maxLines: 15,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: "Refine your resume details...",
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                _generatedResumeText = _resumeDisplayController.text;
              });
              Navigator.pop(context);
              _showResumePreviewDialog(); // Re-show preview with updated text
            },
            style: ElevatedButton.styleFrom(backgroundColor: brandTeal),
            child: const Text(
              "Save Changes",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveGeneratedResume(Uint8List pdfBytes) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isUploading = true);
    try {
      final fileName =
          'ai_resume_${user.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final path = '${user.id}/$fileName';

      await supabase.storage
          .from('resumes')
          .uploadBinary(
            path,
            pdfBytes,
            fileOptions: const FileOptions(contentType: 'application/pdf'),
          );
      final url = supabase.storage.from('resumes').getPublicUrl(path);

      if (_recordExists) {
        await supabase
            .from('tbl_user_details')
            .update({'resume_url': url})
            .eq('user_id', user.id);
      } else {
        await supabase.from('tbl_user_details').insert({
          'user_id': user.id,
          'resume_url': url,
        });
        _recordExists = true;
      }

      _showSnackBar("AI Resume uploaded successfully!", Colors.green);

      setState(() {
        _resumeUrl = url; // Store the URL
        _resumeFile = PlatformFile(
          name: fileName,
          size: pdfBytes.length,
          bytes: pdfBytes,
        );
      });
    } catch (e) {
      _showSnackBar("Saving AI resume failed: $e", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // 1. FILE PICKER LOGIC
  Future<void> _pickResume() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: kIsWeb, // Required for Web
    );
    if (result != null) setState(() => _resumeFile = result.files.first);
  }

  // 2. URL VALIDATOR
  bool _isValidUrl(String url) {
    if (url.isEmpty) return true;
    final urlPattern = RegExp(
      r'^((https?|ftp|smtp):\/\/)?(www.)?[a-z0-9]+\.[a-z]+(\/[a-zA-Z0-9#]+\/?)*$',
      caseSensitive: false,
    );
    return urlPattern.hasMatch(url.trim());
  }

  // 3. FINAL SUBMISSION
   Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isUploading = true);

    try {
      String? resumeUrl = _resumeUrl; // Use already uploaded URL if available

      // A. Upload Resume to Storage (Only if a new file was picked and not yet uploaded)
      if (_resumeFile != null && _resumeUrl == null) {
        final fileExtension = _resumeFile!.extension;
        final fileName = 'resume_${user.id}.$fileExtension';
        final path = '${user.id}/$fileName';

        if (_resumeFile!.bytes != null) {
          await supabase.storage
              .from('resumes')
              .uploadBinary(
                path,
                _resumeFile!.bytes!,
                fileOptions: const FileOptions(
                  upsert: true,
                  contentType: 'application/pdf',
                ),
              );
        } else if (_resumeFile!.path != null) {
          await supabase.storage
              .from('resumes')
              .upload(
                path,
                File(_resumeFile!.path!),
                fileOptions: const FileOptions(upsert: true),
              );
        }
        resumeUrl = supabase.storage.from('resumes').getPublicUrl(path);
      }

      // B. Collect Portfolio Links
      final otherLinks = _otherLinksControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty && _isValidUrl(t))
          .toList();

      // C. Update tbl_user_details (INSERT or UPDATE)
      final detailsMap = {
        'user_id': user.id,
        'resume_url': resumeUrl,
        'linkedin_url': _linkedinController.text.trim(),
        'github_url': _githubController.text.trim(),
        'portfolio_links': otherLinks, // Postgres JSONB
        'profile_completed': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_recordExists) {
        await supabase
            .from('tbl_user_details')
            .update(detailsMap)
            .eq('user_id', user.id);
      } else {
        await supabase.from('tbl_user_details').insert(detailsMap);
        _recordExists = true;
      }

      if (mounted) {
        print(
          "Profile updated with resume: $resumeUrl, LinkedIn: ${_linkedinController.text}, GitHub: ${_githubController.text}, Other Links: $otherLinks",
        );
        Navigator.pop(context); // Close Review Modal
        _showSuccessDialog();
      }
    } catch (e) {
      debugPrint("Upload Error: $e");
      print("Failed to upload resume or update profile: $e");
      _showSnackBar("Save failed: $e", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
          icon: const Icon(Icons.arrow_back_ios, color: brandNavy, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Step 3: Proof of Work",
          style: GoogleFonts.poppins(
            color: brandNavy,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            _buildSectionHeader("Resume / CV", LucideIcons.fileText),
            const SizedBox(height: 12),
            _buildResumeUploader(),
            const SizedBox(height: 32),
            _buildSectionHeader("Professional Socials", LucideIcons.share2),
            const SizedBox(height: 16),
            _buildSocialField(
              "LinkedIn",
              LucideIcons.linkedin,
              _linkedinController,
              "linkedin.com/in/username",
            ),
            const SizedBox(height: 12),
            _buildSocialField(
              "GitHub",
              LucideIcons.github,
              _githubController,
              "github.com/username",
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(
                  "Other Project Links",
                  LucideIcons.externalLink,
                ),
                if (_otherLinksControllers.length > 1 ||
                    _otherLinksControllers[0].text.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() {
                      _otherLinksControllers.clear();
                      _otherLinksControllers.add(TextEditingController());
                    }),
                    child: Text(
                      "Clear All",
                      style: GoogleFonts.poppins(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            Text(
              "Add up to $maxLinks links (${_otherLinksControllers.length}/$maxLinks used)",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ..._otherLinksControllers.asMap().entries.map(
              (entry) => _buildDynamicLinkField(entry.key),
            ),
            if (_otherLinksControllers.length < maxLinks)
              TextButton.icon(
                onPressed: () => setState(
                  () => _otherLinksControllers.add(TextEditingController()),
                ),
                icon: const Icon(
                  Icons.add_circle_outline,
                  size: 18,
                  color: brandTeal,
                ),
                label: Text(
                  "Add another link",
                  style: GoogleFonts.poppins(
                    color: brandTeal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 40),
            _buildActionButtons(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: brandTeal),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: brandNavy,
          ),
        ),
      ],
    );
  }

  Widget _buildResumeUploader() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickResume,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: brandGrey,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: brandTeal.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                const Icon(LucideIcons.fileText, size: 32, color: brandTeal),
                const SizedBox(height: 8),
                Text(
                  _resumeFile == null ? "Upload PDF Resume" : _resumeFile!.name,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: brandNavy,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isGeneratingAI ? null : _createAIResume,
            icon: _isGeneratingAI
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(LucideIcons.sparkles, size: 16),
            label: Text(
              _isGeneratingAI ? "Generating..." : "Generate with AI Gemini",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: brandTeal,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialField(
    String label,
    IconData icon,
    TextEditingController controller,
    String hint,
  ) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.poppins(fontSize: 14, color: brandNavy),
      validator: (v) {
        if (v == null || v.isEmpty) return null;
        if (!_isValidUrl(v)) return "Invalid URL format";
        return null;
      },
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: brandNavy),
        hintText: hint,
        labelText: label,
        labelStyle: const TextStyle(color: brandNavy),
        filled: true,
        fillColor: brandGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
      ),
    );
  }

  Widget _buildDynamicLinkField(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _otherLinksControllers[index],
              style: GoogleFonts.poppins(fontSize: 14, color: brandNavy),
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                if (!_isValidUrl(v)) return "Invalid URL";
                return null;
              },
              decoration: InputDecoration(
                hintText: "https://mywork.com/project",
                filled: true,
                fillColor: brandGrey,
                prefixIcon: const Icon(
                  LucideIcons.link,
                  size: 18,
                  color: brandNavy,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.redAccent, width: 1),
                ),
              ),
            ),
          ),
          if (_otherLinksControllers.length > 1)
            IconButton(
              icon: const Icon(
                LucideIcons.minus,
                color: Colors.redAccent,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _otherLinksControllers.removeAt(index)),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return OutlinedButton.icon(
      onPressed: _showFullReview,
      icon: const Icon(LucideIcons.eye, size: 18),
      label: Text(
        "Preview & Finish",
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: brandNavy,
        minimumSize: const Size(double.infinity, 54),
        side: const BorderSide(color: brandNavy, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showFullReview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Final Review",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: brandNavy,
              ),
            ),
            const Divider(height: 32),
            _reviewRow(
              "Resume",
              _resumeFile != null ? "Attached" : "Not Provided",
              _resumeFile != null,
            ),
            _reviewRow(
              "Socials",
              _linkedinController.text.isNotEmpty
                  ? "LinkedIn added"
                  : "Socials missing",
              _linkedinController.text.isNotEmpty,
            ),
            _reviewRow(
              "Portfolio",
              "${_otherLinksControllers.where((c) => c.text.isNotEmpty).length} Links",
              true,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isUploading
                    ? null
                    : () {
                        Navigator.pop(context);
                        _completeProfile();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandNavy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Confirm & Finish",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _reviewRow(String step, String desc, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.error_outline,
            color: done ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            step,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: brandNavy,
            ),
          ),
          const SizedBox(width: 8),
          Text(desc, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Profile Complete! 🚀"),
        content: const Text(
          "Great job! Your profile is now live and recruiters can find you.",
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              // Close the success dialog and take the user to the dashboard.
              Navigator.of(context).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const StudentDashboard()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: brandTeal),
            child: const Text(
              "Go to Dashboard",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
