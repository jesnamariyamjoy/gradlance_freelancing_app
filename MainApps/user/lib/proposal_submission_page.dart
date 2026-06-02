import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:user/subscription_page.dart';

class ProposalSubmitPage extends StatefulWidget {
  final int workId;
  const ProposalSubmitPage({Key? key, required this.workId}) : super(key: key);

  @override
  State<ProposalSubmitPage> createState() => _ProposalSubmitPageState();
}

class _ProposalSubmitPageState extends State<ProposalSubmitPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController proposalController = TextEditingController();
  final TextEditingController bidController = TextEditingController();
  final TextEditingController resumeDisplayController = TextEditingController();

  bool isPremium = false;
  int applicationCount = 0;

  bool isSubmitting = false;
  bool alreadySubmitted = false;
  bool isGeneratingAI = false;
  bool isGeneratingResume = false;
  bool isUploadingResume = false;

  String? uploadedResumeUrl;
  String? generatedResumeText;

  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? 'Your_Gemini_API_Key';

  Map<String, dynamic>? userBasic;
  Map<String, dynamic>? userDetails;
  List<String> technicalSkills = [];
  List<String> softSkills = [];
  List<String> languages = [];
  List<String> previousWorks = [];

  @override
  void initState() {
    super.initState();
    checkProposal();
    fetchUserData();
    checkSubscriptionStatus();
  }

  Future<void> checkSubscriptionStatus() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final sub = await supabase
        .from('tbl_subscription')
        .select()
        .eq('user_id', user.id)
        .eq('status', 'active')
        .maybeSingle();
    
    final apps = await supabase
        .from('tbl_application')
        .select('application_id')
        .eq('user_id', user.id);

    if (mounted) {
      setState(() {
        isPremium = sub != null;
        applicationCount = (apps as List).length;
      });
    }
  }

  Future<void> fetchUserData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      userBasic = await supabase
          .from('tbl_user')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      userDetails = await supabase
          .from('tbl_user_details')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      final techResp = await supabase
          .from('tbl_user_technicalskill')
          .select('tbl_technicalskill(technicalskill_name)')
          .eq('user_id', user.id);
      final softResp = await supabase
          .from('tbl_user_softskill')
          .select('tbl_softskill(softskill_name)')
          .eq('user_id', user.id);
      final langResp = await supabase
          .from('tbl_user_language')
          .select('tbl_language(language_name)')
          .eq('user_id', user.id);

      technicalSkills = (techResp as List)
          .map<String>(
            (e) => e['tbl_technicalskill']['technicalskill_name'] as String,
          )
          .toList();
      softSkills = (softResp as List)
          .map<String>((e) => e['tbl_softskill']['softskill_name'] as String)
          .toList();
      languages = (langResp as List)
          .map<String>((e) => e['tbl_language']['language_name'] as String)
          .toList();

      final worksResp = await supabase
          .from('tbl_application')
          .select('''
            application_status,
            tbl_work ( work_title )
          ''')
          .eq('user_id', user.id)
          .eq('application_status', 'accepted');

      previousWorks = (worksResp as List)
          .map<String>((e) => e['tbl_work']['work_title'] as String)
          .toList();
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  Future<void> checkProposal() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response = await supabase
        .from('tbl_application')
        .select()
        .eq('work_id', widget.workId)
        .eq('user_id', user.id);

    if (response.isNotEmpty) {
      setState(() => alreadySubmitted = true);
    }
  }

  String _getUserContextPrompt() {
    final name = userBasic?['user_name'] ?? 'Freelancer';
    final course = userDetails?['course'] ?? 'their current field';
    final year = userDetails?['current_year'] ?? 'current year';
    final tech = technicalSkills.join(', ');
    final soft = softSkills.join(', ');
    final lang = languages.join(', ');
    final works = previousWorks.isEmpty
        ? 'None listed'
        : previousWorks.join(', ');

    return '''
My Name: $name
My Course: $course
Status: $year
Technical Skills: $tech
Soft Skills: $soft
Languages: $lang
Previous Completed/Accepted Works: $works
''';
  }

  Future<void> generateAIProposal() async {
    if (geminiApiKey == 'Your_Gemini_API_Key') {
      _showError("Please set a valid Gemini API Key.");
      return;
    }

    setState(() => isGeneratingAI = true);

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash-lite',
        apiKey: geminiApiKey,
      );
      final prompt =
          '''
You are directly writing an application proposal.
Use the following user context:
${_getUserContextPrompt()}

Write a professional, compelling, and concise proposal (around 3 paragraphs) applying for a freelance project. 
Explain why the combination of my skills and education makes me the best fit.
Output ONLY the proposal text. DO NOT start with "Here is your proposal...".
''';

      final response = await model.generateContent([Content.text(prompt)]);
      if (response.text != null) {
        proposalController.text = response.text!.trim();
      }
    } catch (e) {
      _showError("Failed to generate AI proposal: $e");
    }

    if (mounted) setState(() => isGeneratingAI = false);
  }

  Future<void> createAtsResume() async {
    if (geminiApiKey == 'Your_Gemini_API_Key') {
      _showError("Please set a valid Gemini API Key.");
      return;
    }

    setState(() => isGeneratingResume = true);

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash-lite',
        apiKey: geminiApiKey,
      );
      final prompt =
          '''
Based on the following user data, strictly create a clear, ATS-friendly textual resume.
${_getUserContextPrompt()}

Format it cleanly using standard markdown headings (like 'Education', 'Skills', etc.).
Do not include chatty text. Output only the final resume content.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      if (response.text != null) {
        setState(() {
          generatedResumeText = response.text!.trim();
          resumeDisplayController.text = generatedResumeText!;
        });
        _showResumeDialog();
      }
    } catch (e) {
      _showError("Failed to generate ATS Resume: $e");
    }

    if (mounted) setState(() => isGeneratingResume = false);
  }

  void _showResumeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text("Generated Custom Resume"),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: resumeDisplayController,
              maxLines: 15,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Review and edit your resume...",
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _saveAndUploadGeneratedResume(resumeDisplayController.text);
              },
              child: const Text("Save & Upload"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveAndUploadGeneratedResume(String text) async {
    setState(() => isUploadingResume = true);
    final user = supabase.auth.currentUser;

    try {
      final fileName =
          'ai_resume_${user!.id}_${DateTime.now().millisecondsSinceEpoch}.txt';
      final path = '${user.id}/$fileName';

      // Upload raw text bytes
      await supabase.storage
          .from('resumes')
          .uploadBinary(path, Uint8List.fromList(text.codeUnits));

      final url = supabase.storage.from('resumes').getPublicUrl(path);

      // Save to user details as well
      await supabase
          .from('tbl_user_details')
          .update({'resume_url': url})
          .eq('user_id', user.id);

      setState(() {
        uploadedResumeUrl = url;
      });

      _showSuccess("Resume saved and uploaded successfully!");
    } catch (e) {
      _showError("Failed to upload auto-generated resume: $e");
    }

    setState(() => isUploadingResume = false);
  }

  Future<void> uploadManualResume() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => isUploadingResume = true);
        final file = File(result.files.single.path!);
        final user = supabase.auth.currentUser!;
        final fileExtension = result.files.single.extension ?? 'pdf';

        final fileName =
            'manual_resume_${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
        final path = '${user.id}/$fileName';

        await supabase.storage.from('resumes').upload(path, file);
        final url = supabase.storage.from('resumes').getPublicUrl(path);

        await supabase
            .from('tbl_user_details')
            .update({'resume_url': url})
            .eq('user_id', user.id);

        setState(() {
          uploadedResumeUrl = url;
        });

        _showSuccess("Resume uploaded successfully!");
      }
    } catch (e) {
      _showError("Error uploading resume: $e");
    } finally {
      setState(() => isUploadingResume = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  Future<void> submitProposal() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    if (proposalController.text.isEmpty || bidController.text.isEmpty) {
      _showError("Please fill both proposal text and bid amount.");
      return;
    }

    if (!isPremium && applicationCount >= 1) {
      _showLimitDialog("Application Limit Reached", "Free accounts are limited to 1 project application. Upgrade to premium to apply for unlimited projects!");
      return;
    }

    setState(() => isSubmitting = true);

    try {
      // Build final proposal text including the resume link if provided
      String finalProposalText = proposalController.text.trim();
      if (uploadedResumeUrl != null) {
        finalProposalText += "\n\nMy Resume: $uploadedResumeUrl";
      }

      await supabase.from('tbl_application').insert({
        'work_id': widget.workId,
        'user_id': user.id,
        'application_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'proposal_text': finalProposalText,
        'bid_amount': double.tryParse(bidController.text) ?? 0,
        'work_progress': 0,
      });

      try {
        final workData = await supabase
            .from('tbl_work')
            .select('client_id')
            .eq('work_id', widget.workId)
            .single();
        final clientId = workData['client_id'];
        if (clientId != null) {
          await supabase.from('notifications').insert({
            'user_id': clientId,
            'title': 'New Proposal Received',
            'message': 'A new proposal was submitted for your work!',
          });
        }
      } catch (_) {}

      if (mounted) {
        _showSuccess("Proposal submitted successfully!");
        Navigator.pop(context);
      }
    } catch (e) {
      _showError("Error: $e");
    }

    if (mounted) setState(() => isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    const Color brandNavy = Color(0xFF102030);
    const Color brandTeal = Color(0xFF20A0A0);
    const Color brandGrey = Color(0xFFF4F7F9);

    return Scaffold(
      backgroundColor: brandGrey,
      appBar: AppBar(
        title: const Text(
          "Create Proposal",
          style: TextStyle(fontWeight: FontWeight.bold, color: brandNavy),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: brandNavy),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Proposal Description",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: brandNavy.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
                TextButton.icon(
                  onPressed: isGeneratingAI ? null : generateAIProposal,
                  icon: isGeneratingAI
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          LucideIcons.sparkles,
                          size: 16,
                          color: Colors.blueAccent,
                        ),
                  label: Text(
                    "Auto-Generate",
                    style: TextStyle(
                      color: isGeneratingAI ? Colors.grey : Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              controller: proposalController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText:
                    "Review/Edit your proposal here... (Or use Auto-Generate to create one)",
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Resume Section
            Text(
              "Resume Attachment",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: brandNavy.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (uploadedResumeUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Resume attached",
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isUploadingResume
                              ? null
                              : uploadManualResume,
                          icon: const Icon(LucideIcons.upload, size: 16),
                          label: const Text("Upload Resume"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: brandNavy,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isGeneratingResume || isUploadingResume
                              ? null
                              : createAtsResume,
                          icon: isGeneratingResume
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(LucideIcons.fileText, size: 16),
                          label: const Text("Create AI Resume"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandTeal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Bid Area
            Text(
              "Bid Amount (₹)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: brandNavy.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: bidController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: "Enter your custom bid for this task",
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon: const Icon(
                  Icons.currency_rupee_rounded,
                  color: brandTeal,
                  size: 20,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: alreadySubmitted
                  ? ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Already Submitted",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : isSubmitting
                  ? ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandNavy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    )
                  : ElevatedButton(
                      onPressed: submitProposal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandNavy,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Submit Proposal",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLimitDialog(String title, String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Maybe Later")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionPage()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF20A0A0)),
            child: const Text("Upgrade Now", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
