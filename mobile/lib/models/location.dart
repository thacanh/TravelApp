import 'category.dart';

class Location {
  final int id;
  final String name;
  final String? description;
  final String category;
  final List<Category> categories;
  final String? address;
  final String city;
  final String country;
  final double? latitude;
  final double? longitude;
  final double ratingAvg;
  final int totalReviews;
  final List<String> images;
  final DateTime createdAt;

  Location({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    this.categories = const [],
    this.address,
    required this.city,
    required this.country,
    this.latitude,
    this.longitude,
    required this.ratingAvg,
    required this.totalReviews,
    required this.images,
    required this.createdAt,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      category: json['category'],
      categories: json['categories'] != null 
          ? (json['categories'] as List).map((c) => Category.fromJson(c)).toList()
          : [],
      address: json['address'],
      city: json['city'],
      country: json['country'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      ratingAvg: (json['rating_avg'] ?? 0).toDouble(),
      totalReviews: json['total_reviews'] ?? 0,
      images: List<String>.from(json['images'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'categories': categories.map((c) => c.toJson()).toList(),
      'address': address,
      'city': city,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'rating_avg': ratingAvg,
      'total_reviews': totalReviews,
      'images': images,
      'created_at': createdAt.toIso8601String(),
    };
  }
  
  String get categoryDisplay {
    switch (category) {
      case 'beach':
        return 'Bãi biển';
      case 'mountain':
        return 'Núi';
      case 'city':
        return 'Thành phố';
      case 'cultural':
        return 'Văn hóa';
      case 'nature':
        return 'Thiên nhiên';
      default:
        return category;
    }
  }
}
