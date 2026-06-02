import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'client_tutorial_screen.dart';
import '../client_login_page.dart';
import '../client_home_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();

    _checkSession();
  }

  Future<void> _checkSession() async {
    // Wait for animation and a minimum delay for "premium" feel
    await Future.delayed(const Duration(seconds: 3));

    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;

    if (mounted) {
      if (session != null) {
        try {
          final clientData = await supabase
              .from('tbl_client')
              .select('client_status')
              .eq('client_id', session.user.id)
              .maybeSingle();
              
          if (clientData != null && clientData['client_status'] == 'approved') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const Homepage()),
            );
            return;
          } else {
             await supabase.auth.signOut();
          }
        } catch (e) {
             await supabase.auth.signOut();
        }
      }
      
      // If we are here, we are either not logged in or session expired.
      final prefs = await SharedPreferences.getInstance();
      final hasSeenTutorial = prefs.getBool('has_seen_tutorial') ?? false;

      if (!hasSeenTutorial) {
        await prefs.setBool('has_seen_tutorial', true);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ClientTutorialScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color brandNavy = Color(0xFF102030);
    const Color brandTeal = Color(0xFF20A0A0);

    return Scaffold(
      backgroundColor: brandNavy,
      body: Center(
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Image.asset(
                    'assets/gradlance.png',
                    height: 80,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Gradlance",
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Partner Portal",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: brandTeal,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 60),
                const SizedBox(
                  width: 40,
                  height: 2,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(brandTeal),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
