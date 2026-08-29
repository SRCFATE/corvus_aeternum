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

class ForumThreadPage extends StatefulWidget {
  final String forumId;
  final String threadId;
  final FanForumService? service;

  const ForumThreadPage({
    super.key,
    required this.forumId,
    required this.threadId,
    this.service,
  });

  @override
  State<ForumThreadPage> createState() => _ForumThreadPageState();
}

class _ForumThreadPageState extends State<ForumThreadPage> {
  final _replyController = TextEditingController();
  final _replyFormKey = GlobalKey<FormState>();
  late final FanForumService _service;

  FanForum? _forum;
  FanForumThread? _thread;
  List<FanForumReply> _replies = const [];
  bool _loading = true;
  bool _sending = false;
  bool _moderating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FanForumService();
    _load();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
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
      if (forum == null || !forum.canRead) {
        throw StateError('FORUM_ACCESS_REQUIRED');
      }
      final thread = await _service.getThread(widget.threadId);
      if (thread == null || thread.forumId != widget.forumId) {
        throw StateError('THREAD_NOT_FOUND');
      }
      final replies = await _service.getReplies(widget.threadId);
      if (!mounted) return;
      setState(() {
        _forum = forum;
        _thread = thread;
        _replies = replies;
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

  Future<void> _sendReply() async {
    if (_sending || !(_replyFormKey.currentState?.validate() ?? false)) return;
    setState(() => _sending = true);
    try {
      final reply = await _service.createReply(
        forumId: widget.forumId,
        threadId: widget.threadId,
        body: _replyController.text,
      );
      if (!mounted) return;
      setState(() {
        _replies = [..._replies, reply];
        _replyController.clear();
      });
      FocusScope.of(context).unfocus();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo publicar la respuesta: $error')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _setThreadState({bool? pinned, bool? locked}) async {
    if (_moderating) return;
    setState(() => _moderating = true);
    try {
      await _service.setThreadState(
        threadId: widget.threadId,
        pinned: pinned,
        locked: locked,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('No se pudo actualizar la conversación: $error')),
      );
    } finally {
      if (mounted) setState(() => _moderating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CorvusCrowLoader(label: 'Abriendo la conversación...'),
      );
    }
    if (_error != null || _forum == null || _thread == null) {
      return _ThreadMessage(
        icon: Icons.lock_outline_rounded,
        title: 'Conversación no disponible',
        message: 'Debes pertenecer al foro para consultar este contenido.',
        onBack: () => context.go('/forums/${widget.forumId}'),
      );
    }

    final forum = _forum!;
    final thread = _thread!;
    final horizontal = MediaQuery.sizeOf(context).width < 700 ? 16.0 : 28.0;
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 72),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ThreadHeader(
                  forum: forum,
                  thread: thread,
                  moderating: _moderating,
                  onBack: () => context.go('/forums/${forum.id}'),
                  onTogglePinned: forum.canModerate
                      ? () => _setThreadState(pinned: !thread.isPinned)
                      : null,
                  onToggleLocked: forum.canModerate
                      ? () => _setThreadState(locked: !thread.isLocked)
                      : null,
                ),
                const SizedBox(height: 14),
                CorvusReveal(
                  child: _MessageCard(
                    author: thread.author,
                    body: thread.body,
                    createdAt: thread.createdAt,
                    accent: forum.accentColor,
                    originalPost: true,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Text(
                      'RESPUESTAS',
                      style: TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: forum.accentColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_replies.length}',
                        style: TextStyle(
                          color: forum.accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_replies.isEmpty)
                  const _EmptyReplies()
                else
                  ..._replies.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CorvusReveal(
                            delay: Duration(
                              milliseconds: (entry.key * 45).clamp(0, 320),
                            ),
                            child: _MessageCard(
                              author: entry.value.author,
                              body: entry.value.body,
                              createdAt: entry.value.createdAt,
                              accent: forum.accentColor,
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 18),
                if (thread.isLocked)
                  _LockedNotice(canModerate: forum.canModerate)
                else
                  _ReplyComposer(
                    formKey: _replyFormKey,
                    controller: _replyController,
                    sending: _sending,
                    onSend: _sendReply,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThreadHeader extends StatelessWidget {
  final FanForum forum;
  final FanForumThread thread;
  final bool moderating;
  final VoidCallback onBack;
  final VoidCallback? onTogglePinned;
  final VoidCallback? onToggleLocked;

  const _ThreadHeader({
    required this.forum,
    required this.thread,
    required this.moderating,
    required this.onBack,
    this.onTogglePinned,
    this.onToggleLocked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Volver al foro',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  forum.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onTogglePinned != null && onToggleLocked != null)
                PopupMenuButton<String>(
                  tooltip: 'Moderar conversación',
                  enabled: !moderating,
                  onSelected: (value) {
                    if (value == 'pin') onTogglePinned?.call();
                    if (value == 'lock') onToggleLocked?.call();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'pin',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          thread.isPinned
                              ? Icons.push_pin_rounded
                              : Icons.push_pin_outlined,
                        ),
                        title: Text(
                          thread.isPinned ? 'Desfijar' : 'Fijar conversación',
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'lock',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          thread.isLocked
                              ? Icons.lock_open_rounded
                              : Icons.lock_outline_rounded,
                        ),
                        title: Text(
                          thread.isLocked ? 'Reabrir' : 'Cerrar respuestas',
                        ),
                      ),
                    ),
                  ],
                  icon: moderating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.more_horiz_rounded),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              if (thread.isPinned)
                _ThreadStatus(
                  icon: Icons.push_pin_outlined,
                  label: 'Fijada',
                  color: forum.accentColor,
                ),
              if (thread.isLocked)
                const _ThreadStatus(
                  icon: Icons.lock_outline_rounded,
                  label: 'Cerrada',
                  color: AppColors.textMuted,
                ),
            ],
          ),
          if (thread.isPinned || thread.isLocked) const SizedBox(height: 9),
          Text(
            thread.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              height: 1.18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadStatus extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ThreadStatus({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final ForumProfileSummary? author;
  final String body;
  final DateTime createdAt;
  final Color accent;
  final bool originalPost;

  const _MessageCard({
    required this.author,
    required this.body,
    required this.createdAt,
    required this.accent,
    this.originalPost = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: originalPost
            ? accent.withValues(alpha: 0.075)
            : AppColors.card.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: originalPost
              ? accent.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                imageUrl: author?.avatarUrl,
                displayName: author?.displayName ?? 'Miembro',
                radius: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author?.displayName ?? 'Miembro',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _formatDate(createdAt),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (originalPost)
                const Text(
                  'INICIO',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 15),
          FormattedManuscriptText(
            text: body,
            fontSize: 14,
            lineHeight: 1.65,
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final difference = now.difference(local);
    if (difference.inMinutes < 1) return 'Ahora';
    if (difference.inHours < 1) return 'Hace ${difference.inMinutes} min';
    if (difference.inDays < 1) return 'Hace ${difference.inHours} h';
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _ReplyComposer extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _ReplyComposer({
    required this.formKey,
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'SUMAR UNA RESPUESTA',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            CorvusTextField(
              controller: controller,
              label: 'Tu respuesta',
              hint: 'Comparte una idea con la comunidad...',
              maxLines: 6,
              maxLength: 12000,
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? 'Escribe una respuesta.'
                  : null,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined, size: 17),
                label: Text(sending ? 'Publicando' : 'Responder'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyReplies extends StatelessWidget {
  const _EmptyReplies();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: const Column(
        children: [
          Icon(Icons.chat_bubble_outline_rounded, color: AppColors.textMuted),
          SizedBox(height: 8),
          Text(
            'Aún no hay respuestas',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedNotice extends StatelessWidget {
  final bool canModerate;

  const _LockedNotice({required this.canModerate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              canModerate
                  ? 'Las respuestas están cerradas. Puedes reabrirlas desde el menú superior.'
                  : 'La moderación cerró las respuestas de esta conversación.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onBack;

  const _ThreadMessage({
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
              textAlign: TextAlign.center,
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
                onPressed: onBack, child: const Text('Volver al foro')),
          ],
        ),
      ),
    );
  }
}
