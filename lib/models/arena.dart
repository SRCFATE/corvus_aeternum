class ArenaChallenge {
  final String id;
  final String creatorProfileId;
  final String title;
  final String brief;
  final String format;
  final String discipline;
  final String theme;
  final List<String> rules;
  final String prizeDescription;
  final String status;
  final String visibility;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime? votingEndsAt;
  final int maxEntries;
  final DateTime createdAt;
  final String? creatorUsername;
  final String? creatorDisplayName;
  final String? creatorAvatarUrl;
  final int entriesCount;

  const ArenaChallenge({
    required this.id,
    required this.creatorProfileId,
    required this.title,
    required this.brief,
    required this.format,
    required this.discipline,
    required this.theme,
    required this.rules,
    required this.prizeDescription,
    required this.status,
    required this.visibility,
    required this.startsAt,
    required this.endsAt,
    this.votingEndsAt,
    required this.maxEntries,
    required this.createdAt,
    this.creatorUsername,
    this.creatorDisplayName,
    this.creatorAvatarUrl,
    this.entriesCount = 0,
  });

  bool get isDuel => format == 'duel';
  String get effectiveStatus {
    if (status == 'cancelled' || status == 'closed' || status == 'draft') {
      return status;
    }
    final now = DateTime.now();
    if (votingEndsAt != null && now.isAfter(votingEndsAt!)) return 'closed';
    if (now.isAfter(endsAt)) return 'voting';
    return status;
  }

  bool get acceptsEntries =>
      effectiveStatus == 'open' &&
      DateTime.now().isAfter(startsAt) &&
      DateTime.now().isBefore(endsAt) &&
      entriesCount < maxEntries;
  bool get acceptsVotes {
    final now = DateTime.now();
    if (now.isBefore(startsAt)) return false;
    if (votingEndsAt != null && now.isAfter(votingEndsAt!)) return false;
    return effectiveStatus == 'open' || effectiveStatus == 'voting';
  }

  factory ArenaChallenge.fromMap(Map<String, dynamic> map) {
    final profile = _map(map['profiles']);
    final entries = map['arena_entries'];
    return ArenaChallenge(
      id: map['id'] as String,
      creatorProfileId: map['creator_profile_id'] as String,
      title: map['title'] as String? ?? 'Desafio sin titulo',
      brief: map['brief'] as String? ?? '',
      format: map['format'] as String? ?? 'challenge',
      discipline: map['discipline'] as String? ?? 'Multidisciplinario',
      theme: map['theme'] as String? ?? '',
      rules: List<String>.from(map['rules'] as List? ?? const []),
      prizeDescription: map['prize_description'] as String? ?? '',
      status: map['status'] as String? ?? 'open',
      visibility: map['visibility'] as String? ?? 'public',
      startsAt: DateTime.parse(map['starts_at'] as String),
      endsAt: DateTime.parse(map['ends_at'] as String),
      votingEndsAt: map['voting_ends_at'] == null
          ? null
          : DateTime.parse(map['voting_ends_at'] as String),
      maxEntries: map['max_entries'] as int? ?? 50,
      createdAt: DateTime.parse(map['created_at'] as String),
      creatorUsername: profile?['username'] as String?,
      creatorDisplayName: profile?['display_name'] as String?,
      creatorAvatarUrl: profile?['avatar_url'] as String?,
      entriesCount: entries is List ? entries.length : 0,
    );
  }
}

class ArenaEntry {
  final String id;
  final String challengeId;
  final String profileId;
  final String? workId;
  final String title;
  final String statement;
  final String? mediaUrl;
  final String status;
  final DateTime createdAt;
  final String? profileUsername;
  final String? profileDisplayName;
  final String? profileAvatarUrl;
  final String? workCoverUrl;
  final int votesCount;
  final bool votedByMe;

  const ArenaEntry({
    required this.id,
    required this.challengeId,
    required this.profileId,
    this.workId,
    required this.title,
    required this.statement,
    this.mediaUrl,
    required this.status,
    required this.createdAt,
    this.profileUsername,
    this.profileDisplayName,
    this.profileAvatarUrl,
    this.workCoverUrl,
    this.votesCount = 0,
    this.votedByMe = false,
  });

  String get imageUrl =>
      workCoverUrl?.isNotEmpty == true ? workCoverUrl! : mediaUrl ?? '';

  factory ArenaEntry.fromMap(Map<String, dynamic> map, {String? viewerId}) {
    final profile = _map(map['profiles']);
    final work = _map(map['works']);
    final votes = map['arena_votes'] is List
        ? List<Map<String, dynamic>>.from(
            (map['arena_votes'] as List)
                .map((item) => Map<String, dynamic>.from(item as Map)),
          )
        : const <Map<String, dynamic>>[];
    return ArenaEntry(
      id: map['id'] as String,
      challengeId: map['challenge_id'] as String,
      profileId: map['profile_id'] as String,
      workId: map['work_id'] as String?,
      title: map['title'] as String? ?? 'Participacion',
      statement: map['statement'] as String? ?? '',
      mediaUrl: map['media_url'] as String?,
      status: map['status'] as String? ?? 'submitted',
      createdAt: DateTime.parse(map['created_at'] as String),
      profileUsername: profile?['username'] as String?,
      profileDisplayName: profile?['display_name'] as String?,
      profileAvatarUrl: profile?['avatar_url'] as String?,
      workCoverUrl: work?['cover_url'] as String?,
      votesCount: votes.length,
      votedByMe: viewerId != null &&
          votes.any((vote) => vote['voter_profile_id'] == viewerId),
    );
  }
}

Map<String, dynamic>? _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}
