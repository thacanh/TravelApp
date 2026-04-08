class AppConfig {
  // API Configuration
  // static const String baseUrl = "http://10.0.2.2:8000";
  static const String baseUrl = "http://192.168.100.222:8000";
  // static const String baseUrl = "https://api.trawime.com"; // Production
  
  static const String apiVersion = "v1";
  
  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // Pagination
  static const int defaultPageSize = 20;
  
  // File Upload
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const List<String> allowedImageExtensions = ['jpg', 'jpeg', 'png', 'webp'];
  
  // Map Configuration — dùng OpenStreetMap (không cần API key)
  // static const String googleMapsApiKey = "AIzaSyAeL1u1vsE8MzDseh9JeGdEJFAEkN5VWSk"; // deprecated
  
  // Default Location (Trung tâm Việt Nam)
  static const double defaultLatitude = 16.0544;   // Huế
  static const double defaultLongitude = 108.2022;  // Huế
  static const double defaultZoom = 6.0; // zoom 6 — xem được toàn Việt Nam
}
