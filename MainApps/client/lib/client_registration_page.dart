import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'client_login_page.dart';
import 'main.dart';

class ClientRegistration extends StatefulWidget {
  const ClientRegistration({super.key});

  @override
  State<ClientRegistration> createState() => _ClientRegistrationState();
}

class _ClientRegistrationState extends State<ClientRegistration> {
  final _formKey = GlobalKey<FormState>();

  // 🎨 GRADLANCE BRAND COLORS
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  bool _passwordVisible = true;
  bool _confirmPasswordVisible = true;
  bool _isRegistering = false;

  final TextEditingController _clientName = TextEditingController();
  final TextEditingController _clientEmail = TextEditingController();
  final TextEditingController _clientContact = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  Future<void> clientRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    if (_password.text != _confirmPassword.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isRegistering = true);

    try {
      final authResponse = await supabase.auth.signUp(
        email: _clientEmail.text.trim(),
        password: _password.text.trim(),
      );

      final client = authResponse.user;
      if (client == null) throw Exception("Client creation failed");

      await supabase.from('tbl_client').insert({
        'client_id': client.id,
        'client_name': _clientName.text.trim(),
        'client_email': _clientEmail.text.trim(),
        'client_contact': _clientContact.text.trim(),
        'client_status': 'pending',
        'is_active': false,
        'client_password': _password.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account created! Please login and complete your profile."), backgroundColor: brandTeal),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isRegistering = false);
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
          icon: const Icon(Icons.arrow_back_ios_new, color: brandNavy, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Register Business",
          style: GoogleFonts.poppins(color: brandNavy, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome to Gradlance",
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: brandNavy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Start finding student talent today.",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 30),

              _buildSectionTitle("Company Identity"),
              _buildField("Business Name", _clientName, Icons.business_outlined),
              _buildField("Contact Number", _clientContact, Icons.phone_outlined, keyboard: TextInputType.phone),
              _buildField("Business Email", _clientEmail, Icons.email_outlined, keyboard: TextInputType.emailAddress),

              const SizedBox(height: 10),
              _buildSectionTitle("Security"),
              _buildPasswordField("Create Password", _password, _passwordVisible, () {
                setState(() => _passwordVisible = !_passwordVisible);
              }),
              _buildPasswordField("Confirm Password", _confirmPassword, _confirmPasswordVisible, () {
                setState(() => _confirmPasswordVisible = !_confirmPasswordVisible);
              }),

              const SizedBox(height: 30),

              _buildRegisterButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- UI HELPERS ----------------

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: brandNavy),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        style: GoogleFonts.poppins(fontSize: 14),
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
        decoration: _inputDecoration(label, icon),
      ),
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller, bool visible, VoidCallback toggle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        obscureText: visible,
        style: GoogleFonts.poppins(fontSize: 14),
        validator: (v) => v!.length < 6 ? "Min 6 characters" : null,
        decoration: _inputDecoration(label, Icons.lock_outline_rounded).copyWith(
          suffixIcon: IconButton(
            icon: Icon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: brandNavy.withOpacity(0.5)),
            onPressed: toggle,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: brandNavy.withOpacity(0.5), fontSize: 14),
      prefixIcon: Icon(icon, color: brandNavy, size: 20),
      filled: true,
      fillColor: brandGrey,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: brandTeal, width: 1.5),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isRegistering ? null : clientRegistration,
        style: ElevatedButton.styleFrom(
          backgroundColor: brandNavy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isRegistering
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text("Request Account", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}