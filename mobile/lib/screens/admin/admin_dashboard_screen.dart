import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final response = await _apiService.getAdminStats();
      if (response.statusCode == 200) {
        setState(() {
          _stats = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng điều khiển'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                padding: const EdgeInsets.all(AppTheme.paddingM),
                children: [
                  // Summary cards
                  _buildSummaryGrid(),
                  const SizedBox(height: 24),
                  // Quick actions
                  _buildQuickActions(context),
                  const SizedBox(height: 24),
                  // Category breakdown
                  if (_stats?['locations']?['by_category'] != null)
                    _buildCategoryBreakdown(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryGrid() {
    final users = _stats?['users'] ?? {};
    final locations = _stats?['locations'] ?? {};
    final reviews = _stats?['reviews'] ?? {};
    final checkins = _stats?['checkins'] ?? {};

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        _StatCard(
          icon: LucideIcons.users,
          label: 'Người dùng',
          value: '${users['total'] ?? 0}',
          subtitle: '${users['active'] ?? 0} hoạt động',
          color: AppTheme.primaryColor,
        ),
        _StatCard(
          icon: LucideIcons.mapPin,
          label: 'Địa điểm',
          value: '${locations['total'] ?? 0}',
          subtitle: '',
          color: AppTheme.secondaryColor,
        ),
        _StatCard(
          icon: LucideIcons.star,
          label: 'Đánh giá',
          value: '${reviews['total'] ?? 0}',
          subtitle: '⭐ ${reviews['average_rating'] ?? 0}',
          color: AppTheme.accentColor,
        ),
        _StatCard(
          icon: LucideIcons.checkCircle,
          label: 'Check-in',
          value: '${checkins['total'] ?? 0}',
          subtitle: '',
          color: AppTheme.successColor,
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quản lý nhanh',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(LucideIcons.users, color: AppTheme.primaryColor, size: 22),
                title: const Text('Quản lý người dùng'),
                subtitle: const Text('Xem, khóa/mở khóa tài khoản'),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () => Navigator.pushNamed(context, '/admin/users'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(LucideIcons.messageSquare, color: AppTheme.secondaryColor, size: 22),
                title: const Text('Kiểm duyệt đánh giá'),
                subtitle: const Text('Duyệt và xóa đánh giá vi phạm'),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () => Navigator.pushNamed(context, '/admin/reviews'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(LucideIcons.mapPin, color: AppTheme.successColor, size: 22),
                title: const Text('Quản lý địa điểm'),
                subtitle: const Text('Thêm, sửa, xóa địa điểm'),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () => Navigator.pushNamed(context, '/admin/locations'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBreakdown() {
    final categories = _stats!['locations']['by_category'] as Map<String, dynamic>;
    final categoryNames = {
      'beach': 'Bãi biển',
      'mountain': 'Núi',
      'city': 'Thành phố',
      'cultural': 'Văn hóa',
      'nature': 'Thiên nhiên',
    };
    final categoryColors = {
      'beach': Colors.blue,
      'mountain': Colors.green,
      'city': Colors.orange,
      'cultural': Colors.purple,
      'nature': Colors.teal,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Địa điểm theo danh mục',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: categories.entries.map((entry) {
                final total = (_stats!['locations']['total'] as int);
                final percent = total > 0 ? (entry.value as int) / total : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          categoryNames[entry.key] ?? entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: percent,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation(
                            categoryColors[entry.key] ?? AppTheme.primaryColor,
                          ),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${entry.value}'),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
