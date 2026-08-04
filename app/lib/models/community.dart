class Community {
  const Community({
    required this.id,
    required this.name,
    this.description,
    this.coverImage,
    this.category,
    this.membersCount = 0,
    this.trending = false,
    this.joined = false,
    this.membershipStatus,
    this.role,
  });

  final int id;
  final String name;
  final String? description;
  final String? coverImage;
  final String? category;
  final int membersCount;
  final bool trending;
  final bool joined;
  final String? membershipStatus;
  final String? role;

  factory Community.fromJson(Map<String, dynamic> json) => Community(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        coverImage: json['cover_image'] as String?,
        category: json['category'] as String?,
        membersCount: (json['members_count'] as num?)?.toInt() ?? 0,
        trending: json['trending'] == true,
        joined: json['joined'] == true,
        membershipStatus: json['membership_status'] as String?,
        role: json['role'] as String?,
      );
}

class CommunityMember {
  const CommunityMember({
    required this.id,
    required this.fullName,
    this.profileImage,
    this.designation,
    this.companyName,
    this.role = 'member',
  });

  final int id;
  final String fullName;
  final String? profileImage;
  final String? designation;
  final String? companyName;
  final String role;

  factory CommunityMember.fromJson(Map<String, dynamic> json) => CommunityMember(
        id: (json['id'] as num).toInt(),
        fullName: json['full_name'] as String? ?? '',
        profileImage: json['profile_image'] as String?,
        designation: json['designation'] as String?,
        companyName: json['company_name'] as String?,
        role: json['role'] as String? ?? 'member',
      );
}
