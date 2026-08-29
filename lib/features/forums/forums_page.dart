import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/fan_forum.dart';
import '../../services/fan_forum_service.dart';
import '../../shared/layout/corvus_page.dart';
import '../../shared/widgets/corvus_crow_animations.dart';
import '../../shared/widgets/corvus_motion.dart';
import '../../shared/widgets/user_avatar.dart';

enum _ForumFilter { explore, mine, managed, invitations }

class ForumsPage extends StatefulWidget {
  final FanForumService? service;

  const ForumsPage({super.key, this.service});

  @override
  State<ForumsPage> createState() => _ForumsPageState();
}

class _ForumsPageState extends State<ForumsPage> {
  late final FanForumService _service;
  final _searchController = TextEditingController();
  List<FanForum> _forums = const [];
  _ForumFilter _filter = _ForumFilter.explore;
  bool _loading = true;
  bool _canCreate = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FanForumService();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
      final results = await Future.wait<dynamic>([
        _service.getForums(),
        _service.canCreateForum(),
      ]);
      if (!mounted) return;
      setState(() {
        _forums = results[0] as List<FanForum>;
        _canCreate = results[1] as bool;
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

  List<FanForum> get _visibleForums {
    final query = _searchController.text.trim().toLowerCase();
    return _forums.where((forum) {
      final membership = forum.myMembership;
      final matchesFilter = switch (_filter) {
        _ForumFilter.explore => true,
        _ForumFilter.mine => membership?.isActive == true,
        _ForumFilter.managed => forum.canModerate,
        _ForumFilter.invitations => membership?.status == 'invited',
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return '${forum.name} ${forum.description} '
              '${forum.owner?.displayName ?? ''} '
              '${forum.linkedWork?.title ?? ''}'
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  Future<void> _openForum(FanForum forum) async {
    await context.push('/forums/${forum.id}');
    _load();
  }

  Future<void> _createForum() async {
    if (!_canCreate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Publica al menos una obra para abrir una comunidad privada.',
          ),
        ),
      );
      return;
    }
    await context.push('/forums/create');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleForums;
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 700 ? 16 : 28,
          vertical: 26,
        ),
        child: CorvusPage(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ForumsHeader(
                canCreate: _canCreate,
                onCreate: _createForum,
              ),
              const SizedBox(height: 18),
              _ForumSummaryBand(forums: _forums),
              const SizedBox(height: 18),
              _ForumToolbar(
                controller: _searchController,
                selected: _filter,
                onChanged: (value) => setState(() => _filter = value),
                onSearch: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 90),
                  child: CorvusCrowLoader(
                    label: 'Abriendo comunidades privadas...',
                  ),
                )
              else if (_error != null)
                _ForumEmpty(
                  icon: Icons.cloud_off_outlined,
                  title: 'No se pudieron cargar los foros',
                  message: 'La comunidad no respondió. Intenta nuevamente.',
                  actionLabel: 'Reintentar',
                  onAction: _load,
                )
              else if (visible.isEmpty)
                _ForumEmpty(
                  icon: _filter == _ForumFilter.invitations
                      ? Icons.mark_email_unread_outlined
                      : Icons.forum_outlined,
                  title: _filter == _ForumFilter.invitations
                      ? 'No tienes invitaciones pendientes'
                      : 'No hay comunidades en esta vista',
                  message: _filter == _ForumFilter.explore
                      ? 'Los autores pueden abrir aquí espacios privados para sus lectores.'
                      : 'Cambia el filtro o explora nuevas comunidades.',
                  actionLabel: _canCreate ? 'Crear foro privado' : null,
                  onAction: _canCreate ? _createForum : null,
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1080
                        ? 3
                        : constraints.maxWidth >= 680
                            ? 2
                            : 1;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 12) / columns;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: visible.asMap().entries.map((entry) {
                        return SizedBox(
                          width: width,
                          child: CorvusReveal(
                            delay: Duration(
                              milliseconds: (entry.key * 60).clamp(0, 360),
                            ),
                            child: ForumCard(
                              forum: entry.value,
                              onTap: () => _openForum(entry.value),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForumsHeader extends StatelessWidget {
  final bool canCreate;
  final VoidCallback onCreate;

  const _ForumsHeader({required this.canCreate, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CÍRCULOS CORVUS',
              style: TextStyle(
                color: AppColors.primaryLight,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Foros privados de autores',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 27,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Conversaciones cercanas entre creadores, lectores y comunidades de fans.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.48),
                fontSize: 13,
              ),
            ),
          ],
        );
        final button = FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_comment_outlined, size: 18),
          label: Text(canCreate ? 'Crear foro privado' : 'Requisitos'),
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [title, const SizedBox(height: 14), button],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 18),
            button,
          ],
        );
      },
    );
  }
}

class _ForumSummaryBand extends StatelessWidget {
  final List<FanForum> forums;

  const _ForumSummaryBand({required this.forums});

  @override
  Widget build(BuildContext context) {
    final joined = forums.where((forum) => forum.canRead).length;
    final managed = forums.where((forum) => forum.canModerate).length;
    final invitations =
        forums.where((forum) => forum.myMembership?.status == 'invited').length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Wrap(
        spacing: 26,
        runSpacing: 10,
        children: [
          _ForumStat(
            icon: Icons.lock_outline_rounded,
            value: '${forums.length}',
            label: 'descubribles',
          ),
          _ForumStat(
            icon: Icons.groups_outlined,
            value: '$joined',
            label: 'tuyos',
          ),
          _ForumStat(
            icon: Icons.admin_panel_settings_outlined,
            value: '$managed',
            label: 'gestionados',
          ),
          _ForumStat(
            icon: Icons.mark_email_unread_outlined,
            value: '$invitations',
            label: 'invitaciones',
          ),
        ],
      ),
    );
  }
}

class _ForumStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _ForumStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppColors.primaryLight),
        const SizedBox(width: 7),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: AppColors.textMuted)),
      ],
    );
  }
}

class _ForumToolbar extends StatelessWidget {
  final TextEditingController controller;
  final _ForumFilter selected;
  final ValueChanged<_ForumFilter> onChanged;
  final ValueChanged<String> onSearch;

  const _ForumToolbar({
    required this.controller,
    required this.selected,
    required this.onChanged,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 500;
        final search = TextField(
          controller: controller,
          onChanged: onSearch,
          decoration: const InputDecoration(
            hintText: 'Buscar por comunidad, autor u obra',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        );
        final filters = SegmentedButton<_ForumFilter>(
          showSelectedIcon: false,
          style: compact
              ? const ButtonStyle(
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 9),
                  ),
                  visualDensity: VisualDensity.compact,
                )
              : null,
          segments: [
            ButtonSegment(
              value: _ForumFilter.explore,
              label: Text(compact ? 'Todos' : 'Explorar'),
            ),
            ButtonSegment(
              value: _ForumFilter.mine,
              label: Text(compact ? 'Míos' : 'Mis foros'),
            ),
            ButtonSegment(
              value: _ForumFilter.managed,
              label: Text('Gestiono'),
            ),
            ButtonSegment(
              value: _ForumFilter.invitations,
              label: Text(compact ? 'Invitadas' : 'Invitaciones'),
            ),
          ],
          selected: {selected},
          onSelectionChanged: (value) => onChanged(value.first),
        );
        if (constraints.maxWidth < 820) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: filters,
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: 12),
            filters,
          ],
        );
      },
    );
  }
}

class ForumCard extends StatelessWidget {
  final FanForum forum;
  final VoidCallback onTap;

  const ForumCard({
    super.key,
    required this.forum,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = forum.accentColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 246,
          decoration: BoxDecoration(
            color: AppColors.card.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: 0.24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 82,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ForumCardVisual(forum: forum),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.42),
                          ),
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          size: 17,
                          color: accent,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: _MembershipChip(forum: forum),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        forum.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        forum.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          UserAvatar(
                            imageUrl: forum.owner?.avatarUrl,
                            displayName: forum.owner?.displayName ?? 'Autor',
                            radius: 12,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              forum.owner?.displayName ?? 'Autor',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.group_outlined,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${forum.membersCount}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.forum_outlined,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${forum.threadsCount}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForumCardVisual extends StatelessWidget {
  final FanForum forum;

  const _ForumCardVisual({required this.forum});

  @override
  Widget build(BuildContext context) {
    final cover = forum.linkedWork?.coverUrl;
    if (cover != null && cover.isNotEmpty) {
      return ColoredBox(
        color: AppColors.background,
        child: CachedNetworkImage(
          imageUrl: cover,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorWidget: (_, __, ___) =>
              _ForumFallback(accent: forum.accentColor),
        ),
      );
    }
    return _ForumFallback(accent: forum.accentColor);
  }
}

class _ForumFallback extends StatelessWidget {
  final Color accent;

  const _ForumFallback({required this.accent});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        border: Border(
          bottom: BorderSide(color: accent.withValues(alpha: 0.20)),
        ),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 24),
          child: Icon(
            Icons.forum_outlined,
            size: 54,
            color: accent.withValues(alpha: 0.22),
          ),
        ),
      ),
    );
  }
}

class _MembershipChip extends StatelessWidget {
  final FanForum forum;

  const _MembershipChip({required this.forum});

  @override
  Widget build(BuildContext context) {
    final membership = forum.myMembership;
    final label = membership?.statusLabel ??
        (forum.isInviteOnly ? 'Solo invitación' : 'Acceso por solicitud');
    final color = membership?.isActive == true
        ? forum.accentColor
        : Colors.white.withValues(alpha: 0.70);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ForumEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ForumEmpty({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 54),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 38, color: AppColors.primaryLight),
          const SizedBox(height: 13),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
