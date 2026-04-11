import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import '../../config/theme.dart';
import '../../config/app_config.dart';
import '../../services/api_service.dart';

/// Data passed to this screen from itinerary detail.
class ItineraryRouteArgs {
  final int itineraryId;
  final int dayId;
  final String dayTitle;
  final List<Map<String, dynamic>> activities;

  const ItineraryRouteArgs({
    required this.itineraryId,
    required this.dayId,
    required this.dayTitle,
    required this.activities,
  });
}

class ItineraryRouteMapScreen extends StatefulWidget {
  const ItineraryRouteMapScreen({super.key});

  @override
  State<ItineraryRouteMapScreen> createState() => _ItineraryRouteMapScreenState();
}

class _ItineraryRouteMapScreenState extends State<ItineraryRouteMapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  LatLng? _userPosition;
  List<Map<String, dynamic>> _sortedStops = [];
  List<LatLng> _routePoints = [];
  bool _isLoading = true;
  late ItineraryRouteArgs _args;
  bool _argsLoaded = false;

  // AI suggestions
  String? _aiText;
  bool _aiLoading = true;

  // Selected stop index for card highlight
  int _selectedStopIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsLoaded) {
      _argsLoaded = true;
      _args = ModalRoute.of(context)!.settings.arguments as ItineraryRouteArgs;
      _init();
    }
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);

    // 1. Get user location
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm != LocationPermission.denied && perm != LocationPermission.deniedForever) {
        Position? pos = await Geolocator.getLastKnownPosition();
        pos ??= await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        );
        _userPosition = LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {
      debugPrint('Lỗi vị trí — dùng mặc định');
    }
    _userPosition ??= LatLng(AppConfig.defaultLatitude, AppConfig.defaultLongitude);

    // 2. Sort stops by nearest-neighbor
    final geoActs = _args.activities
        .where((a) => a['location_lat'] != null && a['location_lng'] != null)
        .toList();

    final sorted = <Map<String, dynamic>>[];
    double lat = _userPosition!.latitude;
    double lng = _userPosition!.longitude;
    final remaining = List<Map<String, dynamic>>.from(geoActs);

    while (remaining.isNotEmpty) {
      remaining.sort((a, b) {
        final da = _haversine(lat, lng, (a['location_lat'] as num).toDouble(), (a['location_lng'] as num).toDouble());
        final db = _haversine(lat, lng, (b['location_lat'] as num).toDouble(), (b['location_lng'] as num).toDouble());
        return da.compareTo(db);
      });
      final nearest = remaining.removeAt(0);
      final dist = _haversine(lat, lng,
          (nearest['location_lat'] as num).toDouble(), (nearest['location_lng'] as num).toDouble());
      sorted.add({...nearest, 'dist_km': dist.toStringAsFixed(1)});
      lat = (nearest['location_lat'] as num).toDouble();
      lng = (nearest['location_lng'] as num).toDouble();
    }
    _sortedStops = sorted;

    // 3. Run OSRM route + AI suggestions IN PARALLEL
    if (sorted.isNotEmpty) {
      await Future.wait([
        _fetchOSRMRoute().then((pts) {
          _routePoints = pts;
          if (_routePoints.isEmpty) {
            _routePoints = [
              _userPosition!,
              ...sorted.map((s) => LatLng(
                (s['location_lat'] as num).toDouble(),
                (s['location_lng'] as num).toDouble(),
              )),
            ];
          }
        }),
        _fetchAISuggestions(sorted),
      ]);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (_routePoints.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
      }
    }
  }

  Future<List<LatLng>> _fetchOSRMRoute() async {
    if (_sortedStops.isEmpty) return [];
    try {
      final waypoints = [
        '${_userPosition!.longitude},${_userPosition!.latitude}',
        ..._sortedStops.map((s) =>
            '${(s['location_lng'] as num).toDouble()},${(s['location_lat'] as num).toDouble()}'),
      ];
      final url =
          'https://router.project-osrm.org/route/v1/driving/${waypoints.join(';')}?overview=full&geometries=geojson';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final coords = data['routes'][0]['geometry']['coordinates'] as List;
          return coords.map<LatLng>((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
        }
      }
    } catch (e) {
      debugPrint('OSRM error: $e');
    }
    return [];
  }

  Future<void> _fetchAISuggestions(List<Map<String, dynamic>> stops) async {
    final locationNames = stops
        .map((s) => s['location_name'] ?? s['title'] ?? '')
        .where((n) => n.toString().isNotEmpty)
        .join(', ');

    if (locationNames.isEmpty) {
      if (mounted) setState(() { _aiLoading = false; _aiText = _kFallbackAI; });
      return;
    }

    final prompt = '''Tôi đang lên lịch trình thăm các địa điểm: $locationNames.

Trả lời ngắn gọn, súc tích theo 2 mục:

## Phải thử tại mỗi địa điểm
Với mỗi địa điểm, liệt kê 2-3 điều nên làm/thử nhất (ăn gì, xem gì, làm gì).

## Checklist chuẩn bị cho chuyến đi
Liệt kê 6-8 thứ cần mang theo phù hợp với các địa điểm này.

Quy tắc định dạng:
- Chỉ dùng * (dấu sao đơn) cho gạch đầu dòng, KHÔNG dùng **
- Tiêu đề dùng ##
- Trả lời bằng tiếng Việt''';

    try {
      final res = await _apiService.chatWithAI(prompt);
      if (res.statusCode == 200 && mounted) {
        final text = res.data['response'] as String? ?? '';
        setState(() { _aiText = text.isNotEmpty ? text : _kFallbackAI; _aiLoading = false; });
      } else {
        if (mounted) setState(() { _aiLoading = false; _aiText = _kFallbackAI; });
      }
    } catch (e) {
      debugPrint('AI suggestions error: $e');
      if (mounted) setState(() { _aiLoading = false; _aiText = _kFallbackAI; });
    }
  }

  // ── Fallback AI content ───────────────────────────────────────────────────────
  static const String _kFallbackAI = '''
## Gợi ý khi tham quan
* Dậy sớm để tránh đông người và ánh sáng đẹp cho ảnh
* Hỏi người địa phương về món ăn đường phố ngon gần đó
* Ghé chợ buổi sáng để trải nghiệm văn hóa bản địa
* Thử đặc sản vùng miền thay vì chọn nhà hàng phổ thông
* Đi bộ khám phá các con hẻm nhỏ để tìm góc nhìn độc đáo

## Checklist chuẩn bị
* 🧴 Kem chống nắng SPF50+ và kính mát
* 💧 Bình nước tái sử dụng (thời tiết VN rất nóng)
* 🎽 Áo thoáng mát, dễ thấm mồ hôi; thêm áo khoác nhẹ cho buổi tối
* 👟 Giày đi bộ thoải mái (tránh dép lê trơn trượt)
* 🔋 Pin dự phòng đầy điện cho điện thoại
* 💊 Thuốc cơ bản: hạ sốt, tiêu chảy, dị ứng
* 💵 Tiền mặt VNĐ đủ dùng (nhiều nơi chưa nhận thẻ)
* 🛡️ Túi đeo chéo chống móc để giữ đồ an toàn''';

  // ── Helpers ───────────────────────────────────────────────────────────────────

  void _fitBounds() {
    if (_routePoints.isEmpty) return;
    final lats = _routePoints.map((p) => p.latitude).toList();
    final lngs = _routePoints.map((p) => p.longitude).toList();
    _mapController.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds(
        LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
        LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
      ),
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 260),
    ));
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _deg2rad(double d) => d * math.pi / 180;

  // ── Markers ───────────────────────────────────────────────────────────────────

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    if (_userPosition != null) {
      markers.add(Marker(
        point: _userPosition!,
        width: 40, height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue, shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [BoxShadow(color: Colors.blue.withAlpha(80), blurRadius: 10, spreadRadius: 2)],
          ),
          child: const Icon(Icons.my_location, color: Colors.white, size: 20),
        ),
      ));
    }
    for (int i = 0; i < _sortedStops.length; i++) {
      final s = _sortedStops[i];
      final isSelected = i == _selectedStopIndex;
      markers.add(Marker(
        point: LatLng(
          (s['location_lat'] as num).toDouble(),
          (s['location_lng'] as num).toDouble(),
        ),
        width: isSelected ? 42 : 36,
        height: isSelected ? 42 : 36,
        child: GestureDetector(
          onTap: () {
            setState(() => _selectedStopIndex = i);
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text('${i + 1}. ${s['location_name'] ?? s['title'] ?? ''}'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (s['dist_km'] != null)
                      Text('📍 ${s['dist_km']} km từ điểm trước',
                          style: const TextStyle(color: AppTheme.primaryColor)),
                    if ((s['start_time'] as String?) != null) Text('🕐 ${s['start_time']}'),
                  ],
                ),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))],
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: isSelected ? const LinearGradient(
                colors: [Colors.red, Colors.deepOrange],
              ) : AppTheme.primaryGradient,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
              boxShadow: [BoxShadow(
                color: (isSelected ? Colors.red : AppTheme.primaryColor).withAlpha(80),
                blurRadius: isSelected ? 12 : 6,
                offset: const Offset(0, 2),
              )],
            ),
            child: Center(
              child: Text('${i + 1}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: isSelected ? 16 : 14,
                  )),
            ),
          ),
        ),
      ));
    }
    return markers;
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userPosition ?? LatLng(AppConfig.defaultLatitude, AppConfig.defaultLongitude),
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.trawime',
                maxZoom: 19,
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(points: _routePoints, strokeWidth: 5, color: AppTheme.primaryColor),
                ]),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withAlpha(60),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Đang tính lộ trình & Điều nên làm...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Custom AppBar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.arrowLeft, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_argsLoaded ? _args.dayTitle : '',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${_sortedStops.length} điểm dừng · lộ trình tối ưu',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.locateFixed, size: 20),
                      onPressed: () => _userPosition != null ? _mapController.move(_userPosition!, 14) : null,
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.maximize2, size: 18),
                      onPressed: _fitBounds,
                      tooltip: 'Xem toàn bộ lộ trình',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom draggable sheet
          if (!_isLoading && _sortedStops.isNotEmpty)
            DraggableScrollableSheet(
              initialChildSize: 0.33,
              minChildSize: 0.22,
              maxChildSize: 0.70,
              snap: true,
              snapSizes: const [0.33, 0.70],
              builder: (ctx, sheetScrollCtrl) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 20, offset: const Offset(0, -4))
                    ],
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Tabs
                      TabBar(
                        controller: _tabController,
                        labelColor: AppTheme.primaryColor,
                        unselectedLabelColor: AppTheme.textSecondary,
                        indicatorColor: AppTheme.primaryColor,
                        indicatorSize: TabBarIndicatorSize.label,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        tabs: [
                          const Tab(text: 'Lộ trình'),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Điều nên làm'),
                                if (_aiLoading) ...[
                                  const SizedBox(width: 6),
                                  const SizedBox(
                                    width: 10, height: 10,
                                    child: CircularProgressIndicator(strokeWidth: 1.5),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Tab content — fills remaining sheet space
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildRouteTab(),
                            _buildAITab(sheetScrollCtrl),
                          ],
                        ),
                      ),
                      SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Route tab (horizontal scrolling cards) ────────────────────────────────────

  Widget _buildRouteTab() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _sortedStops.length,
      itemBuilder: (ctx, i) {
        final s = _sortedStops[i];
        final isSelected = i == _selectedStopIndex;
        return GestureDetector(
          onTap: () {
            setState(() => _selectedStopIndex = i);
            _mapController.move(
              LatLng(
                (s['location_lat'] as num).toDouble(),
                (s['location_lng'] as num).toDouble(),
              ),
              15,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 155,
            height: 115,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: isSelected ? AppTheme.primaryGradient : null,
              color: isSelected ? null : Colors.grey[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isSelected ? Colors.transparent : Colors.grey[200]!),
              boxShadow: isSelected
                  ? [BoxShadow(color: AppTheme.primaryColor.withAlpha(60), blurRadius: 10, offset: const Offset(0, 4))]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 22, height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withAlpha(50) : AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Text('${i + 1}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                    const Spacer(),
                    Icon(LucideIcons.mapPin,
                        size: 13, color: isSelected ? Colors.white70 : AppTheme.accentColor),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  s['location_name'] ?? s['title'] ?? 'Điểm ${i + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 12,
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                    height: 1.3,
                  ),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                if (s['dist_km'] != null) ...[
                  const SizedBox(height: 4),
                  Text('${s['dist_km']} km',
                      style: TextStyle(
                          fontSize: 10, color: isSelected ? Colors.white70 : AppTheme.textSecondary)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ── AI tab (scrollable with sheet controller) ─────────────────────────────────

  Widget _buildAITab(ScrollController scrollCtrl) {
    if (_aiLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(height: 8),
            Text('AI đang phân tích lộ trình...', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [_buildAIContent(_aiText ?? _kFallbackAI)],
    );
  }

  Widget _buildAIContent(String text) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        // Strip ** trước
        final trimmed = line.trim().replaceAll('**', '');
        if (trimmed.isEmpty) return const SizedBox(height: 4);

        // Header ##
        if (trimmed.startsWith('## ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(trimmed.substring(3),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.3)),
          );
        }
        // Bullet: - • *
        if (RegExp(r'^[-•*]\s').hasMatch(trimmed)) {
          final content = trimmed.replaceFirst(RegExp(r'^[-•*]\s+'), '');
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 5, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(content,
                      style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.textSecondary)),
                ),
              ],
            ),
          );
        }
        // Normal
        return Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(trimmed,
              style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppTheme.textSecondary)),
        );
      }).toList(),
    );
  }
}
