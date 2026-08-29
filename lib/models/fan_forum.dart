import 'package:flutter/material.dart';

class ForumProfileSummary {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  const ForumProfileSummary({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  factory ForumProfileSummary.fromMap(Map<String, dynamic> map) {
    return ForumProfileSummary(
      id: map['id'] as String? ?? '',
      username: map['username'] as String? ?? '',
      displayName: map['display_name'] as String? ?? 'Autor',
      avatarUrl: map['avatar_url'] as String?,
    );
  }
}

class ForumWorkSummary {
  final String id;
  final String title;
  final String? coverUrl;

  const ForumWorkSummary({
    required this.id,
    required this.title,
    this.coverUrl,
  });

  factory ForumWorkSummary.fromMap(Map<String, dynamic> map) {
    return ForumWorkSummary(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Obra vinculada',
      coverUrl: map['cover_url'] as String?,
    );
  }
}

class FanForumMembership {
  final String forumId;
  final String profileId;
  final String role;
  final String status;
  final String? invitedBy;
  final DateTime? requestedAt;
  final DateTime? joinedAt;
  final ForumProfileSummary? profile;

  const FanForumMembership({
    required this.forumId,
    required this.profileId,
    required this.role,
    required this.status,
    this.invitedBy,
    this.requestedAt,
    this.joinedAt,
    this.profile,
  });

  factory FanForumMembership.fromMap(Map<String, dynamic> map) {
    final profile = map['profile'];
    return FanForumMembership(
      forumId: map['forum_id'] as String? ?? '',
      profileId: map['profile_id'] as String? ?? '',
      role: map['role'] as String? ?? 'member',
      status: map['status'] as String? ?? 'pending',
      invitedBy: map['invited_by'] as String?,
      requestedAt: DateTime.tryParse(map['requested_at'] as String? ?? ''),
      joinedAt: DateTime.tryParse(map['joined_at'] as String? ?? ''),
      profile: profile is Map
          ? ForumProfileSummary.fromMap(Map<String, dynamic>.from(profile))
          : null,
    );
  }

  bool get isActive => status == 'active';
  bool get isOwner => role == 'owner';
  bool get canModerate => isActive && (role == 'owner' || role == 'moderator');

  String get statusLabel => switch (status) {
        'active' => role == 'owner'
            ? 'Autor'
            : role == 'moderator'
                ? 'Moderador'
                : 'Miembro',
        'pending' => 'Solicitud pendiente',
        'invited' => 'Invitación pendiente',
        'rejected' => 'Solicitud rechazada',
        'blocked' => 'Acceso retirado',
        _ => status,
      };
}

class FanForum {
  final String id;
  final String ownerId;
  final String? linkedWorkId;
  final String name;
  final String description;
  final String guidelines;
  final String joinPolicy;
  final bool isDiscoverable;
  final String status;
  final String accentHex;
  final int membersCount;
  final int threadsCount;
  final DateTime lastActivityAt;
  final DateTime createdAt;
  final ForumProfileSummary? owner;
  final ForumWorkSummary? linkedWork;
  final FanForumMembership? myMembership;

  const FanForum({
    required this.id,
    required this.ownerId,
    this.linkedWorkId,
    required this.name,
    required this.description,
    required this.guidelines,
    required this.joinPolicy,
    required this.isDiscoverable,
    required this.status,
    required this.accentHex,
    required this.membersCount,
    required this.threadsCount,
    required this.lastActivityAt,
    required this.createdAt,
    this.owner,
    this.linkedWork,
    this.myMembership,
  });

  factory FanForum.fromMap(Map<String, dynamic> map) {
    final owner = map['owner'];
    final linkedWork = map['linked_work'];
    return FanForum(
      id: map['id'] as String? ?? '',
      ownerId: map['owner_id'] as String? ?? '',
      linkedWorkId: map['linked_work_id'] as String?,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      guidelines: map['guidelines'] as String? ?? '',
      joinPolicy: map['join_policy'] as String? ?? 'request',
      isDiscoverable: map['is_discoverable'] as bool? ?? true,
      status: map['status'] as String? ?? 'active',
      accentHex: map['accent_hex'] as String? ?? '#C92F35',
      membersCount: (map['members_count'] as num?)?.toInt() ?? 0,
      threadsCount: (map['threads_count'] as num?)?.toInt() ?? 0,
      lastActivityAt: DateTime.tryParse(
            map['last_activity_at'] as String? ?? '',
          ) ??
          DateTime.now(),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      owner: owner is Map
          ? ForumProfileSummary.fromMap(Map<String, dynamic>.from(owner))
          : null,
      linkedWork: linkedWork is Map
          ? ForumWorkSummary.fromMap(
              Map<String, dynamic>.from(linkedWork),
            )
          : null,
    );
  }

  FanForum withMembership(FanForumMembership? membership) {
    return FanForum(
      id: id,
      ownerId: ownerId,
      linkedWorkId: linkedWorkId,
      name: name,
      description: description,
      guidelines: guidelines,
      joinPolicy: joinPolicy,
      isDiscoverable: isDiscoverable,
      status: status,
      accentHex: accentHex,
      membersCount: membersCount,
      threadsCount: threadsCount,
      lastActivityAt: lastActivityAt,
      createdAt: createdAt,
      owner: owner,
      linkedWork: linkedWork,
      myMembership: membership,
    );
  }

  Color get accentColor {
    final hex = accentHex.replaceAll('#', '');
    return Color(int.tryParse('FF$hex', radix: 16) ?? 0xFFC92F35);
  }

  bool get canRead => myMembership?.isActive == true;
  bool get canModerate => myMembership?.canModerate == true;
  bool get isOwner => myMembership?.isOwner == true;
  bool get isInviteOnly => joinPolicy == 'invite_only';
}

class FanForumThread {
  final String id;
  final String forumId;
  final String authorId;
  final String title;
  final String body;
  final bool isPinned;
  final bool isLocked;
  final int repliesCount;
  final DateTime lastActivityAt;
  final DateTime createdAt;
  final ForumProfileSummary? author;

  const FanForumThread({
    required this.id,
    required this.forumId,
    required this.authorId,
    required this.title,
    required this.body,
    required this.isPinned,
    required this.isLocked,
    required this.repliesCount,
    required this.lastActivityAt,
    required this.createdAt,
    this.author,
  });

  factory FanForumThread.fromMap(Map<String, dynamic> map) {
    final author = map['author'];
    return FanForumThread(
      id: map['id'] as String? ?? '',
      forumId: map['forum_id'] as String? ?? '',
      authorId: map['author_id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      isPinned: map['is_pinned'] as bool? ?? false,
      isLocked: map['is_locked'] as bool? ?? false,
      repliesCount: (map['replies_count'] as num?)?.toInt() ?? 0,
      lastActivityAt: DateTime.tryParse(
            map['last_activity_at'] as String? ?? '',
          ) ??
          DateTime.now(),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      author: author is Map
          ? ForumProfileSummary.fromMap(Map<String, dynamic>.from(author))
          : null,
    );
  }
}

class FanForumReply {
  final String id;
  final String threadId;
  final String forumId;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final ForumProfileSummary? author;

  const FanForumReply({
    required this.id,
    required this.threadId,
    required this.forumId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.author,
  });

  factory FanForumReply.fromMap(Map<String, dynamic> map) {
    final author = map['author'];
    return FanForumReply(
      id: map['id'] as String? ?? '',
      threadId: map['thread_id'] as String? ?? '',
      forumId: map['forum_id'] as String? ?? '',
      authorId: map['author_id'] as String? ?? '',
      body: map['body'] as String? ?? '',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      author: author is Map
          ? ForumProfileSummary.fromMap(Map<String, dynamic>.from(author))
          : null,
    );
  }
}
