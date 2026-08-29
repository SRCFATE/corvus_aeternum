import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/app_notification.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../shared/widgets/corvus_surface.dart';
import '../../shared/widgets/user_avatar.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _notificationService = NotificationService();
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  bool _showUnreadOnly = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = context.read<AuthProvider>().profile;
    if (profile == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Inicia sesion para ver tus notificaciones.';
        });
      }
      return;
    }
    try {
      final notifications =
          await _notificationService.getNotifications(profile.id);
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No pudimos cargar tus notificaciones.';
        });
      }
    }
  }

  Future<void> _markAllAsRead() async {
    final profile = context.read<AuthProvider>().profile;
    if (profile == null) return;

    final previous = _notifications;
    setState(() {
      _notifications = _notifications.map(_readCopy).toList();
    });

    try {
      await _notificationService.markAllAsRead(profile.id);
    } catch (_) {
      if (mounted) setState(() => _notifications = previous);
    }
  }

  Future<void> _openNotification(AppNotification notification) async {
    if (!notification.isRead) {
      setState(() {
        _notifications = _notifications
            .map((item) => item.id == notification.id ? _readCopy(item) : item)
            .toList();
      });
      _notificationService.markAsRead(notification.id);
    }

    final route = _routeFor(notification);
    if (route != null && mounted) {
      context.push(route);
    }
  }

  AppNotification _readCopy(AppNotification notification) {
    return AppNotification(
      id: notification.id,
      profileId: notification.profileId,
      kind: notification.kind,
      title: notification.title,
      body: notification.body,
      actorId: notification.actorId,
      entityType: notification.entityType,
      entityId: notification.entityId,
      isRead: true,
      createdAt: notification.createdAt,
      actorUsername: notification.actorUsername,
      actorAvatarUrl: notification.actorAvatarUrl,
    );
  }

  String? _routeFor(AppNotification notification) {
    final entityId = notification.entityId;
    switch (notification.entityType) {
      case 'work':
        return entityId == null ? null : '/work/$entityId';
      case 'collection':
        return entityId == null ? null : '/collection/$entityId';
      case 'profile':
      case 'user':
        if (notification.actorUsername != null) {
          return '/profile/${notification.actorUsername}';
        }
        return notification.actorId == null
            ? null
            : '/artist/${notification.actorId}';
      case 'auction':
        return entityId == null ? '/auctions' : '/auction/$entityId';
      case 'conspiracy':
        return '/conspiracies';
      case 'fan_forum':
        return entityId == null ? '/forums' : '/forums/$entityId';
    }

    if (notification.kind == 'follow') {
      if (notification.actorUsername != null) {
        return '/profile/${notification.actorUsername}';
      }
      return notification.actorId == null
          ? null
          : '/artist/${notification.actorId}';
    }
    if (notification.kind.contains('auction')) return '/auctions';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;
    final visibleNotifications = _showUnreadOnly
        ? _notifications.where((n) => !n.isRead).toList()
        : _notifications;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/feed'),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Leer todo'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    itemCount:
                        visibleNotifications.isEmpty || _errorMessage != null
                            ? 2
                            : visibleNotifications.length + 1,
                    separatorBuilder: (_, index) => index == 0
                        ? const SizedBox(height: 14)
                        : const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return _NotificationsHeader(
                          totalCount: _notifications.length,
                          unreadCount: unreadCount,
                          showUnreadOnly: _showUnreadOnly,
                          errorMessage: _errorMessage,
                          onFilterChanged: (value) {
                            setState(() => _showUnreadOnly = value);
                          },
                        );
                      }

                      if (_errorMessage != null) {
                        return _NotificationEmptyState(
                          icon: Icons.cloud_off_outlined,
                          title: 'No se pudieron cargar',
                          subtitle: _errorMessage!,
                        );
                      }

                      if (visibleNotifications.isEmpty) {
                        return _NotificationEmptyState(
                          icon: _showUnreadOnly
                              ? Icons.mark_email_read_outlined
                              : Icons.notifications_none_outlined,
                          title: _showUnreadOnly
                              ? 'Todo esta leido'
                              : 'Sin notificaciones',
                          subtitle: _showUnreadOnly
                              ? 'Cuando llegue algo nuevo aparecera aqui.'
                              : 'Tu actividad reciente y avisos importantes viviran aqui.',
                        );
                      }

                      final notification = visibleNotifications[i - 1];
                      return _NotificationTile(
                        notification: notification,
                        onTap: () => _openNotification(notification),
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }
}

class _NotificationsHeader extends StatelessWidget {
  final int totalCount;
  final int unreadCount;
  final bool showUnreadOnly;
  final String? errorMessage;
  final ValueChanged<bool> onFilterChanged;

  const _NotificationsHeader({
    required this.totalCount,
    required this.unreadCount,
    required this.showUnreadOnly,
    required this.errorMessage,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CorvusSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  unreadCount == 0 ? 'Bandeja al dia' : '$unreadCount sin leer',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$totalCount total',
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _FilterChipButton(
                label: 'Todas',
                selected: !showUnreadOnly,
                onTap: () => onFilterChanged(false),
              ),
              _FilterChipButton(
                label: 'Sin leer',
                selected: showUnreadOnly,
                onTap: () => onFilterChanged(true),
              ),
            ],
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withValues(alpha: 0.16),
      backgroundColor: Colors.white.withValues(alpha: 0.04),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.45)
            : Colors.white.withValues(alpha: 0.08),
      ),
    );
  }
}

class _NotificationEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _NotificationEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CorvusSurface(
      onTap: onTap,
      color: notification.isRead
          ? AppColors.card.withValues(alpha: 0.58)
          : AppColors.primary.withValues(alpha: 0.09),
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            UserAvatar(
              imageUrl: notification.actorAvatarUrl,
              displayName: notification.actorUsername,
              radius: 22,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 19,
                height: 19,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(_iconFor(notification.kind),
                    size: 12, color: AppColors.primary),
              ),
            ),
          ],
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: notification.isRead ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
        subtitle: notification.body.isNotEmpty
            ? Text(
                notification.body,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Text(
          _timeAgo(notification.createdAt),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ),
    );
  }

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'like':
        return Icons.favorite_rounded;
      case 'comment':
      case 'comment_reply':
        return Icons.mode_comment_outlined;
      case 'follow':
        return Icons.person_add_alt_1_rounded;
      case 'bid':
      case 'outbid':
        return Icons.gavel_rounded;
      case 'auction_won':
        return Icons.emoji_events_rounded;
      case 'auction_end':
        return Icons.notifications_active_rounded;
      case 'verification_approved':
        return Icons.verified_rounded;
      case 'work_featured':
        return Icons.star_rounded;
      case 'purchase_inquiry':
        return Icons.local_offer_outlined;
      case 'conspiracy_unlocked':
        return Icons.auto_awesome_rounded;
      case 'conspiracy_invitation':
        return Icons.mark_email_unread_rounded;
      case 'forum_request':
        return Icons.how_to_reg_outlined;
      case 'forum_invitation':
        return Icons.mark_email_unread_outlined;
      case 'forum_membership':
        return Icons.groups_2_outlined;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) return '${date.day}/${date.month}';
    if (diff.inDays > 0) return 'hace ${diff.inDays}d';
    if (diff.inHours > 0) return 'hace ${diff.inHours}h';
    if (diff.inMinutes > 0) return 'hace ${diff.inMinutes}m';
    return 'ahora';
  }
}
