import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../models/location.dart';
import '../../providers/location_provider.dart';
import '../locations/widgets/location_card.dart';

class FavoriteLocationsScreen extends StatefulWidget {
  const FavoriteLocationsScreen({super.key});

  @override
  State<FavoriteLocationsScreen> createState() => _FavoriteLocationsScreenState();
}

class _FavoriteLocationsScreenState extends State<FavoriteLocationsScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<Location> _favoriteLocations = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getFavorites();
      if (res.statusCode == 200) {
        final locationIds = List<int>.from(res.data);
        if (locationIds.isEmpty) {
          if (mounted) setState(() { _favoriteLocations = []; _isLoading = false; });
          return;
        }

        // Tạm thời lấy danh sách địa điểm từ API để map với ID. 
        // Trong hệ thống lớn nên gọi 1 API trả về list Locations theo mảng ID.
        // Ở đây lấy thủ công
        final locationProvider = Provider.of<LocationProvider>(context, listen: false);
        // Ensure locations are loaded, maybe fetch if empty
        if (locationProvider.locations.isEmpty) {
          await locationProvider.fetchLocations();
        }
        
        final favLocs = <Location>[];
        for (final id in locationIds) {
          final loc = locationProvider.locations.where((l) => l.id == id).firstOrNull;
          if (loc != null) {
            favLocs.add(loc);
          } else {
             // Fetch from network if not in provider cache
             try {
                final locRes = await _api.getLocation(id);
                if (locRes.statusCode == 200) {
                  favLocs.add(Location.fromJson(locRes.data));
                }
             } catch (_) {}
          }
        }
       
        if (mounted) {
          setState(() {
            _favoriteLocations = favLocs;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Địa điểm Yêu thích'),
        backgroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favoriteLocations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.heart, size: 40, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Bạn chưa có địa điểm yêu thích nào',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Hãy thả tim ở trang chi tiết địa điểm nhé!',
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _favoriteLocations.length,
                  itemBuilder: (context, index) {
                    final loc = _favoriteLocations[index];
                    return LocationCard(
                      location: loc,
                      onTap: () {
                        Navigator.pushNamed(context, '/location-detail', arguments: loc)
                          .then((_) => _loadFavorites()); // Reload when coming back
                      },
                    );
                  },
                ),
    );
  }
}
