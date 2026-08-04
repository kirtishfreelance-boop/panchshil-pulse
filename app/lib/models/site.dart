class Site {
  const Site({
    required this.id,
    required this.name,
    this.city,
    this.address,
    this.logoUrl,
    this.active = true,
  });

  final int id;
  final String name;
  final String? city;
  final String? address;
  final String? logoUrl;
  final bool active;

  factory Site.fromJson(Map<String, dynamic> json) => Site(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? 'Site',
        city: json['city'] as String?,
        address: json['address'] as String?,
        logoUrl: json['logo_url'] as String?,
        active: json['active'] != false,
      );
}

class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.name,
    this.icon,
    this.route,
    this.serviceTag,
    this.position = 0,
  });

  final int id;
  final String name;
  final String? icon;
  final String? route;
  final String? serviceTag;
  final int position;

  factory ServiceCategory.fromJson(Map<String, dynamic> json) => ServiceCategory(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
        icon: json['icon'] as String?,
        route: json['route'] as String?,
        serviceTag: json['service_tag'] as String?,
        position: (json['position'] as num?)?.toInt() ?? 0,
      );
}
