import 'work.dart';

class Collection {
  final String id;
  final String? profileId;
  final String curatorName;
  final String title;
  final String description;
  final String? coverUrl;
  final List<String> tags;
  final String collectionType;
  final int piecesCount;
  final int likesCount;
  final int viewsCount;
  final bool isPublic;
  final bool isFeatured;
  final bool isEditorial;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? curatorUsername;
  final String? curatorDisplayName;
  final String? curatorAvatarUrl;

  const Collection({
    required this.id,
    this.profileId,
    required this.curatorName,
    required this.title,
    required this.description,
    this.coverUrl,
    required this.tags,
    required this.collectionType,
    required this.piecesCount,
    required this.likesCount,
    required this.viewsCount,
    required this.isPublic,
    required this.isFeatured,
    required this.isEditorial,
    required this.createdAt,
    required this.updatedAt,
    this.curatorUsername,
    this.curatorDisplayName,
    this.curatorAvatarUrl,
  });

  factory Collection.fromMap(Map<String, dynamic> map) {
    final profile = _map(map['profiles']);
    return Collection(
      id: map['id'] as String,
      profileId: map['profile_id'] as String?,
      curatorName: map['curator_name'] as String? ?? 'Corvus',
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      coverUrl: map['cover_url'] as String?,
      tags: List<String>.from(map['tags'] as List? ?? const []),
      collectionType: map['collection_type'] as String? ?? 'curated',
      piecesCount: map['pieces_count'] as int? ?? 0,
      likesCount: map['likes_count'] as int? ?? 0,
      viewsCount: map['views_count'] as int? ?? 0,
      isPublic: map['is_public'] as bool? ?? true,
      isFeatured: map['is_featured'] as bool? ?? false,
      isEditorial: map['is_editorial'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      curatorUsername: profile?['username'] as String?,
      curatorDisplayName: profile?['display_name'] as String?,
      curatorAvatarUrl: profile?['avatar_url'] as String?,
    );
  }

  String get typeLabel {
    return switch (collectionType) {
      'personal' => 'Archivo personal',
      'inspiration' => 'Inspiración',
      'exhibition' => 'Exposición',
      'series' => 'Serie temática',
      _ => 'Curaduría',
    };
  }

  String get curatorLabel {
    final display = curatorDisplayName?.trim() ?? '';
    if (display.isNotEmpty) return display;
    final username = curatorUsername?.trim() ?? '';
    if (username.isNotEmpty) return '@$username';
    return curatorName;
  }

  bool isOwnedBy(String? profileId) {
    return profileId != null && this.profileId == profileId;
  }

  Collection copyWith({
    String? title,
    String? description,
    String? coverUrl,
    List<String>? tags,
    String? collectionType,
    int? piecesCount,
    int? likesCount,
    int? viewsCount,
    bool? isPublic,
    DateTime? updatedAt,
  }) {
    return Collection(
      id: id,
      profileId: profileId,
      curatorName: curatorName,
      title: title ?? this.title,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      tags: tags ?? this.tags,
      collectionType: collectionType ?? this.collectionType,
      piecesCount: piecesCount ?? this.piecesCount,
      likesCount: likesCount ?? this.likesCount,
      viewsCount: viewsCount ?? this.viewsCount,
      isPublic: isPublic ?? this.isPublic,
      isFeatured: isFeatured,
      isEditorial: isEditorial,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      curatorUsername: curatorUsername,
      curatorDisplayName: curatorDisplayName,
      curatorAvatarUrl: curatorAvatarUrl,
    );
  }
}

class CollectionItem {
  final String collectionId;
  final String workId;
  final int position;
  final String note;
  final String? addedBy;
  final DateTime addedAt;
  final Work? work;

  const CollectionItem({
    required this.collectionId,
    required this.workId,
    required this.position,
    required this.note,
    this.addedBy,
    required this.addedAt,
    this.work,
  });

  factory CollectionItem.fromMap(Map<String, dynamic> map) {
    final workMap = _map(map['works']);
    return CollectionItem(
      collectionId: map['collection_id'] as String,
      workId: map['work_id'] as String,
      position: map['position'] as int? ?? 0,
      note: map['note'] as String? ?? '',
      addedBy: map['added_by'] as String?,
      addedAt: DateTime.parse(map['added_at'] as String),
      work: workMap == null ? null : Work.fromMap(workMap),
    );
  }

  CollectionItem copyWith({int? position, String? note}) {
    return CollectionItem(
      collectionId: collectionId,
      workId: workId,
      position: position ?? this.position,
      note: note ?? this.note,
      addedBy: addedBy,
      addedAt: addedAt,
      work: work,
    );
  }
}

Map<String, dynamic>? _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}
