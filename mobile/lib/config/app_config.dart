class AppConfig {
  // API Configuration
  static const String baseUrl = "http://192.168.100.222:8000"; // Local network
  // static const String baseUrl = "http://10.0.2.2:8000"; // Android emulator
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
  
  // Map Configuration (Replace with your own API key)
  static const String googleMapsApiKey = "AIzaSyAeL1u1vsE8MzDseh9JeGdEJFAEkN5VWSk";
  
  // Default Location (Vietnam)
  static const double defaultLatitude = 16.0544;
  static const double defaultLongitude = 108.2022;
  static const double defaultZoom = 6.0;
}
