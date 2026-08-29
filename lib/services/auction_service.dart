import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/auction.dart';
import '../models/work.dart';

class AuctionService {
  static const _auctionSelect =
      '*, seller:profiles!auctions_seller_profile_id_fkey(username, display_name, avatar_url), works(title, cover_url, discipline)';
  static const _bidSelect =
      '*, bidder:profiles!auction_bids_bidder_id_fkey(username, display_name, avatar_url)';

  Future<void> syncStatuses() async {
    await supabase.rpc('sync_auction_statuses');
  }

  Future<List<Auction>> getAuctions({
    String? status,
    int limit = 50,
  }) async {
    await syncStatuses();
    var query = supabase.from('auctions').select(_auctionSelect);

    if (status != null) {
      query = query.eq('status', status);
    }

    final data = status == 'ended'
        ? await query.order('ends_at', ascending: false).limit(limit)
        : status == 'live'
            ? await query.order('ends_at', ascending: true).limit(limit)
            : await query.order('starts_at', ascending: true).limit(limit);

    return (data as List)
        .map((item) => Auction.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<Auction>> getMyAuctions(
    String profileId, {
    int limit = 100,
  }) async {
    await syncStatuses();
    final data = await supabase
        .from('auctions')
        .select(_auctionSelect)
        .eq('seller_profile_id', profileId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List)
        .map((item) => Auction.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Auction> getAuctionById(String id) async {
    await syncStatuses();
    final data = await supabase
        .from('auctions')
        .select(_auctionSelect)
        .eq('id', id)
        .single();
    return Auction.fromMap(data);
  }

  Future<List<AuctionBid>> getAuctionBids(
    String auctionId, {
    int limit = 100,
  }) async {
    final data = await supabase
        .from('auction_bids')
        .select(_bidSelect)
        .eq('auction_id', auctionId)
        .order('amount', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List)
        .map((item) => AuctionBid.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<Work>> getEligibleWorks(String profileId) async {
    final data = await supabase
        .from('works')
        .select(
          '*, profiles!works_profile_id_fkey(username, display_name, avatar_url)',
        )
        .eq('profile_id', profileId)
        .eq('status', 'published')
        .eq('is_public', true)
        .order('created_at', ascending: false);

    return (data as List)
        .map((item) => Work.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Auction> createAuction({
    required Work work,
    required String sellerProfileId,
    required String artistName,
    required String lotTitle,
    required String description,
    required DateTime startsAt,
    required DateTime endsAt,
    required double startingBid,
    required double bidIncrement,
    required String currency,
    required String lotType,
    double? reservePrice,
    String condition = '',
    String editionLabel = '',
    String shippingNotes = '',
    String certificateId = '',
    int antiSnipeMinutes = 2,
    int extensionMinutes = 5,
  }) async {
    final now = DateTime.now();
    final status = startsAt.isAfter(now) ? 'upcoming' : 'live';
    final data = await supabase
        .from('auctions')
        .insert({
          'work_id': work.id,
          'artist_id': work.artistId,
          'seller_profile_id': sellerProfileId,
          'artist_name': artistName.trim(),
          'lot_title': lotTitle.trim(),
          'description': description.trim(),
          'cover_url': work.displayImage.isEmpty ? null : work.displayImage,
          'status': status,
          'starts_at': startsAt.toUtc().toIso8601String(),
          'ends_at': endsAt.toUtc().toIso8601String(),
          'original_ends_at': endsAt.toUtc().toIso8601String(),
          'starting_bid': startingBid,
          'bid_increment': bidIncrement,
          'reserve_price': reservePrice,
          'currency': currency,
          'lot_type': lotType,
          'condition': condition.trim(),
          'edition_label': editionLabel.trim(),
          'shipping_notes': shippingNotes.trim(),
          'certificate_id': certificateId.trim(),
          'anti_snipe_minutes': antiSnipeMinutes,
          'extension_minutes': extensionMinutes,
        })
        .select(_auctionSelect)
        .single();
    return Auction.fromMap(data);
  }

  Future<Auction> updateAuction({
    required String auctionId,
    required String lotTitle,
    required String description,
    required DateTime startsAt,
    required DateTime endsAt,
    required double startingBid,
    required double bidIncrement,
    required String currency,
    required String lotType,
    double? reservePrice,
    String condition = '',
    String editionLabel = '',
    String shippingNotes = '',
    String certificateId = '',
  }) async {
    try {
      await supabase.rpc('update_auction_details', params: {
        'p_auction_id': auctionId,
        'p_lot_title': lotTitle.trim(),
        'p_description': description.trim(),
        'p_starts_at': startsAt.toUtc().toIso8601String(),
        'p_ends_at': endsAt.toUtc().toIso8601String(),
        'p_starting_bid': startingBid,
        'p_bid_increment': bidIncrement,
        'p_reserve_price': reservePrice,
        'p_currency': currency,
        'p_lot_type': lotType,
        'p_condition': condition.trim(),
        'p_edition_label': editionLabel.trim(),
        'p_shipping_notes': shippingNotes.trim(),
        'p_certificate_id': certificateId.trim(),
      });
      return getAuctionById(auctionId);
    } on PostgrestException catch (error) {
      throw AuctionFailure(error.message);
    }
  }

  Future<Auction> placeBid(String auctionId, double amount) async {
    try {
      await supabase.rpc('place_auction_bid', params: {
        'p_auction_id': auctionId,
        'p_amount': amount,
      });
      return getAuctionById(auctionId);
    } on PostgrestException catch (error) {
      throw AuctionFailure(error.message);
    }
  }

  Future<bool> isWatching(String auctionId, String profileId) async {
    final data = await supabase
        .from('auction_watchers')
        .select('auction_id')
        .eq('auction_id', auctionId)
        .eq('profile_id', profileId)
        .maybeSingle();
    return data != null;
  }

  Future<void> watchAuction(String auctionId, String profileId) async {
    await supabase.from('auction_watchers').upsert({
      'auction_id': auctionId,
      'profile_id': profileId,
    }, onConflict: 'auction_id,profile_id', ignoreDuplicates: true);
  }

  Future<void> unwatchAuction(String auctionId, String profileId) async {
    await supabase
        .from('auction_watchers')
        .delete()
        .eq('auction_id', auctionId)
        .eq('profile_id', profileId);
  }

  Future<void> cancelAuction(String auctionId) async {
    try {
      await supabase.rpc('cancel_auction', params: {
        'p_auction_id': auctionId,
      });
    } on PostgrestException catch (error) {
      throw AuctionFailure(error.message);
    }
  }

  Future<void> deleteAuction(String auctionId) async {
    await supabase
        .from('auctions')
        .delete()
        .eq('id', auctionId)
        .eq('bids_count', 0);
  }

  Stream<List<Map<String, dynamic>>> watchAuctionUpdates(String auctionId) {
    return supabase
        .from('auctions')
        .stream(primaryKey: ['id']).eq('id', auctionId);
  }
}

class AuctionFailure implements Exception {
  final String message;

  const AuctionFailure(this.message);

  @override
  String toString() => message;
}
