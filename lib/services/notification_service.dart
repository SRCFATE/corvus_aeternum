import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/app_notification.dart';

class PurchaseInquiryFailure implements Exception {
  const PurchaseInquiryFailure(this.message, {this.alreadySent = false});

  final String message;
  final bool alreadySent;

  factory PurchaseInquiryFailure.fromPostgrest(PostgrestException error) {
    switch (error.code) {
      case '23505':
        return const PurchaseInquiryFailure(
          'Ya enviaste una consulta por esta obra.',
          alreadySent: true,
        );
      case '42501':
        return const PurchaseInquiryFailure(
          'La obra ya no esta disponible para consultas.',
        );
      default:
        return const PurchaseInquiryFailure(
          'No se pudo enviar la consulta. Intenta de nuevo.',
        );
    }
  }

  @override
  String toString() => message;
}

class NotificationService {
  static const _purchaseInquiryPrefix = 'purchase_inquiry:';

  Future<List<AppNotification>> getNotifications(String profileId) async {
    final results = await Future.wait<dynamic>([
      supabase
          .from('notifications')
          .select('*, actor:actor_id(username, avatar_url)')
          .eq('profile_id', profileId)
          .order('created_at', ascending: false)
          .limit(50),
      supabase
          .from('purchase_inquiries')
          .select(
            'id, work_id, buyer_profile_id, artist_profile_id, '
            'work_title_snapshot, is_read, created_at, '
            'actor:profiles!purchase_inquiries_buyer_profile_id_fkey('
            'username, avatar_url)',
          )
          .eq('artist_profile_id', profileId)
          .order('created_at', ascending: false)
          .limit(50),
    ]);

    final notifications = (results[0] as List<dynamic>)
        .map((entry) => AppNotification.fromMap(entry as Map<String, dynamic>))
        .toList();
    notifications.addAll(
      (results[1] as List<dynamic>).map(
        (entry) => _purchaseInquiryFromMap(entry as Map<String, dynamic>),
      ),
    );
    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notifications.take(50).toList();
  }

  Future<int> getUnreadCount(String profileId) async {
    final results = await Future.wait<dynamic>([
      supabase
          .from('notifications')
          .select('id')
          .eq('profile_id', profileId)
          .eq('is_read', false),
      supabase
          .from('purchase_inquiries')
          .select('id')
          .eq('artist_profile_id', profileId)
          .eq('is_read', false),
    ]);
    return (results[0] as List<dynamic>).length +
        (results[1] as List<dynamic>).length;
  }

  Future<void> markAllAsRead(String profileId) async {
    await Future.wait<dynamic>([
      supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('profile_id', profileId)
          .eq('is_read', false),
      supabase
          .from('purchase_inquiries')
          .update({'is_read': true})
          .eq('artist_profile_id', profileId)
          .eq('is_read', false),
    ]);
  }

  Future<void> markAsRead(String notificationId) async {
    if (notificationId.startsWith(_purchaseInquiryPrefix)) {
      final inquiryId = notificationId.substring(_purchaseInquiryPrefix.length);
      await supabase
          .from('purchase_inquiries')
          .update({'is_read': true}).eq('id', inquiryId);
      return;
    }
    await supabase
        .from('notifications')
        .update({'is_read': true}).eq('id', notificationId);
  }

  Future<void> createPurchaseInquiry({
    required String profileId,
    required String actorId,
    required String workId,
    required String workTitle,
  }) async {
    try {
      await supabase.from('purchase_inquiries').insert({
        'work_id': workId,
        'buyer_profile_id': actorId,
        'artist_profile_id': profileId,
        'work_title_snapshot': workTitle,
      });
    } on PostgrestException catch (error) {
      throw PurchaseInquiryFailure.fromPostgrest(error);
    }
  }

  AppNotification _purchaseInquiryFromMap(Map<String, dynamic> map) {
    final actor = map['actor'] as Map<String, dynamic>?;
    final workTitle = map['work_title_snapshot'] as String;
    return AppNotification(
      id: '$_purchaseInquiryPrefix${map['id'] as String}',
      profileId: map['artist_profile_id'] as String,
      kind: 'purchase_inquiry',
      title: 'Nueva consulta de compra',
      body:
          'Una persona esta interesada en "$workTitle". Revisa la ficha de archivo para dar seguimiento.',
      actorId: map['buyer_profile_id'] as String,
      entityType: 'work',
      entityId: map['work_id'] as String,
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      actorUsername: actor?['username'] as String?,
      actorAvatarUrl: actor?['avatar_url'] as String?,
    );
  }
}
