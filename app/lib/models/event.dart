class EventRegistration {
  const EventRegistration({
    required this.id,
    this.guests = 0,
    this.amountPaid = 0,
    this.paymentStatus = 'pending',
    required this.ticketCode,
    this.attended = false,
    this.attendedAt,
  });

  final int id;
  final int guests;
  final double amountPaid;
  final String paymentStatus;
  final String ticketCode;
  final bool attended;
  final DateTime? attendedAt;

  factory EventRegistration.fromJson(Map<String, dynamic> json) => EventRegistration(
        id: (json['id'] as num).toInt(),
        guests: (json['guests'] as num?)?.toInt() ?? 0,
        amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0,
        paymentStatus: json['payment_status'] as String? ?? 'pending',
        ticketCode: json['ticket_code'] as String? ?? '',
        attended: json['attended'] == true,
        attendedAt: DateTime.tryParse(json['attended_at'] as String? ?? ''),
      );
}

class EventCategory {
  const EventCategory({required this.id, required this.name});

  final int id;
  final String name;

  factory EventCategory.fromJson(Map<String, dynamic> json) => EventCategory(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
      );
}

class Event {
  const Event({
    required this.id,
    required this.title,
    this.description,
    this.venue,
    this.coverImage,
    required this.startsAt,
    this.endsAt,
    this.categoryId,
    this.categoryName,
    this.isPaid = false,
    this.amount = 0,
    this.capacity = 0,
    this.seatsTaken = 0,
    this.seatsLeft,
    this.isPast = false,
    this.registration,
    this.inCalendar = false,
  });

  final int id;
  final String title;
  final String? description;
  final String? venue;
  final String? coverImage;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int? categoryId;
  final String? categoryName;
  final bool isPaid;
  final double amount;
  final int capacity;
  final int seatsTaken;
  final int? seatsLeft;
  final bool isPast;
  final EventRegistration? registration;
  final bool inCalendar;

  bool get isRegistered => registration != null;
  bool get isSoldOut => seatsLeft != null && seatsLeft! <= 0;
  bool get canRegister => !isPast && !isRegistered && !isSoldOut;

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String? ?? 'Untitled event',
        description: json['description'] as String?,
        venue: json['venue'] as String?,
        coverImage: json['cover_image'] as String?,
        startsAt: DateTime.tryParse(json['starts_at'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        endsAt: DateTime.tryParse(json['ends_at'] as String? ?? '')?.toLocal(),
        categoryId: (json['category_id'] as num?)?.toInt(),
        categoryName: json['category_name'] as String?,
        isPaid: json['is_paid'] == true,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        capacity: (json['capacity'] as num?)?.toInt() ?? 0,
        seatsTaken: (json['seats_taken'] as num?)?.toInt() ?? 0,
        seatsLeft: (json['seats_left'] as num?)?.toInt(),
        isPast: json['is_past'] == true,
        registration: json['registration'] is Map<String, dynamic>
            ? EventRegistration.fromJson(json['registration'] as Map<String, dynamic>)
            : null,
        inCalendar: json['in_calendar'] == true,
      );
}
