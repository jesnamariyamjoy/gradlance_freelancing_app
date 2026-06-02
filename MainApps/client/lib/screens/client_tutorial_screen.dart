import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../client_login_page.dart';

class ClientTutorialScreen extends StatefulWidget {
  const ClientTutorialScreen({super.key});

  @override
  State<ClientTutorialScreen> createState() => _ClientTutorialScreenState();
}

class _ClientTutorialScreenState extends State<ClientTutorialScreen> {
  final PageController _controller = PageController();
  int currentIndex = 0;

  static const Color brandNavy = Color(0xFF102030);

  final List<Map<String, dynamic>> pages = [
    {
      "icon": LucideIcons.building2,
      "title": "Post Student Projects",
      "desc": "Post your projects and hire talented students eager to prove their skills."
    },
    {
      "icon": LucideIcons.users,
      "title": "Review Applications",
      "desc": "Browse student profiles, previous works, and proposals."
    },
    {
      "icon": LucideIcons.shieldCheck,
      "title": "Secure Collaboration",
      "desc": "Manage the work progress seamlessly using our built-in tasks and secure payments."
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
        color: Colors.white,
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
                        Container(
                          height: 140,
                          width: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: brandNavy.withOpacity(0.05),
                          ),
                          child: Icon(
                            pages[index]['icon'],
                            size: 60,
                            color: brandNavy,
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
                      color: currentIndex == index ? brandNavy : brandNavy.withOpacity(0.2),
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
