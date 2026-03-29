import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../services/api_service.dart';

class AIRecommendScreen extends StatefulWidget {
  const AIRecommendScreen({super.key});

  @override
  State<AIRecommendScreen> createState() => _AIRecommendScreenState();
}

class _AIRecommendScreenState extends State<AIRecommendScreen> {
  final ApiService _apiService = ApiService();
  final _inputController = TextEditingController();
  List<dynamic> _results = [];
  String _explanation = '';
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _getRecommendations() async {
    if (_inputController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.getAIRecommendations({
        'preferences': _inputController.text.trim(),
      });

      if (response.statusCode == 200) {
        setState(() {
          _results = response.data['recommendations'] ?? [];
          _explanation = response.data['explanation'] ?? '';
        });
      } else {
        setState(() {
          _errorMessage = 'Lỗi server: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Không thể kết nối server. Kiểm tra lại mạng.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Gradient header
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppTheme.primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF00BCD4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AI Gợi ý Địa điểm',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                Text(
                                  'Mô tả nhu cầu, AI tìm nơi phù hợp nhất',
                                  style: TextStyle(fontSize: 13, color: Colors.white70),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Search area
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: 'VD: Biển đẹp, yên tĩnh, có resort ngoài trời...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6C63FF), Color(0xFF00BCD4)],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                              ),
                              onPressed: _getRecommendations,
                            ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    maxLines: 3,
                    minLines: 1,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _getRecommendations(),
                  ),
                  const SizedBox(height: 10),
                  // Quick suggestion chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _QuickChip(label: '🏖 Biển đẹp', onTap: () {
                          _inputController.text = 'Tôi muốn nghỉ dưỡng ở biển, nơi yên tĩnh, có bãi biển đẹp';
                          _getRecommendations();
                        }),
                        _QuickChip(label: '⛰ Leo núi', onTap: () {
                          _inputController.text = 'Tôi muốn leo núi, trekking, khám phá thiên nhiên hoang sơ';
                          _getRecommendations();
                        }),
                        _QuickChip(label: '🏛 Văn hóa', onTap: () {
                          _inputController.text = 'Tôi muốn tham quan di tích lịch sử, đền chùa, văn hóa';
                          _getRecommendations();
                        }),
                        _QuickChip(label: '🌿 Thiên nhiên', onTap: () {
                          _inputController.text = 'Tôi muốn khám phá thiên nhiên hoang sơ, hang động, rừng';
                          _getRecommendations();
                        }),
                        _QuickChip(label: '🏙 Thành phố', onTap: () {
                          _inputController.text = 'Tôi muốn du lịch thành phố, ẩm thực, mua sắm, giải trí';
                          _getRecommendations();
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content area
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 56, height: 56,
                      child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF6C63FF)),
                    ),
                    SizedBox(height: 20),
                    Text('AI đang phân tích...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    SizedBox(height: 6),
                    Text('Đang tìm địa điểm phù hợp nhất cho bạn', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else if (_errorMessage != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _getRecommendations,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (!_hasSearched)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.travel_explore, size: 72, color: const Color(0xFF6C63FF).withOpacity(0.5)),
                    ),
                    const SizedBox(height: 20),
                    const Text('Bạn muốn đi đâu?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('Mô tả nhu cầu hoặc chọn gợi ý nhanh bên trên',
                        style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              ),
            )
          else if (_results.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text('Chưa tìm thấy kết quả phù hợp'),
                    const SizedBox(height: 8),
                    Text('Thử mô tả khác hoặc dùng gợi ý nhanh', style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              ),
            )
          else ...[
            // Explanation banner
            if (_explanation.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF6C63FF).withOpacity(0.08), const Color(0xFF00BCD4).withOpacity(0.08)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Color(0xFF6C63FF), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_explanation, style: const TextStyle(fontSize: 13, height: 1.4)),
                      ),
                    ],
                  ),
                ),
              ),

            // Results list
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = _results[index];
                  return _ResultCard(
                    recommendation: item,
                    rank: index + 1,
                    onTap: () {
                      final locId = item['location_id'];
                      if (locId != null) {
                        Navigator.pushNamed(context, AppRoutes.locationDetail, arguments: locId);
                      }
                    },
                  );
                },
                childCount: _results.length,
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12.5)),
        onPressed: onTap,
        backgroundColor: Colors.grey[50],
        side: BorderSide(color: Colors.grey[200]!),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> recommendation;
  final int rank;
  final VoidCallback onTap;
  const _ResultCard({required this.recommendation, required this.rank, required this.onTap});

  IconData _categoryIcon(String? cat) {
    switch (cat) {
      case 'beach': return Icons.beach_access;
      case 'mountain': return Icons.terrain;
      case 'city': return Icons.location_city;
      case 'cultural': return Icons.account_balance;
      case 'nature': return Icons.nature;
      default: return Icons.place;
    }
  }

  String _categoryLabel(String? cat) {
    switch (cat) {
      case 'beach': return 'Bãi biển';
      case 'mountain': return 'Núi';
      case 'city': return 'Thành phố';
      case 'cultural': return 'Văn hóa';
      case 'nature': return 'Thiên nhiên';
      default: return 'Khác';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = recommendation['name'] ?? 'Địa điểm';
    final city = recommendation['city'] ?? '';
    final reason = recommendation['reason'] ?? '';
    final matchScore = recommendation['match_score'];
    final rating = recommendation['rating'];
    final category = recommendation['category'] as String?;
    final images = recommendation['images'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image with overlay
              if (images.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Stack(
                    children: [
                      Image.network(
                        images.first,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [const Color(0xFF6C63FF).withOpacity(0.3), const Color(0xFF00BCD4).withOpacity(0.3)],
                            ),
                          ),
                          child: Center(child: Icon(_categoryIcon(category), size: 40, color: Colors.white70)),
                        ),
                      ),
                      // Rank badge
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF00BCD4)]),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('#$rank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                      // Category badge
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_categoryIcon(category), size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(_categoryLabel(category), style: const TextStyle(color: Colors.white, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + rating
                    Row(
                      children: [
                        Expanded(
                          child: Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        ),
                        if (rating != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                const SizedBox(width: 2),
                                Text('${(rating as num).toStringAsFixed(1)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    // City
                    if (city.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 3),
                          Text(city, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        ],
                      ),
                    ],

                    // AI reason
                    if (reason.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withOpacity(0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.1)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.auto_awesome, size: 15, color: Color(0xFF6C63FF)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(reason, style: const TextStyle(fontSize: 13, height: 1.4)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Match score bar
                    if (matchScore != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (matchScore as num).toDouble().clamp(0.0, 1.0),
                                backgroundColor: Colors.grey[100],
                                valueColor: const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Phù hợp ${((matchScore as num) * 100).toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
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
