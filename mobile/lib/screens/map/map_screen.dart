import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  List<Location> _locations = [];
  bool _isLoading = true;
  LatLng _currentPosition = const LatLng(AppConfig.defaultLatitude, AppConfig.defaultLongitude);
  bool _gotUserLocation = false;

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _gotUserLocation = true;
      });

      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition, 12));
    } catch (e) {
      // Fallback to default location
    }
  }

  Future<void> _loadLocations() async {
    try {
      final response = await _apiService.getLocations(limit: 100);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        setState(() {
          _locations = data.map((json) => Location.fromJson(json)).toList();
          _isLoading = false;
          _buildMarkers();
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _buildMarkers() {
    _markers.clear();

    // User location marker
    if (_gotUserLocation) {
      _markers.add(Marker(
        markerId: const MarkerId('user_location'),
        position: _currentPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Vị trí của bạn'),
      ));
    }

    // Location markers
    for (final loc in _locations) {
      if (loc.latitude != null && loc.longitude != null) {
        _markers.add(Marker(
          markerId: MarkerId('loc_${loc.id}'),
          position: LatLng(loc.latitude!, loc.longitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(_categoryHue(loc.category)),
          infoWindow: InfoWindow(
            title: loc.name,
            snippet: '${loc.categoryDisplay} • ⭐ ${loc.ratingAvg.toStringAsFixed(1)}',
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.locationDetail, arguments: loc);
            },
          ),
        ));
      }
    }
  }

  double _categoryHue(String category) {
    switch (category) {
      case 'beach': return BitmapDescriptor.hueCyan;
      case 'mountain': return BitmapDescriptor.hueGreen;
      case 'city': return BitmapDescriptor.hueViolet;
      case 'cultural': return BitmapDescriptor.hueOrange;
      case 'nature': return BitmapDescriptor.hueGreen;
      default: return BitmapDescriptor.hueRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bản đồ')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: AppConfig.defaultZoom,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),

          // Legend
          Positioned(
            bottom: 16,
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
                  _legendItem('Núi/Thiên nhiên', Colors.green),
                  _legendItem('Thành phố', Colors.purple),
                  _legendItem('Văn hóa', Colors.orange),
                ],
              ),
            ),
          ),

          // Current location button
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                if (_gotUserLocation) {
                  _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition, 14));
                } else {
                  _getCurrentLocation();
                }
              },
              child: const Icon(Icons.my_location, color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
