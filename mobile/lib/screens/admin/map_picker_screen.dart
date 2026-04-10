import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../config/theme.dart';

/// Màn hình chọn tọa độ trên bản đồ.
/// Trả về [LatLng] khi người dùng xác nhận, hoặc null nếu hủy.
class MapPickerScreen extends StatefulWidget {
  /// Tọa độ ban đầu (nếu đã có sẵn khi mở)
  final LatLng? initialLatLng;

  const MapPickerScreen({super.key, this.initialLatLng});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  LatLng? _picked;
  bool _locating = false;

  // Mặc định: Hà Nội
  static const _defaultCenter = LatLng(21.0285, 105.8542);

  @override
  void initState() {
    super.initState();
    _picked = widget.initialLatLng;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _locating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Vui lòng bật GPS trên thiết bị');
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        _showSnack('Ứng dụng chưa được cấp quyền vị trí');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() => _picked = latLng);
      _mapController.move(latLng, 15);
    } catch (e) {
      _showSnack('Không lấy được vị trí: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.initialLatLng ?? _defaultCenter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn vị trí trên bản đồ'),
        actions: [
          if (_picked != null)
            TextButton.icon(
              onPressed: () => Navigator.pop(context, _picked),
              icon: const Icon(LucideIcons.check, size: 18, color: Colors.white),
              label: const Text('Xác nhận', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13,
              onTap: (_, latLng) => setState(() => _picked = latLng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.trawime.app',
              ),
              if (_picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _picked!,
                      width: 48,
                      height: 56,
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
                            ),
                            child: const Icon(LucideIcons.mapPin, color: Colors.white, size: 20),
                          ),
                          CustomPaint(
                            size: const Size(12, 8),
                            painter: _TrianglePainter(AppTheme.primaryColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ── Hint banner ──────────────────────────────────────────────
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(160),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.hand, color: Colors.white70, size: 16),
                  SizedBox(width: 8),
                  Text('Nhấn vào bản đồ để đặt ghim vị trí', style: TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
          ),

          // ── Coordinates chip ─────────────────────────────────────────
          if (_picked != null)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppTheme.softShadow,
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.locateFixed, color: AppTheme.primaryColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vĩ độ: ${_picked!.latitude.toStringAsFixed(6)}\nKinh độ: ${_picked!.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 13, height: 1.5, fontWeight: FontWeight.w500),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 16, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _picked = null),
                      tooltip: 'Bỏ ghim',
                    ),
                  ],
                ),
              ),
            ),

          // ── My location button ───────────────────────────────────────
          Positioned(
            bottom: 24,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  onPressed: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, zoom + 1);
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  onPressed: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, zoom - 1);
                  },
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'my_location',
                  backgroundColor: AppTheme.primaryColor,
                  onPressed: _locating ? null : _goToCurrentLocation,
                  child: _locating
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.my_location, color: Colors.white),
                ),
              ],
            ),
          ),

          // ── Confirm bottom button ────────────────────────────────────
          if (_picked != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 90,
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, _picked),
                  icon: const Icon(LucideIcons.check, size: 18),
                  label: const Text('Dùng vị trí này', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tam giác nhỏ dưới pin marker
class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
