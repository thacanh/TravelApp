import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';

class AdminLocationsScreen extends StatefulWidget {
  const AdminLocationsScreen({super.key});

  @override
  State<AdminLocationsScreen> createState() => _AdminLocationsScreenState();
}

class _AdminLocationsScreenState extends State<AdminLocationsScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _locations = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? search}) async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getLocations(limit: 100, search: search);
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _locations = res.data as List;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa địa điểm?'),
        content: Text('Bạn có chắc muốn xóa "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteLocation(id);
      _load(search: _searchCtrl.text.isEmpty ? null : _searchCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã xóa địa điểm'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Quản lý Địa điểm'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            onPressed: () => _load(search: _searchCtrl.text.isEmpty ? null : _searchCtrl.text),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/admin/location-form');
          if (result == true) _load();
        },
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(LucideIcons.plus, color: Colors.white, size: 20),
        label: const Text('Thêm địa điểm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm địa điểm...',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _load();
                        },
                      )
                    : null,
              ),
              onChanged: (v) {
                setState(() {});
                if (v.length >= 2 || v.isEmpty) _load(search: v.isEmpty ? null : v);
              },
            ),
          ),

          // Count banner
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(LucideIcons.mapPin, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '${_locations.length} địa điểm',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _locations.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: () => _load(search: _searchCtrl.text.isEmpty ? null : _searchCtrl.text),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          itemCount: _locations.length,
                          itemBuilder: (ctx, i) => _LocationAdminCard(
                            location: _locations[i],
                            onEdit: () async {
                              final result = await Navigator.pushNamed(
                                context,
                                '/admin/location-form',
                                arguments: _locations[i],
                              );
                              if (result == true) _load();
                            },
                            onDelete: () => _delete(
                              _locations[i]['id'],
                              _locations[i]['name'] ?? '',
                            ),
                          ),
                        ),
                      ),
          ),
        ],
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
            child: const Icon(LucideIcons.flag, size: 36, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 16),
          const Text('Chưa có địa điểm nào', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Nhấn nút + để thêm địa điểm mới', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _LocationAdminCard extends StatelessWidget {
  final Map<String, dynamic> location;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LocationAdminCard({required this.location, required this.onEdit, required this.onDelete});

  String _catLabel(String? cat) {
    switch (cat) {
      case 'beach': return 'Bãi biển';
      case 'mountain': return 'Núi';
      case 'city': return 'Thành phố';
      case 'cultural': return 'Văn hóa';
      case 'nature': return 'Thiên nhiên';
      default: return cat ?? '';
    }
  }

  Color _catColor(String? cat) {
    switch (cat) {
      case 'beach': return const Color(0xFF00BCD4);
      case 'mountain': return const Color(0xFF4CAF50);
      case 'city': return const Color(0xFFFF9800);
      case 'cultural': return const Color(0xFF9C27B0);
      case 'nature': return const Color(0xFF2E7D32);
      default: return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = (location['images'] as List?) ?? [];
    final cat = location['category'] as String?;
    final catColor = _catColor(cat);
    final rating = (location['rating_avg'] as num?)?.toDouble() ?? 0.0;
    final totalReviews = location['total_reviews'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            child: SizedBox(
              width: 90,
              height: 90,
              child: images.isNotEmpty
                  ? Image.network(
                      images.first as String,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(catColor),
                    )
                  : _placeholder(catColor),
            ),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location['name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: catColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(_catLabel(cat),
                            style: TextStyle(fontSize: 11, color: catColor, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 6),
                      const Icon(LucideIcons.mapPin, size: 11, color: AppTheme.textSecondary),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          location['city'] ?? '',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (totalReviews > 0)
                    Row(
                      children: [
                        const Icon(LucideIcons.star, size: 12, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text('${rating.toStringAsFixed(1)} ($totalReviews)',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
                      ],
                    ),
                ],
              ),
            ),
          ),
          // Actions
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(LucideIcons.pencil, size: 18, color: AppTheme.primaryColor),
                onPressed: onEdit,
                tooltip: 'Chỉnh sửa',
              ),
              IconButton(
                icon: const Icon(LucideIcons.trash2, size: 18, color: AppTheme.errorColor),
                onPressed: onDelete,
                tooltip: 'Xóa',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder(Color color) {
    return Container(
      color: color.withAlpha(30),
      child: Icon(LucideIcons.image, color: color, size: 28),
    );
  }
}
