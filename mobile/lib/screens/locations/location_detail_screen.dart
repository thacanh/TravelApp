import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../models/location.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/api_service.dart';

class LocationDetailScreen extends StatefulWidget {
  const LocationDetailScreen({super.key});

  @override
  State<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<LocationDetailScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _reviews = [];
  bool _isLoadingReviews = true;
  bool _isFavorite = false;
  bool _initialized = false;

  late Location location;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    location = ModalRoute.of(context)!.settings.arguments as Location;
    if (!_initialized) {
      _initialized = true;
      _loadReviews();
      _checkFavorite();
    }
  }

  Future<void> _checkFavorite() async {
    try {
      final res = await _apiService.getFavorites();
      if (res.statusCode == 200) {
        final List<dynamic> favIds = res.data;
        if (mounted) {
          setState(() {
            _isFavorite = favIds.contains(location.id);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    final originalState = _isFavorite;
    setState(() => _isFavorite = !_isFavorite);
    
    try {
      if (_isFavorite) {
        await _apiService.addFavorite(location.id);
      } else {
        await _apiService.removeFavorite(location.id);
      }
    } catch (_) {
      // Revert if failed
      if (mounted) setState(() => _isFavorite = originalState);
    }
  }

  Future<void> _loadReviews() async {
    try {
      final response = await _apiService.getLocationReviews(location.id);
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _reviews = response.data as List;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  Future<void> _submitReview(double rating, String comment) async {
    try {
      final response = await _apiService.createReview({
        'location_id': location.id,
        'rating': rating,
        'comment': comment,
      });
      if (response.statusCode == 201 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã gửi đánh giá thành công!'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _loadReviews(); // Reload reviews list
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Đã có lỗi xảy ra';
        if (e.toString().contains('400')) errorMsg = 'Bạn đã đánh giá địa điểm này rồi';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa địa điểm?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Bạn có chắc muốn xóa "${location.name}" không?\nHành động này không thể hoàn tác.',
          style: const TextStyle(color: AppTheme.textSecondary),
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
      final res = await _apiService.deleteLocation(location.id);
      if ((res.statusCode ?? 0) < 300 && mounted) {
        await context.read<LocationProvider>().fetchLocations(forceRefresh: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa "${location.name}"'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.pop(context); // trở về list
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xóa: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // ─── Image Header ───
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppTheme.primaryColor,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              // ─── Admin actions ───
              Consumer<AuthProvider>(
                builder: (_, auth, __) {
                  if (!auth.isAdmin) return const SizedBox.shrink();
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit button
                      _AdminActionBtn(
                        icon: LucideIcons.pencil,
                        color: Colors.white,
                        tooltip: 'Chỉnh sửa',
                        onTap: () async {
                          final result = await Navigator.pushNamed(
                            context,
                            AppRoutes.adminLocationForm,
                            arguments: location.toJson(),
                          );
                          if (result == true && context.mounted) {
                            // Reload provider và pop về list
                            await context.read<LocationProvider>().fetchLocations(forceRefresh: true);
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      // Delete button
                      _AdminActionBtn(
                        icon: LucideIcons.trash2,
                        color: Colors.redAccent,
                        tooltip: 'Xóa',
                        onTap: () => _confirmDelete(context),
                      ),
                      const SizedBox(width: 4),
                    ],
                  );
                },
              ),
              // Favorite button
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: _isFavorite ? Colors.redAccent : Colors.white,
                      size: 20,
                    ),
                    onPressed: _toggleFavorite,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: location.images.isNotEmpty
                  ? CarouselSlider(
                      items: location.images.map((url) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              placeholder: (_, __) => Container(color: const Color(0xFFE8E8E8)),
                              errorWidget: (_, __, ___) => Container(
                                color: const Color(0xFFE8E8E8),
                                child: const Icon(Icons.image_not_supported_outlined, size: 50),
                              ),
                            ),
                            // Bottom gradient
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withAlpha(80)],
                                    stops: const [0.6, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                      options: CarouselOptions(
                        height: 320,
                        viewportFraction: 1.0,
                        autoPlay: true,
                        autoPlayInterval: const Duration(seconds: 4),
                      ),
                    )
                  : Container(
                      decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
                      child: const Icon(Icons.image_not_supported, size: 80, color: Colors.white54),
                    ),
            ),
          ),

          // ─── Content ───
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title & Category
                      Text(
                        location.name,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (location.categories.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withAlpha(18),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.primaryColor.withAlpha(45)),
                                    ),
                                    child: Text(location.categoryDisplay,
                                      style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600, fontSize: 12)),
                                  )
                                else
                                  ...location.categories.map((c) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withAlpha(18),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.primaryColor.withAlpha(45)),
                                    ),
                                    child: Text(c.name,
                                      style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600, fontSize: 12)),
                                  )),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  _isLoadingReviews
                                      ? location.ratingDisplay
                                      : _reviews.isEmpty
                                          ? 'Chưa có'
                                          : (_reviews
                                              .map((r) => (r['rating'] as num).toDouble())
                                              .reduce((a, b) => a + b) /
                                              _reviews.length)
                                              .toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '(${_reviews.length})',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Location
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withAlpha(18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.location_on, color: AppTheme.primaryColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${location.address ?? ''} ${location.city}, ${location.country}',
                                style: const TextStyle(fontSize: 14, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Description
                      const Text('Giới thiệu', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Text(
                        location.description ?? 'Chưa có mô tả',
                        style: const TextStyle(fontSize: 14.5, height: 1.65, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 24),

                      // Action button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: AppTheme.buttonShadow,
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, AppRoutes.checkin, arguments: location).then((value) {
                              if (value == true) {
                                _loadReviews(); // Reload after return
                              }
                            }),
                            icon: const Icon(Icons.rate_review, size: 20),
                            label: const Text('Ghé thăm & Đánh giá'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Reviews section
                      Row(
                        children: [
                          const Text('Đánh giá', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          if (_reviews.isNotEmpty)
                            Text('${_reviews.length} đánh giá', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (_isLoadingReviews)
                        const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                      else if (_reviews.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: AppTheme.softShadow,
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.rate_review_outlined, size: 44, color: Colors.grey[300]),
                              const SizedBox(height: 10),
                              Text('Chưa có đánh giá nào', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Text('Hãy là người đầu tiên đánh giá!', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                            ],
                          ),
                        )
                      else
                        ...(_reviews.map((review) => _ReviewCard(review: review))),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Removed _showReviewDialog as it's merged into CheckinScreen
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final user = review['user'] as Map<String, dynamic>?;
    final rating = (review['rating'] as num?)?.toDouble() ?? 0;
    final comment = review['comment'] as String? ?? '';
    final createdAt = review['created_at'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primaryColor.withAlpha(20),
                child: Text(
                  (user?['full_name'] ?? 'U').substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?['full_name'] ?? 'Người dùng', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    if (createdAt != null)
                      Text(
                        _formatDate(createdAt),
                        style: TextStyle(fontSize: 11.5, color: Colors.grey[400]),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  return Icon(
                    i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 16,
                  );
                }),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(comment, style: const TextStyle(height: 1.4, fontSize: 13.5, color: AppTheme.textSecondary)),
          ],
          if (review['photos'] != null && (review['photos'] as List).isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: (review['photos'] as List).length,
                itemBuilder: (context, index) {
                  final url = (review['photos'] as List)[index] as String;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey[200]),
                        errorWidget: (context, url, error) => Container(color: Colors.grey[200], child: const Icon(Icons.error)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }
}

/// Button nhỏ cho admin trong SliverAppBar với nền mờ
class _AdminActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _AdminActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(55),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                tooltip,
                style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
