import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SubscriptionPaymentPage extends StatefulWidget {
  final Map<String, dynamic> plan;

  const SubscriptionPaymentPage({
    super.key,
    required this.plan,
  });

  @override
  State<SubscriptionPaymentPage> createState() => _SubscriptionPaymentPageState();
}

class _SubscriptionPaymentPageState extends State<SubscriptionPaymentPage> {
  final supabase = Supabase.instance.client;
  bool isProcessing = false;
  String selectedMethod = 'upi'; // upi, card

  // Colors
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);

  Future<void> _completePayment() async {
    setState(() => isProcessing = true);

    try {
      // 1. Simulate API call to Payment Gateway
      await Future.delayed(const Duration(seconds: 3));

      final userId = supabase.auth.currentUser!.id;
      final duration = widget.plan['plan_duration_days'] as int;
      final endDate = DateTime.now().add(Duration(days: duration));

      // 2. Deactivate old subscription
      await supabase
          .from('tbl_subscription')
          .update({'status': 'expired'})
          .eq('user_id', userId)
          .eq('status', 'active');

      // 3. Insert new subscription
      await supabase.from('tbl_subscription').insert({
        'user_id': userId,
        'plan_id': widget.plan['plan_id'],
        'end_date': endDate.toIso8601String(),
        'status': 'active',
      });

      // 4. Update tbl_client premium status
      await supabase
          .from('tbl_client')
          .update({'is_premium': true})
          .eq('client_id', userId);

      if (mounted) _showSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  void _showSuccess() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SubSuccessScreen(planName: widget.plan['plan_name']),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        title: Text("Checkout Upgrade", style: GoogleFonts.poppins(color: brandNavy, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: brandNavy),
      ),
      body: isProcessing ? _buildProcessingState() : _buildGatewayUI(),
    );
  }

  Widget _buildProcessingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: brandTeal, strokeWidth: 3),
          const SizedBox(height: 24),
          Text("Confirming Payment...", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: brandNavy)),
          const SizedBox(height: 8),
          Text("Finalizing your subscription upgrade.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildGatewayUI() {
    return Column(
      children: [
        // Summary Card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: brandNavy,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: brandNavy.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Upgrading to", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text(widget.plan['plan_name'], style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Total Pay", style: GoogleFonts.poppins(color: Colors.white60, fontSize: 14)),
                  Text("₹${widget.plan['plan_price']}", style: GoogleFonts.poppins(color: brandTeal, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),

        // Payment Methods
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Select Payment Method", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: brandNavy)),
                const SizedBox(height: 16),
                
                _methodCard(
                  id: 'upi',
                  label: "UPI (Google Pay / PhonePe)",
                  icon: LucideIcons.smartphone,
                  color: Colors.purple,
                ),
                const SizedBox(height: 12),
                _methodCard(
                  id: 'card',
                  label: "Credit / Debit Card",
                  icon: LucideIcons.creditCard,
                  color: Colors.blue,
                ),

                const Spacer(),
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _completePayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandTeal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text("Upgrade Now", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _methodCard({required String id, required String label, required IconData icon, required Color color}) {
    bool isSelected = selectedMethod == id;
    return GestureDetector(
      onTap: () => setState(() => selectedMethod = id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? brandTeal : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: brandNavy)),
            const Spacer(),
            Icon(isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded, color: isSelected ? brandTeal : Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}

class SubSuccessScreen extends StatelessWidget {
  final String planName;

  const SubSuccessScreen({super.key, required this.planName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 100),
              const SizedBox(height: 24),
              Text("Plan Upgrade Active!", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("Your '$planName' subscription is now active. Enjoy priority features.", textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey[600])),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF102030), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: Text("Continue to Dashboard", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
