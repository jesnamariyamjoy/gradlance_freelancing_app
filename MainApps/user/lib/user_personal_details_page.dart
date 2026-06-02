import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserPersonalDetailsPage extends StatefulWidget {
  const UserPersonalDetailsPage({super.key});

  @override
  State<UserPersonalDetailsPage> createState() => _UserPersonalDetailsPageState();
}

class _UserPersonalDetailsPageState extends State<UserPersonalDetailsPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  Map<String, dynamic>? userData;
  Map<String, dynamic>? userDetails;

  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);

  @override
  void initState() {
    super.initState();
    fetchDetails();
  }

  Future<void> fetchDetails() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final results = await Future.wait([
        supabase.from('tbl_user').select().eq('id', user.id).single(),
        supabase.from('tbl_user_details').select('''
          *,
          tbl_places (
            place_name,
            tbl_district (
              district_name,
              tbl_states (
                states_name,
                tbl_country (
                  country_name
                )
              )
            )
          )
        ''').eq('user_id', user.id).maybeSingle(),
      ]);

      setState(() {
        userData = results[0];
        userDetails = results[1];
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => isLoading = false);
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: brandNavy, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Personal Details",
          style: GoogleFonts.poppins(color: brandNavy, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: brandTeal))
          : userData == null
              ? const Center(child: Text("Unable to load profile meta-data"))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildProfileHeader(),
                      const SizedBox(height: 32),
                      _buildInfoSection("Contact Information", [
                        _infoTile(Icons.email_outlined, "Email Address", userData!['user_email']),
                        _infoTile(Icons.phone_android_outlined, "Phone Number", userData!['user_contact'] ?? "Not provided"),
                      ]),
                      const SizedBox(height: 24),
                      _buildInfoSection("Academic Profile", [
                        _infoTile(Icons.school_outlined, "College/University", userData!['college'] ?? "Not provided"),
                        _infoTile(Icons.auto_stories_outlined, "Course", userDetails?['course'] ?? "Not provided"),
                        _infoTile(Icons.calendar_today_outlined, "Current Year", userDetails?['current_year'] ?? "Not provided"),
                        _infoTile(Icons.access_time_outlined, "Expected Graduation", userDetails?['expected_graduation'] ?? "Not provided"),
                      ]),
                      const SizedBox(height: 24),
                      _buildInfoSection("Personal Meta", [
                        _infoTile(Icons.cake_outlined, "Date of Birth", userDetails?['dob'] ?? "Not provided"),
                        _infoTile(Icons.person_outline_rounded, "Gender", userDetails?['gender'] ?? "Not provided"),
                        _infoTile(Icons.location_on_outlined, "Address", userDetails?['address'] ?? "Not provided"),
                        _infoTile(Icons.map_outlined, "Location", _formatLocation()),
                      ]),
                    ],
                  ),
                ),
    );
  }

  String _formatLocation() {
    if (userDetails == null || userDetails!['tbl_places'] == null) return "Not provided";
    final place = userDetails!['tbl_places'];
    final district = place['tbl_district'];
    final state = district?['tbl_states'];
    final country = state?['tbl_country'];

    return "${place['place_name']}, ${district?['district_name']}, ${state?['states_name']}, ${country?['country_name']}";
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: brandTeal.withOpacity(0.1),
          backgroundImage: userData!['user_photo'] != null ? NetworkImage(userData!['user_photo']) : null,
          child: userData!['user_photo'] == null ? const Icon(Icons.person, size: 50, color: brandTeal) : null,
        ),
        const SizedBox(height: 16),
        Text(
          userData!['user_name'] ?? "User",
          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: brandNavy),
        ),
        Text(
          "Student ID: GL-S-${userData!['id'].toString().substring(0, 8).toUpperCase()}",
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: brandTeal, letterSpacing: 1),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: brandNavy.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: brandNavy),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: brandNavy)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
