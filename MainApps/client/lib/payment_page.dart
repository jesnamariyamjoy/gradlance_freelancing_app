import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentPage extends StatefulWidget {
  final int applicationId;
  final num amount;
  final String devName;

  const PaymentPage({
    super.key,
    required this.applicationId,
    required this.amount,
    required this.devName,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
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

      // 2. Fetch work_id
      final appData = await supabase
          .from('tbl_application')
          .select('work_id')
          .eq('application_id', widget.applicationId)
          .single();
      
      final int workId = appData['work_id'];

      // 3. Update Supabase
      await supabase.from('tbl_application').update({
        'payment_status': 'paid',
        'application_status': 'completed'
      }).eq('application_id', widget.applicationId);

      await supabase.from('tbl_work').update({
        'work_status': 'paid',
        'payment_status': true
      }).eq('work_id', workId);

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
        builder: (context) => PaymentSuccessScreen(amount: widget.amount, devName: widget.devName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        title: Text("Secure Checkout", style: GoogleFonts.poppins(color: brandNavy, fontWeight: FontWeight.bold, fontSize: 18)),
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
          Text("Authorizing Payment...", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: brandNavy)),
          const SizedBox(height: 8),
          Text("Please do not close the app or go back.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
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
              Text("Total Amount", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text("₹${widget.amount}", style: GoogleFonts.poppins(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(LucideIcons.user, color: brandTeal, size: 16),
                  const SizedBox(width: 8),
                  Text("Paying to: ", style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12)),
                  Text(widget.devName, style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
                  label: "UPI (GPay / PhonePe)",
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
                
                // Card Details (Show if card selected)
                if (selectedMethod == 'card') 
                  _buildCardForm()
                else
                  _buildUPIPlaceholder(),

                const SizedBox(height: 20),
                
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
                    child: Text("Pay Securely", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
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
          boxShadow: [if (isSelected) BoxShadow(color: brandTeal.withOpacity(0.1), blurRadius: 10)],
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

  Widget _buildCardForm() {
    return Column(
      children: [
        TextField(
          decoration: _inputStyle("Card Number", LucideIcons.hash),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: TextField(decoration: _inputStyle("Expiry", LucideIcons.calendar), keyboardType: TextInputType.datetime)),
            const SizedBox(width: 12),
            Expanded(child: TextField(decoration: _inputStyle("CVV", LucideIcons.lock), keyboardType: TextInputType.number, obscureText: true)),
          ],
        ),
      ],
    );
  }

  Widget _buildUPIPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: brandTeal.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: brandTeal.withOpacity(0.1))),
      child: Row(
        children: [
          const Icon(LucideIcons.info, color: brandTeal, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text("You will be redirected to your UPI app to complete the transaction.", style: GoogleFonts.poppins(fontSize: 12, color: brandTeal))),
        ],
      ),
    );
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18, color: brandNavy),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }
}

class PaymentSuccessScreen extends StatelessWidget {
  final num amount;
  final String devName;

  const PaymentSuccessScreen({super.key, required this.amount, required this.devName});

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
              Text("Payment Successful", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF102030))),
              const SizedBox(height: 8),
              Text("₹$amount has been securely sent to $devName", textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey[600])),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF102030), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: Text("Return to Dashboard", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}