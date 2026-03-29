import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  
  late Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    // Add interceptor for auth token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        return handler.next(error);
      },
    ));
  }
  
  // Token Management
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'access_token', value: token);
  }
  
  Future<String?> getToken() async {
    return await _storage.read(key: 'access_token');
  }
  
  Future<void> clearToken() async {
    await _storage.delete(key: 'access_token');
  }
  
  // Auth APIs
  Future<Response> register(Map<String, dynamic> data) async {
    return await _dio.post('/api/auth/register', data: data);
  }
  
  Future<Response> login(String email, String password) async {
    final formData = FormData.fromMap({
      'username': email,
      'password': password,
    });
    return await _dio.post('/api/auth/login', data: formData);
  }
  
  Future<Response> getCurrentUser() async {
    return await _dio.get('/api/auth/me');
  }
  
  // Category APIs
  Future<Response> getCategories() async {
    return await _dio.get('/api/categories');
  }
  
  // Location APIs
  Future<Response> getLocations({
    int skip = 0,
    int limit = 20,
    String? category,
    String? city,
    String? search,
    double? minRating,
  }) async {
    final queryParams = <String, dynamic>{
      'skip': skip,
      'limit': limit,
    };
    if (category != null) queryParams['category'] = category;
    if (city != null) queryParams['city'] = city;
    if (search != null) queryParams['search'] = search;
    if (minRating != null) queryParams['min_rating'] = minRating;
    
    return await _dio.get('/api/locations', queryParameters: queryParams);
  }
  
  Future<Response> getLocation(int id) async {
    return await _dio.get('/api/locations/$id');
  }
  
  Future<Response> getNearbyLocations(double lat, double lon, {double radius = 50}) async {
    return await _dio.get('/api/locations/nearby', queryParameters: {
      'latitude': lat,
      'longitude': lon,
      'radius_km': radius,
    });
  }
  
  // Check-in APIs
  Future<Response> createCheckin(Map<String, dynamic> data) async {
    return await _dio.post('/api/checkins', data: data);
  }
  
  Future<Response> uploadCheckinPhotos(List<String> filePaths) async {
    final formData = FormData();
    for (var path in filePaths) {
      formData.files.add(MapEntry(
        'files',
        await MultipartFile.fromFile(path),
      ));
    }
    return await _dio.post('/api/checkins/upload-photos', data: formData);
  }
  
  Future<Response> getMyCheckins({int skip = 0, int limit = 20}) async {
    return await _dio.get('/api/checkins', queryParameters: {
      'skip': skip,
      'limit': limit,
    });
  }
  
  // Review APIs
  Future<Response> createReview(Map<String, dynamic> data) async {
    return await _dio.post('/api/reviews', data: data);
  }

  Future<Response> uploadReviewPhotos(List<String> filePaths) async {
    final formData = FormData();
    for (var path in filePaths) {
      formData.files.add(MapEntry(
        'files',
        await MultipartFile.fromFile(path),
      ));
    }
    return await _dio.post('/api/reviews/upload-photos', data: formData);
  }
  
  Future<Response> getLocationReviews(int locationId) async {
    return await _dio.get('/api/reviews/location/$locationId');
  }
  
  // Itinerary APIs
  Future<Response> getItineraries() async {
    return await _dio.get('/api/itineraries');
  }
  
  Future<Response> createItinerary(Map<String, dynamic> data) async {
    return await _dio.post('/api/itineraries', data: data);
  }
  
  Future<Response> updateItinerary(int id, Map<String, dynamic> data) async {
    return await _dio.put('/api/itineraries/$id', data: data);
  }
  
  Future<Response> deleteItinerary(int id) async {
    return await _dio.delete('/api/itineraries/$id');
  }

  // Generic helpers (for nested routes like days and activities)
  Future<Response> post(String path, Map<String, dynamic> data) async {
    return await _dio.post(path, data: data);
  }

  Future<Response> put(String path, Map<String, dynamic> data) async {
    return await _dio.put(path, data: data);
  }

  Future<Response> delete(String path) async {
    return await _dio.delete(path);
  }

  // AI Chat Session APIs
  Future<Response> getChatSessions() async {
    return await _dio.get('/api/chat/sessions');
  }

  Future<Response> getChatSession(int sessionId) async {
    return await _dio.get('/api/chat/sessions/$sessionId');
  }

  Future<Response> sendChatMessage({int? sessionId, required String message}) async {
    return await _dio.post('/api/chat/send', data: {
      'session_id': sessionId,
      'message': message,
    });
  }

  Future<Response> deleteChatSession(int sessionId) async {
    return await _dio.delete('/api/chat/sessions/$sessionId');
  }

  // User Profile APIs
  Future<Response> updateProfile(Map<String, dynamic> data) async {
    return await _dio.put('/api/users/profile', data: data);
  }

  Future<Response> uploadAvatar(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    return await _dio.post('/api/users/avatar', data: formData);
  }

  Future<Response> changePassword(String currentPassword, String newPassword) async {
    return await _dio.put('/api/users/change-password', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  // AI APIs
  Future<Response> getAIRecommendations(Map<String, dynamic> data) async {
    return await _dio.post('/api/ai/recommend', data: data);
  }
  
  Future<Response> chatWithAI(String message, {Map<String, dynamic>? context}) async {
    return await _dio.post('/api/ai/chat', data: {
      'message': message,
      'context': context,
    });
  }

  // Admin APIs
  Future<Response> getAdminStats() async {
    return await _dio.get('/api/admin/stats');
  }

  Future<Response> getAdminUsers({String? search, int skip = 0, int limit = 50}) async {
    final params = <String, dynamic>{'skip': skip, 'limit': limit};
    if (search != null) params['search'] = search;
    return await _dio.get('/api/admin/users', queryParameters: params);
  }

  Future<Response> toggleUserActive(int userId) async {
    return await _dio.put('/api/admin/users/$userId/toggle-active');
  }

  Future<Response> getAdminReviews({int skip = 0, int limit = 50}) async {
    return await _dio.get('/api/admin/reviews', queryParameters: {
      'skip': skip,
      'limit': limit,
    });
  }

  Future<Response> deleteAdminReview(int reviewId) async {
    return await _dio.delete('/api/admin/reviews/$reviewId');
  }
}
