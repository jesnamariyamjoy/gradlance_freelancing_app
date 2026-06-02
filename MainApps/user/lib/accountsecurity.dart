import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:user/changepass.dart';

class AccountSecurityPage extends StatefulWidget {
  const AccountSecurityPage({super.key});

  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  // 🎨 THEME
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  Future<void> _handlePasswordReset() async {
    final email = supabase.auth.currentUser?.email;
    if (email == null) return;

    setState(() => _isLoading = true);
    try {
      await supabase.auth.resetPasswordForEmail(email);
      _showSuccessSnackBar("Password reset link sent to $email");
    } catch (e) {
      _showErrorSnackBar("Error: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: brandTeal),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

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
          "Account Security",
          style: GoogleFonts.poppins(color: brandNavy, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: brandTeal))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSecurityHeader(),
                const SizedBox(height: 32),
                
                _buildSectionLabel("Login Credentials"),
                _buildInfoTile(LucideIcons.mail, "Email Address", user?.email ?? "Not available"),
                const SizedBox(height: 12),
                _buildActionTile(
  LucideIcons.lock, 
  "Change Password", 
  "Send a reset link to your email",
  onTap: () {
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => const ChangePasswordPage())
    );
  },
),
                
                const SizedBox(height: 32),
                _buildSectionLabel("Advanced Security"),
                _buildToggleTile(LucideIcons.shieldCheck, "Two-Factor Auth", false),
                _buildInfoTile(LucideIcons.clock, "Last Login", user?.lastSignInAt ?? "Unknown"),
                
                const SizedBox(height: 40),
                _buildDangerZone(),
              ],
            ),
          ),
    );
  }

  Widget _buildSecurityHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: brandNavy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.shieldCheck, color: brandTeal, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Security Status", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                Text("Your account is secure", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: brandTeal, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: brandGrey, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, size: 20, color: brandNavy),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
              Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: brandNavy)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, String subtitle, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: brandGrey), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(icon, color: brandTeal),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: brandNavy)),
                  Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile(IconData icon, String title, bool value) {
    return SwitchListTile(
      secondary: Icon(icon, color: brandNavy),
      title: Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
      value: value,
      activeColor: brandTeal,
      onChanged: (val) {}, // Placeholder for 2FA logic
    );
  }

  Widget _buildDangerZone() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text("Danger Zone", style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {}, // Logic for account deletion
            child: Text("Deactivate Account", style: GoogleFonts.poppins(color: Colors.red, fontSize: 13)),
          )
        ],
      ),
    );
  }
}