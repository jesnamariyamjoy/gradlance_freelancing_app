import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:client/subscription_payment_page.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> plans = [];
  bool isLoading = true;
  Map<String, dynamic>? currentSubscription;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      setState(() => isLoading = true);
      final userId = supabase.auth.currentUser!.id;

      // Fetch plans for clients
      final planRes = await supabase
          .from('tbl_subscription_plan')
          .select()
          .eq('plan_type', 'client')
          .order('plan_price');

      // Fetch active subscription
      final subRes = await supabase
          .from('tbl_subscription')
          .select('*, tbl_subscription_plan(*)')
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();

      setState(() {
        plans = List<Map<String, dynamic>>.from(planRes);
        currentSubscription = subRes;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> subscribe(Map<String, dynamic> plan) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionPaymentPage(plan: plan),
      ),
    ).then((_) => fetchData());
  }

  @override
  Widget build(BuildContext context) {
    const brandPink = Color(0xFFFF5FA0);
    const brandTeal = Color(0xFF00CFA2);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Subscription Plans",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentSubscription != null) ...[
                    _buildCurrentPlanCard(currentSubscription!, brandTeal),
                    const SizedBox(height: 32),
                  ],
                  Text(
                    "Choose Your Upgrade",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Unlock more work posts and premium features.",
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  ...plans.map(
                    (p) => _buildPlanCard(
                      p,
                      brandPink,
                      currentSubscription?['plan_id'] == p['plan_id'],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentPlanCard(Map<String, dynamic> sub, Color color) {
    final plan = sub['tbl_subscription_plan'];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ACTIVE PLAN",
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const Icon(LucideIcons.circle, color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            plan['plan_name'],
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Valid until: ${DateTime.parse(sub['end_date']).toLocal().toString().split(' ')[0]}",
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    Map<String, dynamic> plan,
    Color color,
    bool isCurrent,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCurrent ? color : Colors.grey[200]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                plan['plan_name'],
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Current",
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "₹${plan['plan_price']}",
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            "for ${plan['plan_duration_days']} days",
            style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
          ),
          const Divider(height: 32),
          _featureRow(
            LucideIcons.check,
            "${plan['max_count'] == 0 ? 'Unlimited' : plan['max_count']} Work Posts",
          ),
          _featureRow(LucideIcons.check, "Priority Support"),
          _featureRow(LucideIcons.check, "Direct Contact Student"),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isCurrent ? null : () => subscribe(plan),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey[200],
              ),
              child: Text(
                isCurrent ? "Active" : "Subscribe Now",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.green),
          const SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.poppins(color: Colors.grey[800], fontSize: 14),
          ),
        ],
      ),
    );
  }
}
