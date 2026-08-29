import 'aeternum_ficha.dart';

class Work {
  final String id;
  final String profileId;
  final String? artistId;
  final String title;
  final String description;
  final String discipline;
  final String subdiscipline;
  final String medium;
  final int? year;
  final String? coverUrl;
  final List<String> mediaUrls;
  final List<String> tags;
  final List<String> contentWarnings;
  final int likesCount;
  final int viewsCount;
  final int savesCount;
  final int commentsCount;
  final bool isPublic;
  final bool isFeatured;
  final bool isForSale;
  final double? price;
  final String currency;
  final String status;
  final String workType;
  final String? textBody;
  final String? audioUrl;
  final String? technique;
  final String? dimensions;
  final String? musicGenre;
  final String? duration;
  final String? language;
  final String? audience;
  final bool isMature;
  final bool isComplete;
  final AeternumFicha aeternumFicha;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined fields
  final String? authorUsername;
  final String? authorDisplayName;
  final String? authorAvatarUrl;

  const Work({
    required this.id,
    required this.profileId,
    this.artistId,
    required this.title,
    required this.description,
    required this.discipline,
    required this.subdiscipline,
    required this.medium,
    this.year,
    this.coverUrl,
    required this.mediaUrls,
    required this.tags,
    this.contentWarnings = const [],
    required this.likesCount,
    required this.viewsCount,
    required this.savesCount,
    required this.commentsCount,
    required this.isPublic,
    required this.isFeatured,
    required this.isForSale,
    this.price,
    required this.currency,
    required this.status,
    required this.workType,
    this.textBody,
    this.audioUrl,
    this.technique,
    this.dimensions,
    this.musicGenre,
    this.duration,
    this.language,
    this.audience,
    required this.isMature,
    required this.isComplete,
    required this.aeternumFicha,
    required this.createdAt,
    required this.updatedAt,
    this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
  });

  factory Work.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return Work(
      id: map['id'] as String,
      profileId: map['profile_id'] as String,
      artistId: map['artist_id'] as String?,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      discipline: map['discipline'] as String? ?? '',
      subdiscipline: map['subdiscipline'] as String? ?? '',
      medium: map['medium'] as String? ?? '',
      year: map['year'] as int?,
      coverUrl: map['cover_url'] as String?,
      mediaUrls: List<String>.from(map['media_urls'] as List? ?? []),
      tags: List<String>.from(map['tags'] as List? ?? []),
      contentWarnings:
          List<String>.from(map['content_warnings'] as List? ?? []),
      likesCount: map['likes_count'] as int? ?? 0,
      viewsCount: map['views_count'] as int? ?? 0,
      savesCount: map['saves_count'] as int? ?? 0,
      commentsCount: map['comments_count'] as int? ?? 0,
      isPublic: map['is_public'] as bool? ?? true,
      isFeatured: map['is_featured'] as bool? ?? false,
      isForSale: map['is_for_sale'] as bool? ?? false,
      price: (map['price'] as num?)?.toDouble(),
      currency: map['currency'] as String? ?? 'USD',
      status: map['status'] as String? ?? 'published',
      workType: map['work_type'] as String? ?? 'image',
      textBody: map['text_body'] as String?,
      audioUrl: map['audio_url'] as String?,
      technique: map['technique'] as String?,
      dimensions: map['dimensions'] as String?,
      musicGenre: map['music_genre'] as String?,
      duration: map['duration'] as String?,
      language: map['language'] as String?,
      audience: map['audience'] as String?,
      isMature: map['is_mature'] as bool? ?? false,
      isComplete: map['is_complete'] as bool? ?? false,
      aeternumFicha: AeternumFicha.fromSource(
        map['aeternum_ficha'],
        workMap: map,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      authorUsername: profile?['username'] as String?,
      authorDisplayName: profile?['display_name'] as String?,
      authorAvatarUrl: profile?['avatar_url'] as String?,
    );
  }

  String get displayImage =>
      coverUrl ?? (mediaUrls.isNotEmpty ? mediaUrls.first : '');

  bool get hasImage => coverUrl != null || mediaUrls.isNotEmpty;
}
