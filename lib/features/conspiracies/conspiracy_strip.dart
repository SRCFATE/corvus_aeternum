import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/conspiracy_membership.dart';
import '../../services/conspiracy_service.dart';
import '../../shared/widgets/conspiracy_emblem.dart';

/// Vitrina de Casas para perfiles propios y públicos.
class ConspiracyStrip extends StatefulWidget {
  final String profileId;
  final bool isOwnProfile;

  const ConspiracyStrip({
    super.key,
    required this.profileId,
    required this.isOwnProfile,
  });

  @override
  State<ConspiracyStrip> createState() => _ConspiracyStripState();
}

class _ConspiracyStripState extends State<ConspiracyStrip> {
  final _service = ConspiracyService();
  EffectiveMemberships? _memberships;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ConspiracyStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId ||
        oldWidget.isOwnProfile != widget.isOwnProfile) {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loaded = false);
    try {
      final memberships = widget.isOwnProfile
          ? await _service.getEffectiveMemberships()
          : await _service.getProfileEmblems(widget.profileId);
      if (mounted) {
        setState(() {
          _memberships = memberships;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _memberships = null;
          _loaded = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Container(
        height: 112,
        decoration: _sectionDecoration(),
        alignment: Alignment.center,
        child: const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final memberships = _memberships;
    if (memberships == null) {
      return _ConspiracyUnavailable(
        onRetry: _load,
        onOpenRegistry: () => context.push('/conspiracies'),
      );
    }

    return ProfileConspiracyEmblems(
      memberships: memberships,
      isOwnProfile: widget.isOwnProfile,
      onOpenRegistry: () async {
        await context.push('/conspiracies');
        _load();
      },
    );
  }
}

class ProfileConspiracyEmblems extends StatelessWidget {
  final EffectiveMemberships memberships;
  final bool isOwnProfile;
  final VoidCallback onOpenRegistry;

  const ProfileConspiracyEmblems({
    super.key,
    required this.memberships,
    required this.isOwnProfile,
    required this.onOpenRegistry,
  });

  @override
  Widget build(BuildContext context) {
    final entries = _entries();
    final primaryName = memberships.primary?.house.shortName;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _sectionDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final badgeWidth = constraints.maxWidth < 270
              ? constraints.maxWidth
              : compact
                  ? (constraints.maxWidth - 8) / 2
                  : 190.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EmblemsHeader(
                count: entries.length,
                description: primaryName != null
                    ? '${isOwnProfile ? 'Tu' : 'Su'} Casa primaria es $primaryName.'
                    : isOwnProfile
                        ? 'Tu raíz está presente. Aún no has elegido Casa primaria.'
                        : 'La raíz está presente. Aún no hay Casa primaria.',
                onOpenRegistry: onOpenRegistry,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in entries)
                    _ProfileEmblemBadge(
                      entry: entry,
                      width: badgeWidth,
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  List<_ProfileEmblemEntry> _entries() {
    final entries = <_ProfileEmblemEntry>[];
    final included = <String>{};

    void add(
      ConspiracySummary? house,
      String role, {
      bool emphasized = false,
    }) {
      if (house == null || !included.add(house.id)) return;
      entries.add(
        _ProfileEmblemEntry(
          house: house,
          role: role,
          emphasized: emphasized,
        ),
      );
    }

    add(memberships.root, 'Raíz');
    add(
      memberships.primary?.house,
      'Casa primaria',
      emphasized: true,
    );
    for (final membership in memberships.secondaries) {
      add(membership.house, 'Casa secundaria');
    }
    for (final house in memberships.unlocks) {
      add(
        house,
        house.rarity == 'legendary' ? 'Legendaria' : 'Conquistada',
      );
    }
    return entries;
  }
}

class _EmblemsHeader extends StatelessWidget {
  final int count;
  final String description;
  final VoidCallback onOpenRegistry;

  const _EmblemsHeader({
    required this.count,
    required this.description,
    required this.onOpenRegistry,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 10,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 7,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(
                    Icons.workspace_premium_outlined,
                    size: 17,
                    color: AppColors.primary,
                  ),
                  const Text(
                    'EMBLEMAS DE CONSPIRACIÓN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.46),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onOpenRegistry,
          icon: const Icon(Icons.auto_stories_outlined, size: 16),
          label: const Text('Abrir Registro'),
        ),
      ],
    );
  }
}

class _ProfileEmblemBadge extends StatelessWidget {
  final _ProfileEmblemEntry entry;
  final double width;

  const _ProfileEmblemBadge({
    required this.entry,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final house = entry.house;
    final accent = house.accentColor;
    return Semantics(
      container: true,
      label: '${house.shortName}, ${entry.role}',
      child: Container(
        width: width,
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: entry.emphasized ? 0.13 : 0.055),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: accent.withValues(alpha: entry.emphasized ? 0.58 : 0.25),
          ),
        ),
        child: Row(
          children: [
            ConspiracyEmblem(
              code: house.code,
              symbol: house.symbol,
              label: house.shortName,
              rarity: house.rarity,
              accent: accent,
              size: 46,
              glowing: entry.emphasized || house.rarity == 'legendary',
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    house.shortName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConspiracyUnavailable extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onOpenRegistry;

  const _ConspiracyUnavailable({
    required this.onRetry,
    required this.onOpenRegistry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _sectionDecoration(),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Los emblemas del perfil no están disponibles.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
            ),
          ),
          IconButton(
            tooltip: 'Reintentar',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Abrir Registro',
            onPressed: onOpenRegistry,
            icon: const Icon(Icons.auto_stories_outlined),
          ),
        ],
      ),
    );
  }
}

class _ProfileEmblemEntry {
  final ConspiracySummary house;
  final String role;
  final bool emphasized;

  const _ProfileEmblemEntry({
    required this.house,
    required this.role,
    required this.emphasized,
  });
}

BoxDecoration _sectionDecoration() {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.028),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Colors.white.withValues(alpha: 0.075)),
  );
}
