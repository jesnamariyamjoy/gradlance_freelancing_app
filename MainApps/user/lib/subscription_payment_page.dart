import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SubscriptionPaymentPage extends StatefulWidget {
  final Map<String, dynamic> plan;
  const SubscriptionPaymentPage({super.key, required this.plan});

  @override
  State<SubscriptionPaymentPage> createState() => _SubscriptionPaymentPageState();
}

class _SubscriptionPaymentPageState extends State<SubscriptionPaymentPage> {
  final supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();
  bool isProcessing = false;

  final _cardController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isProcessing = true);

    await Future.delayed(const Duration(seconds: 2));

    try {
      final userId = supabase.auth.currentUser!.id;
      final duration = widget.plan['plan_duration_days'] as int;
      final endDate = DateTime.now().add(Duration(days: duration));

      await supabase
          .from('tbl_subscription')
          .update({'status': 'expired'})
          .eq('user_id', userId)
          .eq('status', 'active');

      await supabase.from('tbl_subscription').insert({
        'user_id': userId,
        'plan_id': widget.plan['plan_id'],
        'end_date': endDate.toIso8601String(),
        'status': 'active',
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError("Payment successful but activation failed");
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Checkout",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: brandNavy)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: brandNavy),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// PLAN SUMMARY
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: brandTeal.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.package,
                        color: brandTeal, size: 40),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.plan['plan_name'],
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: brandNavy)),
                        Text(
                          "Duration: ${widget.plan['plan_duration_days']} Days",
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text("₹${widget.plan['plan_price']}",
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: brandTeal)),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              Text("Payment Details",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: brandNavy)),

              const SizedBox(height: 16),

              /// CARD NUMBER
              _buildTextField(
                _cardController,
                "Card Number",
                LucideIcons.creditCard,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                  CardFormatter(),
                ],
                validator: (value) {
                  if (value == null ||
                      value.replaceAll(" ", "").length != 16) {
                    return "Enter valid 16 digit card number";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  /// EXPIRY
                  Expanded(
                    child: _buildTextField(
                      _expiryController,
                      "MM/YY",
                      LucideIcons.calendar,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                        ExpiryFormatter(),
                      ],
                      validator: (value) {
                        if (value == null || value.length != 5) {
                          return "Invalid";
                        }

                        final parts = value.split('/');
                        int month = int.parse(parts[0]);
                        int year = int.parse(parts[1]);

                        if (month < 1 || month > 12) {
                          return "Invalid month";
                        }

                        final now = DateTime.now();
                        int currentYear = now.year % 100;
                        int currentMonth = now.month;

                        if (year < currentYear ||
                            (year == currentYear &&
                                month < currentMonth)) {
                          return "Card expired";
                        }

                        return null;
                      },
                    ),
                  ),

                  const SizedBox(width: 16),

                  /// CVV
                  Expanded(
                    child: _buildTextField(
                      _cvvController,
                      "CVV",
                      LucideIcons.lock,
                      isObscure: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      validator: (value) {
                        if (value == null || value.length != 3) {
                          return "Invalid CVV";
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              /// PAY BUTTON
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isProcessing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandNavy,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  child: isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text("Pay & Activate",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.shieldCheck,
                        color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text("Secure SSL Payment",
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isObscure = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: brandTeal),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandTeal),
        ),
      ),
    );
  }
}

/// CARD FORMATTER
class CardFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(oldValue, newValue) {
    var text = newValue.text.replaceAll(" ", "");

    if (text.length > 16) return oldValue;

    var newText = "";
    for (int i = 0; i < text.length; i++) {
      if (i % 4 == 0 && i != 0) newText += " ";
      newText += text[i];
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

/// EXPIRY FORMATTER
class ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(oldValue, newValue) {
    String text = newValue.text.replaceAll("/", "");

    if (text.length > 4) return oldValue;

    if (text.length >= 3) {
      text = "${text.substring(0, 2)}/${text.substring(2)}";
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}