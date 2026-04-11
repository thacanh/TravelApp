import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  final _api = ApiService();
  List<dynamic> _reviews = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.getMyCheckins(limit: 100);
      if (res.statusCode == 200 && mounted) {
        final all = res.data as List;
        setState(() {
          _reviews = all.where((c) => c['rating'] != null).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ── Edit dialog ──────────────────────────────────────────────────────────────
  Future<void> _showEditDialog(Map<String, dynamic> review) async {
    double rating = (review['rating'] as num?)?.toDouble() ?? 3.0;
    final commentCtrl = TextEditingController(text: review['comment'] as String? ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Chỉnh sửa đánh giá', style: TextStyle(fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Đánh giá', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                RatingBar.builder(
                  initialRating: rating,
                  minRating: 1,
                  itemCount: 5,
                  itemSize: 32,
                  itemBuilder: (_, __) => const Icon(Icons.star, color: Colors.amber),
                  onRatingUpdate: (r) => setStateDlg(() => rating = r),
                ),
                const SizedBox(height: 16),
                const Text('Nhận xét', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: commentCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Chia sẻ cảm nhận của bạn...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final res = await _api.updateReview(review['id'], {
        'rating': rating,
        'comment': commentCtrl.text.trim(),
      });
      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã cập nhật đánh giá!'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _load(); // reload
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  // ── Delete confirm ───────────────────────────────────────────────────────────
  Future<void> _confirmDelete(Map<String, dynamic> review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa đánh giá?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Bạn có chắc muốn xóa đánh giá này không?\nHành động này không thể hoàn tác.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
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

    if (confirmed != true || !mounted) return;

    try {
      final res = await _api.deleteReview(review['id']);
      if ((res.statusCode ?? 0) < 300 && mounted) {
        setState(() => _reviews.removeWhere((r) => r['id'] == review['id']));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã xóa đánh giá'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Đánh giá của tôi${_reviews.isNotEmpty ? " (${_reviews.length})" : ""}'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            onPressed: _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _reviews.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _reviews.length,
                        itemBuilder: (_, i) => _ReviewCard(
                          review: _reviews[i],
                          onEdit: () => _showEditDialog(_reviews[i]),
                          onDelete: () => _confirmDelete(_reviews[i]),
                        ),
                      ),
                    ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withAlpha(15),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.star, size: 36, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 16),
          const Text('Bạn chưa có đánh giá nào',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Hãy ghé thăm và đánh giá các địa điểm!',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.alertCircle, size: 48, color: AppTheme.errorColor),
          const SizedBox(height: 12),
          Text(_error ?? 'Lỗi không xác định',
              style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _load, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

// ── Review Card ──────────────────────────────────────────────────────────────
class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReviewCard({
    required this.review,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final comment = review['comment'] as String? ?? '';
    final locationName = review['location_name'] as String? ??
        (review['location'] as Map?)?['name'] as String? ??
        'Địa điểm';
    final createdAt = review['created_at'] as String? ?? '';
    final photos = (review['photos'] as List?) ?? [];
    final dateStr = createdAt.isNotEmpty
        ? (DateTime.tryParse(createdAt)?.let(
                (d) => '${d.day}/${d.month}/${d.year}') ??
            createdAt)
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
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locationName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Stars
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            LucideIcons.star,
                            size: 14,
                            color: i < rating ? Colors.amber : Colors.grey[300],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Action buttons
                Row(
                  children: [
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(LucideIcons.pencil, size: 17),
                      color: AppTheme.primaryColor,
                      tooltip: 'Chỉnh sửa',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(LucideIcons.trash2, size: 17),
                      color: AppTheme.errorColor,
                      tooltip: 'Xóa',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Comment ───────────────────────────────────────────────────────
          if (comment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                comment,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppTheme.textSecondary,
                  height: 1.55,
                ),
              ),
            ),

          // ── Photos ────────────────────────────────────────────────────────
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: photos.length,
                itemBuilder: (_, i) => Container(
                  width: 75,
                  margin: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      photos[i] as String,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: const Icon(LucideIcons.image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],

          // ── Footer ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(
              children: [
                const Icon(LucideIcons.calendar, size: 12, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(dateStr,
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
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
}

extension _LetExt<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
