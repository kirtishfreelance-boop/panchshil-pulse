class Notice {
  const Notice({
    required this.id,
    required this.title,
    this.body,
    this.coverImage,
    this.category,
    this.isImportant = false,
    this.expiresAt,
    this.createdAt,
  });

  final int id;
  final String title;
  final String? body;
  final String? coverImage;
  final String? category;
  final bool isImportant;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  factory Notice.fromJson(Map<String, dynamic> json) => Notice(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String? ?? '',
        body: json['body'] as String?,
        coverImage: json['cover_image'] as String?,
        category: json['category'] as String?,
        isImportant: json['is_important'] == true,
        expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '')?.toLocal(),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal(),
      );
}
