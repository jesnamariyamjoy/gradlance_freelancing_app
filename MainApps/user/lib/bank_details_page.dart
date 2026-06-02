import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

class BankDetailsPage extends StatefulWidget {
  const BankDetailsPage({super.key});

  @override
  State<BankDetailsPage> createState() => _BankDetailsPageState();
}

class _BankDetailsPageState extends State<BankDetailsPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _holderController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;

  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);

  @override
  void initState() {
    super.initState();
    _fetchBankDetails();
  }

  Future<void> _fetchBankDetails() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final data = await supabase
          .from('tbl_bank_details')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _holderController.text = data['account_holder_name'] ?? '';
          _bankNameController.text = data['bank_name'] ?? '';
          _accountController.text = data['account_number'] ?? '';
          _ifscController.text = data['ifsc_code'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("Error fetching bank details: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchBankFromIFSC(String ifsc) async {
    if (ifsc.length != 11) return;
    try {
      final response = await http.get(Uri.parse('https://ifsc.razorpay.com/$ifsc'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted && _bankNameController.text.isEmpty) {
          setState(() {
            _bankNameController.text = data['BANK'] ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint("IFSC Fetch Error: $e");
    }
  }

  static const List<String> _indianBanks = [
    'State Bank of India', 'HDFC Bank', 'ICICI Bank', 'Axis Bank', 'Kotak Mahindra Bank',
    'IndusInd Bank', 'Yes Bank', 'Punjab National Bank', 'Bank of Baroda', 'Canara Bank',
    'Union Bank of India', 'Bank of India', 'IDBI Bank', 'Central Bank of India',
    'Indian Bank', 'UCO Bank', 'Federal Bank', 'South Indian Bank', 'Karnataka Bank',
    'Karur Vysya Bank', 'Standard Chartered Bank', 'HSBC Bank India', 'Citi India',
    'DBS Bank India', 'Bandhan Bank', 'RBL Bank', 'Punjab & Sind Bank', 'Dhanlaxmi Bank',
    'CSB Bank', 'City Union Bank', 'Tamilnad Mercantile Bank', 'Saraswat Bank',
    'Cosmos Bank', 'Shamrao Vithal Co-operative Bank', 'Bharat Co-operative Bank',
    'Abhyudaya Co-operative Bank', 'NKGSB Bank',
  ];

  Future<void> _saveDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final details = {
        'user_id': userId,
        'account_holder_name': _holderController.text.trim(),
        'bank_name': _bankNameController.text.trim(),
        'account_number': _accountController.text.trim(),
        'ifsc_code': _ifscController.text.trim(),
      };

      await supabase.from('tbl_bank_details').upsert(details);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bank details saved successfully!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving details: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        title: Text("Payout Settings", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: brandNavy)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: brandNavy),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: brandTeal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Bank Account Details",
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: brandNavy),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Enter your bank details to receive payments from clients once work is approved.",
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),
                    _buildTextField("Account Holder Name", _holderController, Icons.person_outline),
                    _buildBankNameField(),
                    _buildTextField("Account Number", _accountController, Icons.numbers, isNumeric: true, limit: 18),
                    _buildTextField("IFSC Code", _ifscController, Icons.code, isIFSC: true),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : _saveDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandTeal,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text("Save Information", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBankNameField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Bank Name", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: brandNavy)),
          const SizedBox(height: 8),
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue t) {
              if (t.text.isEmpty) return const Iterable<String>.empty();
              return _indianBanks.where((s) => s.toLowerCase().contains(t.text.toLowerCase()));
            },
            onSelected: (s) => _bankNameController.text = s,
            fieldViewBuilder: (ctx, ctrl, focus, onFieldSubmitted) {
              if (ctrl.text != _bankNameController.text && _bankNameController.text.isNotEmpty && ctrl.text.isEmpty) {
                 ctrl.text = _bankNameController.text;
              }
              ctrl.addListener(() => _bankNameController.text = ctrl.text);
              
              return TextFormField(
                controller: ctrl,
                focusNode: focus,
                onFieldSubmitted: (s) => onFieldSubmitted(),
                style: GoogleFonts.poppins(fontSize: 14, color: brandNavy),
                validator: (v) => v == null || v.isEmpty ? "Required" : null,
                decoration: _fieldDecoration(Icons.account_balance_outlined, "Bank Name"),
              );
            },
            optionsViewBuilder: (ctx, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: MediaQuery.of(ctx).size.width - 48,
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (ctx, i) {
                        final s = options.elementAt(i);
                        return ListTile(
                          title: Text(s, style: GoogleFonts.poppins(fontSize: 13)),
                          onTap: () => onSelected(s),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(IconData icon, String hint) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: brandTeal, size: 20),
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: brandTeal, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1)),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isNumeric = false, int? limit, bool isIFSC = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: brandNavy)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            textCapitalization: isIFSC ? TextCapitalization.characters : TextCapitalization.none,
            maxLength: limit,
            inputFormatters: [
              if (isNumeric) FilteringTextInputFormatter.digitsOnly,
              if (isIFSC) LengthLimitingTextInputFormatter(11),
              if (isIFSC) UpperCaseTextFormatter(),
            ],
            onChanged: (v) {
              if (isIFSC && v.length == 11) {
                _fetchBankFromIFSC(v);
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty) return "Required";
              if (label == "Account Number") {
                if (value.length < 9 || value.length > 18) return "Enter 9 to 18 digits";
              } else if (label == "IFSC Code") {
                if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(value)) {
                  return "Invalid IFSC format";
                }
              }
              return null;
            },
            decoration: _fieldDecoration(icon, label).copyWith(counterText: ""),
          ),
        ],
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection);
  }
}
