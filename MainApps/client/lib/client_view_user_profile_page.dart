import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smooth_star_rating_nsafe/smooth_star_rating.dart';
import 'package:intl/intl.dart';

class ClientViewUserProfilePage extends StatefulWidget {
  final String userId;

  const ClientViewUserProfilePage({super.key, required this.userId});

  @override
  State<ClientViewUserProfilePage> createState() =>
      _ClientViewUserProfilePageState();
}

class _ClientViewUserProfilePageState extends State<ClientViewUserProfilePage> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? userData;
  Map<String, dynamic>? userDetails;
  List<Map<String, dynamic>> ratings = [];
  bool isLoading = true;

  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      // Fetch user basic info
      final user = await supabase
          .from('tbl_user')
          .select('*')
          .eq('id', widget.userId)
          .single();

      // Fetch user details
      final details = await supabase
          .from('tbl_user_details')
          .select('*')
          .eq('user_id', widget.userId)
          .maybeSingle();

      // Fetch ratings for this user
      final userRatings = await supabase
          .from('tbl_rating')
          .select('*')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          userData = user;
          userDetails = details;
          ratings = userRatings.cast<Map<String, dynamic>>();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  double _calculateAverageRating() {
    if (ratings.isEmpty) return 0;
    double sum = 0;
    for (var r in ratings) {
      sum += (r['rating_score'] ?? 0);
    }
    return sum / ratings.length;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: brandGrey,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: brandNavy),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: brandTeal),
        ),
      );
    }

    if (userData == null) {
      return Scaffold(
        backgroundColor: brandGrey,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: brandNavy),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(
            'User not found',
            style: GoogleFonts.poppins(color: Colors.grey[600]),
          ),
        ),
      );
    }

    final avgRating = _calculateAverageRating();

    return Scaffold(
      backgroundColor: brandGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: brandNavy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'User Profile',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, color: brandNavy, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: brandTeal.withOpacity(0.2),
                    backgroundImage: userData!['user_photo'] != null
                        ? NetworkImage(userData!['user_photo'])
                        : null,
                    child: userData!['user_photo'] == null
                        ? Text(
                            userData!['user_name'][0].toUpperCase(),
                            style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: brandTeal),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Name
                  Text(
                    userData!['user_name'] ?? 'Unknown',
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  // Email
                  Text(
                    userData!['user_email'] ?? 'No email',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey[600]),
                  ),

                  const SizedBox(height: 12),

                  // Rating Section
                  if (avgRating > 0)
                    Column(
                      children: [
                        SmoothStarRating(
                          rating: avgRating,
                          size: 28,
                          starCount: 5,
                          spacing: 4,
                          color: Colors.orange,
                          borderColor: Colors.grey[300]!,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${avgRating.toStringAsFixed(1)}/5.0 (${ratings.length} ${ratings.length == 1 ? 'rating' : 'ratings'})',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: brandTeal),
                        ),
                      ],
                    )
                  else
                    Text(
                      'No ratings yet',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey[500]),
                    ),

                  const SizedBox(height: 16),

                  // User Status
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(userData!['user_status'] ?? 'new')
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (userData!['user_status'] ?? 'new').toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(userData!['user_status'] ?? 'new'),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Details Card
            if (userDetails != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Professional Details',
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('College', userDetails!['college']),
                    _buildDetailRow('Course', userDetails!['course']),
                    _buildDetailRow('Gender', userDetails!['gender']),
                    _buildDetailRow('Contact', userData!['user_contact']),
                    _buildDetailRow(
                        'Work Preference', userDetails!['work_preference']),
                    _buildDetailRow('Hourly Rate',
                        '₹${userDetails!['hourly_rate'] ?? 'N/A'}/hour'),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Ratings Section
            if (ratings.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Client Ratings & Reviews',
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: ratings.length,
                      itemBuilder: (context, index) {
                        final rating = ratings[index];
                        return Column(
                          children: [
                            Row(
                              children: [
                                SmoothStarRating(
                                  rating: (rating['rating_score'] ?? 0)
                                      .toDouble(),
                                  size: 16,
                                  starCount: 5,
                                  spacing: 2,
                                  color: Colors.orange,
                                  borderColor: Colors.grey[300]!,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${rating['rating_score']}/5',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                Text(
                                  DateFormat('dd MMM yyyy').format(
                                      DateTime.parse(rating['created_at'])),
                                  style: GoogleFonts.poppins(
                                      fontSize: 10, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            if (rating['rating_content'] != null)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  rating['rating_content'],
                                  style: GoogleFonts.poppins(
                                      fontSize: 12, color: Colors.grey[700]),
                                ),
                              ),
                            if (index < ratings.length - 1)
                              Divider(color: Colors.grey[200]),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style:
                GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
          ),
          Text(
            value?.toString() ?? 'N/A',
            style:
                GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'suspended':
        return Colors.red;
      case 'new':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
