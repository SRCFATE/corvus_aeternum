class Auction {
  final String id;
  final String? workId;
  final String? artistId;
  final String? sellerProfileId;
  final String artistName;
  final String lotTitle;
  final String description;
  final String? coverUrl;
  final String status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? originalEndsAt;
  final double? reservePrice;
  final double startingBid;
  final double bidIncrement;
  final double? currentBid;
  final String? currentBidder;
  final String? winnerId;
  final bool reserveMet;
  final String settlementStatus;
  final String lotType;
  final String condition;
  final String editionLabel;
  final String shippingNotes;
  final String certificateId;
  final int antiSnipeMinutes;
  final int extensionMinutes;
  final int bidsCount;
  final int watchersCount;
  final bool isFeatured;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? sellerUsername;
  final String? sellerDisplayName;
  final String? sellerAvatarUrl;
  final String? workDiscipline;

  const Auction({
    required this.id,
    this.workId,
    this.artistId,
    this.sellerProfileId,
    required this.artistName,
    required this.lotTitle,
    required this.description,
    this.coverUrl,
    required this.status,
    this.startsAt,
    this.endsAt,
    this.originalEndsAt,
    this.reservePrice,
    required this.startingBid,
    required this.bidIncrement,
    this.currentBid,
    this.currentBidder,
    this.winnerId,
    required this.reserveMet,
    required this.settlementStatus,
    required this.lotType,
    required this.condition,
    required this.editionLabel,
    required this.shippingNotes,
    required this.certificateId,
    required this.antiSnipeMinutes,
    required this.extensionMinutes,
    required this.bidsCount,
    required this.watchersCount,
    required this.isFeatured,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
    this.sellerUsername,
    this.sellerDisplayName,
    this.sellerAvatarUrl,
    this.workDiscipline,
  });

  factory Auction.fromMap(Map<String, dynamic> map) {
    final seller = _map(map['seller']);
    final work = _map(map['works']);
    return Auction(
      id: map['id'] as String,
      workId: map['work_id'] as String?,
      artistId: map['artist_id'] as String?,
      sellerProfileId: map['seller_profile_id'] as String?,
      artistName: map['artist_name'] as String? ?? '',
      lotTitle: map['lot_title'] as String,
      description: map['description'] as String? ?? '',
      coverUrl: map['cover_url'] as String?,
      status: map['status'] as String? ?? 'upcoming',
      startsAt: _date(map['starts_at']),
      endsAt: _date(map['ends_at']),
      originalEndsAt: _date(map['original_ends_at']),
      reservePrice: (map['reserve_price'] as num?)?.toDouble(),
      startingBid: (map['starting_bid'] as num?)?.toDouble() ?? 0,
      bidIncrement: (map['bid_increment'] as num?)?.toDouble() ?? 10,
      currentBid: (map['current_bid'] as num?)?.toDouble(),
      currentBidder: map['current_bidder'] as String?,
      winnerId: map['winner_id'] as String?,
      reserveMet: map['reserve_met'] as bool? ?? false,
      settlementStatus: map['settlement_status'] as String? ?? 'not_started',
      lotType: map['lot_type'] as String? ?? 'digital',
      condition: map['condition'] as String? ?? '',
      editionLabel: map['edition_label'] as String? ?? '',
      shippingNotes: map['shipping_notes'] as String? ?? '',
      certificateId: map['certificate_id'] as String? ?? '',
      antiSnipeMinutes: map['anti_snipe_minutes'] as int? ?? 2,
      extensionMinutes: map['extension_minutes'] as int? ?? 5,
      bidsCount: map['bids_count'] as int? ?? 0,
      watchersCount: map['watchers_count'] as int? ?? 0,
      isFeatured: map['is_featured'] as bool? ?? false,
      currency: map['currency'] as String? ?? 'MXN',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      sellerUsername: seller?['username'] as String?,
      sellerDisplayName: seller?['display_name'] as String?,
      sellerAvatarUrl: seller?['avatar_url'] as String?,
      workDiscipline: work?['discipline'] as String?,
    );
  }

  bool get isLive => status == 'live';
  bool get isUpcoming => status == 'upcoming';
  bool get hasEnded => status == 'ended';
  bool get isCancelled => status == 'cancelled';
  bool get hasBids => currentBid != null || bidsCount > 0;
  bool get hasWinner => hasEnded && winnerId != null;
  bool get isExtended => originalEndsAt != null && endsAt != originalEndsAt;

  double get displayBid => currentBid ?? startingBid;
  double get minimumBid =>
      currentBid == null ? startingBid : currentBid! + bidIncrement;

  String get sellerLabel {
    final display = sellerDisplayName?.trim() ?? '';
    if (display.isNotEmpty) return display;
    final username = sellerUsername?.trim() ?? '';
    if (username.isNotEmpty) return '@$username';
    return artistName;
  }

  String get lotTypeLabel {
    return switch (lotType) {
      'physical' => 'Obra física',
      'hybrid' => 'Edición física y digital',
      'service' => 'Comisión o servicio',
      _ => 'Obra digital',
    };
  }

  bool isOwnedBy(String? profileId) {
    return profileId != null && sellerProfileId == profileId;
  }
}

class AuctionBid {
  final String id;
  final String auctionId;
  final String bidderId;
  final double amount;
  final bool isWinning;
  final DateTime createdAt;
  final String? bidderUsername;
  final String? bidderDisplayName;
  final String? bidderAvatarUrl;

  const AuctionBid({
    required this.id,
    required this.auctionId,
    required this.bidderId,
    required this.amount,
    required this.isWinning,
    required this.createdAt,
    this.bidderUsername,
    this.bidderDisplayName,
    this.bidderAvatarUrl,
  });

  factory AuctionBid.fromMap(Map<String, dynamic> map) {
    final bidder = _map(map['bidder']);
    return AuctionBid(
      id: map['id'] as String,
      auctionId: map['auction_id'] as String,
      bidderId: map['bidder_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      isWinning: map['is_winning'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      bidderUsername: bidder?['username'] as String?,
      bidderDisplayName: bidder?['display_name'] as String?,
      bidderAvatarUrl: bidder?['avatar_url'] as String?,
    );
  }

  String get bidderLabel {
    final display = bidderDisplayName?.trim() ?? '';
    if (display.isNotEmpty) return display;
    final username = bidderUsername?.trim() ?? '';
    if (username.isNotEmpty) return '@$username';
    final suffix = bidderId.length > 4
        ? bidderId.substring(bidderId.length - 4).toUpperCase()
        : bidderId.toUpperCase();
    return 'Postor $suffix';
  }
}

Map<String, dynamic>? _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}
