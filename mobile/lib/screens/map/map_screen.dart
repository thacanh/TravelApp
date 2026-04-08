import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../config/theme.dart';
import '../../config/app_config.dart';
import '../../config/routes.dart';
import '../../services/api_service.dart';
import '../../models/location.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();

  List<Location> _locations = [];
  bool _isLoading = true;
  LatLng _currentPosition = LatLng(AppConfig.defaultLatitude, AppConfig.defaultLongitude);
  bool _gotUserLocation = false;

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _checkAndRequestLocation();
  }

  Future<void> _checkAndRequestLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _gotUserLocation = true;
        });
        _mapController.move(_currentPosition, 12);
      }
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  Future<void> _loadLocations() async {
    try {
      final response = await _apiService.getLocations(limit: 100);
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = response.data;
        setState(() {
          _locations = data.map((json) => Location.fromJson(json)).toList();
          _isLoading = false;
        });
      } else if (mounted) {
        // API trả về status khác 200 — vẫn cần unlock loading
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Load locations error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'beach': return Colors.cyan;
      case 'mountain': return Colors.green;
      case 'city': return const Color(0xFF9C27B0);
      case 'cultural': return Colors.orange;
      case 'nature': return Colors.teal;
      default: return AppTheme.primaryColor;
    }
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // User location marker
    if (_gotUserLocation) {
      markers.add(Marker(
        point: _currentPosition,
        width: 36,
        height: 36,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [BoxShadow(color: Colors.blue.withAlpha(80), blurRadius: 10, spreadRadius: 3)],
          ),
          child: const Icon(Icons.my_location, color: Colors.white, size: 18),
        ),
      ));
    }

    // Location markers
    for (final loc in _locations) {
      if (loc.latitude != null && loc.longitude != null) {
        final color = _categoryColor(loc.category);
        markers.add(Marker(
          point: LatLng(loc.latitude!, loc.longitude!),
          width: 36,
          height: 36,
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.locationDetail, arguments: loc),
            child: Tooltip(
              message: loc.name,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: const Icon(Icons.place, color: Colors.white, size: 18),
              ),
            ),
          ),
        ));
      }
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bản đồ')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition,
              initialZoom: AppConfig.defaultZoom,
              minZoom: 5.0,   // giới hạn zoom out trong phạm vi tile.openstreetmap.vn
              maxZoom: 19.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // OpenStreetMap tiles
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.trawime',
                maxZoom: 19,
              ),
              // Location markers
              MarkerLayer(markers: _buildMarkers()),
              // ✨ Vietnamese sovereignty overlay — hiển thị tên tiếng Việt cho Hoàng Sa/Trường Sa
              // Đặt sau MarkerLayer để render trên top của mọi thứ
              MarkerLayer(
                markers: [
                  _vietnamTerritoryMarker(
                    LatLng(16.467, 112.0),
                    'Quần đảo Hoàng Sa',
                  ),
                  _vietnamTerritoryMarker(
                    LatLng(9.9, 114.3),
                    'Quần đảo Trường Sa',
                  ),
                ],
              ),
            ],
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.white.withAlpha(160),
              child: const Center(child: CircularProgressIndicator()),
            ),

          // Legend
          Positioned(
            bottom: 80,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Chú thích', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  _legendItem('Bãi biển', Colors.cyan),
                  _legendItem('Núi/Thiên nhiên', Colors.teal),
                  _legendItem('Thành phố', const Color(0xFF9C27B0)),
                  _legendItem('Văn hóa', Colors.orange),
                ],
              ),
            ),
          ),

          // Location button
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                if (_gotUserLocation) {
                  _mapController.move(_currentPosition, 14);
                } else {
                  _checkAndRequestLocation();
                }
              },
              child: const Icon(Icons.my_location, color: AppTheme.primaryColor),
            ),
          ),

          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              color: Colors.white.withAlpha(180),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: const Text(
                '© OpenStreetMap Việt Nam (openstreetmap.vn)',
                style: TextStyle(fontSize: 9, color: Colors.black54),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Marker chủ quyền VN — đè lên tên Trung Quốc từ OSM tiles
  Marker _vietnamTerritoryMarker(LatLng point, String name) {
    return Marker(
      point: point,
      width: 150,
      height: 36,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFDA251D), // màu đỏ cờ Việt Nam
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🇻🇳', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
