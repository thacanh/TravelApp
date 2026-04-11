import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // ------------------------------------------------------------------
  // Đọc từ .env — chỉ cần sửa .env là áp dụng toàn app
  // ------------------------------------------------------------------
  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'http://192.168.100.222:8000';

  static String get appName =>
      dotenv.env['APP_NAME'] ?? 'TRAWIME';

  // ------------------------------------------------------------------
  // Timeouts
  // ------------------------------------------------------------------
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ------------------------------------------------------------------
  // Pagination
  // ------------------------------------------------------------------
  static const int defaultPageSize = 20;

  // ------------------------------------------------------------------
  // File Upload
  // ------------------------------------------------------------------
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const List<String> allowedImageExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  // ------------------------------------------------------------------
  // Map Configuration — dùng OpenStreetMap (không cần API key)
  // ------------------------------------------------------------------
  static const double defaultLatitude = 16.0544;   // Huế
  static const double defaultLongitude = 108.2022; // Huế
  static const double defaultZoom = 6.0;
}
