import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:user/profilestep3.dart';

class CompleteProfileSkills extends StatefulWidget {
  const CompleteProfileSkills({super.key});

  @override
  State<CompleteProfileSkills> createState() => _CompleteProfileSkillsState();
}

class _CompleteProfileSkillsState extends State<CompleteProfileSkills> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  // 🎨 THEME
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  // Logic & Data States
  bool _isLoading = true;
  bool _isSaving = false;
  bool _recordExists = false;
  bool _isReadyToWork = true;
  double _hourlyRate = 500;
  String _workPreference = "Remote Only";
  final TextEditingController _interestsController = TextEditingController();

  List<Map<String, dynamic>> _techSkills = [];
  List<Map<String, dynamic>> _softSkills = [];
  List<Map<String, dynamic>> _languages = [];

  final Set<int> _selectedTechIds = {};
  final Set<int> _selectedSoftIds = {};
  final Set<int> _selectedLangIds = {};

  @override
  void initState() {
    super.initState();
    _loadSkillsData();
  }

  Future<void> _loadUserSelections() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final responses = await Future.wait<dynamic>([
        supabase
            .from('tbl_user_details')
            .select()
            .eq('user_id', user.id)
            .maybeSingle(),
        supabase
            .from('tbl_user_technicalskill')
            .select('technicalskill_id')
            .eq('user_id', user.id),
        supabase
            .from('tbl_user_softskill')
            .select('softskill_id')
            .eq('user_id', user.id),
        supabase
            .from('tbl_user_language')
            .select('language_id')
            .eq('user_id', user.id),
      ]);

      final details = responses[0] as Map<String, dynamic>?;
      if (details != null) {
        _recordExists = true;
      }
      final tech = responses[1] as List<dynamic>;
      final soft = responses[2] as List<dynamic>;
      final lang = responses[3] as List<dynamic>;

      if (mounted) {
        setState(() {
          if (details != null) {
            _isReadyToWork = details['is_ready_to_work'] ?? true;
            _hourlyRate = (details['hourly_rate'] as num?)?.toDouble() ?? 500.0;
            _workPreference = details['work_preference'] ?? "Remote Only";
            _interestsController.text = details['interests'] ?? "";
          }
          _selectedTechIds.addAll(
            tech.map((e) => e['technicalskill_id'] as int),
          );
          _selectedSoftIds.addAll(soft.map((e) => e['softskill_id'] as int));
          _selectedLangIds.addAll(lang.map((e) => e['language_id'] as int));
        });
      }
    } catch (e) {
      debugPrint("Load Selections Error: $e");
    }
  }

  Future<void> _loadSkillsData() async {
    try {
      final responses = await Future.wait([
        supabase
            .from('tbl_technicalskill')
            .select('technicalskill_id, technicalskill_name'),
        supabase.from('tbl_softskill').select('softskill_id, softskill_name'),
        supabase.from('tbl_language').select('language_id, language_name'),
      ]);

      setState(() {
        _techSkills = List<Map<String, dynamic>>.from(responses[0]);
        _softSkills = List<Map<String, dynamic>>.from(responses[1]);
        _languages = List<Map<String, dynamic>>.from(responses[2]);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Fetch Error: $e");
    } finally {
      await _loadUserSelections();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UPDATED SAVE LOGIC ---
  Future<void> _saveStep2Data() async {
    if (!_formKey.currentState!.validate()) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      // Step A: Update parent user row safely
      await supabase
          .from('tbl_user')
          .update({'user_status': 'profile_filling'})
          .eq('id', user.id);

      // Step B: Update user details (INSERT or UPDATE)
      final detailsMap = {
        'user_id': user.id,
        'is_ready_to_work': _isReadyToWork,
        'hourly_rate': _hourlyRate,
        'work_preference': _workPreference,
        'interests': _interestsController.text.trim(),
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
      // Step C: Map data correctly
      final techData = _selectedTechIds
          .map((id) => {'user_id': user.id, 'technicalskill_id': id})
          .toList();
      final softData = _selectedSoftIds
          .map((id) => {'user_id': user.id, 'softskill_id': id})
          .toList();
      final langData = _selectedLangIds
          .map((id) => {'user_id': user.id, 'language_id': id})
          .toList();

      // Step D: Sync Bridge Tables
      await Future.wait([
        supabase
            .from('tbl_user_technicalskill')
            .delete()
            .eq('user_id', user.id)
            .then((_) async {
              if (techData.isNotEmpty)
                await supabase.from('tbl_user_technicalskill').insert(techData);
            }),
        supabase
            .from('tbl_user_softskill')
            .delete()
            .eq('user_id', user.id)
            .then((_) async {
              if (softData.isNotEmpty)
                await supabase.from('tbl_user_softskill').insert(softData);
            }),
        supabase.from('tbl_user_language').delete().eq('user_id', user.id).then(
          (_) async {
            if (langData.isNotEmpty)
              await supabase.from('tbl_user_language').insert(langData);
          },
        ),
      ]);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CompleteProfilePortfolio()),
        );
      }
    } catch (e) {
      debugPrint("Expertise Save Error: $e");
      if (mounted) {
        debugPrint("Expertise Save Error: $e");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save expertise: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: brandTeal)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: brandNavy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Step 2: Expertise",
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
            _buildToggleTile(),
            const SizedBox(height: 32),

            _buildSectionLabel("Technical Skills", LucideIcons.codeXml),
            _buildChipGroup(
              _techSkills,
              _selectedTechIds,
              'technicalskill_id',
              'technicalskill_name',
            ),
            const SizedBox(height: 24),

            _buildSectionLabel("Soft Skills", LucideIcons.users),
            _buildChipGroup(
              _softSkills,
              _selectedSoftIds,
              'softskill_id',
              'softskill_name',
            ),
            const SizedBox(height: 24),

            _buildSectionLabel("Languages", LucideIcons.languages),
            _buildChipGroup(
              _languages,
              _selectedLangIds,
              'language_id',
              'language_name',
            ),
            const SizedBox(height: 32),

            _buildSectionLabel("Expected Hourly Rate", LucideIcons.banknote),
            _buildRateSlider(),
            const SizedBox(height: 32),

            _buildSectionLabel("Work Preference", LucideIcons.mapPin),
            _buildDropdownField(["Remote Only", "Hybrid", "On-site"]),
            const SizedBox(height: 32),

            _buildSectionLabel("Interests & Hobbies", LucideIcons.heart),
            _buildTextField(
              "e.g. Photography, AI Research, Open Source",
              _interestsController,
            ),

            const SizedBox(height: 40),
            _buildContinueButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildSectionLabel(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: brandTeal),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: brandNavy,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isReadyToWork ? brandTeal.withOpacity(0.05) : brandGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isReadyToWork ? brandTeal : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Ready to Work",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: brandNavy,
                  ),
                ),
                Text(
                  "Makes you visible to active recruiters.",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.blueGrey,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isReadyToWork,
            activeColor: brandTeal,
            onChanged: (val) => setState(() => _isReadyToWork = val),
          ),
        ],
      ),
    );
  }

  Widget _buildChipGroup(
    List<Map<String, dynamic>> items,
    Set<int> selectionSet,
    String idKey,
    String nameKey,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final int id = item[idKey];
        final String name = item[nameKey];
        final bool isSelected = selectionSet.contains(id);

        return FilterChip(
          label: Text(name),
          selected: isSelected,
          onSelected: (val) => setState(
            () => val ? selectionSet.add(id) : selectionSet.remove(id),
          ),
          selectedColor: brandTeal.withOpacity(0.15),
          checkmarkColor: brandTeal,
          labelStyle: GoogleFonts.poppins(
            fontSize: 13,
            color: isSelected ? brandTeal : brandNavy,
          ),
          backgroundColor: brandGrey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected ? brandTeal : Colors.transparent,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRateSlider() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "₹200/hr",
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
            ),
            Text(
              "₹${_hourlyRate.toInt()}",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: brandTeal,
                fontSize: 18,
              ),
            ),
            Text(
              "₹2000+",
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        Slider(
          value: _hourlyRate,
          min: 200,
          max: 2000,
          divisions: 18,
          activeColor: brandTeal,
          onChanged: (val) => setState(() => _hourlyRate = val),
        ),
      ],
    );
  }

  Widget _buildDropdownField(List<String> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: brandGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _workPreference,
          isExpanded: true,
          style: GoogleFonts.poppins(color: brandNavy, fontSize: 14),
          dropdownColor: Colors.white,
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: const TextStyle(color: brandNavy)),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _workPreference = val!),
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.poppins(fontSize: 14, color: brandNavy),
      validator: (v) => v == null || v.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
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

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandNavy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: _isSaving ? null : _saveStep2Data,
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                "Continue to Step 3",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
