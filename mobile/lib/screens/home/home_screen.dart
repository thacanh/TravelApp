import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../config/app_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../models/location.dart';
import '../locations/location_list_screen.dart';
import '../ai/chatbot_screen.dart';
import '../profile/profile_screen.dart';
import '../admin/admin_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.currentUser?.role == 'admin';

    final List<Widget> screens = isAdmin
        ? [
            const HomeContent(),
            const ExploreScreen(),
            const AdminDashboardScreen(),
            const ChatbotScreenSimple(),
            const ProfileScreenSimple(),
          ]
        : [
            const HomeContent(),
            const ExploreScreen(),
            const ChatbotScreenSimple(),
            const ProfileScreenSimple(),
          ];

    final List<BottomNavigationBarItem> navItems = isAdmin
        ? const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'Trang chủ'),
            BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), activeIcon: Icon(Icons.explore), label: 'Khám phá'),
            BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings_outlined), activeIcon: Icon(Icons.admin_panel_settings), label: 'Quản trị'),
            BottomNavigationBarItem(icon: Icon(Icons.smart_toy_outlined), activeIcon: Icon(Icons.smart_toy), label: 'AI Chat'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Cá nhân'),
          ]
        : const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'Trang chủ'),
            BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), activeIcon: Icon(Icons.explore), label: 'Khám phá'),
            BottomNavigationBarItem(icon: Icon(Icons.smart_toy_outlined), activeIcon: Icon(Icons.smart_toy), label: 'AI Chat'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Cá nhân'),
          ];

    if (_selectedIndex >= screens.length) _selectedIndex = 0;

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 20, offset: const Offset(0, -4)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: navItems,
        ),
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final List<String> categories = ['beach', 'mountain', 'city', 'cultural', 'nature'];
  final Map<String, String> categoryNames = {
    'beach': 'Bãi biển',
    'mountain': 'Núi',
    'city': 'Thành phố',
    'cultural': 'Văn hóa',
    'nature': 'Thiên nhiên',
  };
  final Map<String, IconData> categoryIcons = {
    'beach': Icons.beach_access,
    'mountain': Icons.terrain,
    'city': Icons.location_city,
    'cultural': Icons.account_balance,
    'nature': Icons.nature,
  };
  final Map<String, List<Color>> categoryGradients = {
    'beach': [const Color(0xFF00BCD4), const Color(0xFF26C6DA)],
    'mountain': [const Color(0xFF4CAF50), const Color(0xFF66BB6A)],
    'city': [const Color(0xFFFF9800), const Color(0xFFFFB74D)],
    'cultural': [const Color(0xFF9C27B0), const Color(0xFFBA68C8)],
    'nature': [const Color(0xFF2E7D32), const Color(0xFF81C784)],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LocationProvider>(context, listen: false).fetchLocations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ─── Header ───
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          automaticallyImplyLeading: false,
          backgroundColor: AppTheme.primaryColor,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Xin chào, ${auth.currentUser?.fullName ?? 'Guest'}',
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Hôm nay bạn muốn đi đâu?',
                                      style: TextStyle(fontSize: 14, color: Colors.white.withAlpha(190)),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(40),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
                                  onPressed: () {},
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      // Search bar
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, AppRoutes.locationList),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search, color: Colors.grey[400], size: 22),
                              const SizedBox(width: 10),
                              Text('Tìm kiếm địa điểm...', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ─── Quick Actions ───
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Truy cập nhanh', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _QuickAction(
                      icon: Icons.auto_awesome,
                      label: 'AI Gợi ý',
                      gradient: const [Color(0xFF6C63FF), Color(0xFF00BCD4)],
                      onTap: () => Navigator.pushNamed(context, AppRoutes.aiRecommend),
                    ),
                    _QuickAction(
                      icon: Icons.map_rounded,
                      label: 'Bản đồ',
                      gradient: const [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                      onTap: () => Navigator.pushNamed(context, AppRoutes.map),
                    ),
                    _QuickAction(
                      icon: Icons.camera_alt_rounded,
                      label: 'Đánh giá',
                      gradient: const [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                      onTap: () => Navigator.pushNamed(context, AppRoutes.checkin),
                    ),
                    _QuickAction(
                      icon: Icons.calendar_today_rounded,
                      label: 'Lịch trình',
                      gradient: const [Color(0xFFFF9800), Color(0xFFFFB74D)],
                      onTap: () => Navigator.pushNamed(context, AppRoutes.itineraryList),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ─── Categories ───
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Danh mục', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                SizedBox(
                  height: 88,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final gradient = categoryGradients[cat] ?? [AppTheme.primaryColor, AppTheme.secondaryColor];
                      return GestureDetector(
                        onTap: () => Navigator.pushNamed(context, AppRoutes.locationList),
                        child: Column(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [gradient[0].withAlpha(25), gradient[1].withAlpha(25)]),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: gradient[0].withAlpha(50)),
                              ),
                              child: Icon(categoryIcons[cat], color: gradient[0], size: 26),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              categoryNames[cat] ?? cat,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── Featured locations ───
        SliverToBoxAdapter(
          child: Consumer<LocationProvider>(
            builder: (context, locationProvider, _) {
              if (locationProvider.isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final locations = locationProvider.locations;
              if (locations.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.explore_off, size: 56, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('Chưa có địa điểm nào', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        Text('Kiểm tra kết nối tới server', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 20, top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Địa điểm nổi bật', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, AppRoutes.locationList),
                            child: const Text('Xem tất cả →', style: TextStyle(color: AppTheme.primaryColor, fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    CarouselSlider(
                      options: CarouselOptions(
                        height: 210,
                        autoPlay: true,
                        enlargeCenterPage: true,
                        viewportFraction: 0.82,
                        autoPlayInterval: const Duration(seconds: 4),
                      ),
                      items: locations.take(5).map((location) {
                        return _FeaturedLocationCard(location: location);
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
      ],
    );
  }
}

class _FeaturedLocationCard extends StatelessWidget {
  final Location location;

  const _FeaturedLocationCard({required this.location});

  @override
  Widget build(BuildContext context) {
    final imageUrl = location.images.isNotEmpty
        ? (location.images.first.startsWith('http')
            ? location.images.first
            : '${AppConfig.baseUrl}/${location.images.first}')
        : null;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.locationDetail, arguments: location),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl != null)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: const Color(0xFFE8E8E8)),
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFFE8E8E8),
                    child: const Icon(Icons.image, size: 50, color: Colors.grey),
                  ),
                )
              else
                Container(
                  decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
                  child: const Icon(Icons.landscape, size: 50, color: Colors.white54),
                ),
              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withAlpha(180)],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),
              // Info
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white70, size: 14),
                        const SizedBox(width: 3),
                        Text(location.city, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const Spacer(),
                        if (location.totalReviews > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(40),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                              const SizedBox(width: 3),
                              Text(
                                location.ratingDisplay,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: gradient.first.withAlpha(60),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// Wrapper screens for bottom nav
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LocationListScreen();
  }
}

class ChatbotScreenSimple extends StatelessWidget {
  const ChatbotScreenSimple({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatbotScreen();
  }
}

class ProfileScreenSimple extends StatelessWidget {
  const ProfileScreenSimple({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileScreen();
  }
}
