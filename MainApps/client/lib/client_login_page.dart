import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Add this to pubspec.yaml
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:client/client_home_page.dart';
import 'package:client/main.dart';
import 'package:client/client_registration_page.dart';
import 'package:client/forgot_password_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _passwordVisible = true;
  bool _isLoading = false;

  // 🎨 GRADLANCE BRAND COLORS
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = response.user;
      if (user != null) {
        try {
          final clientData = await supabase
              .from('tbl_client')
              .select('client_status')
              .eq('client_id', user.id)
              .maybeSingle()
              .timeout(const Duration(seconds: 5)); // Add timeout for DB query

          if (clientData == null) {
            // Not a client (maybe student or invalid)
            await supabase.auth.signOut();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Account not found in client portal. Please register or contact support."), backgroundColor: Colors.redAccent),
              );
            }
            return;
          }

          final status = clientData['client_status'];
          if (status != 'approved') {
            // Block login
            await supabase.auth.signOut();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Account is ${status?.toUpperCase() ?? 'PENDING'}. You cannot log in yet. Please wait for approval."), 
                  backgroundColor: Colors.orange
                ),
              );
            }
            return;
          }

          // Successfully verified and approved
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => Homepage()),
            );
          }
        } catch (e) {
          debugPrint("Client status check error: $e");
          await supabase.auth.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Failed to verify account status. Please try again or contact support."),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        String errMsg = "Invalid email or password";
        if (e.toString().contains("timeout")) errMsg = "Connection slow. Please check your network.";
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brandGrey,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // 🔹 BRAND IDENTITY SECTION
                Image.asset('assets/gradlance.png', height: 80),
                const SizedBox(height: 16),
                Text(
                  "Gradlance",
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: brandNavy,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 40),

                // 🔹 PROFESSIONAL FORM CONTAINER
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: brandNavy.withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Client Portal",
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: brandNavy,
                          ),
                        ),
                        Text(
                          "Sign in to manage your projects",
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 30),

                        _buildInputField(
                          label: "Business Email",
                          controller: _emailController,
                          icon: Icons.email_outlined,
                          isPassword: false,
                        ),
                        const SizedBox(height: 20),

                        _buildInputField(
                          label: "Password",
                          controller: _passwordController,
                          icon: Icons.lock_outline,
                          isPassword: true,
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ClientForgotPasswordPage()),
                              );
                            },
                            child: const Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: brandTeal,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 15),

                        _loginButton(),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                _signUpRow(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- UI COMPONENTS ----------------

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isPassword,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: brandNavy,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? _passwordVisible : false,
          cursorColor: brandNavy,
          style: const TextStyle(color: brandNavy, fontSize: 16),
          validator: (value) {
            if (value == null || value.isEmpty) return "$label is required";
            if (!isPassword) {
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return "Enter a valid email";
              }
            }
            if (isPassword && value.length < 6) return "Minimum 6 characters required";
            return null;
          },
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: brandNavy.withOpacity(0.4), size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _passwordVisible ? Icons.visibility_off : Icons.visibility,
                      color: brandNavy.withOpacity(0.4),
                      size: 20,
                    ),
                    onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                  )
                : null,
            filled: true,
            fillColor: brandGrey,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: brandTeal, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _loginButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : login,
        style: ElevatedButton.styleFrom(
          backgroundColor: brandNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                "Login",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _signUpRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Don’t have a business account? "),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientRegistration()),
            );
          },
          child: const Text(
            "Create Account",
            style: TextStyle(
              color: brandNavy,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}