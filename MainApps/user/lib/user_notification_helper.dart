import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;

  // Local state for toggles
  bool pushEnabled = true;
  bool emailEnabled = true;
  bool gigAlerts = true;
  bool messageAlerts = true;
  bool paymentAlerts = true;

  // 🎨 BRAND COLORS
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Logic: Fetch current preferences from Supabase 'tbl_user_details'
    // For now, using simulated delay
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _updateSetting(String key, bool value) async {
    setState(() => _isLoading = true);
    try {
      // Example Supabase Update:
      // await supabase.from('tbl_user_details').update({key: value}).eq('user_id', supabase.auth.currentUser!.id);
      
      _showSuccessSnackBar("Preference updated");
    } catch (e) {
      _showErrorSnackBar("Failed to update setting");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: brandTeal, behavior: SnackBarBehavior.floating),
    );
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F14) : const Color(0xFFF4F7F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : brandNavy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Notifications",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: isDark ? Colors.white : brandNavy),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: brandTeal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("Master Controls"),
                  _buildToggleCard(
                    title: "Push Notifications",
                    subtitle: "Receive alerts on your device",
                    value: pushEnabled,
                    icon: Icons.notifications_active_outlined,
                    onChanged: (val) => setState(() => pushEnabled = val),
                  ),
                  _buildToggleCard(
                    title: "Email Notifications",
                    subtitle: "Receive updates via your inbox",
                    value: emailEnabled,
                    icon: Icons.alternate_email_rounded,
                    onChanged: (val) => setState(() => emailEnabled = val),
                  ),

                  const SizedBox(height: 32),
                  _buildSectionHeader("Activity Alerts"),
                  _buildToggleCard(
                    title: "New Gig Alerts",
                    subtitle: "Get notified when new work matches your skills",
                    value: gigAlerts,
                    icon: Icons.work_outline_rounded,
                    onChanged: (val) => setState(() => gigAlerts = val),
                  ),
                  _buildToggleCard(
                    title: "Direct Messages",
                    subtitle: "Alerts for new chat messages",
                    value: messageAlerts,
                    icon: Icons.chat_bubble_outline_rounded,
                    onChanged: (val) => setState(() => messageAlerts = val),
                  ),
                  _buildToggleCard(
                    title: "Payments & Payouts",
                    subtitle: "Updates on your earnings and withdrawals",
                    value: paymentAlerts,
                    icon: Icons.account_balance_wallet_outlined,
                    onChanged: (val) => setState(() => paymentAlerts = val),
                  ),
                  
                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      "System notifications regarding security and account recovery cannot be turned off.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: brandTeal,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildToggleCard({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required Function(bool) onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? brandNavy.withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark) BoxShadow(color: brandNavy.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: brandTeal.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: brandTeal, size: 22),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: isDark ? Colors.white : brandNavy,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
        ),
        value: value,
        activeColor: brandTeal,
        onChanged: onChanged,
      ),
    );
  }
}