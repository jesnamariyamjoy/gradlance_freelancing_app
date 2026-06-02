import 'dart:io';
import 'package:client/client_complaint_page.dart';
import 'package:client/faq_page.dart';
import 'package:client/mycomplaints.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:client/providers/theme_provider.dart';
import 'package:path/path.dart' as path;
import 'package:client/subscription_page.dart';
import 'client_login_page.dart';

class ClientProfilePage extends StatefulWidget {
  const ClientProfilePage({super.key});

  @override
  State<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends State<ClientProfilePage> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  Map<String, dynamic>? profileData;

  final Color brandNavy = const Color(0xFF102030);
  final Color brandTeal = Color(0xFF20A0A0);
  final Color brandGrey = const Color(0xFFF4F7F9);

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final data = await supabase
          .from('tbl_client')
          .select()
          .eq('client_id', userId)
          .single();

      if (mounted) {
        setState(() {
          profileData = data;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF20A0A0)),
        ),
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F14) : brandGrey,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF102030) : Colors.white,
        title: Text(
          "Account Settings",
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : brandNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 30),
            _sectionHeader("PROFILE ACCESSIBILITY"),
            _menuCard([
              SwitchListTile(
                title: Text(
                  "Dark Mode",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : brandNavy,
                  ),
                ),
                subtitle: Text(
                  "Enable dark mode across the app",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                ),
                secondary: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: brandTeal.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    LucideIcons.moon,
                    color: isDark ? brandTeal : brandNavy,
                    size: 20,
                  ),
                ),
                value: Provider.of<ThemeProvider>(context).isDark,
                activeColor: brandTeal,
                onChanged: (val) => Provider.of<ThemeProvider>(
                  context,
                  listen: false,
                ).toggleTheme(val),
              ),
              Divider(
                height: 1,
                indent: 70,
                endIndent: 20,
                color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1),
              ),
              _menuItem(
                LucideIcons.user,
                "Personal Information",
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ViewProfileScreen(data: profileData!),
                    ),
                  );
                },
                subtitle: "View your full profile details",
              ),

              _menuItem(
                LucideIcons.userPlus,
                "Complete/Edit Profile",
                () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(data: profileData!),
                    ),
                  );
                  _fetchProfile();
                },
                subtitle: "Update name, contact & business address",
              ),

              _menuItem(
                LucideIcons.award,
                "My Subscriptions",
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SubscriptionPage()),
                  );
                },
                subtitle: "Manage your subscription & billing",
              ),
            ]),
            const SizedBox(height: 25),
            _sectionHeader("SECURITY & SUPPORT"),
            _menuCard([
              _menuItem(
                LucideIcons.lock,
                "Security & Password",
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangePasswordScreen(
                        oldStoredPassword:
                            profileData!['client_password'] ?? "",
                      ),
                    ),
                  );
                },
                subtitle: "Manage your account security",
              ),

              _menuItem(
                LucideIcons.circleQuestionMark,
                "Help & Support",
                () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                    ),
                    builder: (context) => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Wrap(
                          children: [
                            // 1. FAQ PAGE (Newly Integrated)
                            ListTile(
                              leading: const Icon(
                                LucideIcons.circleQuestionMark500,
                                color: Color(0xFF20A0A0),
                              ),
                              title: Text(
                                "Browse FAQs",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                "Quick answers to common questions",
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ClientFAQPage(),
                                  ),
                                );
                              },
                            ),
                            const Divider(indent: 70, endIndent: 20),

                            // 2. RAISE COMPLAINT
                            ListTile(
                              leading: const Icon(
                                LucideIcons.messageSquarePlus,
                                color: Colors.orange,
                              ),
                              title: Text(
                                "Raise New Ticket",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                "Report an issue or project dispute",
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ClientComplaintPage(),
                                  ),
                                );
                              },
                            ),

                            // 3. HISTORY
                            ListTile(
                              leading: const Icon(
                                LucideIcons.history,
                                color: Color(0xFF20A0A0),
                              ),
                              title: Text(
                                "Ticket History",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                "Track your previous support requests",
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ClientComplaintStatusPage(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                subtitle: "FAQs, contact support & ticket status",
              ),
            ]),
            const SizedBox(height: 30),
            _menuCard([
              _menuItem(
                LucideIcons.logOut,
                "Logout Session",
                () {
                  _showLogoutDialog();
                },
                color: Colors.redAccent,
                textColor: Colors.redAccent,
              ),
            ]),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF102030) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: brandNavy.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: brandTeal.withOpacity(0.1),
            backgroundImage: profileData?['client_logo'] != null
                ? NetworkImage(profileData?['client_logo'])
                : null,
            child: profileData?['client_logo'] == null
                ? const Icon(
                    LucideIcons.briefcase,
                    size: 40,
                    color: Color(0xFF20A0A0),
                  )
                : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profileData?['client_name'] ?? "Business Name",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : brandNavy,
                  ),
                ),
                Text(
                  profileData?['client_email'] ?? "Email",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (profileData?['client_status'] == 'approved'
                                    ? Colors.green
                                    : Colors.orange)
                                .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        (profileData?['client_status'] ?? "PENDING")
                            .toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: profileData?['client_status'] == 'approved'
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                    ),
                    if (profileData?['is_premium'] == true) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber, width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.workspace_premium,
                              color: Colors.amber,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "PRO",
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF102030) : Colors.white,
          title: Text(
            "Logout?",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : brandNavy,
            ),
          ),
          content: Text(
            "Are you sure you want to end your session?",
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white70 : brandNavy,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: GoogleFonts.poppins(color: brandTeal),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                await supabase.auth.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "Logout",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _menuCard(List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF102030) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: brandNavy.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _menuItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    String? subtitle,
    Color? color,
    Color? textColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (color ?? brandTeal).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: color ?? (isDark ? brandTeal : brandNavy),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor ?? (isDark ? Colors.white : brandNavy),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        size: 18,
        color: isDark ? Colors.white24 : Colors.grey,
      ),
    );
  }
}

class ViewProfileScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const ViewProfileScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(title: const Text("My Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white,
                backgroundImage: data['client_logo'] != null
                    ? NetworkImage(data['client_logo'])
                    : null,
                child: data['client_logo'] == null
                    ? const Icon(
                        LucideIcons.briefcase,
                        size: 60,
                        color: Color(0xFF20A0A0),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 30),
            _infoCard([
              _infoTile("Company Name", data['client_name']),
              _infoTile("Registered Email", data['client_email']),
              _infoTile("Contact Number", data['client_contact']),
              _infoTile(
                "Business Address",
                data['client_address'] ?? "Not Provided",
                isLast: true,
              ),
            ]),
            const SizedBox(height: 20),
            _infoCard([
              _infoTile(
                "KYC Verification",
                data['client_status']?.toUpperCase() ?? "PENDING",
              ),
              if (data['client_proof'] != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Business Proof Document is securely uploaded.",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ], "VERIFICATION STATUS"),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(List<Widget> children, [String? title]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 8),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _infoTile(String label, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF102030),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const EditProfileScreen({super.key, required this.data});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _email;
  late TextEditingController _contact;
  late TextEditingController _address;
  bool _isSaving = false;

  File? _logoImage;
  File? _proofImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(bool isLogo) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          Text(
            "Select Image Source",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: const Color(0xFF102030),
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(LucideIcons.camera, color: Color(0xFF20A0A0)),
            title: Text("Take a Photo", style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.pop(context);
              _processImage(isLogo, ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.image, color: Color(0xFF20A0A0)),
            title: Text("Choose from Gallery", style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.pop(context);
              _processImage(isLogo, ImageSource.gallery);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _processImage(bool isLogo, ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 50, // Compress to 50%
      maxWidth: 800, // Resize to reasonable web/app dimensions
      maxHeight: 800,
    );
    if (image != null) {
      if (mounted) {
        setState(() {
          if (isLogo) {
            _logoImage = File(image.path);
          } else {
            _proofImage = File(image.path);
          }
        });
      }
    }
  }

  Future<String?> _uploadImage(File file, String prefix) async {
    try {
      final fileName =
          "${prefix}_${DateTime.now().millisecondsSinceEpoch}${path.extension(file.path)}";
      await Supabase.instance.client.storage
          .from('Client')
          .upload(fileName, file);
      return Supabase.instance.client.storage
          .from('Client')
          .getPublicUrl(fileName);
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.data['client_name']);
    _email = TextEditingController(text: widget.data['client_email']);
    _contact = TextEditingController(text: widget.data['client_contact']);
    _address = TextEditingController(text: widget.data['client_address'] ?? "");
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final updates = <String, dynamic>{
        'client_name': _name.text.trim(),
        'client_email': _email.text.trim(),
        'client_contact': _contact.text.trim(),
        'client_address': _address.text.trim(),
      };

      // Upload images in parallel if they exist
      if (_logoImage != null || _proofImage != null) {
        final List<Future<String?>> uploadTasks = [];

        if (_logoImage != null) {
          uploadTasks.add(_uploadImage(_logoImage!, "logo"));
        } else {
          uploadTasks.add(Future.value(null));
        }

        if (_proofImage != null) {
          uploadTasks.add(_uploadImage(_proofImage!, "proof"));
        } else {
          uploadTasks.add(Future.value(null));
        }

        final results = await Future.wait(uploadTasks);

        if (results[0] != null) updates['client_logo'] = results[0];
        if (results[1] != null) updates['client_proof'] = results[1];

        updates['client_status'] = 'pending'; // Requires re-verification
      }

      await Supabase.instance.client
          .from('tbl_client')
          .update(updates)
          .eq('client_id', widget.data['client_id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Profile updated successfully! Security review initiated.",
            ),
            backgroundColor: Color(0xFF20A0A0),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Update failed: $e"),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(title: const Text("Edit Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (widget.data['client_logo'] == null ||
                  widget.data['client_proof'] == null)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Provide a logo and business proof to get verified and start posting works.",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  _buildImagePickerBox(
                    "Update Logo",
                    _logoImage ??
                        (widget.data['client_logo'] != null
                            ? widget.data['client_logo']
                            : null),
                    true,
                  ),
                  const SizedBox(width: 16),
                  _buildImagePickerBox(
                    "Update Proof",
                    _proofImage ??
                        (widget.data['client_proof'] != null
                            ? widget.data['client_proof']
                            : null),
                    false,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildInputField("Business Name", _name, LucideIcons.briefcase),
              const SizedBox(height: 16),
              _buildInputField(
                "Registered Email",
                _email,
                LucideIcons.mail,
                keyboard: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _buildInputField(
                "Contact Phone",
                _contact,
                LucideIcons.phone,
                keyboard: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildInputField(
                "Business Address",
                _address,
                LucideIcons.mapPin,
                maxLines: 3,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF102030),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Update Profile",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF20A0A0)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return "Required field";
        if (keyboard == TextInputType.emailAddress) {
          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
            return "Enter a valid email";
          }
        }
        if (keyboard == TextInputType.phone) {
          if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) {
            return "Invalid 10-digit number";
          }
        }
        return null;
      },
    );
  }

  Widget _buildImagePickerBox(String label, dynamic image, bool isLogo) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF102030),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _pickImage(isLogo),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: const Color(0xFF102030).withOpacity(0.05),
                ),
                image: image != null
                    ? DecorationImage(
                        image: image is File
                            ? FileImage(image)
                            : NetworkImage(image.toString()) as ImageProvider,
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: image == null
                  ? const Center(
                      child: Icon(
                        Icons.add_a_photo_outlined,
                        color: Color(0xFF102030),
                        size: 24,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  final String oldStoredPassword;
  const ChangePasswordScreen({super.key, required this.oldStoredPassword});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPass = TextEditingController();
  final _newPass = TextEditingController();
  final _retypePass = TextEditingController();
  bool _isUpdating = false;

  // 1. Add boolean states for visibility
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureRetype = true;

  Future<void> _update() async {
    if (!_formKey.currentState!.validate()) return;
    if (_oldPass.text != widget.oldStoredPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Incorrect old password"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (_newPass.text != _retypePass.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Passwords do not match"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _isUpdating = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.updateUser(UserAttributes(password: _newPass.text));
      await supabase
          .from('tbl_client')
          .update({'client_password': _newPass.text})
          .eq('client_id', supabase.auth.currentUser!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password changed successfully!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(title: const Text("Security")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Change Password",
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF102030),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Ensure your account is using a long, random password to stay secure.",
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 30),

              // 2. Pass the specific bool and a callback to the helper
              _buildPassField("Current Password", _oldPass, _obscureOld, () {
                setState(() => _obscureOld = !_obscureOld);
              }),
              const SizedBox(height: 16),
              _buildPassField("New Password", _newPass, _obscureNew, () {
                setState(() => _obscureNew = !_obscureNew);
              }),
              const SizedBox(height: 16),
              _buildPassField(
                "Retype New Password",
                _retypePass,
                _obscureRetype,
                () {
                  setState(() => _obscureRetype = !_obscureRetype);
                },
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isUpdating ? null : _update,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF102030),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _isUpdating
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Update Password",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPassField(
    String label,
    TextEditingController controller,
    bool isObscured,
    VoidCallback onToggle,
  ) {
    return TextFormField(
      controller: controller,
      obscureText: isObscured, // Uses the passed bool
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(
          LucideIcons.lock,
          size: 20,
          color: Color(0xFF20A0A0),
        ),
        // Added Suffix Icon for the Eye toggle
        suffixIcon: IconButton(
          icon: Icon(
            isObscured ? LucideIcons.eyeOff : LucideIcons.eye,
            size: 20,
            color: Colors.grey,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (v) => v!.length < 6 ? "Minimum 6 characters" : null,
    );
  }
}
