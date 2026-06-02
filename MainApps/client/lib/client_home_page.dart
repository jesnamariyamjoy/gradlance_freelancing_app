import 'package:client/client_profile_page.dart';
import 'package:client/work_list_page.dart';
import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// Import your actual files here
import 'package:client/application_list_page.dart';
import 'package:client/screens/chat_list_page.dart';
import 'package:client/client_dashboard_page.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  _HomepageState createState() => _HomepageState();
}
class _HomepageState extends State<Homepage> {
  int _selectedIndex = 0;

  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  // 🔹 FIX 1: Ensure the list matches the number of tabs (5 items)
  static final List<Widget> _widgetOptions = <Widget>[
    const PremiumClientDashboard(), // Index 0
    const ClientApplicationsPage(),  // Index 1
    const ChatListPage(isClientApp: true), // Index 2
    const WorkListPage(),            // Index 3
    const ClientProfilePage(), // Index 4
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(blurRadius: 20, color: brandNavy.withOpacity(.08))
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8),
            child: GNav(
              rippleColor: brandTeal.withOpacity(0.1),
              hoverColor: brandGrey,
              gap: 8,
              activeColor: brandTeal,
              iconSize: 22,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: brandTeal.withOpacity(0.1),
              color: brandNavy.withOpacity(0.6),
              selectedIndex: _selectedIndex,
              onTabChange: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              // 🔹 FIX 2: 5 Buttons = 5 Screens
              tabs: const [
                GButton(icon: LucideIcons.layoutGrid, text: 'Home'),    // 0
                GButton(icon: LucideIcons.fileText, text: 'Apps'),      // 1
                GButton(icon: LucideIcons.messageSquare, text: 'Chat'),  // 2
                GButton(icon: LucideIcons.briefcase, text: 'Works'),     // 3
                GButton(icon: LucideIcons.user, text: 'Profile'),       // 4
              ],
            ),
          ),
        ),
      ),
    );
  }
}
