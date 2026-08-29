class WorkComment {
  final String id;
  final String workId;
  final String profileId;
  final String? parentId;
  final String body;
  final int likesCount;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final String? authorUsername;
  final String? authorDisplayName;
  final String? authorAvatarUrl;

  const WorkComment({
    required this.id,
    required this.workId,
    required this.profileId,
    this.parentId,
    required this.body,
    required this.likesCount,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
    this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
  });

  factory WorkComment.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return WorkComment(
      id: map['id'] as String,
      workId: map['work_id'] as String,
      profileId: map['profile_id'] as String,
      parentId: map['parent_id'] as String?,
      body: map['body'] as String,
      likesCount: map['likes_count'] as int? ?? 0,
      isDeleted: map['is_deleted'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      authorUsername: profile?['username'] as String?,
      authorDisplayName: profile?['display_name'] as String?,
      authorAvatarUrl: profile?['avatar_url'] as String?,
    );
  }
}
