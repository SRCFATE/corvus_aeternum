class Artist {
  final String id;
  final String profileId;
  final String username;
  final String displayName;
  final String tagline;
  final String shortBio;
  final String styleLabel;
  final String? avatarUrl;
  final String? coverUrl;
  final String? location;
  final int? yearsActive;
  final List<String> disciplines;
  final Map<String, dynamic> socialLinks;
  final int followersCount;
  final int worksCount;
  final int totalLikes;
  final bool isFeatured;
  final DateTime? featuredUntil;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Artist({
    required this.id,
    required this.profileId,
    required this.username,
    required this.displayName,
    required this.tagline,
    required this.shortBio,
    required this.styleLabel,
    this.avatarUrl,
    this.coverUrl,
    this.location,
    this.yearsActive,
    required this.disciplines,
    required this.socialLinks,
    required this.followersCount,
    required this.worksCount,
    required this.totalLikes,
    required this.isFeatured,
    this.featuredUntil,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Artist.fromMap(Map<String, dynamic> map) {
    return Artist(
      id: map['id'] as String,
      profileId: map['profile_id'] as String,
      username: map['username'] as String? ?? '',
      displayName: map['display_name'] as String? ?? '',
      tagline: map['tagline'] as String? ?? '',
      shortBio: map['short_bio'] as String? ?? '',
      styleLabel: map['style_label'] as String? ?? '',
      avatarUrl: map['avatar_url'] as String?,
      coverUrl: map['cover_url'] as String?,
      location: map['location'] as String?,
      yearsActive: map['years_active'] as int?,
      disciplines: List<String>.from(map['disciplines'] as List? ?? []),
      socialLinks: Map<String, dynamic>.from(map['social_links'] as Map? ?? {}),
      followersCount: map['followers_count'] as int? ?? 0,
      worksCount: map['works_count'] as int? ?? 0,
      totalLikes: map['total_likes'] as int? ?? 0,
      isFeatured: map['is_featured'] as bool? ?? false,
      featuredUntil: map['featured_until'] != null
          ? DateTime.parse(map['featured_until'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
