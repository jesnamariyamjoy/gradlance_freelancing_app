import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart'; // Using Lucide for a premium look
import 'package:user/user_login_page.dart';
// Ensure this matches your login file path

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int currentIndex = 0;

  // 🎨 GRADLANCE BRAND COLORS
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  final List<Map<String, dynamic>> pages = [
    {
      "icon": LucideIcons.briefcase,
      "title": "Find Real Projects",
      "desc": "Access curated freelance projects designed specifically for student skillsets."
    },
    {
      "icon": LucideIcons.graduationCap,
      "title": "Learn & Earn",
      "desc": "Bridge the gap between academic theory and real-world professional experience."
    },
    {
      "icon": LucideIcons.shieldCheck,
      "title": "Secure Payments",
      "desc": "Focus on your work while we ensure your payments are safe and on time."
    },
  ];

  void goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white, // Clean white background for Gradlance
        child: SafeArea(
          child: Column(
            children: [
              // Skip Button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: TextButton(
                    onPressed: goToLogin,
                    child: Text(
                      "Skip",
                      style: GoogleFonts.poppins(color: brandNavy.withOpacity(0.5), fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),

              // Content
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (index) {
                    setState(() => currentIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon Container
                        Container(
                          height: 140,
                          width: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: brandTeal.withOpacity(0.1),
                          ),
                          child: Icon(
                            pages[index]['icon'],
                            size: 60,
                            color: brandTeal,
                          ),
                        ),

                        const SizedBox(height: 50),

                        Text(
                          pages[index]['title'],
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: brandNavy,
                          ),
                        ),

                        const SizedBox(height: 20),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 45),
                          child: Text(
                            pages[index]['desc'],
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              color: brandNavy.withOpacity(0.6),
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Page Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.all(4),
                    height: 6,
                    width: currentIndex == index ? 24 : 6,
                    decoration: BoxDecoration(
                      color: currentIndex == index ? brandTeal : brandTeal.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Action Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandNavy,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    if (currentIndex < pages.length - 1) {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      goToLogin();
                    }
                  },
                  child: Text(
                    currentIndex == pages.length - 1 ? "Get Started" : "Continue",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}