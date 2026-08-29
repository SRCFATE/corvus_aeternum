class UserProfile {
  final String id;
  final String username;
  final String displayName;
  final String bio;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? country;
  final String? websiteUrl;
  final String? instagramHandle;
  final String? twitterHandle;
  final String role;
  final bool isArtistVerified;
  final bool isBanned;
  final String? conspiracyId;
  final int followersCount;
  final int followingCount;
  final int worksCount;
  final int collectionsCount;
  final int totalLikesReceived;
  final List<String> disciplines;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? usernameChangedAt;

  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.bio,
    this.avatarUrl,
    this.bannerUrl,
    this.country,
    this.websiteUrl,
    this.instagramHandle,
    this.twitterHandle,
    required this.role,
    required this.isArtistVerified,
    required this.isBanned,
    this.conspiracyId,
    required this.followersCount,
    required this.followingCount,
    required this.worksCount,
    required this.collectionsCount,
    required this.totalLikesReceived,
    required this.disciplines,
    required this.createdAt,
    required this.updatedAt,
    this.usernameChangedAt,
  });

  // Whether 365 days have passed since the last username change (or never changed).
  bool get canChangeUsername {
    if (usernameChangedAt == null) return true;
    return DateTime.now().difference(usernameChangedAt!).inDays >= 365;
  }

  // Date when the next username change will be allowed.
  DateTime? get nextUsernameChangeDate {
    if (usernameChangedAt == null) return null;
    return usernameChangedAt!.add(const Duration(days: 365));
  }

  bool get isArtist => role == 'artist';
  bool get isCrow => role == 'crow';
  bool get isAdmin => role == 'admin';

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      username: map['username'] as String,
      displayName: map['display_name'] as String? ?? '',
      bio: map['bio'] as String? ?? '',
      avatarUrl: map['avatar_url'] as String?,
      bannerUrl: map['banner_url'] as String?,
      country: map['country'] as String?,
      websiteUrl: map['website_url'] as String?,
      instagramHandle: map['instagram_handle'] as String?,
      twitterHandle: map['twitter_handle'] as String?,
      role: map['role'] as String? ?? 'crow',
      isArtistVerified: map['is_artist_verified'] as bool? ?? false,
      isBanned: map['is_banned'] as bool? ?? false,
      conspiracyId: map['conspiracy_id'] as String?,
      followersCount: map['followers_count'] as int? ?? 0,
      followingCount: map['following_count'] as int? ?? 0,
      worksCount: map['works_count'] as int? ?? 0,
      collectionsCount: map['collections_count'] as int? ?? 0,
      totalLikesReceived: map['total_likes_received'] as int? ?? 0,
      disciplines: List<String>.from(map['disciplines'] as List? ?? []),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      usernameChangedAt: map['username_changed_at'] != null
          ? DateTime.parse(map['username_changed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'display_name': displayName,
      'bio': bio,
      'avatar_url': avatarUrl,
      'banner_url': bannerUrl,
      'country': country,
      'website_url': websiteUrl,
      'instagram_handle': instagramHandle,
      'twitter_handle': twitterHandle,
      'disciplines': disciplines,
    };
  }

  UserProfile copyWith({
    String? username,
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? bannerUrl,
    String? country,
    String? websiteUrl,
    String? instagramHandle,
    String? twitterHandle,
    List<String>? disciplines,
    DateTime? usernameChangedAt,
  }) {
    return UserProfile(
      id: id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      country: country ?? this.country,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      twitterHandle: twitterHandle ?? this.twitterHandle,
      role: role,
      isArtistVerified: isArtistVerified,
      isBanned: isBanned,
      conspiracyId: conspiracyId,
      followersCount: followersCount,
      followingCount: followingCount,
      worksCount: worksCount,
      collectionsCount: collectionsCount,
      totalLikesReceived: totalLikesReceived,
      disciplines: disciplines ?? this.disciplines,
      createdAt: createdAt,
      updatedAt: updatedAt,
      usernameChangedAt: usernameChangedAt ?? this.usernameChangedAt,
    );
  }
}
