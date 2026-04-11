import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../config/theme.dart';
import '../../config/app_config.dart';

/// Màn hình chọn toạ độ từ bản đồ.
/// Trả về Map<String, double> {'lat': ..., 'lng': ...} khi confirm.
class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late final MapController _mapController;
  late LatLng _pickedPoint;
  bool _hasLocation = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pickedPoint = LatLng(
      widget.initialLat ?? AppConfig.defaultLatitude,
      widget.initialLng ?? AppConfig.defaultLongitude,
    );
    if (widget.initialLat != null && widget.initialLng != null) {
      _hasLocation = true;
    }
    _tryGetCurrentLocation();
  }

  Future<void> _tryGetCurrentLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
      if (mounted && !_hasLocation) {
        setState(() {
          _pickedPoint = LatLng(pos.latitude, pos.longitude);
          _hasLocation = true;
        });
        _mapController.move(_pickedPoint, 13);
      }
    } catch (_) {}
  }

  void _onTap(TapPosition _, LatLng point) {
    setState(() {
      _pickedPoint = point;
      _hasLocation = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn vị trí'),
        actions: [
          if (_hasLocation)
            TextButton.icon(
              onPressed: () => Navigator.pop(context, {
                'lat': _pickedPoint.latitude,
                'lng': _pickedPoint.longitude,
              }),
              icon: const Icon(LucideIcons.check, size: 18),
              label: const Text('Xác nhận', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pickedPoint,
              initialZoom: widget.initialLat != null ? 14 : AppConfig.defaultZoom,
              onTap: _onTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.trawime',
              ),
              if (_hasLocation)
                MarkerLayer(markers: [
                  Marker(
                    point: _pickedPoint,
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withAlpha(80),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.place, color: Colors.white, size: 22),
                    ),
                  ),
                ]),
            ],
          ),

          // Instruction banner
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: Colors.black.withAlpha(130),
              child: const Text(
                'Nhấn vào bản đồ để chọn vị trí',
                style: TextStyle(color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Coordinate display
          if (_hasLocation)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.mapPin, size: 18, color: AppTheme.primaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Lat: ${_pickedPoint.latitude.toStringAsFixed(6)}\n'
                        'Lng: ${_pickedPoint.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, {
                        'lat': _pickedPoint.latitude,
                        'lng': _pickedPoint.longitude,
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Dùng vị trí này', style: TextStyle(fontWeight: FontWeight.w600)),
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
