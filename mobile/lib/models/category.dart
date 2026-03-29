class Category {
  final int id;
  final String slug;
  final String name;
  final String? icon;

  Category({
    required this.id,
    required this.slug,
    required this.name,
    this.icon,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      slug: json['slug'],
      name: json['name'],
      icon: json['icon'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'name': name,
      'icon': icon,
    };
  }
}
