import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class EditProfessionalProfilePage extends StatefulWidget {
  const EditProfessionalProfilePage({super.key});

  @override
  State<EditProfessionalProfilePage> createState() => _EditProfessionalProfilePageState();
}

class _EditProfessionalProfilePageState extends State<EditProfessionalProfilePage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // 🎨 THEME
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  // --- DATA STATES ---
  bool _isLoading = true;
  bool _isSaving = false;
  File? _tempPhotoFile;
  String? _photoUrl;
  String? _resumeUrl;

  // Controllers
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _courseController = TextEditingController();
  final TextEditingController _hourlyRateController = TextEditingController();

  // Location Hierarchy
  String? _selectedCountryId, _selectedStateId, _selectedDistrictId, _selectedPlaceId;
  List<Map<String, dynamic>> _countries = [], _states = [], _districts = [], _places = [];

  // Skill Selection (Master Lists)
  List<Map<String, dynamic>> _techMaster = [], _softMaster = [], _langMaster = [];
  final Set<int> _selectedTechIds = {}, _selectedSoftIds = {}, _selectedLangIds = {};

  String? _workPreference;
  bool _isReadyToWork = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Fetch Master Data for Chips & Dropdowns
      final responses = await Future.wait([
        supabase.from('tbl_country').select().order('country_name'),
        supabase.from('tbl_technicalskill').select(),
        supabase.from('tbl_softskill').select(),
        supabase.from('tbl_language').select(),
        supabase.from('tbl_user').select('user_photo').eq('id', user.id).single(),
      ]);

      _countries = List<Map<String, dynamic>>.from(responses[0] as List);
      _techMaster = List<Map<String, dynamic>>.from(responses[1] as List);
      _softMaster = List<Map<String, dynamic>>.from(responses[2] as List);
      _langMaster = List<Map<String, dynamic>>.from(responses[3] as List);
      _photoUrl = (responses[4] as Map)['user_photo'];

      // 2. Fetch User Specific Details
      final details = await supabase
          .from('tbl_user_details')
          .select('*, tbl_places(place_id, district_id, tbl_district(states_id, tbl_states(country_id)))')
          .eq('user_id', user.id)
          .maybeSingle();

      // 3. Fetch Existing Bridge Table Selections
      final bridgeData = await Future.wait([
        supabase.from('tbl_user_technicalskill').select('technicalskill_id').eq('user_id', user.id),
        supabase.from('tbl_user_softskill').select('softskill_id').eq('user_id', user.id),
        supabase.from('tbl_user_language').select('language_id').eq('user_id', user.id),
      ]);

      if (mounted) {
        setState(() {
          if (details != null) {
            _pincodeController.text = details['pincode']?.toString() ?? '';
            _dobController.text = details['dob'] ?? '';
            _courseController.text = details['course'] ?? '';
            _hourlyRateController.text = details['hourly_rate']?.toString() ?? '';
            _workPreference = details['work_preference'];
            _isReadyToWork = details['is_ready_to_work'] ?? false;
            _resumeUrl = details['resume_url'];
            _selectedPlaceId = details['place']?.toString();

            final p = details['tbl_places'];
            if (p != null) {
              _selectedDistrictId = p['district_id']?.toString();
              final d = p['tbl_district'];
              if (d != null) {
                _selectedStateId = d['states_id']?.toString();
                _selectedCountryId = d['tbl_states']?['country_id']?.toString();
              }
            }
          }

          _selectedTechIds.addAll((bridgeData[0] as List).map((e) => e['technicalskill_id'] as int));
          _selectedSoftIds.addAll((bridgeData[1] as List).map((e) => e['softskill_id'] as int));
          _selectedLangIds.addAll((bridgeData[2] as List).map((e) => e['language_id'] as int));
          
          _isLoading = false;
        });

        if (_selectedCountryId != null) await _fetchStates(_selectedCountryId!);
        if (_selectedStateId != null) await _fetchDistricts(_selectedStateId!);
        if (_selectedDistrictId != null) await _fetchPlaces(_selectedDistrictId!);
      }
    } catch (e) {
      debugPrint("Load Error: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- LOCATION FETCHERS ---
  Future<void> _fetchStates(String id) async {
    final data = await supabase.from('tbl_states').select().eq('country_id', id);
    setState(() => _states = List<Map<String, dynamic>>.from(data));
  }
  Future<void> _fetchDistricts(String id) async {
    final data = await supabase.from('tbl_district').select().eq('states_id', id);
    setState(() => _districts = List<Map<String, dynamic>>.from(data));
  }
  Future<void> _fetchPlaces(String id) async {
    final data = await supabase.from('tbl_places').select().eq('district_id', id);
    setState(() => _places = List<Map<String, dynamic>>.from(data));
  }

  // --- FILE HANDLING ---
  Future<void> _pickPhoto() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _tempPhotoFile = File(pickedFile.path));
    }
  }

  Future<void> _pickResume() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null) {
       _uploadFile(File(result.files.single.path!), 'resumes', 'resume_url');
    }
  }

  Future<void> _uploadFile(File file, String bucket, String column) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      final path = "$userId/${DateTime.now().millisecondsSinceEpoch}";
      await supabase.storage.from(bucket).upload(path, file);
      final url = supabase.storage.from(bucket).getPublicUrl(path);
      await supabase.from('tbl_user_details').update({column: url}).eq('user_id', userId!);
      setState(() => column == 'resume_url' ? _resumeUrl = url : null);
    } catch (e) {
      debugPrint("File Error: $e");
    }
  }

  // --- SAVE LOGIC ---
  Future<void> _saveAll() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Upload Photo if changed
      if (_tempPhotoFile != null) {
        final path = "User/${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg";
        await supabase.storage.from('User').upload(path, _tempPhotoFile!);
        final url = supabase.storage.from('User').getPublicUrl(path);
        await supabase.from('tbl_user').update({'user_photo': url}).eq('id', user.id);
      }

      // 2. Update Details Table
      await supabase.from('tbl_user_details').upsert({
        'user_id': user.id,
        'pincode': _pincodeController.text,
        'place': _selectedPlaceId,
        'dob': _dobController.text,
        'course': _courseController.text,
        'is_ready_to_work': _isReadyToWork,
        'hourly_rate': double.tryParse(_hourlyRateController.text) ?? 0,
        'work_preference': _workPreference,
        'profile_completed': true,
      }, onConflict: 'user_id');

      // 3. Sync Bridge Tables (Delete then Re-insert)
      await _syncBridgeTables(user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!"), backgroundColor: brandTeal));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Save Error: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _syncBridgeTables(String userId) async {
    await supabase.from('tbl_user_technicalskill').delete().eq('user_id', userId);
    if (_selectedTechIds.isNotEmpty) {
      await supabase.from('tbl_user_technicalskill').insert(_selectedTechIds.map((id) => {'user_id': userId, 'technicalskill_id': id}).toList());
    }
    // Repeat for Soft Skills and Languages...
    await supabase.from('tbl_user_softskill').delete().eq('user_id', userId);
    if (_selectedSoftIds.isNotEmpty) {
      await supabase.from('tbl_user_softskill').insert(_selectedSoftIds.map((id) => {'user_id': userId, 'softskill_id': id}).toList());
    }
    await supabase.from('tbl_user_language').delete().eq('user_id', userId);
    if (_selectedLangIds.isNotEmpty) {
      await supabase.from('tbl_user_language').insert(_selectedLangIds.map((id) => {'user_id': userId, 'language_id': id}).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: brandTeal)));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text("Edit Master Profile", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: brandNavy)), centerTitle: true, backgroundColor: Colors.white, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPhotoHeader(),
              const SizedBox(height: 30),
              
              _buildSectionLabel("Personal Info", LucideIcons.user),
              _buildTextField(
                "Date of Birth",
                _dobController,
                hint: "YYYY-MM-DD",
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    _dobController.text = picked.toString().split(' ').first;
                  }
                },
                validator: (v) {
                  if (v == null || v.isEmpty) return "Required";
                  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) return "Invalid format (YYYY-MM-DD)";
                  return null;
                },
              ),
              _buildTextField(
                "Pincode",
                _pincodeController,
                keyboard: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return "Required";
                  if (!RegExp(r'^\d{6}$').hasMatch(v)) return "Enter 6-digit pincode";
                  return null;
                },
              ),
              
              const SizedBox(height: 20),
              _buildSectionLabel("Location", LucideIcons.mapPin),
              _buildLocationDropdown("Country", _countries, _selectedCountryId, (v) {
                setState(() => _selectedCountryId = v); _fetchStates(v!);
              }),
              _buildLocationDropdown("State", _states, _selectedStateId, (v) {
                setState(() => _selectedStateId = v); _fetchDistricts(v!);
              }),
              _buildLocationDropdown("District", _districts, _selectedDistrictId, (v) {
                setState(() => _selectedDistrictId = v); _fetchPlaces(v!);
              }),
              _buildLocationDropdown("Place", _places, _selectedPlaceId, (v) => setState(() => _selectedPlaceId = v)),

              const SizedBox(height: 20),
              _buildSectionLabel("Technical Skills", LucideIcons.code),
              _buildChipGroup(_techMaster, _selectedTechIds, 'technicalskill_id', 'technicalskill_name'),
              
              const SizedBox(height: 20),
              _buildSectionLabel("Soft Skills", LucideIcons.users),
              _buildChipGroup(_softMaster, _selectedSoftIds, 'softskill_id', 'softskill_name'),

              const SizedBox(height: 30),
              _buildSectionLabel("Availability", LucideIcons.briefcase),
              _buildToggleTile(),
              _buildTextField(
                "Hourly Rate (\$)",
                _hourlyRateController,
                keyboard: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return "Required";
                  if (double.tryParse(v) == null || double.parse(v) < 0) return "Enter valid amount";
                  return null;
                },
              ),
              
              const SizedBox(height: 40),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---
  Widget _buildPhotoHeader() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: brandGrey,
            backgroundImage: _tempPhotoFile != null 
              ? FileImage(_tempPhotoFile!) 
              : (_photoUrl != null ? NetworkImage(_photoUrl!) : null) as ImageProvider?,
            child: (_tempPhotoFile == null && _photoUrl == null) ? const Icon(Icons.person, size: 50, color: brandNavy) : null,
          ),
          Positioned(
            bottom: 0, right: 0,
            child: GestureDetector(
              onTap: _pickPhoto,
              child: const CircleAvatar(radius: 18, backgroundColor: brandTeal, child: Icon(Icons.camera_alt, size: 16, color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChipGroup(List<Map<String, dynamic>> items, Set<int> selectionSet, String idKey, String nameKey) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: items.map((item) {
        final id = item[idKey] as int;
        final isSelected = selectionSet.contains(id);
        return FilterChip(
          label: Text(item[nameKey]),
          selected: isSelected,
          onSelected: (val) => setState(() => val ? selectionSet.add(id) : selectionSet.remove(id)),
          selectedColor: brandTeal.withOpacity(0.2),
          checkmarkColor: brandTeal,
          labelStyle: GoogleFonts.poppins(fontSize: 13, color: isSelected ? brandTeal : brandNavy),
          backgroundColor: brandGrey,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        );
      }).toList(),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? hint,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        readOnly: onTap != null,
        onTap: onTap,
        style: GoogleFonts.poppins(fontSize: 14),
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: brandGrey,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildLocationDropdown(String label, List<Map<String, dynamic>> items, String? current, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: current,
        decoration: InputDecoration(labelText: label, filled: true, fillColor: brandGrey, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
        items: items.map((e) {
          final idKey = e.keys.firstWhere((k) => k.contains('_id'));
          final nameKey = e.keys.firstWhere((k) => k.contains('_name'));
          return DropdownMenuItem(value: e[idKey].toString(), child: Text(e[nameKey], style: GoogleFonts.poppins(fontSize: 14)));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSectionLabel(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Icon(icon, size: 18, color: brandTeal),
        const SizedBox(width: 8),
        Text(label.toUpperCase(), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
      ]),
    );
  }

  Widget _buildToggleTile() {
    return SwitchListTile(
      title: Text("Open to Work", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text("Recruiters can see you", style: GoogleFonts.poppins(fontSize: 12)),
      value: _isReadyToWork,
      activeColor: brandTeal,
      onChanged: (v) => setState(() => _isReadyToWork = v),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity, height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: brandNavy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        onPressed: _isSaving ? null : _saveAll,
        child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Update Master Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}