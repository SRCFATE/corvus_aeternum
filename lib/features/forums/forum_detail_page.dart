import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/fan_forum.dart';
import '../../services/fan_forum_service.dart';
import '../../shared/widgets/corvus_crow_animations.dart';
import '../../shared/widgets/corvus_motion.dart';
import '../../shared/widgets/corvus_text_field.dart';
import '../../shared/widgets/formatted_manuscript_text.dart';
import '../../shared/widgets/user_avatar.dart';

class ForumDetailPage extends StatefulWidget {
  final String forumId;
  final FanForumService? service;

  const ForumDetailPage({
    super.key,
    required this.forumId,
    this.service,
  });

  @override
  State<ForumDetailPage> createState() => _ForumDetailPageState();
}

class _ForumDetailPageState extends State<ForumDetailPage> {
  late final FanForumService _service;
  FanForum? _forum;
  List<FanForumThread> _threads = const [];
  List<FanForumMembership> _members = const [];
  bool _loading = true;
  bool _acting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FanForumService();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final forum = await _service.getForum(widget.forumId);
      if (forum == null) {
        if (mounted) {
          setState(() {
            _error = 'FORUM_NOT_FOUND';
            _loading = false;
          });
        }
        return;
      }
      final results = await Future.wait<dynamic>([
        if (forum.canRead)
          _service.getThreads(widget.forumId)
        else
          Future.value(<FanForumThread>[]),
        if (forum.canModerate)
          _service.getMembers(widget.forumId)
        else
          Future.value(<FanForumMembership>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _forum = forum;
        _threads = results[0] as List<FanForumThread>;
        _members = results[1] as List<FanForumMembership>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await action();
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo completar la acción: $error')),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _createThread() async {
    final draft = await showDialog<_ThreadDraft>(
      context: context,
      builder: (_) => const _CreateThreadDialog(),
    );
    if (draft == null) return;
    try {
      final thread = await _service.createThread(
        forumId: widget.forumId,
        title: draft.title,
        body: draft.body,
      );
      if (!mounted) return;
      await context.push(
        '/forums/${widget.forumId}/thread/${thread.id}',
      );
      _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo publicar: $error')),
      );
    }
  }

  Future<void> _inviteFan() async {
    final controller = TextEditingController();
    final username = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Invitar fan'),
        content: CorvusTextField(
          controller: controller,
          label: 'Nombre de usuario',
          hint: '@lector',
          markdownPreview: false,
          prefixIcon: const Icon(Icons.alternate_email_rounded),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim(),
            ),
            icon: const Icon(Icons.send_outlined, size: 17),
            label: const Text('Invitar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (username == null || username.isEmpty) return;
    await _perform(() => _service.inviteByUsername(widget.forumId, username));
  }

  Future<void> _leaveForum() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Salir de la comunidad?'),
        content: const Text(
          'Dejarás de ver sus conversaciones privadas. Podrás volver a solicitar acceso si el foro lo permite.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.logout_rounded, size: 17),
            label: const Text('Salir del foro'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _service.leaveForum(widget.forumId);
      if (mounted) context.go('/forums');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo salir del foro: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CorvusCrowLoader(label: 'Abriendo el círculo privado...'),
      );
    }
    if (_error != null || _forum == null) {
      return _DetailMessage(
        icon: Icons.lock_outline_rounded,
        title: 'Foro no disponible',
        message:
            'La comunidad no existe, fue archivada o no puedes consultar su ficha.',
        onBack: () => context.go('/forums'),
      );
    }

    final forum = _forum!;
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          MediaQuery.sizeOf(context).width < 700 ? 16 : 28,
          20,
          MediaQuery.sizeOf(context).width < 700 ? 16 : 28,
          64,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ForumHeader(
                  forum: forum,
                  onBack: () => context.go('/forums'),
                  onEdit: forum.isOwner
                      ? () => context.push('/forums/${forum.id}/edit')
                      : null,
                  onLeave: forum.canRead && !forum.isOwner ? _leaveForum : null,
                ),
                const SizedBox(height: 16),
                if (!forum.canRead)
                  _MembershipGate(
                    forum: forum,
                    acting: _acting,
                    onRequest: () => _perform(
                      () => _service.requestAccess(forum.id),
                    ),
                    onAccept: () => _perform(
                      () => _service.acceptInvitation(forum.id),
                    ),
                  )
                else ...[
                  if (forum.guidelines.trim().isNotEmpty) ...[
                    _CommunityGuidelines(
                      guidelines: forum.guidelines,
                      accent: forum.accentColor,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (forum.canModerate) ...[
                    _ModerationPanel(
                      forum: forum,
                      members: _members,
                      acting: _acting,
                      onInvite: _inviteFan,
                      onUpdate: (membership, status, role) => _perform(
                        () => _service.updateMembership(
                          forumId: forum.id,
                          profileId: membership.profileId,
                          status: status,
                          role: role,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _ThreadsSection(
                    forum: forum,
                    threads: _threads,
                    onCreate: _createThread,
                    onOpen: (thread) => context.push(
                      '/forums/${forum.id}/thread/${thread.id}',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ForumHeader extends StatelessWidget {
  final FanForum forum;
  final VoidCallback onBack;
  final VoidCallback? onEdit;
  final VoidCallback? onLeave;

  const _ForumHeader({
    required this.forum,
    required this.onBack,
    this.onEdit,
    this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final accent = forum.accentColor;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final content = Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Volver a foros',
                      onPressed: onBack,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded, size: 13, color: accent),
                          const SizedBox(width: 5),
                          Text(
                            'FORO PRIVADO',
                            style: TextStyle(
                              color: accent,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (onEdit != null)
                      IconButton(
                        tooltip: 'Editar comunidad',
                        onPressed: onEdit,
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    if (onLeave != null)
                      IconButton(
                        tooltip: 'Salir de la comunidad',
                        onPressed: onLeave,
                        icon: const Icon(Icons.logout_rounded),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  forum.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 10),
                FormattedManuscriptText(
                  text: forum.description,
                  fontSize: 14,
                  lineHeight: 1.55,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _AuthorLabel(profile: forum.owner),
                    _HeaderMetric(
                      icon: Icons.group_outlined,
                      label: '${forum.membersCount} miembros',
                    ),
                    _HeaderMetric(
                      icon: Icons.forum_outlined,
                      label: '${forum.threadsCount} conversaciones',
                    ),
                    _HeaderMetric(
                      icon: forum.isInviteOnly
                          ? Icons.mark_email_unread_outlined
                          : Icons.how_to_reg_outlined,
                      label: forum.isInviteOnly
                          ? 'Solo invitación'
                          : 'Solicitudes abiertas',
                    ),
                  ],
                ),
              ],
            ),
          );
          final visual = _LinkedWorkVisual(forum: forum);
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [visual, content],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: content),
              SizedBox(width: 230, child: visual),
            ],
          );
        },
      ),
    );
  }
}

class _LinkedWorkVisual extends StatelessWidget {
  final FanForum forum;

  const _LinkedWorkVisual({required this.forum});

  @override
  Widget build(BuildContext context) {
    final cover = forum.linkedWork?.coverUrl;
    final child = cover != null && cover.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: cover,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            errorWidget: (_, __, ___) => _fallback(),
          )
        : _fallback();
    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      color: AppColors.background.withValues(alpha: 0.72),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }

  Widget _fallback() {
    return Center(
      child: Icon(
        Icons.groups_2_outlined,
        size: 72,
        color: forum.accentColor.withValues(alpha: 0.35),
      ),
    );
  }
}

class _AuthorLabel extends StatelessWidget {
  final ForumProfileSummary? profile;

  const _AuthorLabel({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        UserAvatar(
          imageUrl: profile?.avatarUrl,
          displayName: profile?.displayName ?? 'Autor',
          radius: 13,
        ),
        const SizedBox(width: 7),
        Text(
          profile?.displayName ?? 'Autor',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderMetric({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
        ),
      ],
    );
  }
}

class _MembershipGate extends StatelessWidget {
  final FanForum forum;
  final bool acting;
  final VoidCallback onRequest;
  final VoidCallback onAccept;

  const _MembershipGate({
    required this.forum,
    required this.acting,
    required this.onRequest,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final membership = forum.myMembership;
    final invited = membership?.status == 'invited';
    final pending = membership?.status == 'pending';
    final blocked = membership?.status == 'blocked';
    final rejected = membership?.status == 'rejected';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 38),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Icon(
            invited ? Icons.mark_email_unread_outlined : Icons.lock_rounded,
            size: 40,
            color: forum.accentColor,
          ),
          const SizedBox(height: 13),
          Text(
            invited
                ? 'El autor te invitó'
                : pending
                    ? 'Solicitud en revisión'
                    : blocked
                        ? 'Acceso retirado'
                        : rejected
                            ? 'Solicitud no aprobada'
                            : 'Conversación privada',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            invited
                ? 'Acepta la invitación para leer y participar.'
                : pending
                    ? 'El autor o sus moderadores responderán tu solicitud.'
                    : forum.isInviteOnly
                        ? 'Esta comunidad admite fans únicamente mediante invitación.'
                        : 'Solicita acceso para convivir con el autor y sus lectores.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (invited) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: acting ? null : onAccept,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Aceptar invitación'),
            ),
          ] else if ((membership == null || rejected) &&
              !forum.isInviteOnly) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: acting ? null : onRequest,
              icon: const Icon(Icons.how_to_reg_outlined),
              label: Text(
                rejected ? 'Volver a solicitar acceso' : 'Solicitar acceso',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CommunityGuidelines extends StatelessWidget {
  final String guidelines;
  final Color accent;

  const _CommunityGuidelines({
    required this.guidelines,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel_outlined, size: 17, color: accent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ACUERDOS DE CONVIVENCIA',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FormattedManuscriptText(
            text: guidelines,
            fontSize: 13.5,
            lineHeight: 1.6,
          ),
        ],
      ),
    );
  }
}

class _ModerationPanel extends StatelessWidget {
  final FanForum forum;
  final List<FanForumMembership> members;
  final bool acting;
  final VoidCallback onInvite;
  final void Function(
    FanForumMembership membership,
    String status,
    String role,
  ) onUpdate;

  const _ModerationPanel({
    required this.forum,
    required this.members,
    required this.acting,
    required this.onInvite,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final pending = members.where((item) => item.status == 'pending').toList();
    final active = members
        .where((item) => item.status == 'active' && !item.isOwner)
        .toList();
    return ExpansionTile(
      collapsedBackgroundColor: AppColors.card.withValues(alpha: 0.58),
      backgroundColor: AppColors.card.withValues(alpha: 0.58),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      collapsedShape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: const Icon(Icons.admin_panel_settings_outlined),
      title: const Text(
        'Gestión de la comunidad',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        pending.isEmpty
            ? '${active.length} miembros gestionables'
            : '${pending.length} solicitudes pendientes',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Invitar fan',
            onPressed: onInvite,
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
          const Icon(Icons.expand_more_rounded),
        ],
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (pending.isNotEmpty) ...[
          const Divider(),
          for (final membership in pending)
            _MemberRow(
              membership: membership,
              actions: [
                IconButton(
                  tooltip: 'Rechazar',
                  onPressed: acting
                      ? null
                      : () => onUpdate(membership, 'rejected', 'member'),
                  icon: const Icon(Icons.close_rounded),
                ),
                IconButton.filled(
                  tooltip: 'Aprobar',
                  onPressed: acting
                      ? null
                      : () => onUpdate(membership, 'active', 'member'),
                  icon: const Icon(Icons.check_rounded),
                ),
              ],
            ),
        ],
        if (active.isNotEmpty) ...[
          const Divider(),
          for (final membership in active.take(12))
            _MemberRow(
              membership: membership,
              actions: [
                PopupMenuButton<String>(
                  tooltip: 'Gestionar miembro',
                  onSelected: (value) {
                    if (value == 'moderator') {
                      onUpdate(membership, 'active', 'moderator');
                    } else if (value == 'member') {
                      onUpdate(membership, 'active', 'member');
                    } else if (value == 'blocked') {
                      onUpdate(membership, 'blocked', membership.role);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: membership.role == 'moderator'
                          ? 'member'
                          : 'moderator',
                      child: Text(
                        membership.role == 'moderator'
                            ? 'Retirar moderación'
                            : 'Hacer moderador',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'blocked',
                      child: Text('Retirar acceso'),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  final FanForumMembership membership;
  final List<Widget> actions;

  const _MemberRow({required this.membership, required this.actions});

  @override
  Widget build(BuildContext context) {
    final profile = membership.profile;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: UserAvatar(
        imageUrl: profile?.avatarUrl,
        displayName: profile?.displayName ?? 'Lector',
        radius: 18,
      ),
      title: Text(profile?.displayName ?? 'Lector'),
      subtitle: Text(
        profile?.username.isNotEmpty == true
            ? '@${profile!.username}'
            : membership.statusLabel,
      ),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: actions),
    );
  }
}

class _ThreadsSection extends StatelessWidget {
  final FanForum forum;
  final List<FanForumThread> threads;
  final VoidCallback onCreate;
  final ValueChanged<FanForumThread> onOpen;

  const _ThreadsSection({
    required this.forum,
    required this.threads,
    required this.onCreate,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final title = const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONVERSACIONES',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Dentro del círculo',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            );
            final button = FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_comment_outlined, size: 18),
              label: const Text('Nueva conversación'),
            );
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [title, const SizedBox(height: 12), button],
              );
            }
            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 16),
                button,
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        if (threads.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 46, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.card.withValues(alpha: 0.46),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: const Column(
              children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 34),
                SizedBox(height: 10),
                Text(
                  'Inicia la primera conversación',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          )
        else
          ...threads.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: CorvusReveal(
                    delay: Duration(
                      milliseconds: (entry.key * 55).clamp(0, 330),
                    ),
                    child: _ThreadCard(
                      thread: entry.value,
                      accent: forum.accentColor,
                      onTap: () => onOpen(entry.value),
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}

class _ThreadCard extends StatelessWidget {
  final FanForumThread thread;
  final Color accent;
  final VoidCallback onTap;

  const _ThreadCard({
    required this.thread,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.card.withValues(alpha: 0.60),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: thread.isPinned
                  ? accent.withValues(alpha: 0.40)
                  : Colors.white.withValues(alpha: 0.07),
            ),
          ),
          child: Row(
            children: [
              UserAvatar(
                imageUrl: thread.author?.avatarUrl,
                displayName: thread.author?.displayName ?? 'Miembro',
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (thread.isPinned) ...[
                          Icon(Icons.push_pin_outlined,
                              size: 14, color: accent),
                          const SizedBox(width: 5),
                        ],
                        Expanded(
                          child: Text(
                            thread.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (thread.isLocked)
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 15,
                            color: AppColors.textMuted,
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      thread.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${thread.author?.displayName ?? 'Miembro'} · ${thread.repliesCount} respuestas',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadDraft {
  final String title;
  final String body;

  const _ThreadDraft({required this.title, required this.body});
}

class _CreateThreadDialog extends StatefulWidget {
  const _CreateThreadDialog();

  @override
  State<_CreateThreadDialog> createState() => _CreateThreadDialogState();
}

class _CreateThreadDialogState extends State<_CreateThreadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva conversación'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CorvusTextField(
                  controller: _titleController,
                  label: 'Título',
                  maxLength: 140,
                  markdownPreview: false,
                  validator: (value) => (value?.trim().length ?? 0) < 3
                      ? 'Escribe un título.'
                      : null,
                ),
                const SizedBox(height: 12),
                CorvusTextField(
                  controller: _bodyController,
                  label: 'Mensaje',
                  maxLines: 8,
                  maxLength: 12000,
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Escribe el mensaje inicial.'
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _ThreadDraft(
                title: _titleController.text,
                body: _bodyController.text,
              ),
            );
          },
          icon: const Icon(Icons.send_outlined, size: 17),
          label: const Text('Publicar'),
        ),
      ],
    );
  }
}

class _DetailMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onBack;

  const _DetailMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.primaryLight),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: onBack, child: const Text('Volver a foros')),
          ],
        ),
      ),
    );
  }
}
