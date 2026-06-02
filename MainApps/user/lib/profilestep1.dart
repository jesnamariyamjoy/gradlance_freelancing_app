import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Ensure this is in pubspec.yaml
import 'package:user/profilestep2.dart';

class CompleteProfileBase extends StatefulWidget {
  const CompleteProfileBase({super.key});

  @override
  State<CompleteProfileBase> createState() => _CompleteProfileBaseState();
}

class _CompleteProfileBaseState extends State<CompleteProfileBase> {
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);

  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _recordExists = false;

  // Controllers
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _gradController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _collegeController = TextEditingController();
  final _courseController = TextEditingController();

  String? _selectedGender;
  String? _selectedYear;

  // Cascading Location States
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _states = [];
  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _places = [];

  String? _selectedCountryId;
  String? _selectedStateId;
  String? _selectedDistrictId;
  String? _selectedPlaceId;

  String? _selectedNationality;
  String? _selectedState;
  String? _selectedDistrict;

  @override
  void initState() {
    super.initState();
    _fetchExistingData();
    _fetchCountries();
  }

  Future<void> _fetchCountries() async {
    try {
      final data = await supabase
          .from('tbl_country')
          .select()
          .order('country_name');
      setState(() => _countries = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint("Error fetching countries: $e");
    }
  }

  Future<void> _fetchStates(String countryId) async {
    try {
      final data = await supabase
          .from('tbl_states')
          .select()
          .eq('country_id', countryId)
          .order('states_name');
      setState(() {
        _states = List<Map<String, dynamic>>.from(data);
        _selectedStateId = null;
        _selectedDistrictId = null;
        _selectedPlaceId = null;
        _districts = [];
        _places = [];
      });
    } catch (e) {
      debugPrint("Error fetching states: $e");
    }
  }

  Future<void> _fetchDistricts(String stateId) async {
    try {
      final data = await supabase
          .from('tbl_district')
          .select()
          .eq('states_id', stateId)
          .order('district_name');
      setState(() {
        _districts = List<Map<String, dynamic>>.from(data);
        _selectedDistrictId = null;
        _selectedPlaceId = null;
        _places = [];
      });
    } catch (e) {
      debugPrint("Error fetching districts: $e");
    }
  }

  Future<void> _fetchPlaces(String districtId) async {
    try {
      final data = await supabase
          .from('tbl_places')
          .select('place_id, place_name')
          .eq('district_id', districtId)
          .order('place_name');
      setState(() {
        _places = List<Map<String, dynamic>>.from(data);
        _selectedPlaceId = null;
      });
    } catch (e) {
      debugPrint("Error fetching places: $e");
    }
  }

  Future<void> _fetchExistingData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      // 1. Fetch from tbl_user
      final userData = await supabase
          .from('tbl_user')
          .select('user_name, user_contact, user_email, college')
          .eq('id', user.id)
          .single();

      final detailDetails = await supabase
          .from('tbl_user_details')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (detailDetails != null) {
        _recordExists = true;
      }

      if (mounted) {
        setState(() {
          _nameController.text = userData['user_name'] ?? "";
          _phoneController.text = userData['user_contact'] ?? "";
          _collegeController.text = userData['college'] ?? "";

          if (detailDetails != null) {
            _dobController.text = detailDetails['dob'] ?? "";
            _selectedGender = detailDetails['gender'];
            _courseController.text = detailDetails['course'] ?? "";
            _selectedYear = detailDetails['current_year'];
            _gradController.text = detailDetails['expected_graduation'] ?? "";
            _addressController.text = detailDetails['address'] ?? "";
            _pincodeController.text = detailDetails['pincode'] ?? "";
            _selectedPlaceId = detailDetails['place']?.toString();
          }
        });

        // Handle cascading pre-selection based ONLY on 'place' ID
        if (_selectedPlaceId != null) {
          try {
            // Reconstruct hierarchy from tbl_places using ID
            final hierarchy = await supabase
                .from('tbl_places')
                .select('''
                  district_id,
                  tbl_district (
                    district_name,
                    states_id,
                    tbl_states (
                      states_name,
                      country_id,
                      tbl_country (
                        country_name
                      )
                    )
                  )
                ''')
                .eq('place_id', _selectedPlaceId!)
                .maybeSingle();

            if (hierarchy != null) {
              final district = hierarchy['tbl_district'];
              final state = district?['tbl_states'];
              final country = state?['tbl_country'];

              setState(() {
                _selectedNationality = country?['country_name'];
                _selectedState = state?['states_name'];
                _selectedDistrict = district?['district_name'];

                _selectedCountryId = state?['country_id']?.toString();
                _selectedStateId = district?['states_id']?.toString();
                _selectedDistrictId = hierarchy['district_id']?.toString();
              });

              // Pre-fetch lists to ensure dropdowns are populated
              if (_selectedCountryId != null) await _fetchStates(_selectedCountryId!);
              if (_selectedStateId != null) await _fetchDistricts(_selectedStateId!);
              if (_selectedDistrictId != null) await _fetchPlaces(_selectedDistrictId!);
              
              // Ensure place ID is still selected after re-fetching places
              setState(() => _selectedPlaceId = detailDetails?['place']?.toString());
            }
          } catch (e) {
            debugPrint("Error reconstructing hierarchy: $e");
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching existing data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper for safe list searching


  // 1. Save Data to tbl_user_details
  Future<void> _saveAndContinue() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Simple Validation
    if (!_formKey.currentState!.validate() ||
        _selectedGender == null ||
        _selectedNationality == null ||
        _selectedState == null ||
        _selectedDistrict == null ||
        _selectedPlaceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in all required fields properly."),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. UPDATE tbl_user (Removed the .eq() - upsert handles the match via ID automatically)
      await supabase
          .from('tbl_user')
          .update({'id': user.id, 'college': _collegeController.text.trim()})
          .eq('id', user.id);

      // 2. INSERT or UPDATE tbl_user_details (Storing Place ID as foreign key)
      final detailsMap = {
        'user_id': user.id,
        'dob': _dobController.text,
        'gender': _selectedGender,
        'course': _courseController.text.trim(),
        'current_year': _selectedYear,
        'expected_graduation': _gradController.text.trim(),
        'address': _addressController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'place': int.tryParse(_selectedPlaceId ?? ''),
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
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CompleteProfileSkills()),
        );
      }
    } catch (e) {
      debugPrint("Full Error: $e"); // Check your console for this!
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error saving profile: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          "Step 1: Basic Details",
          style: GoogleFonts.poppins(
            color: brandNavy,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            _buildSectionHeader("Personal Identity"),
            _buildField(
              "Full Name",
              Icons.person_outline,
              controller: _nameController,
              validator: (v) => v!.isEmpty ? "Name is required" : null,
            ),

            // 🔹 Display Email (Read-only as it's from Auth)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: TextEditingController(
                  text: supabase.auth.currentUser?.email ?? "",
                ),
                readOnly: true,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: brandNavy.withOpacity(0.5),
                ),
                decoration: InputDecoration(
                  labelText: "Email Address",
                  labelStyle: TextStyle(color: brandNavy.withOpacity(0.5)),
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: brandNavy.withOpacity(0.3),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: _buildDatePicker("Date of Birth", _dobController),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdown(
                      "Gender",
                      _selectedGender,
                      [
                        "Male",
                        "Female",
                        "Other",
                      ],
                      (val) => _selectedGender = val,
                      validator: (v) => v == null ? "Required" : null,
                  ),
                ),
              ],
            ),

            Row(
              children: [
                Expanded(
                  child: _buildLocationDropdown(
                    "Nationality",
                    _selectedCountryId,
                    _countries
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e['country_id'].toString(),
                            child: Text(e['country_name']),
                          ),
                        )
                        .toList(),
                    (val) {
                      setState(() {
                        _selectedCountryId = val;
                        _selectedNationality = _countries.firstWhere(
                          (e) => e['country_id'].toString() == val,
                        )['country_name'];
                      });
                      if (val != null) _fetchStates(val);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildField(
                    "Phone Number",
                    Icons.phone_android_outlined,
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v!.isEmpty) return "Required";
                      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) return "Invalid mobile number";
                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
            _buildSectionHeader("Academic Background"),
            _buildField(
              "University / College",
              Icons.school_outlined,
              controller: _collegeController,
              validator: (v) => v!.isEmpty ? "Required" : null,
            ),
            _buildField(
              "Stream / Course",
              Icons.auto_stories_outlined,
              controller: _courseController,
              hint: "e.g. B.Tech Computer Science",
              validator: (v) => v!.isEmpty ? "Required" : null,
            ),

            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                      "Current Year", _selectedYear, [
                    "1st Year",
                    "2nd Year",
                    "3rd Year",
                    "4th Year",
                    "5th Year",
                  ], (val) => _selectedYear = val,
                     validator: (v) => v == null ? "Required" : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildField(
                    "Academic Year",
                    Icons.calendar_today_outlined,
                    controller: _gradController,
                    hint: "e.g. 2024-2026",
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
            _buildSectionHeader("Address & Location"),
            _buildField(
              "Full Address",
              Icons.home_outlined,
              controller: _addressController,
              maxLines: 2,
              validator: (v) => v!.isEmpty ? "Required" : null,
            ),

            Row(
              children: [
                Expanded(
                  child: _buildLocationDropdown(
                    "State",
                    _selectedStateId,
                    _states
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e['states_id'].toString(),
                            child: Text(e['states_name']),
                          ),
                        )
                        .toList(),
                    (val) {
                      setState(() {
                        _selectedStateId = val;
                        _selectedState = _states.firstWhere(
                          (e) => e['states_id'].toString() == val,
                        )['states_name'];
                      });
                      if (val != null) _fetchDistricts(val);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildLocationDropdown(
                    "District",
                    _selectedDistrictId,
                    _districts
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e['district_id'].toString(),
                            child: Text(e['district_name']),
                          ),
                        )
                        .toList(),
                    (val) {
                      setState(() {
                        _selectedDistrictId = val;
                        _selectedDistrict = _districts.firstWhere(
                          (e) => e['district_id'].toString() == val,
                        )['district_name'];
                      });
                      if (val != null) _fetchPlaces(val);
                    },
                  ),
                ),
              ],
            ),

            Row(
              children: [
                Expanded(
                  child: _buildField(
                    "Pincode",
                    Icons.pin_drop_outlined,
                    controller: _pincodeController,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v!.isEmpty) return "Required";
                      if (!RegExp(r'^\d{6}$').hasMatch(v)) return "6 digits required";
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildLocationDropdown(
                    "Place",
                    _selectedPlaceId,
                    _places
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e['place_id'].toString(),
                            child: Text(e['place_name']),
                          ),
                        )
                        .toList(),
                    (val) => setState(() => _selectedPlaceId = val),
                  ),
                ),
              ],
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

  // --- UI HELPER METHODS ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: brandTeal,
            ),
          ),
          const Divider(thickness: 1),
        ],
      ),
    );
  }

  Widget _buildField(
    String label,
    IconData icon, {
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    TextEditingController? controller,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        onChanged: onChanged,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.poppins(fontSize: 14, color: brandNavy),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: brandNavy.withOpacity(0.7)),
          prefixIcon: Icon(icon, color: brandNavy.withOpacity(0.6), size: 20),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: brandTeal, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged, {
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        style: GoogleFonts.poppins(fontSize: 14, color: brandNavy),
        dropdownColor: Colors.white,
        icon: const Icon(Icons.arrow_drop_down, color: brandNavy),
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: brandNavy.withOpacity(0.7)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 16,
          ),
        ),
        items: items
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Text(
                  e,
                  style: GoogleFonts.poppins(color: brandNavy, fontSize: 14),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildLocationDropdown(
    String label,
    String? value,
    List<DropdownMenuItem<String>> items,
    Function(String?) onChanged, {
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        style: GoogleFonts.poppins(fontSize: 14, color: brandNavy),
        dropdownColor: Colors.white,
        icon: const Icon(Icons.arrow_drop_down, color: brandNavy),
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: brandNavy.withOpacity(0.7)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 16,
          ),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDatePicker(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        style: GoogleFonts.poppins(fontSize: 14, color: brandNavy),
        validator: (v) => v == null || v.isEmpty ? "Required" : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: brandNavy.withOpacity(0.7)),
          suffixIcon: const Icon(
            Icons.calendar_month,
            size: 20,
            color: brandNavy,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1),
          ),
        ),
        onTap: () async {
          DateTime? picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
            firstDate: DateTime(1990),
            lastDate: DateTime.now(),
          );
          if (picked != null) {
            controller.text = DateFormat('yyyy-MM-dd').format(picked);
          }
        },
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
        onPressed: _isLoading ? null : _saveAndContinue,
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                "Continue to Step 2",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
