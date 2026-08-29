class AeternumCertificate {
  final String id;
  final String certificateNumber;
  final String verificationCode;
  final String workId;
  final String? auctionId;
  final String? issuerProfileId;
  final String? ownerProfileId;
  final String status;
  final String editionLabel;
  final String titleSnapshot;
  final String artistSnapshot;
  final int? year;
  final String discipline;
  final String technique;
  final String dimensions;
  final bool ownerPublic;
  final String ownerLabel;
  final String? coverUrl;
  final DateTime issuedAt;
  final DateTime updatedAt;
  final DateTime? revokedAt;
  final List<CertificateEvent> events;

  const AeternumCertificate({
    required this.id,
    required this.certificateNumber,
    required this.verificationCode,
    required this.workId,
    this.auctionId,
    this.issuerProfileId,
    this.ownerProfileId,
    required this.status,
    required this.editionLabel,
    required this.titleSnapshot,
    required this.artistSnapshot,
    this.year,
    required this.discipline,
    required this.technique,
    required this.dimensions,
    required this.ownerPublic,
    required this.ownerLabel,
    this.coverUrl,
    required this.issuedAt,
    required this.updatedAt,
    this.revokedAt,
    this.events = const [],
  });

  factory AeternumCertificate.fromMap(Map<String, dynamic> map) {
    final work = _map(map['work']) ?? _map(map['works']);
    final owner = _map(map['owner']);
    final issuer = _map(map['issuer']);
    final ownerPublic = map['owner_public'] as bool? ?? false;
    final ownerDisplay = owner?['display_name'] as String? ?? '';
    final ownerUsername = owner?['username'] as String? ?? '';
    final explicitOwnerLabel = map['owner_label'] as String? ?? '';
    final ownerLabel = explicitOwnerLabel.isNotEmpty
        ? explicitOwnerLabel
        : ownerPublic && ownerDisplay.trim().isNotEmpty
            ? ownerDisplay.trim()
            : ownerPublic && ownerUsername.trim().isNotEmpty
                ? '@${ownerUsername.trim()}'
                : 'Colección privada';

    return AeternumCertificate(
      id: map['id'] as String? ?? '',
      certificateNumber: map['certificate_number'] as String,
      verificationCode: map['verification_code'] as String? ?? '',
      workId: map['work_id'] as String,
      auctionId: map['auction_id'] as String?,
      issuerProfileId: map['issuer_profile_id'] as String?,
      ownerProfileId: map['owner_profile_id'] as String?,
      status: map['status'] as String? ?? 'active',
      editionLabel: map['edition_label'] as String? ?? 'Original',
      titleSnapshot: map['title_snapshot'] as String? ??
          work?['title'] as String? ??
          'Obra sin título',
      artistSnapshot: map['artist_snapshot'] as String? ??
          issuer?['display_name'] as String? ??
          issuer?['username'] as String? ??
          '',
      year: map['year'] as int?,
      discipline: map['discipline'] as String? ?? '',
      technique: map['technique'] as String? ?? '',
      dimensions: map['dimensions'] as String? ?? '',
      ownerPublic: ownerPublic,
      ownerLabel: ownerLabel,
      coverUrl: map['cover_url'] as String? ?? work?['cover_url'] as String?,
      issuedAt: _date(map['issued_at']),
      updatedAt: _date(map['updated_at']),
      revokedAt: _nullableDate(map['revoked_at']),
      events: (map['events'] as List? ?? const [])
          .whereType<Map>()
          .map((event) => CertificateEvent.fromMap(
                Map<String, dynamic>.from(event),
              ))
          .toList(),
    );
  }

  bool get isValid => status != 'revoked';
  bool get wasTransferred => status == 'transferred';

  String get statusLabel {
    return switch (status) {
      'transferred' => 'Transferido',
      'revoked' => 'Revocado',
      _ => 'Activo',
    };
  }

  bool canManage(String? profileId) {
    return profileId != null &&
        (issuerProfileId == profileId || ownerProfileId == profileId);
  }
}

class CertificateEvent {
  final String eventType;
  final String note;
  final DateTime createdAt;

  const CertificateEvent({
    required this.eventType,
    required this.note,
    required this.createdAt,
  });

  factory CertificateEvent.fromMap(Map<String, dynamic> map) {
    return CertificateEvent(
      eventType: map['event_type'] as String? ?? 'issued',
      note: map['note'] as String? ?? '',
      createdAt: _date(map['created_at']),
    );
  }

  String get label {
    return switch (eventType) {
      'auction_awarded' => 'Adjudicado en subasta',
      'transferred' => 'Titularidad transferida',
      'revoked' => 'Certificado revocado',
      'privacy_changed' => 'Privacidad actualizada',
      _ => 'Certificado emitido',
    };
  }
}

Map<String, dynamic>? _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

DateTime _date(dynamic value) {
  return _nullableDate(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _nullableDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}
