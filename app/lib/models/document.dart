class DocumentFolder {
  const DocumentFolder({
    required this.id,
    required this.name,
    this.description,
    this.documentCount = 0,
    this.totalKb = 0,
    this.lastUpdated,
  });

  final int id;
  final String name;
  final String? description;
  final int documentCount;
  final int totalKb;
  final DateTime? lastUpdated;

  String get sizeLabel => totalKb >= 1024
      ? '${(totalKb / 1024).toStringAsFixed(1)} MB'
      : '$totalKb KB';

  factory DocumentFolder.fromJson(Map<String, dynamic> json) => DocumentFolder(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        documentCount: (json['document_count'] as num?)?.toInt() ?? 0,
        totalKb: (json['total_kb'] as num?)?.toInt() ?? 0,
        lastUpdated: DateTime.tryParse(json['last_updated'] as String? ?? '')?.toLocal(),
      );
}

class PulseDocument {
  const PulseDocument({
    required this.id,
    required this.title,
    this.description,
    required this.fileUrl,
    this.fileType,
    this.sizeKb = 0,
    this.folderId,
    this.updatedAt,
  });

  final int id;
  final String title;
  final String? description;
  final String fileUrl;
  final String? fileType;
  final int sizeKb;
  final int? folderId;
  final DateTime? updatedAt;

  String get sizeLabel =>
      sizeKb >= 1024 ? '${(sizeKb / 1024).toStringAsFixed(1)} MB' : '$sizeKb KB';

  factory PulseDocument.fromJson(Map<String, dynamic> json) => PulseDocument(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        fileUrl: json['file_url'] as String? ?? '',
        fileType: json['file_type'] as String?,
        sizeKb: (json['size_kb'] as num?)?.toInt() ?? 0,
        folderId: (json['folder_id'] as num?)?.toInt(),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '')?.toLocal(),
      );
}

class SosContact {
  const SosContact({
    required this.id,
    required this.name,
    this.role,
    required this.phone,
    this.category = 'Emergency',
    this.isUrgent = false,
  });

  final int id;
  final String name;
  final String? role;
  final String phone;
  final String category;
  final bool isUrgent;

  factory SosContact.fromJson(Map<String, dynamic> json) => SosContact(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
        role: json['role'] as String?,
        phone: json['phone'] as String? ?? '',
        category: json['category'] as String? ?? 'Emergency',
        isUrgent: json['is_urgent'] == true,
      );
}
