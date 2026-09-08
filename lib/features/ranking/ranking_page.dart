import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/corvus_design.dart';
import '../../models/artist_ranking.dart';
import '../../providers/auth_provider.dart';
import '../../providers/conspiration_provider.dart';
import '../../services/profile_service.dart';
import '../../shared/layout/corvus_page.dart';
import '../../shared/widgets/corvus_crow_animations.dart';
import '../../shared/widgets/corvus_empty_state.dart';
import '../../shared/widgets/corvus_motion.dart';
import '../../shared/widgets/user_avatar.dart';

const _rankingDisciplines = [
  'Todas',
  'Pintura',
  'Fotografía',
  'Ilustración',
  'Arte Digital',
  'Escultura',
  'Música',
  'Literatura',
  'Cine',
  'Diseño',
];

class RankingPage extends StatefulWidget {
  final ProfileService? service;

  const RankingPage({super.key, this.service});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  late final ProfileService _service;

  List<ArtistRankingEntry> _entries = const [];
  String _discipline = 'Todas';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProfileService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _service.getArtistRanking(
        discipline: _discipline == 'Todas' ? null : _discipline,
      );
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No pudimos abrir la clasificación en este momento.';
      });
    }
  }

  void _selectDiscipline(String discipline) {
    if (discipline == _discipline) return;
    setState(() => _discipline = discipline);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<ConspirationProvider>().accent;
    final currentProfileId = context.watch<AuthProvider>().profile?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: accent,
        onRefresh: _load,
        child: CorvusPage(
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.only(top: 30, bottom: 22),
                sliver: SliverToBoxAdapter(
                  child: CorvusReveal(
                    child: _RankingHeader(
                      accent: accent,
                      count: _entries.length,
                      onMethodology: () => _showMethodology(context, accent),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _DisciplineRail(
                  selected: _discipline,
                  accent: accent,
                  onSelect: _selectDiscipline,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CorvusCrowLoader(label: 'Calculando el índice...'),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: CorvusEmptyState(
                    icon: Icons.query_stats_rounded,
                    title: 'El índice está en pausa',
                    subtitle: _error!,
                    actionText: 'Intentar de nuevo',
                    onAction: _load,
                  ),
                )
              else if (_entries.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: CorvusEmptyState(
                    icon: Icons.workspace_premium_outlined,
                    title: 'Aún no hay trayectorias',
                    subtitle:
                        'La primera obra publicada inaugurará esta edición.',
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: CorvusReveal(
                    delay: const Duration(milliseconds: 80),
                    child: _Podium(
                      entries: _entries.take(3).toList(),
                      accent: accent,
                      currentProfileId: currentProfileId,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 38)),
                SliverToBoxAdapter(
                  child: CorvusSectionLabel(
                    label: 'Clasificación completa',
                    count: _entries.length,
                    accent: accent,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),
                SliverList.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CorvusScrollReveal(
                      index: index,
                      offset: 14,
                      child: _RankingRow(
                        entry: _entries[index],
                        accent: accent,
                        isCurrent:
                            _entries[index].profile.id == currentProfileId,
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 52)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showMethodology(BuildContext context, Color accent) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MethodologySheet(accent: accent),
    );
  }
}

class _RankingHeader extends StatelessWidget {
  final Color accent;
  final int count;
  final VoidCallback onMethodology;

  const _RankingHeader({
    required this.accent,
    required this.count,
    required this.onMethodology,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.15),
            AppColors.card.withValues(alpha: 0.78),
            AppColors.surface.withValues(alpha: 0.90),
          ],
        ),
        borderRadius: BorderRadius.circular(CorvusRadius.lg),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
        boxShadow: CorvusElevation.medium,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -36,
            child: Icon(
              Icons.workspace_premium_outlined,
              size: 170,
              color: accent.withValues(alpha: 0.055),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 650;
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EDICIÓN PERMANENTE · ARCHIVO CORVUS',
                    style: CorvusType.eyebrow(accent, alpha: 0.86),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Índice Aeternum',
                    style: CorvusType.display.copyWith(
                      fontSize: narrow ? 34 : 46,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Text(
                      'Una lectura viva de las trayectorias que dan forma al archivo: creación, recepción y comunidad en una sola medida.',
                      style: CorvusType.body.copyWith(fontSize: 14.5),
                    ),
                  ),
                ],
              );

              final action = OutlinedButton.icon(
                onPressed: onMethodology,
                icon: const Icon(Icons.menu_book_outlined, size: 17),
                label: Text(
                    count > 0 ? 'Cómo se calcula · $count' : 'Cómo se calcula'),
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    copy,
                    const SizedBox(height: 22),
                    action,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 24),
                  action,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DisciplineRail extends StatelessWidget {
  final String selected;
  final Color accent;
  final ValueChanged<String> onSelect;

  const _DisciplineRail({
    required this.selected,
    required this.accent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _rankingDisciplines.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final discipline = _rankingDisciplines[index];
          final active = selected == discipline;
          return Semantics(
            button: true,
            selected: active,
            child: CorvusPressable(
              hoverScale: 1,
              hoverLift: 0,
              pressedScale: 0.96,
              onTap: () => onSelect(discipline),
              child: AnimatedContainer(
                duration: CorvusMotion.fast,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: active
                      ? accent.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.035),
                  borderRadius: BorderRadius.circular(CorvusRadius.pill),
                  border: Border.all(
                    color: active
                        ? accent.withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  discipline,
                  style: TextStyle(
                    color: active ? accent : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<ArtistRankingEntry> entries;
  final Color accent;
  final String? currentProfileId;

  const _Podium({
    required this.entries,
    required this.accent,
    required this.currentProfileId,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ordered = entries.length == 3
            ? [entries[1], entries[0], entries[2]]
            : entries;
        if (constraints.maxWidth < 720) {
          return Column(
            children: [
              for (final entry in entries) ...[
                _PodiumCard(
                  entry: entry,
                  accent: accent,
                  isCurrent: entry.profile.id == currentProfileId,
                ),
                if (entry != entries.last) const SizedBox(height: 10),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final entry in ordered) ...[
              Expanded(
                child: _PodiumCard(
                  entry: entry,
                  accent: accent,
                  isCurrent: entry.profile.id == currentProfileId,
                  emphasized: entry.position == 1,
                ),
              ),
              if (entry != ordered.last) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final ArtistRankingEntry entry;
  final Color accent;
  final bool isCurrent;
  final bool emphasized;

  const _PodiumCard({
    required this.entry,
    required this.accent,
    required this.isCurrent,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final profile = entry.profile;
    final medal = _medalColor(entry.position);
    return CorvusPressable(
      onTap: () => context.push('/artist/${profile.id}'),
      glow: medal,
      borderRadius: BorderRadius.circular(CorvusRadius.lg),
      child: Container(
        padding: EdgeInsets.fromLTRB(18, emphasized ? 28 : 20, 18, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              medal.withValues(alpha: emphasized ? 0.20 : 0.10),
              AppColors.card.withValues(alpha: 0.92),
            ],
          ),
          borderRadius: BorderRadius.circular(CorvusRadius.lg),
          border: Border.all(
            color: isCurrent
                ? accent.withValues(alpha: 0.72)
                : medal.withValues(alpha: 0.32),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  entry.position.toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: medal,
                    fontFamily: 'serif',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (isCurrent)
                  Text('TÚ', style: CorvusType.eyebrow(accent, alpha: 0.9)),
                Icon(Icons.arrow_outward_rounded,
                    size: 16, color: Colors.white.withValues(alpha: 0.28)),
              ],
            ),
            SizedBox(height: emphasized ? 18 : 14),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: medal.withValues(alpha: 0.6)),
              ),
              child: UserAvatar(
                imageUrl: profile.avatarUrl,
                displayName: profile.displayName,
                radius: emphasized ? 42 : 36,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              profile.displayName.isEmpty
                  ? profile.username
                  : profile.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CorvusType.subtitle.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 3),
            Text('@${profile.username}', style: CorvusType.muted),
            const SizedBox(height: 14),
            Text(
              '${entry.score} pts',
              style: TextStyle(
                color: medal,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              entry.circle.shortLabel.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final ArtistRankingEntry entry;
  final Color accent;
  final bool isCurrent;

  const _RankingRow({
    required this.entry,
    required this.accent,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final profile = entry.profile;
    return CorvusPressable(
      onTap: () => context.push('/artist/${profile.id}'),
      hoverScale: 1.002,
      hoverLift: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isCurrent
              ? accent.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(CorvusRadius.md),
          border: Border.all(
            color: isCurrent
                ? accent.withValues(alpha: 0.42)
                : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              child: Text(
                entry.position.toString().padLeft(2, '0'),
                style: TextStyle(
                  color: entry.position <= 3
                      ? _medalColor(entry.position)
                      : AppColors.textMuted,
                  fontFamily: 'serif',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            UserAvatar(
              imageUrl: profile.avatarUrl,
              displayName: profile.displayName,
              radius: 21,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.displayName.isEmpty
                              ? profile.username
                              : profile.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (profile.isArtistVerified) ...[
                        const SizedBox(width: 5),
                        Icon(Icons.verified_rounded, color: accent, size: 14),
                      ],
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Text('TÚ', style: CorvusType.eyebrow(accent)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${entry.circle.label} · ${profile.worksCount} obras · ${profile.totalLikesReceived} reconocimientos',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CorvusType.muted.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.score}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text('PUNTOS', style: CorvusType.eyebrow(accent, alpha: 0.5)),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: Colors.white.withValues(alpha: 0.24)),
          ],
        ),
      ),
    );
  }
}

class _MethodologySheet extends StatelessWidget {
  final Color accent;

  const _MethodologySheet({required this.accent});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 26),
            decoration: BoxDecoration(
              color: AppColors.cardElevated,
              borderRadius: BorderRadius.circular(CorvusRadius.xl),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
              boxShadow: CorvusElevation.high,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('NOTA EDITORIAL',
                      style: CorvusType.eyebrow(accent, alpha: 0.9)),
                  const SizedBox(height: 8),
                  Text('Cómo se compone el índice', style: CorvusType.title),
                  const SizedBox(height: 10),
                  Text(
                    'El Índice Aeternum combina cuatro señales públicas. La comunidad y los reconocimientos tienen rendimiento decreciente; así, el volumen nunca borra el trabajo sostenido.',
                    style: CorvusType.body,
                  ),
                  const SizedBox(height: 20),
                  _MethodRow(
                    icon: Icons.auto_stories_outlined,
                    title: 'Obra publicada',
                    description: '15 puntos por obra, hasta 100 obras.',
                    accent: accent,
                  ),
                  _MethodRow(
                    icon: Icons.favorite_border_rounded,
                    title: 'Reconocimiento',
                    description: 'Recepción acumulada con escala progresiva.',
                    accent: accent,
                  ),
                  _MethodRow(
                    icon: Icons.people_alt_outlined,
                    title: 'Comunidad',
                    description: 'Seguidores con peso moderado y decreciente.',
                    accent: accent,
                  ),
                  _MethodRow(
                    icon: Icons.collections_bookmark_outlined,
                    title: 'Curaduría y verificación',
                    description:
                        'Colecciones creadas y autenticidad de la trayectoria.',
                    accent: accent,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Entendido'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MethodRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color accent;

  const _MethodRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(CorvusRadius.sm),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: CorvusType.subtitle),
                const SizedBox(height: 3),
                Text(description, style: CorvusType.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _medalColor(int position) => switch (position) {
      1 => AppColors.gold,
      2 => AppColors.silver,
      3 => AppColors.bronze,
      _ => AppColors.textMuted,
    };
