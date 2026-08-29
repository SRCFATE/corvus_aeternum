import 'package:corvus_aeternum/models/auction.dart';
import 'package:corvus_aeternum/models/aeternum_certificate.dart';
import 'package:corvus_aeternum/models/collection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Collection', () {
    test('parses curator metadata and ownership', () {
      final collection = Collection.fromMap({
        'id': 'collection-1',
        'profile_id': 'profile-1',
        'curator_name': 'Archivo Corvus',
        'title': 'Nocturnos',
        'description': 'Una selección de obra nocturna.',
        'tags': ['noche', 'fotografía'],
        'collection_type': 'exhibition',
        'pieces_count': 4,
        'likes_count': 8,
        'views_count': 13,
        'is_public': true,
        'is_featured': false,
        'is_editorial': false,
        'created_at': '2026-08-15T12:00:00Z',
        'updated_at': '2026-08-16T12:00:00Z',
        'profiles': {
          'username': 'curadora',
          'display_name': 'María Luna',
          'avatar_url': null,
        },
      });

      expect(collection.typeLabel, 'Exposición');
      expect(collection.curatorLabel, 'María Luna');
      expect(collection.isOwnedBy('profile-1'), isTrue);
      expect(collection.isOwnedBy('profile-2'), isFalse);
    });

    test('copyWith updates counters without losing metadata', () {
      final collection = Collection.fromMap({
        'id': 'collection-1',
        'profile_id': 'profile-1',
        'title': 'Archivo',
        'created_at': '2026-08-15T12:00:00Z',
        'updated_at': '2026-08-15T12:00:00Z',
      });

      final liked = collection.copyWith(likesCount: 1, isPublic: false);

      expect(liked.likesCount, 1);
      expect(liked.isPublic, isFalse);
      expect(liked.title, collection.title);
      expect(liked.profileId, collection.profileId);
    });
  });

  group('Auction', () {
    test('uses starting bid before the first offer', () {
      final auction = Auction.fromMap(_auctionMap());

      expect(auction.displayBid, 100);
      expect(auction.minimumBid, 100);
      expect(auction.lotTypeLabel, 'Obra digital');
      expect(auction.sellerLabel, 'Irene Sol');
      expect(auction.isOwnedBy('seller-1'), isTrue);
    });

    test('adds the increment and detects an extended close', () {
      final auction = Auction.fromMap(
        _auctionMap(
          currentBid: 175,
          currentBidder: 'bidder-1',
          bidsCount: 3,
          endsAt: '2026-08-16T13:05:00Z',
          winnerId: 'bidder-1',
          status: 'ended',
        ),
      );

      expect(auction.minimumBid, 200);
      expect(auction.isExtended, isTrue);
      expect(auction.hasWinner, isTrue);
    });
  });

  test('AuctionBid falls back to an anonymized bidder label', () {
    final bid = AuctionBid.fromMap({
      'id': 'bid-1',
      'auction_id': 'auction-1',
      'bidder_id': '00000000-0000-0000-0000-12345678abcd',
      'amount': 125,
      'is_winning': true,
      'created_at': '2026-08-16T12:30:00Z',
    });

    expect(bid.bidderLabel, 'Postor ABCD');
    expect(bid.isWinning, isTrue);
  });

  group('AeternumCertificate', () {
    test('parses public verification and provenance', () {
      final certificate = AeternumCertificate.fromMap({
        'certificate_number': 'CA-2026-000001',
        'verification_code': 'verify-1',
        'work_id': 'work-1',
        'status': 'transferred',
        'edition_label': '03/25',
        'title_snapshot': 'Nocturno IV',
        'artist_snapshot': 'Irene Sol',
        'discipline': 'Pintura',
        'technique': 'Óleo sobre lienzo',
        'dimensions': '80 × 60 cm',
        'owner_public': false,
        'owner_label': 'Colección privada',
        'issued_at': '2026-08-16T12:00:00Z',
        'updated_at': '2026-08-16T13:00:00Z',
        'events': [
          {
            'event_type': 'auction_awarded',
            'note': 'Transferencia registrada.',
            'created_at': '2026-08-16T13:00:00Z',
          },
        ],
      });

      expect(certificate.statusLabel, 'Transferido');
      expect(certificate.wasTransferred, isTrue);
      expect(certificate.ownerLabel, 'Colección privada');
      expect(certificate.events.single.label, 'Adjudicado en subasta');
    });

    test('allows only issuer or owner to manage private records', () {
      final certificate = AeternumCertificate.fromMap({
        'id': 'certificate-1',
        'certificate_number': 'CA-2026-000002',
        'verification_code': 'verify-2',
        'work_id': 'work-1',
        'issuer_profile_id': 'artist-1',
        'owner_profile_id': 'collector-1',
        'status': 'active',
        'edition_label': 'Original',
        'title_snapshot': 'Eclipse',
        'artist_snapshot': 'Irene Sol',
        'owner_public': true,
        'owner': {
          'display_name': 'Coleccionista Uno',
          'username': 'collector',
        },
        'issued_at': '2026-08-16T12:00:00Z',
        'updated_at': '2026-08-16T12:00:00Z',
      });

      expect(certificate.ownerLabel, 'Coleccionista Uno');
      expect(certificate.canManage('artist-1'), isTrue);
      expect(certificate.canManage('collector-1'), isTrue);
      expect(certificate.canManage('visitor-1'), isFalse);
    });
  });
}

Map<String, dynamic> _auctionMap({
  double? currentBid,
  String? currentBidder,
  int bidsCount = 0,
  String endsAt = '2026-08-16T13:00:00Z',
  String? winnerId,
  String status = 'live',
}) {
  return {
    'id': 'auction-1',
    'work_id': 'work-1',
    'artist_id': 'artist-1',
    'seller_profile_id': 'seller-1',
    'artist_name': 'Irene Sol',
    'lot_title': 'Eclipse',
    'description': 'Pieza única.',
    'cover_url': null,
    'status': status,
    'starts_at': '2026-08-16T11:00:00Z',
    'ends_at': endsAt,
    'original_ends_at': '2026-08-16T13:00:00Z',
    'reserve_price': 150,
    'starting_bid': 100,
    'bid_increment': 25,
    'current_bid': currentBid,
    'current_bidder': currentBidder,
    'winner_id': winnerId,
    'reserve_met': currentBid != null && currentBid >= 150,
    'settlement_status': winnerId == null ? 'not_started' : 'awaiting_payment',
    'lot_type': 'digital',
    'condition': '',
    'edition_label': '1/1',
    'shipping_notes': '',
    'certificate_id': 'CORVUS-001',
    'anti_snipe_minutes': 2,
    'extension_minutes': 5,
    'bids_count': bidsCount,
    'watchers_count': 7,
    'is_featured': false,
    'currency': 'MXN',
    'created_at': '2026-08-16T10:00:00Z',
    'updated_at': '2026-08-16T12:00:00Z',
    'seller': {
      'username': 'irene',
      'display_name': 'Irene Sol',
      'avatar_url': null,
    },
    'works': {'discipline': 'Fotografía'},
  };
}
