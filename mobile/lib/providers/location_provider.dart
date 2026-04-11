import 'package:flutter/material.dart';
import '../models/location.dart';
import '../models/category.dart';
import '../services/api_service.dart';

class LocationProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<Location> _locations = [];
  List<Location> _featuredLocations = [];
  List<Category> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Location> get locations => _locations;
  List<Location> get featuredLocations => _featuredLocations;
  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchLocations({
    String? category,
    String? city,
    String? search,
    double? minRating,
    bool forceRefresh = false, // bỏ qua cache nếu cần reload ngay
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.getLocations(
        category: category,
        city: city,
        search: search,
        minRating: minRating,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _locations = data.map((json) => Location.fromJson(json)).toList();
      }
    } catch (e) {
      _errorMessage = 'Không thể tải danh sách địa điểm';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchFeaturedLocations() async {
    try {
      final response = await _apiService.getLocations(limit: 20);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final all = data.map((json) => Location.fromJson(json)).toList();
        // Sort by ratingAvg descending, pick top 10
        all.sort((a, b) => b.ratingAvg.compareTo(a.ratingAvg));
        _featuredLocations = all.take(10).toList();
        notifyListeners();
      }
    } catch (e) {
      // Silent fail for featured
    }
  }

  Future<void> fetchCategories() async {
    try {
      final response = await _apiService.getCategories();
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _categories = data.map((json) => Category.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      // Silent fail for categories
    }
  }

  Future<Location?> getLocationById(int id) async {
    try {
      final response = await _apiService.getLocation(id);
      if (response.statusCode == 200) {
        return Location.fromJson(response.data);
      }
    } catch (e) {
      _errorMessage = 'Không thể tải thông tin địa điểm';
    }
    return null;
  }
}
