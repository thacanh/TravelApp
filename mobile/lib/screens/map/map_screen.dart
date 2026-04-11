import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<Location> _locations = [];
  List<Location> _searchResults = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _showSearchResults = false;

  LatLng _currentPosition =
      LatLng(AppConfig.defaultLatitude, AppConfig.defaultLongitude);
  bool _gotUserLocation = false;

  // Routing state
  Location? _selectedDestination;
  List<LatLng> _routePoints = [];
  bool _loadingRoute = false;
  Map<String, dynamic>? _routeInfo;

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _checkAndRequestLocation();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Location permission ──────────────────────────────────────────────────────

  Future<void> _checkAndRequestLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) return;

      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );

      if (mounted && position != null) {
        setState(() {
          _currentPosition = LatLng(position!.latitude, position!.longitude);
          _gotUserLocation = true;
        });
        _mapController.move(_currentPosition, 12);
      }
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  // ── Load locations ───────────────────────────────────────────────────────────

  Future<void> _loadLocations() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final response = await _apiService.getLocations(limit: 100);
      debugPrint('MapScreen: status=${response.statusCode} count=${(response.data as List?)?.length}');
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = response.data;
        setState(() {
          _locations = data.map((json) => Location.fromJson(json)).toList();
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() { _isLoading = false; _hasError = true; });
      }
    } catch (e) {
      debugPrint('MapScreen: Load locations error: $e');
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  // ── Search ───────────────────────────────────────────────────────────────────

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() { _searchResults = []; _showSearchResults = false; });
      return;
    }
    final results = _locations.where((loc) {
      return loc.name.toLowerCase().contains(query) ||
          loc.city.toLowerCase().contains(query) ||
          loc.categories.any((c) => c.name.toLowerCase().contains(query));
    }).take(8).toList();

    setState(() { _searchResults = results; _showSearchResults = results.isNotEmpty; });
  }

  void _selectSearchResult(Location loc) {
    _searchController.text = loc.name;
    _searchFocus.unfocus();
    setState(() => _showSearchResults = false);
    if (loc.latitude != null && loc.longitude != null) {
      _mapController.move(LatLng(loc.latitude!, loc.longitude!), 15);
    }
    _setDestination(loc);
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _showSearchResults = false;
      _selectedDestination = null;
      _routePoints = [];
      _routeInfo = null;
    });
  }

  // ── Routing (OSRM — free, no API key) ────────────────────────────────────────

  Future<void> _setDestination(Location dest) async {
    if (dest.latitude == null || dest.longitude == null) return;
    setState(() {
      _selectedDestination = dest;
      _routePoints = [];
      _routeInfo = null;
    });
    if (!_gotUserLocation) return;

    setState(() => _loadingRoute = true);
    try {
      final origin = '${_currentPosition.longitude},${_currentPosition.latitude}';
      final destination = '${dest.longitude},${dest.latitude}';
      final url =
          'https://router.project-osrm.org/route/v1/driving/$origin;$destination?overview=full&geometries=geojson';

      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final coords = route['geometry']['coordinates'] as List;
          final points = coords
              .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
              .toList();
          final distM = (route['distance'] as num).toDouble();
          final durS = (route['duration'] as num).toDouble();

          if (mounted) {
            setState(() {
              _routePoints = points;
              _routeInfo = {
                'distance': _fmtDistance(distM),
                'duration': _fmtDuration(durS),
              };
            });
            _fitRoute();
          }
        }
      }
    } catch (e) {
      debugPrint('Route error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Không thể tính đường đi. Kiểm tra kết nối mạng.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  void _fitRoute() {
    if (_routePoints.isEmpty) return;
    final lats = _routePoints.map((p) => p.latitude).toList();
    final lngs = _routePoints.map((p) => p.longitude).toList();
    final sw = LatLng(
      lats.reduce((a, b) => a < b ? a : b) - 0.01,
      lngs.reduce((a, b) => a < b ? a : b) - 0.01,
    );
    final ne = LatLng(
      lats.reduce((a, b) => a > b ? a : b) + 0.01,
      lngs.reduce((a, b) => a > b ? a : b) + 0.01,
    );
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(sw, ne),
        padding: const EdgeInsets.fromLTRB(40, 40, 40, 220),
      ),
    );
  }

  String _fmtDistance(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.round()} m';

  String _fmtDuration(double s) {
    final min = (s / 60).round();
    if (min >= 60) {
      final h = min ~/ 60;
      final m = min % 60;
      return '${h}h${m > 0 ? ' ${m}p' : ''}';
    }
    return '$min phút';
  }

  Future<void> _openGoogleMaps() async {
    if (_selectedDestination == null) return;
    final lat = _selectedDestination!.latitude!;
    final lng = _selectedDestination!.longitude!;

    // Thử mở Google Maps app trước (geo: scheme)
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    // Fallback: mở web Google Maps
    final webUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        // Force launch bỏ qua canLaunchUrl check
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể mở Google Maps: $e')),
        );
      }
    }
  }

  // ── Markers ──────────────────────────────────────────────────────────────────

  Color _catColor(String slug) {
    switch (slug) {
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

    if (_gotUserLocation) {
      markers.add(Marker(
        point: _currentPosition,
        width: 36, height: 36,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue, shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [BoxShadow(color: Colors.blue.withAlpha(80), blurRadius: 10, spreadRadius: 3)],
          ),
          child: const Icon(Icons.my_location, color: Colors.white, size: 18),
        ),
      ));
    }

    for (final loc in _locations) {
      if (loc.latitude == null || loc.longitude == null) continue;
      final isSelected = _selectedDestination?.id == loc.id;
      final slug = loc.categories.isNotEmpty ? loc.categories.first.slug : '';
      final color = isSelected ? Colors.red : _catColor(slug);
      final size = isSelected ? 48.0 : 36.0;

      markers.add(Marker(
        point: LatLng(loc.latitude!, loc.longitude!),
        width: size, height: size,
        child: GestureDetector(
          onTap: () {
            if (isSelected) {
              Navigator.pushNamed(context, AppRoutes.locationDetail, arguments: loc);
            } else {
              _selectSearchResult(loc);
            }
          },
          child: Tooltip(
            message: loc.name,
            child: Container(
              decoration: BoxDecoration(
                color: color, shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
                boxShadow: [BoxShadow(
                    color: color.withAlpha(isSelected ? 140 : 60),
                    blurRadius: isSelected ? 12 : 6,
                    spreadRadius: isSelected ? 2 : 0,
                    offset: const Offset(0, 2))],
              ),
              child: Icon(
                isSelected ? Icons.flag_rounded : Icons.place,
                color: Colors.white,
                size: isSelected ? 24 : 18,
              ),
            ),
          ),
        ),
      ));
    }

    return markers;
  }

  Marker _vietMarker(LatLng point, String name) => Marker(
    point: point, width: 150, height: 36,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFDA251D),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🇻🇳', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Flexible(child: Text(name,
            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    ),
  );

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản đồ'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: _buildSearchBar(),
          ),
        ),
      ),
      body: Stack(
        children: [
          // ── Map ─────────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition,
              initialZoom: AppConfig.defaultZoom,
              minZoom: 5.0, maxZoom: 19.0,
              onTap: (_, __) {
                _searchFocus.unfocus();
                setState(() => _showSearchResults = false);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.trawime',
                maxZoom: 19,
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: const Color(0xFF4C6EF5),
                      strokeWidth: 5,
                    ),
                  ],
                ),
              MarkerLayer(markers: _buildMarkers()),
              MarkerLayer(markers: [
                _vietMarker(LatLng(16.467, 112.0), 'Quần đảo Hoàng Sa'),
                _vietMarker(LatLng(9.9, 114.3), 'Quần đảo Trường Sa'),
              ]),
            ],
          ),

          // ── Loading ──────────────────────────────────────────────────────────
          if (_isLoading)
            Container(
              color: Colors.white.withAlpha(160),
              child: const Center(child: CircularProgressIndicator()),
            ),

          // ── Error + Retry ───────────────────────────────────────────────────
          if (_hasError && !_isLoading)
            Positioned(
              top: 12, left: 16, right: 16,
              child: Material(
                borderRadius: BorderRadius.circular(12),
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.red, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Không tải được địa điểm',
                          style: TextStyle(fontSize: 13, color: Colors.red))),
                      TextButton(onPressed: _loadLocations, child: const Text('Thử lại')),
                    ],
                  ),
                ),
              ),
            ),

          // ── Search dropdown ───────────────────────────────────────────────────
          if (_showSearchResults && _searchResults.isNotEmpty)
            Positioned(
              top: 6, left: 12, right: 12,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    children: _searchResults.map((loc) => InkWell(
                      onTap: () => _selectSearchResult(loc),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withAlpha(20),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.place, color: AppTheme.primaryColor, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(loc.name,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(loc.city,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                ],
                              ),
                            ),
                            const Icon(Icons.directions, color: AppTheme.primaryColor, size: 18),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              ),
            ),

          // ── Route info card ───────────────────────────────────────────────────
          if (_selectedDestination != null)
            Positioned(
              bottom: 70, left: 12, right: 12,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.flag_rounded, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_selectedDestination!.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          InkWell(onTap: _clearSearch,
                              child: const Icon(Icons.close, size: 18, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(_selectedDestination!.city,
                          style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      if (_loadingRoute) ...[
                        const SizedBox(height: 10),
                        const Row(children: [
                          SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 10),
                          Text('Đang tính đường đi...', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        ]),
                      ] else if (_routeInfo != null) ...[
                        const SizedBox(height: 10),
                        Row(children: [
                          _chip(Icons.directions_car, _routeInfo!['distance'], Colors.blue),
                          const SizedBox(width: 8),
                          _chip(Icons.access_time, _routeInfo!['duration'], Colors.orange),
                        ]),
                      ] else if (!_gotUserLocation) ...[
                        const SizedBox(height: 6),
                        const Text('Bật vị trí để xem đường đi',
                            style: TextStyle(fontSize: 12, color: Colors.orange)),
                      ],
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(
                                context, AppRoutes.locationDetail, arguments: _selectedDestination),
                            icon: const Icon(Icons.info_outline, size: 16),
                            label: const Text('Chi tiết'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: const BorderSide(color: AppTheme.primaryColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _selectedDestination!.latitude != null ? _openGoogleMaps : null,
                            icon: const Icon(Icons.navigation_rounded, size: 16, color: Colors.white),
                            label: const Text('Google Maps', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),

          // ── My location FAB ───────────────────────────────────────────────────
          Positioned(
            bottom: 16, right: 12,
            child: FloatingActionButton.small(
              heroTag: 'my_location',
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

          // Copyright
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              color: Colors.white.withAlpha(180),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: const Text('© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 9, color: Colors.black54)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search, color: Colors.grey[400], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              decoration: InputDecoration(
                hintText: 'Tìm địa điểm để chỉ đường...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 14),
              textInputAction: TextInputAction.search,
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: _clearSearch,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.close, size: 18, color: Colors.grey[400]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
