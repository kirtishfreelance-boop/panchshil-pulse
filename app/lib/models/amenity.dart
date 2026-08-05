class FacilityCategory {
  const FacilityCategory({
    required this.id,
    required this.name,
    this.icon,
    this.facType = 'bookable',
    this.facilityCount = 0,
  });

  final int id;
  final String name;
  final String? icon;
  final String facType;
  final int facilityCount;

  factory FacilityCategory.fromJson(Map<String, dynamic> json) => FacilityCategory(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
        icon: json['icon'] as String?,
        facType: json['fac_type'] as String? ?? 'bookable',
        facilityCount: (json['facility_count'] as num?)?.toInt() ?? 0,
      );
}

class Facility {
  const Facility({
    required this.id,
    required this.name,
    this.description,
    this.location,
    this.coverImage,
    this.categoryName,
    this.capacity = 0,
    this.opensAt = '06:00',
    this.closesAt = '22:00',
    this.slotMinutes = 60,
    this.pricePerSlot = 0,
    this.maxPerUser = 2,
    this.active = true,
  });

  final int id;
  final String name;
  final String? description;
  final String? location;
  final String? coverImage;
  final String? categoryName;
  final int capacity;
  final String opensAt;
  final String closesAt;
  final int slotMinutes;
  final double pricePerSlot;
  final int maxPerUser;
  final bool active;

  bool get isFree => pricePerSlot <= 0;

  /// "06:00:00" from the database reads better as "06:00".
  String get opensLabel => opensAt.length >= 5 ? opensAt.substring(0, 5) : opensAt;
  String get closesLabel => closesAt.length >= 5 ? closesAt.substring(0, 5) : closesAt;

  factory Facility.fromJson(Map<String, dynamic> json) => Facility(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        location: json['location'] as String?,
        coverImage: json['cover_image'] as String?,
        categoryName: json['category_name'] as String?,
        capacity: (json['capacity'] as num?)?.toInt() ?? 0,
        opensAt: json['opens_at'] as String? ?? '06:00',
        closesAt: json['closes_at'] as String? ?? '22:00',
        slotMinutes: (json['slot_minutes'] as num?)?.toInt() ?? 60,
        pricePerSlot: (json['price_per_slot'] as num?)?.toDouble() ?? 0,
        maxPerUser: (json['max_per_user'] as num?)?.toInt() ?? 2,
        active: json['active'] != false,
      );
}

class FacilitySlot {
  const FacilitySlot({
    required this.startsAt,
    required this.endsAt,
    required this.label,
    required this.available,
    this.mine = false,
    this.reason,
  });

  final DateTime startsAt;
  final DateTime endsAt;
  final String label;
  final bool available;
  final bool mine;
  final String? reason;

  factory FacilitySlot.fromJson(Map<String, dynamic> json) => FacilitySlot(
        startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
        endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
        label: json['label'] as String? ?? '',
        available: json['available'] == true,
        mine: json['mine'] == true,
        reason: json['reason'] as String?,
      );
}

class FacilityBooking {
  const FacilityBooking({
    required this.id,
    required this.facilityId,
    this.facilityName,
    this.facilityLocation,
    this.coverImage,
    required this.startsAt,
    required this.endsAt,
    this.status = 'confirmed',
    this.amountPaid = 0,
    this.notes,
    this.isPast = false,
  });

  final int id;
  final int facilityId;
  final String? facilityName;
  final String? facilityLocation;
  final String? coverImage;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  final double amountPaid;
  final String? notes;
  final bool isPast;

  bool get isCancellable => !isPast && status == 'confirmed';

  factory FacilityBooking.fromJson(Map<String, dynamic> json) => FacilityBooking(
        id: (json['id'] as num).toInt(),
        facilityId: (json['facility_id'] as num).toInt(),
        facilityName: json['facility_name'] as String?,
        facilityLocation: json['facility_location'] as String?,
        coverImage: json['cover_image'] as String?,
        startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
        endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
        status: json['status'] as String? ?? 'confirmed',
        amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0,
        notes: json['notes'] as String?,
        isPast: json['is_past'] == true,
      );
}
