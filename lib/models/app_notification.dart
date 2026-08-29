class AppNotification {
  final String id;
  final String profileId;
  final String kind;
  final String title;
  final String body;
  final String? actorId;
  final String? entityType;
  final String? entityId;
  final bool isRead;
  final DateTime createdAt;

  // Joined
  final String? actorUsername;
  final String? actorAvatarUrl;

  const AppNotification({
    required this.id,
    required this.profileId,
    required this.kind,
    required this.title,
    required this.body,
    this.actorId,
    this.entityType,
    this.entityId,
    required this.isRead,
    required this.createdAt,
    this.actorUsername,
    this.actorAvatarUrl,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    final actor = map['actor'] as Map<String, dynamic>?;
    return AppNotification(
      id: map['id'] as String,
      profileId: map['profile_id'] as String,
      kind: map['kind'] as String,
      title: map['title'] as String,
      body: map['body'] as String? ?? '',
      actorId: map['actor_id'] as String?,
      entityType: map['entity_type'] as String?,
      entityId: map['entity_id'] as String?,
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      actorUsername: actor?['username'] as String?,
      actorAvatarUrl: actor?['avatar_url'] as String?,
    );
  }

  String get icon {
    switch (kind) {
      case 'like': return '❤️';
      case 'comment': return '💬';
      case 'comment_reply': return '↩️';
      case 'follow': return '👤';
      case 'bid': return '🔨';
      case 'outbid': return '⚡';
      case 'auction_won': return '🏆';
      case 'auction_end': return '🔔';
      case 'verification_approved': return '✅';
      case 'work_featured': return '⭐';
      default: return '🪶';
    }
  }
}
