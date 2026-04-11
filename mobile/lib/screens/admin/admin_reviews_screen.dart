import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
      final response = await _apiService.getAdminReviews(limit: 200);
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _reviews = response.data as List;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteReview(int reviewId) async {
    try {
      final response = await _apiService.deleteAdminReview(reviewId);
      if ((response.statusCode ?? 0) < 300 && mounted) {
        setState(() => _reviews.removeWhere((r) => r['id'] == reviewId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã xóa đánh giá'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa đánh giá?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Bạn có chắc muốn xóa đánh giá này?\n'
          '"${(review['comment'] as String? ?? '').isEmpty ? 'Không có nội dung' : review['comment']}"',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) _deleteReview(review['id']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Kiểm duyệt đánh giá (${_reviews.length})'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            onPressed: _loadReviews,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reviews.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withAlpha(12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.star, size: 36, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(height: 16),
                      const Text('Chưa có đánh giá nào',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReviews,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reviews.length,
                    itemBuilder: (context, index) {
                      return _ReviewCard(
                        review: _reviews[index],
                        onDelete: () => _confirmDelete(_reviews[index]),
                      );
                    },
                  ),
                ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  final VoidCallback onDelete;

  const _ReviewCard({required this.review, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final comment = review['comment'] as String? ?? '';
    final userId = review['user_id'];
    final locationId = review['location_id'];
    final locationName = review['location_name'] as String? ?? 'Địa điểm #$locationId';
    final userName = review['user_name'] as String? ?? 'User #$userId';
    final photos = (review['photos'] as List?) ?? [];
    final createdAt = review['created_at'] as String? ?? '';
    final dateStr = createdAt.isNotEmpty
        ? (DateTime.tryParse(createdAt)?.let((d) => '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}') ?? createdAt)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar placeholder
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.user, size: 18, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 2),
                      // Stars
                      Row(
                        children: List.generate(5, (i) => Icon(
                          i < rating ? LucideIcons.star : LucideIcons.star,
                          color: i < rating ? Colors.amber : Colors.grey[300],
                          size: 13,
                        )),
                      ),
                    ],
                  ),
                ),
                // Delete button
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(LucideIcons.trash2, size: 18, color: AppTheme.errorColor),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),

          // ── Location name ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                const Icon(LucideIcons.mapPin, size: 13, color: AppTheme.primaryColor),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    locationName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // ── Comment ──────────────────────────────────────────────────────
          if (comment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                comment,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                  height: 1.55,
                ),
              ),
            ),

          // ── Photos ───────────────────────────────────────────────────────
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: photos.length,
                itemBuilder: (_, i) {
                  final url = photos[i] as String;
                  return GestureDetector(
                    onTap: () => _showPhoto(context, url),
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.grey[200],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            LucideIcons.image,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          // ── Footer: date + photo count ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(
              children: [
                const Icon(LucideIcons.clock, size: 12, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(dateStr, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                if (photos.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  const Icon(LucideIcons.image, size: 12, color: AppTheme.textSecondary),
                  const SizedBox(width: 3),
                  Text('${photos.length} ảnh',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPhoto(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

extension _LetExt<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
