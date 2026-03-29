import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';

class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getAdminReviews();
      if (response.statusCode == 200) {
        setState(() {
          _reviews = response.data as List;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteReview(int reviewId) async {
    try {
      final response = await _apiService.deleteAdminReview(reviewId);
      if (response.statusCode == 204) {
        await _loadReviews();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa đánh giá')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiểm duyệt đánh giá'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reviews.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Không có đánh giá nào'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReviews,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppTheme.paddingM),
                    itemCount: _reviews.length,
                    itemBuilder: (context, index) {
                      final review = _reviews[index];
                      return _ReviewCard(
                        review: review,
                        onDelete: () => _confirmDelete(review),
                      );
                    },
                  ),
                ),
    );
  }

  void _confirmDelete(Map<String, dynamic> review) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa đánh giá?'),
        content: Text(
          'Bạn có chắc muốn xóa đánh giá này?\n\n'
          '"${review['comment'] ?? 'Không có nội dung'}"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteReview(review['id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  final VoidCallback onDelete;

  const _ReviewCard({
    required this.review,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final rating = (review['rating'] ?? 0).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Stars
                Row(
                  children: List.generate(5, (i) {
                    return Icon(
                      i < rating ? Icons.star : Icons.star_border,
                      color: AppTheme.accentColor,
                      size: 18,
                    );
                  }),
                ),
                const Spacer(),
                Text(
                  'User #${review['user_id']}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(width: 8),
                Text(
                  'Location #${review['location_id']}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (review['comment'] != null && review['comment'].isNotEmpty)
              Text(
                review['comment'],
                style: const TextStyle(fontSize: 14),
              ),
            if (review['created_at'] != null) ...[
              const SizedBox(height: 8),
              Text(
                review['created_at'],
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Xóa'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
