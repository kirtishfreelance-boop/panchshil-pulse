class PostAuthor {
  const PostAuthor({
    required this.id,
    required this.fullName,
    this.profileImage,
    this.designation,
    this.companyName,
  });

  final int id;
  final String fullName;
  final String? profileImage;
  final String? designation;
  final String? companyName;

  String get initials {
    final parts = fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'P';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String get subtitle =>
      [designation, companyName].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

  factory PostAuthor.fromJson(Map<String, dynamic> json) => PostAuthor(
        id: (json['id'] as num).toInt(),
        fullName: json['full_name'] as String? ?? '',
        profileImage: json['profile_image'] as String?,
        designation: json['designation'] as String?,
        companyName: json['company_name'] as String?,
      );
}

class Post {
  const Post({
    required this.id,
    required this.body,
    this.imageUrl,
    this.communityId,
    this.communityName,
    this.author,
    this.createdAt,
    this.commentsCount = 0,
    this.likesCount = 0,
    this.myReaction,
  });

  final int id;
  final String body;
  final String? imageUrl;
  final int? communityId;
  final String? communityName;
  final PostAuthor? author;
  final DateTime? createdAt;
  final int commentsCount;
  final int likesCount;
  final String? myReaction;

  bool get isLiked => myReaction != null;

  Post copyWith({int? likesCount, String? myReaction, bool clearReaction = false}) => Post(
        id: id,
        body: body,
        imageUrl: imageUrl,
        communityId: communityId,
        communityName: communityName,
        author: author,
        createdAt: createdAt,
        commentsCount: commentsCount,
        likesCount: likesCount ?? this.likesCount,
        myReaction: clearReaction ? null : (myReaction ?? this.myReaction),
      );

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: (json['id'] as num).toInt(),
        body: json['body'] as String? ?? '',
        imageUrl: json['image_url'] as String?,
        communityId: (json['community_id'] as num?)?.toInt(),
        communityName: json['community_name'] as String?,
        author: json['author'] is Map<String, dynamic>
            ? PostAuthor.fromJson(json['author'] as Map<String, dynamic>)
            : null,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal(),
        commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
        likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
        myReaction: json['my_reaction'] as String?,
      );
}

class Comment {
  const Comment({
    required this.id,
    required this.body,
    this.author,
    this.createdAt,
  });

  final int id;
  final String body;
  final PostAuthor? author;
  final DateTime? createdAt;

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: (json['id'] as num).toInt(),
        body: json['body'] as String? ?? '',
        author: json['author'] is Map<String, dynamic>
            ? PostAuthor.fromJson(json['author'] as Map<String, dynamic>)
            : null,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal(),
      );
}
