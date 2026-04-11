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

class _ItineraryRouteMapScreenState extends State<ItineraryRouteMapScreen> {
  final MapController _mapController = MapController();
  LatLng? _userPosition;
  List<Map<String, dynamic>> _sortedStops = [];
  List<LatLng> _routePoints = [];
  bool _isLoading = true;
  late ItineraryRouteArgs _args;
  bool _argsLoaded = false;

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
          timeLimit: const Duration(seconds: 5), // Added timeout to prevent emulator hang
        );
        _userPosition = LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {
      debugPrint("Lỗi lấy vị trí (hoặc timeout trên máy ảo), dùng vị trí mặc định");
    }
    _userPosition ??= LatLng(AppConfig.defaultLatitude, AppConfig.defaultLongitude);

    // 2. Sort stops by nearest-neighbor from user position
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
          (nearest['location_lat'] as num).toDouble(),
          (nearest['location_lng'] as num).toDouble());
      sorted.add({...nearest, 'dist_km': dist.toStringAsFixed(1)});
      lat = (nearest['location_lat'] as num).toDouble();
      lng = (nearest['location_lng'] as num).toDouble();
    }
    _sortedStops = sorted;

    // 3. Fetch OSRM route (free, no API key — same as Leaflet example)
    if (sorted.isNotEmpty) {
      _routePoints = await _fetchOSRMRoute();
    }

    // If OSRM failed, draw straight lines
    if (_routePoints.isEmpty && sorted.isNotEmpty) {
      _routePoints = [
        _userPosition!,
        ...sorted.map((s) => LatLng(
          (s['location_lat'] as num).toDouble(),
          (s['location_lng'] as num).toDouble(),
        )),
      ];
    }

    if (mounted) {
      setState(() => _isLoading = false);
      // Fit camera to show all stops
      if (_routePoints.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
      }
    }
  }

  /// Fetch road route using OSRM — free, no API key needed.
  Future<List<LatLng>> _fetchOSRMRoute() async {
    if (_sortedStops.isEmpty) return [];
    try {
      final waypoints = [
        '${_userPosition!.longitude},${_userPosition!.latitude}',
        ..._sortedStops.map((s) =>
          '${(s['location_lng'] as num).toDouble()},${(s['location_lat'] as num).toDouble()}'),
      ];
      final coords = waypoints.join(';');
      final url = 'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final coords = data['routes'][0]['geometry']['coordinates'] as List;
          // GeoJSON is [lng, lat] → convert to LatLng [lat, lng]
          return coords.map<LatLng>((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
        }
      }
    } catch (e) {
      debugPrint('OSRM error: $e — using straight line fallback');
    }
    return [];
  }

  void _fitBounds() {
    if (_routePoints.isEmpty) return;
    final lats = _routePoints.map((p) => p.latitude).toList();
    final lngs = _routePoints.map((p) => p.longitude).toList();
    final bounds = LatLngBounds(
      LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
      LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
    );
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)));
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

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // User marker
    if (_userPosition != null) {
      markers.add(Marker(
        point: _userPosition!,
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [BoxShadow(color: Colors.blue.withAlpha(80), blurRadius: 10, spreadRadius: 2)],
          ),
          child: const Icon(Icons.my_location, color: Colors.white, size: 20),
        ),
      ));
    }

    // Stop markers  
    for (int i = 0; i < _sortedStops.length; i++) {
      final s = _sortedStops[i];
      markers.add(Marker(
        point: LatLng(
          (s['location_lat'] as num).toDouble(),
          (s['location_lng'] as num).toDouble(),
        ),
        width: 36,
        height: 36,
        child: GestureDetector(
          onTap: () {
            // Show info on tap
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
                    if ((s['start_time'] as String?) != null)
                      Text('🕐 ${s['start_time']}'),
                  ],
                ),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))],
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Center(
              child: Text(
                '${i + 1}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
        ),
      ));
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          // Map with OpenStreetMap tiles
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userPosition ?? LatLng(AppConfig.defaultLatitude, AppConfig.defaultLongitude),
              initialZoom: 12,
            ),
            children: [
              // OpenStreetMap — tile đã xác nhận hoạt động tốt
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.trawime',
                maxZoom: 19,
              ),
              // Route polyline (from OSRM)
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5,
                      color: AppTheme.primaryColor,
                      borderStrokeWidth: 2,
                      borderColor: Colors.white,
                    ),
                  ],
                ),
              // Markers
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
                        Text('Đang tính toán lộ trình...'),
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text('${_sortedStops.length} điểm dừng · lộ trình tối ưu (OSRM)',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.locateFixed, size: 20),
                      onPressed: () {
                        if (_userPosition != null) {
                          _mapController.move(_userPosition!, 14);
                        }
                      },
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

          // Bottom stop list panel
          if (!_isLoading && _sortedStops.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 20, offset: const Offset(0, -4))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.navigation, size: 18, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          const Text('Lộ trình tối ưu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          const Spacer(),
                          Text('${_sortedStops.length} điểm',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        itemCount: _sortedStops.length,
                        itemBuilder: (ctx, i) {
                          final s = _sortedStops[i];
                          return GestureDetector(
                            onTap: () => _mapController.move(
                              LatLng(
                                (s['location_lat'] as num).toDouble(),
                                (s['location_lng'] as num).toDouble(),
                              ),
                              15,
                            ),
                            child: Container(
                              width: 160,
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: i == 0 ? AppTheme.primaryGradient : null,
                                color: i == 0 ? null : Colors.grey[50],
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: i == 0 ? Colors.transparent : Colors.grey[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 24, height: 24,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: i == 0 ? Colors.white.withAlpha(50) : AppTheme.primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text('${i + 1}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                                      ),
                                      const Spacer(),
                                      Icon(LucideIcons.mapPin,
                                          size: 14, color: i == 0 ? Colors.white70 : AppTheme.accentColor),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    s['location_name'] ?? s['title'] ?? 'Điểm ${i + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 13,
                                      color: i == 0 ? Colors.white : AppTheme.textPrimary,
                                    ),
                                    maxLines: 2, overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  if (s['dist_km'] != null)
                                    Text(
                                      '${s['dist_km']} km',
                                      style: TextStyle(fontSize: 11, color: i == 0 ? Colors.white70 : AppTheme.textSecondary),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
