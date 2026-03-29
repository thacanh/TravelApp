import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // ─── Gradient Header ───
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: AppTheme.primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
              ),
            ),
          ),

          // ─── Profile Card ───
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -56),
              child: Column(
                children: [
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, _) {
                      final user = authProvider.currentUser;
                      final isAdmin = user?.role == 'admin';
                      return Column(
                        children: [
                          // Avatar
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 16, offset: const Offset(0, 4))],
                            ),
                            child: CircleAvatar(
                              radius: 48,
                              backgroundColor: const Color(0xFFF3F4F8),
                              backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
                              child: user?.avatarUrl == null
                                  ? const Icon(Icons.person, size: 48, color: AppTheme.primaryColor)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            user?.fullName ?? 'Guest',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.admin_panel_settings, size: 15, color: Colors.white),
                                  SizedBox(width: 5),
                                  Text('Quản trị viên', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  _buildMenuSection(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = authProvider.isAdmin;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Personal section
          const _SectionTitle(title: 'CÁ NHÂN'),
          const SizedBox(height: 8),
          _MenuCard(children: [
            _MenuItem(icon: Icons.edit_outlined, title: 'Chỉnh sửa thông tin', onTap: () => Navigator.pushNamed(context, AppRoutes.editProfile)),
            const _MenuDivider(),
            _MenuItem(icon: Icons.check_circle_outline, title: 'Check-in của tôi', onTap: () {}),
            const _MenuDivider(),
            _MenuItem(icon: Icons.rate_review_outlined, title: 'Đánh giá của tôi', onTap: () {}),
            const _MenuDivider(),
            _MenuItem(icon: Icons.favorite_outline, title: 'Yêu thích', onTap: () {}),
            const _MenuDivider(),
            _MenuItem(icon: Icons.map_outlined, title: 'Lịch trình', onTap: () => Navigator.pushNamed(context, AppRoutes.itineraryList)),
          ]),

          // Admin section
          if (isAdmin) ...[
            const SizedBox(height: 20),
            const _SectionTitle(title: 'QUẢN TRỊ'),
            const SizedBox(height: 8),
            _MenuCard(children: [
              _MenuItem(icon: Icons.dashboard_outlined, title: 'Bảng điều khiển', onTap: () => Navigator.pushNamed(context, AppRoutes.adminDashboard), iconColor: AppTheme.primaryColor),
              const _MenuDivider(),
              _MenuItem(icon: Icons.people_outline, title: 'Quản lý người dùng', onTap: () => Navigator.pushNamed(context, AppRoutes.adminUsers), iconColor: AppTheme.primaryColor),
              const _MenuDivider(),
              _MenuItem(icon: Icons.rate_review, title: 'Kiểm duyệt đánh giá', onTap: () => Navigator.pushNamed(context, AppRoutes.adminReviews), iconColor: AppTheme.primaryColor),
            ]),
          ],

          const SizedBox(height: 20),
          const _SectionTitle(title: 'KHÁC'),
          const SizedBox(height: 8),
          _MenuCard(children: [
            _MenuItem(icon: Icons.settings_outlined, title: 'Cài đặt', onTap: () {}),
            const _MenuDivider(),
            _MenuItem(icon: Icons.help_outline, title: 'Trợ giúp', onTap: () {}),
            const _MenuDivider(),
            _MenuItem(icon: Icons.info_outline, title: 'Về chúng tôi', onTap: () {}),
          ]),

          const SizedBox(height: 20),
          _MenuCard(children: [
            _MenuItem(
              icon: Icons.logout_rounded,
              title: 'Đăng xuất',
              isDestructive: true,
              onTap: () async {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
            ),
          ]),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, letterSpacing: 0.8),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<Widget> children;
  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(children: children),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: Colors.grey[100], indent: 56);
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;
  final Color? iconColor;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppTheme.errorColor : (iconColor ?? AppTheme.textSecondary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: (isDestructive ? AppTheme.errorColor : (iconColor ?? AppTheme.primaryColor)).withAlpha(18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: isDestructive ? AppTheme.errorColor : AppTheme.textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[350], size: 20),
          ],
        ),
      ),
    );
  }
}
