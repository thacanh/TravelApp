import 'category.dart';

class Location {
  final int id;
  final String name;
  final String? description;
  final List<Category> categories;
  final String? address;
  final String city;
  final String country;
  final double? latitude;
  final double? longitude;
  final double ratingAvg;     // Computed from reviews table (returned by API)
  final int totalReviews;     // Computed from reviews table (returned by API)
  final List<String> images;
  final String? thumbnail;   // Ảnh đại diện; fallback = images[0]
  final DateTime createdAt;

  Location({
    required this.id,
    required this.name,
    this.description,
    this.categories = const [],
    this.address,
    required this.city,
    required this.country,
    this.latitude,
    this.longitude,
    this.ratingAvg = 0.0,
    this.totalReviews = 0,
    required this.images,
    this.thumbnail,
    required this.createdAt,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      categories: json['categories'] != null
          ? (json['categories'] as List).map((c) => Category.fromJson(c)).toList()
          : [],
      address: json['address'],
      city: json['city'],
      country: json['country'] ?? 'Vietnam',
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      ratingAvg: (json['rating_avg'] as num? ?? 0).toDouble(),
      totalReviews: (json['total_reviews'] as num? ?? 0).toInt(),
      images: List<String>.from(json['images'] ?? []),
      thumbnail: json['thumbnail'] as String?,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'categories': categories.map((c) => c.toJson()).toList(),
      'address': address,
      'city': city,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'rating_avg': ratingAvg,
      'total_reviews': totalReviews,
      'images': images,
      'thumbnail': thumbnail,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Effective thumbnail: explicit pick hoặc fallback images[0].
  String? get effectiveThumbnail => thumbnail ?? (images.isNotEmpty ? images.first : null);

  @override
  bool operator ==(Object other) => other is Location && other.id == id;

  @override
  int get hashCode => id.hashCode;

  /// Returns human-readable category label (lấy từ danh sách categories N-N).
  String get categoryDisplay {
    if (categories.isNotEmpty) {
      return categories.map((c) => c.name).join(', ');
    }
    return 'Khác'; // Fallback khi chưa có category
  }

  /// Formatted rating string, e.g. "4.5" or "Chưa có".
  String get ratingDisplay =>
      totalReviews > 0 ? ratingAvg.toStringAsFixed(1) : 'Chưa có';
}
