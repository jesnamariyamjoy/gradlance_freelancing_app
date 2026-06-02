import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class FAQPage extends StatefulWidget {
  const FAQPage({super.key});

  @override
  State<FAQPage> createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> {
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);

  final List<Map<String, String>> faqs = [
    {
      "category": "Payments",
      "question": "When do I get paid for a project?",
      "answer": "Once a client approves your submission, funds are moved to your Gradlance wallet. You can withdraw them to your bank account every Friday."
    },
    {
      "category": "Profile",
      "question": "How do I get the PRO badge?",
      "answer": "The PRO badge is awarded to users who subscribe to our premium plan and maintain a rating above 4.5 stars."
    },
    {
      "category": "Account",
      "question": "Can I change my registered email?",
      "answer": "For security reasons, email changes must be requested through a Support Ticket in the Help Center."
    },
    {
      "category": "Security",
      "question": "Is my data safe on Gradlance?",
      "answer": "Yes, we use Supabase's high-level encryption and Row Level Security (RLS) to ensure only you can access your private data."
    },
    {
      "category": "Payments",
      "question": "How do I withdraw my money?",
      "answer": "Go to 'Payout Settings'. Once you have a minimum of ₹500, you can request a transfer to your linked UPI or Bank Account."
    },
    {
      "category": "Profile",
      "question": "Why is my verification pending?",
      "answer": "We manually check Student IDs to keep Gradlance safe. This usually takes 12-24 hours. You'll get a notification once approved!"
    },
    {
      "category": "Security",
      "question": "A client asked to pay outside the app?",
      "answer": "🚨 Do not do this. Paying outside Gradlance leaves you unprotected. Report the client immediately via the 'Report Issue' button."
    },
  ];

  String selectedCategory = "All";
  List<String> categories = ["All", "Payments", "Profile", "Account", "Security"];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Filter logic
    final filteredFaqs = selectedCategory == "All" 
        ? faqs 
        : faqs.where((faq) => faq['category'] == selectedCategory).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F14) : const Color(0xFFF4F7F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: isDark ? Colors.white : brandNavy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Help Center",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : brandNavy,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(isDark),
          _buildCategoryFilter(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: filteredFaqs.length,
              itemBuilder: (context, index) {
                return _buildFAQTile(filteredFaqs[index], isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Search questions...",
          prefixIcon: const Icon(LucideIcons.search, size: 20),
          filled: true,
          fillColor: isDark ? brandNavy.withOpacity(0.5) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          bool isSelected = selectedCategory == categories[index];
          return GestureDetector(
            onTap: () => setState(() => selectedCategory = categories[index]),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? brandTeal : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: brandTeal, width: 1),
              ),
              child: Center(
                child: Text(
                  categories[index],
                  style: GoogleFonts.poppins(
                    color: isSelected ? Colors.white : brandTeal,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFAQTile(Map<String, String> faq, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 15),
      decoration: BoxDecoration(
        color: isDark ? brandNavy.withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        iconColor: brandTeal,
        collapsedIconColor: Colors.grey,
        title: Text(
          faq['question']!,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isDark ? Colors.white : brandNavy,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Text(
              faq['answer']!,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}