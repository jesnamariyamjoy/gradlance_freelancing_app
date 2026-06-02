import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientOnboardingPage extends StatefulWidget {
  const ClientOnboardingPage({super.key});

  @override
  State<ClientOnboardingPage> createState() => _ClientOnboardingPageState();
}

class _ClientOnboardingPageState extends State<ClientOnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  // Controllers
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _industryController = TextEditingController();
  final _websiteController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _bioController = TextEditingController();

  Future<void> _completeOnboarding() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 🔹 Upsert data into tbl_client
      // Ensure these columns exist in your Supabase 'tbl_client' table
      await supabase.from('tbl_client').upsert({
        'client_id': user.id,
        'client_name': _nameController.text.trim(),
        'client_company': _companyController.text.trim(),
        'client_industry': _industryController.text.trim(),
        'client_website': _websiteController.text.trim(),
        'client_linkedin': _linkedinController.text.trim(),
        'client_bio': _bioController.text.trim(),
        'onboarding_complete': true,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        // Navigate to your Premium Dashboard
        Navigator.pushReplacementNamed(context, '/client_dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving profile: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _industryController.dispose();
    _websiteController.dispose();
    _linkedinController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            colors: [Colors.indigo, Colors.blueAccent],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Client Onboarding",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Establish your professional presence on Gradlance.",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F6FA),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(25),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle("Basic Information"),
                        _buildTextField(_nameController, "Full Name", Icons.person),
                        _buildTextField(_companyController, "Company Name", Icons.business),
                        _buildTextField(_industryController, "Industry", Icons.category),
                        
                        const SizedBox(height: 20),
                        _sectionTitle("Professional Verification"),
                        _buildTextField(
                          _websiteController, 
                          "Company Website (URL)", 
                          Icons.language,
                          hint: "https://example.com"
                        ),
                        _buildTextField(
                          _linkedinController, 
                          "LinkedIn Profile (URL)", 
                          Icons.link,
                          hint: "linkedin.com/in/username"
                        ),

                        const SizedBox(height: 20),
                        _sectionTitle("About You"),
                        _buildTextField(
                          _bioController, 
                          "Profile Bio", 
                          Icons.description, 
                          maxLines: 3,
                          hint: "Describe your goals and the type of student talent you are looking for..."
                        ),
                        
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _completeOnboarding,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    "Launch Dashboard",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 10),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String label, 
    IconData icon, 
    {int maxLines = 1, String? hint}
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: (value) => value!.isEmpty ? "$label is required" : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.indigo),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}