import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ClientFAQPage extends StatefulWidget {
  const ClientFAQPage({super.key});

  @override
  State<ClientFAQPage> createState() => _ClientFAQPageState();
}

class _ClientFAQPageState extends State<ClientFAQPage> {
  // GRADLANCE BRAND COLORS
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  // Client-Specific FAQ Data
  final List<Map<String, String>> _clientFaqs = [
    {
      "q": "How do I hire a student?",
      "a": "Review the applications on your project dashboard. Click on a student's profile to see their skills and previous work, then click 'Accept' to start the contract.",
      "cat": "Hiring"
    },
    {
      "q": "When should I release the payment?",
      "a": "You should only click 'Approve & Pay' once you have reviewed the submitted work and are satisfied with the quality. Funds are transferred instantly upon approval.",
      "cat": "Payments"
    },
    {
      "q": "Can I set milestones for long projects?",
      "a": "Currently, we support full project payments. For longer tasks, we recommend breaking the work into smaller individual 'Works' to track progress effectively.",
      "cat": "Projects"
    },
    {
      "q": "What happens if a student misses a deadline?",
      "a": "If a deadline is missed, you have the option to cancel the project and receive a full refund, or message the student to negotiate an extension.",
      "cat": "Support"
    },
    {
      "q": "Are the students verified?",
      "a": "Yes, every student on Gradlance is verified using their college ID and academic email to ensure you are working with genuine talent.",
      "cat": "Safety"
    },
    {
      "q": "How do I start a new project?",
      "a": "Navigate to the 'Post Work' tab, fill in the project title, budget, and deadline. Once posted, students will begin applying immediately.",
      "cat": "General"
    },
    {
      "q": "Is my payment secure?",
      "a": "Yes. Gradlance uses a secure payment gateway. Funds are held until you 'Approve' the work submitted by the student.",
      "cat": "Payments"
    },
    {
      "q": "What if the work quality is not as expected?",
      "a": "You can use the 'Reject' button or request a revision via the chat feature. We recommend discussing specific requirements before the student starts.",
      "cat": "Project"
    },
    {
      "q": "How can I view the student's previous work?",
      "a": "Click on the student's name in the Work Review page to view their full portfolio and ratings from other clients.",
      "cat": "Student"
    },
    {
      "q": "Can I cancel a project after a student is hired?",
      "a": "Cancellations are possible but may be subject to a partial fee if the student has already completed a significant portion of the work.",
      "cat": "Project"
    },
  ];

  String _searchQuery = "";
  String _selectedCategory = "All";

  @override
  Widget build(BuildContext context) {
    // Combined filtering for search and categories
    final filteredFaqs = _clientFaqs.where((f) {
      final matchesSearch = f['q']!.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat = _selectedCategory == "All" || f['cat'] == _selectedCategory;
      return matchesSearch && matchesCat;
    }).toList();

    return Scaffold(
      backgroundColor: brandGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          "Client Help Center",
          style: GoogleFonts.poppins(
            color: brandNavy, 
            fontWeight: FontWeight.bold, 
            fontSize: 18
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSearchArea(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                const SizedBox(height: 10),
                _buildCategoryChips(),
                const SizedBox(height: 20),
                if (filteredFaqs.isEmpty) 
                  _buildNoResults()
                else
                  ...filteredFaqs.map((faq) => _buildExpandableFaq(faq)),
                const SizedBox(height: 30),
                _buildContactSupportCard(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchArea() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          hintText: "Search for hiring tips, payments...",
          prefixIcon: const Icon(LucideIcons.search, size: 20, color: brandTeal),
          filled: true,
          fillColor: brandGrey,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = ["All", "Hiring", "Payments", "Projects", "Safety"];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          bool isSelected = _selectedCategory == cat;
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (val) {
                setState(() => _selectedCategory = cat);
              },
              selectedColor: brandTeal,
              labelStyle: GoogleFonts.poppins(
                color: isSelected ? Colors.white : brandNavy,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              pressElevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide(color: isSelected ? brandTeal : brandNavy.withOpacity(0.1)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExpandableFaq(Map<String, String> faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: brandNavy.withOpacity(0.05)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: brandTeal,
          collapsedIconColor: brandNavy.withOpacity(0.3),
          title: Text(
            faq['q']!,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: brandNavy,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                faq['a']!,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.blueGrey,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSupportCard() {
    return GestureDetector(
      onTap: () {
        // Navigate to Support Chat or Mail
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [brandNavy, Color(0xFF1A3045)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.headset, color: brandTeal, size: 40),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Need more help?",
                    style: GoogleFonts.poppins(
                      color: Colors.white, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  Text(
                    "Talk to our project coordinators",
                    style: GoogleFonts.poppins(
                      color: Colors.white70, 
                      fontSize: 12
                    ),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Padding(
      padding: const EdgeInsets.only(top: 50),
      child: Column(
        children: [
          Icon(LucideIcons.searchX, size: 48, color: brandNavy.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
            "No results for '$_searchQuery'",
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}