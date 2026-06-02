import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smooth_star_rating_nsafe/smooth_star_rating.dart';

class RateUserPage extends StatefulWidget {
  final Map<String, dynamic> workData;
  final Map<String, dynamic> userData;

  const RateUserPage({
    super.key,
    required this.workData,
    required this.userData,
  });

  @override
  State<RateUserPage> createState() => _RateUserPageState();
}

class _RateUserPageState extends State<RateUserPage> {
  final supabase = Supabase.instance.client;

  double _rating = 0;
  final _reviewController = TextEditingController();
  bool _isSubmitting = false;

  // Gradlance Brand Colors
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  Future<void> _submitRating() async {
    if (_rating == 0) {
      _showSnackBar('Please select a star rating', Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final String currentUserId = supabase.auth.currentUser!.id;
      final String targetUserId = widget.userData['id'].toString();
      final int workId = widget.workData['work_id'];

      // 1. Insert Rating into tbl_rating
      await supabase.from('tbl_rating').insert({
        'work_id': workId,
        'client_id': currentUserId,
        'user_id': targetUserId,
        'rating_value': _rating.toInt(),
        'rating_content': _reviewController.text.trim(),
      });

      // 2. Fetch all ratings for this user to calculate the new average
      final response = await supabase
          .from('tbl_rating')
          .select('rating_value')
          .eq('user_id', targetUserId);

      if (response != null) {
       final List allRatings = response as List;
double totalScore = 0;

for (var r in allRatings) {
  final value = r['rating_value'];
  if (value != null) {
    totalScore += (value as num).toDouble();
  }
}
        
     double averageRating = 0;

if (allRatings.isNotEmpty) {
  averageRating = totalScore / allRatings.length;
}

        // 3. Update the user's main rating in tbl_user
        await supabase
            .from('tbl_user')
            .update({'rating': averageRating})
            .eq('id', targetUserId);
      }

      _showSnackBar('Thank you! Your rating has been submitted.', Colors.green);

      if (mounted) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } catch (e) {
      _showSnackBar('Error submitting rating: $e', Colors.red);
      print('Error submitting rating: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brandGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close, color: brandNavy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Rate Experience',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, color: brandNavy, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // User Avatar & Name
            CircleAvatar(
              radius: 45,
              backgroundColor: brandTeal.withOpacity(0.1),
              backgroundImage: widget.userData['user_photo'] != null
                  ? NetworkImage(widget.userData['user_photo'])
                  : null,
              child: widget.userData['user_photo'] == null
                  ? Text(
                      widget.userData['user_name'][0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: brandTeal),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              widget.userData['user_name'] ?? 'Freelancer',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.bold, color: brandNavy),
            ),
            Text(
              'Project: ${widget.workData['work_title'] ?? "Completed Work"}',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            ),

            const SizedBox(height: 40),

            // Rating Stars Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Tap to Rate',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: brandNavy),
                  ),
                  const SizedBox(height: 20),
                  SmoothStarRating(
                    rating: _rating,
                    size: 50,
                    filledIconData: Icons.star_rounded,
                    halfFilledIconData: Icons.star_half_rounded,
                    defaultIconData: Icons.star_outline_rounded,
                    starCount: 5,
                    spacing: 8,
                    color: Colors.orangeAccent,
                    borderColor: Colors.grey[300]!,
                    onRatingChanged: (v) {
                      setState(() => _rating = v);
                    },
                  ),
                  const SizedBox(height: 15),
                  if (_rating > 0)
                    Text(
                      _getRatingText(_rating),
                      style: GoogleFonts.poppins(
                          color: brandTeal, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Review Input
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text('Feedback (Optional)',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: brandNavy)),
              ),
            ),
            TextField(
              controller: _reviewController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Share your thoughts on the collaboration...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 40),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandTeal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Submit Feedback',
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText(double rating) {
    if (rating >= 5) return 'Excellent!';
    if (rating >= 4) return 'Very Good';
    if (rating >= 3) return 'Good';
    if (rating >= 2) return 'Fair';
    return 'Poor';
  }
}