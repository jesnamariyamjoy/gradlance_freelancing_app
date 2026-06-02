import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

// Ensure these imports match your project structure
import 'package:user/accountsecurity.dart';
import 'package:user/complaint.dart';
import 'package:user/faq_page.dart';
import 'package:user/user_edit_profile_page.dart';
import 'package:user/user_login_page.dart';
import 'package:user/my_complaints_page.dart';
import 'package:user/notifications_page.dart';
import 'package:user/profilestep1.dart';
import 'package:user/user_notification_helper.dart';
import 'package:user/user_personal_details_page.dart';
import 'package:user/providers/theme_provider.dart';
import 'package:user/subscription_page.dart';
import 'package:user/bank_details_page.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? userData;
  bool isProfileComplete = false;
  String? profileImageUrl;
  File? _imageFile;
  bool isUploading = false;

  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandLightGrey = Color(0xFFF4F7F9);

  @override
  void initState() {
    super.initState();
    fetchUser();
  }

  /// Fixes the Signed URL issue by returning the String directly from SDK
  Future<String?> _resolveSupabaseSignedUrl(String publicUrl) async {
    try {
      if (!publicUrl.contains('/storage/v1/object/public/')) return publicUrl;

      final uri = Uri.parse(publicUrl);
      final pathSegments = uri.pathSegments;

      // Typical path: /storage/v1/object/public/bucket_name/file_path.png
      final publicIndex = pathSegments.indexOf('public');
      if (publicIndex == -1 || pathSegments.length < publicIndex + 3)
        return publicUrl;

      final bucket = pathSegments[publicIndex + 1];
      final filePath = pathSegments.sublist(publicIndex + 2).join('/');

      // Modern Supabase SDK returns String directly
      final String signedUrl = await supabase.storage
          .from(bucket)
          .createSignedUrl(filePath, 3600);

      return signedUrl;
    } catch (e) {
      debugPrint("Signed URL Error: $e");
      return publicUrl;
    }
  }

  Future<void> fetchUser() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      // 1. Fetch Basic Info and Completion Status
      final userRes = await supabase
          .from('tbl_user')
          .select()
          .eq('id', currentUser.id)
          .single();

      final detailsRes = await supabase
          .from('tbl_user_details')
          .select('profile_completed')
          .eq('user_id', currentUser.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          userData = userRes;
          isProfileComplete =
              detailsRes != null && detailsRes['profile_completed'] == true;
        });

        // 2. Resolve Image URL
        final String? rawPhoto = userRes['user_photo'];
        if (rawPhoto != null && rawPhoto.isNotEmpty) {
          final resolvedUrl = await _resolveSupabaseSignedUrl(rawPhoto);
          if (mounted) {
            setState(() => profileImageUrl = resolvedUrl);
          }
        }
      }
    } catch (e) {
      debugPrint("Fetch User Error: $e");
    }
  }

  Future<void> pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile == null) return;

    setState(() {
      _imageFile = File(pickedFile.path);
      isUploading = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User session expired');

      final ext = _imageFile!.path.split('.').last;
      final fileName =
          "User-$userId-${DateTime.now().millisecondsSinceEpoch}.$ext";

      await supabase.storage
          .from('User')
          .upload(
            fileName,
            _imageFile!,
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl = supabase.storage.from('User').getPublicUrl(fileName);

      await supabase
          .from('tbl_user')
          .update({'user_photo': imageUrl})
          .eq('id', userId);

      await fetchUser();
      _showSnackBar("Profile updated successfully", brandTeal);
    } catch (e) {
      _showSnackBar("Update failed: ${e.toString()}", Colors.redAccent);
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (userData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: brandTeal)),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final email = supabase.auth.currentUser?.email ?? "";

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F14) : brandLightGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          "My Profile",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : brandNavy,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: brandTeal.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 55,
                      backgroundColor: isDark ? brandNavy : Colors.white,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : (profileImageUrl != null
                                ? NetworkImage(profileImageUrl!)
                                : null),
                      child: _imageFile == null && profileImageUrl == null
                          ? Icon(
                              Icons.person_rounded,
                              size: 50,
                              color: brandTeal.withOpacity(0.5),
                            )
                          : null,
                    ),
                  ),
                  GestureDetector(
                    onTap: pickAndUploadImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: brandTeal,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF0A0F14)
                              : brandLightGrey,
                          width: 3,
                        ),
                      ),
                      child: isUploading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  userData!['user_name'] ?? "Gradlance User",
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : brandNavy,
                  ),
                ),
                if (userData!['is_premium'] == true) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.workspace_premium,
                          color: Colors.amber,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "PRO",
                          style: GoogleFonts.poppins(
                            color: Colors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            Text(
              email,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  userData!['rating']?.toString() ?? "0.0",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : brandNavy,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  "Rating",
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildProfileButton(),
            const SizedBox(height: 32),
            _buildSectionTitle("Account Settings"),
            _menuTile(
              Icons.person_outline_rounded,
              "Personal Details",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserPersonalDetailsPage(),
                ),
              ),
            ),
            _menuTile(
              Icons.workspace_premium_outlined,
              "My Subscriptions",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionPage(),
                ),
              ),
            ),
            _menuTile(
              Icons.wallet_outlined, 
              "Payout Settings",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BankDetailsPage(),
                ),
              ),
            ),
            _menuTile(
              Icons.shield_outlined,
              "Account Security",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccountSecurityPage(),
                ),
              ),
            ),
            _buildSectionTitle("Preferences"),
            _customToggleTile(context),
            _menuTile(
              Icons.notifications_none_rounded,
              "Notification Settings",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationSettingsPage(),
                ),
              ),
            ),
            _buildSectionTitle("Support & Feedback"),
            _menuTile(
              Icons.chat_bubble_outline_rounded,
              "My Support Tickets",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyComplaintsPage(),
                ),
              ),
            ),
            _menuTile(
              Icons.help_outline_rounded,
              "Report an issue",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserComplaintPage(),
                ),
              ),
            ),
            
            _menuTile(
              Icons.help_outline_rounded,
              "Help Center",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FAQPage()),
              ),
            ),
            const Divider(thickness: 1, height: 40),
            _menuTile(
              Icons.logout_rounded,
              "Sign Out",
              isDanger: true,
              onTap: () async {
                await supabase.auth.signOut();
                if (mounted)
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: isProfileComplete
              ? [brandTeal, const Color(0xFF178A8A)]
              : [brandNavy, const Color(0xFF1A3045)],
        ),
        boxShadow: [
          BoxShadow(
            color: (isProfileComplete ? brandTeal : brandNavy).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => isProfileComplete
                  ? const EditProfessionalProfilePage()
                  : const CompleteProfileBase(),
            ),
          );
          fetchUser();
        },
        child: Text(
          isProfileComplete
              ? "Edit Professional Profile"
              : "Complete Professional Profile",
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
        child: Text(
          title.toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: brandTeal,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _customToggleTile(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? brandNavy.withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          if (!isDark)
            BoxShadow(color: brandNavy.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: SwitchListTile(
        title: Text(
          "Dark Mode",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 15),
        ),
        secondary: const Icon(Icons.dark_mode_outlined, color: brandTeal),
        value: themeProvider.isDark,
        activeColor: brandTeal,
        onChanged: (value) => themeProvider.toggleTheme(value),
      ),
    );
  }

  Widget _menuTile(
    IconData icon,
    String title, {
    bool isDanger = false,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? brandNavy.withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          if (!isDark)
            BoxShadow(color: brandNavy.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        leading: Icon(
          icon,
          color: isDanger ? Colors.redAccent : brandTeal,
          size: 22,
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: isDanger
                ? Colors.redAccent
                : (isDark ? Colors.white : brandNavy),
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: isDanger ? Colors.redAccent : Colors.grey[400],
        ),
        onTap: onTap,
      ),
    );
  }
}
