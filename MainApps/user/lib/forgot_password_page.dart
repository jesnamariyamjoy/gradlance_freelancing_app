import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:math';

class UserForgotPasswordPage extends StatefulWidget {
  const UserForgotPasswordPage({super.key});

  @override
  State<UserForgotPasswordPage> createState() => _UserForgotPasswordPageState();
}

class _UserForgotPasswordPageState extends State<UserForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _captchaController = TextEditingController();
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  int _num1 = 0;
  int _num2 = 0;

  @override
  void initState() {
    super.initState();
    _generateCaptcha();
  }

  void _generateCaptcha() {
    final random = Random();
    setState(() {
      _num1 = random.nextInt(10) + 1; // 1 to 10
      _num2 = random.nextInt(10) + 1; // 1 to 10
      _captchaController.clear();
    });
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();
    final answer = int.tryParse(_captchaController.text.trim());

    if (email.isEmpty) {
      _showSnackBar("Please enter your email address.", isError: true);
      return;
    }

    if (answer == null || answer != (_num1 + _num2)) {
      _showSnackBar("Incorrect math puzzle answer.", isError: true);
      _generateCaptcha();
      return;
    }

    setState(() => _isLoading = true);

    try {
      await supabase.auth.resetPasswordForEmail(email);
      _showSuccessDialog(email);
    } catch (e) {
      _showSnackBar("Error sending reset link: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade800 : brandTeal,
      ),
    );
  }

  void _showSuccessDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Check your email", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: brandNavy)),
          content: Text(
            "We've sent a secure password reset link to $email. Please check your inbox and click the link to reset your password.",
            style: GoogleFonts.poppins(fontSize: 14, color: brandNavy.withOpacity(0.8)),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: brandTeal),
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // switch back to login
              },
              child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Reset Password", style: GoogleFonts.poppins(color: brandNavy, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: brandNavy),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: brandTeal.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(LucideIcons.shieldAlert, size: 60, color: brandTeal),
            ),
            const SizedBox(height: 32),
            Text(
              "Forgot your password?",
              style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: brandNavy),
            ),
            const SizedBox(height: 12),
            Text(
              "Enter your registered email address below, complete the security puzzle, and we'll send you a password reset link.",
              style: GoogleFonts.poppins(fontSize: 14, color: brandNavy.withOpacity(0.6), height: 1.5),
            ),
            const SizedBox(height: 32),

            // Email Field
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: brandNavy),
              decoration: InputDecoration(
                labelText: "Email Address",
                prefixIcon: const Icon(LucideIcons.mail, color: brandNavy),
                filled: true,
                fillColor: brandGrey,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),

            // Captcha Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: brandGrey.withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: brandNavy.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Security Puzzle",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: brandNavy, fontSize: 14),
                      ),
                      IconButton(
                        onPressed: _generateCaptcha,
                        icon: const Icon(LucideIcons.refreshCw, size: 18, color: brandTeal),
                        tooltip: "Refresh Puzzle",
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(color: brandTeal, borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          "$_num1 + $_num2 = ?",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _captchaController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: brandNavy, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: "Answer",
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: brandNavy.withOpacity(0.2))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: brandNavy.withOpacity(0.2))),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandNavy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isLoading ? null : _sendResetLink,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text("Send Reset Link", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
