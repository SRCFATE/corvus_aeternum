import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/arena.dart';
import '../../models/work.dart';
import '../../providers/auth_provider.dart';
import '../../services/arena_service.dart';
import '../../services/work_service.dart';
import '../../shared/layout/corvus_page.dart';
import '../../shared/widgets/corvus_crow_animations.dart';
import '../../shared/widgets/corvus_markdown_preview.dart';
import '../../shared/widgets/formatted_manuscript_text.dart';
import '../../shared/widgets/corvus_motion.dart';

enum _ArenaFilter { active, duels, history }

class ArenaPage extends StatefulWidget {
  final ArenaService? service;
  final String? profileIdOverride;

  const ArenaPage({
    super.key,
    this.service,
    this.profileIdOverride,
  });

  @override
  State<ArenaPage> createState() => _ArenaPageState();
}

class _ArenaPageState extends State<ArenaPage> {
  late final ArenaService _service;
  List<ArenaChallenge> _challenges = const [];
  _ArenaFilter _filter = _ArenaFilter.active;
  bool _loading = true;
  String? _error;
  String? _loadedForProfile;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ArenaService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profileId =
        widget.profileIdOverride ?? context.read<AuthProvider>().profile?.id;
    if (profileId != null && profileId != _loadedForProfile) {
      _loadedForProfile = profileId;
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final challenges = await _service.getChallenges();
      if (!mounted) return;
      setState(() {
        _challenges = challenges;
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

  List<ArenaChallenge> get _visibleChallenges => switch (_filter) {
        _ArenaFilter.active => _challenges
            .where((item) =>
                item.effectiveStatus == 'open' ||
                item.effectiveStatus == 'voting')
            .toList(),
        _ArenaFilter.duels => _challenges
            .where((item) =>
                item.isDuel &&
                item.effectiveStatus != 'closed' &&
                item.effectiveStatus != 'cancelled')
            .toList(),
        _ArenaFilter.history => _challenges
            .where((item) =>
                item.effectiveStatus == 'closed' ||
                item.effectiveStatus == 'cancelled')
            .toList(),
      };

  Future<void> _createChallenge(String profileId) async {
    final result = await showDialog<_ChallengeDraft>(
      context: context,
      builder: (_) => const _CreateChallengeDialog(),
    );
    if (result == null) return;
    try {
      await _service.createChallenge(
        profileId: profileId,
        title: result.title,
        brief: result.brief,
        format: result.format,
        discipline: result.discipline,
        theme: result.theme,
        rules: result.rules,
        prizeDescription: result.prize,
        endsAt: DateTime.now().add(Duration(days: result.durationDays)),
        maxEntries: result.maxEntries,
      );
      await _load();
      if (!mounted) return;
      await showCrowFlight(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el desafio: $error')));
    }
  }

  Future<void> _openChallenge(
      ArenaChallenge challenge, String profileId) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ArenaDetailDialog(
        challenge: challenge,
        profileId: profileId,
        service: _service,
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profileIdOverride == null
        ? context.watch<AuthProvider>().profile
        : null;
    final profileId = widget.profileIdOverride ?? profile?.id;
    if (profileId == null) {
      return const Center(
          child: Text('Inicia sesion para entrar a Arena Corvus.',
              style: TextStyle(color: AppColors.textSecondary)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
            vertical: 26,
            horizontal: MediaQuery.sizeOf(context).width < 700 ? 16 : 28),
        child: CorvusPage(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ArenaHeader(onCreate: () => _createChallenge(profileId)),
              const SizedBox(height: 18),
              _ArenaStatusBand(challenges: _challenges),
              const SizedBox(height: 18),
              _ArenaFilterBar(
                  selected: _filter,
                  onSelected: (value) => setState(() => _filter = value)),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: CorvusCrowLoader(label: 'Convocando la Arena'))
              else if (_error != null)
                _ArenaMessage(
                    icon: Icons.cloud_off_outlined,
                    title: 'No se pudo abrir la Arena',
                    message: _error!,
                    onRetry: _load)
              else if (_visibleChallenges.isEmpty)
                _ArenaMessage(
                    icon: Icons.emoji_events_outlined,
                    title: 'No hay convocatorias en esta vista',
                    message:
                        'Crea un desafio o cambia el filtro para consultar la historia de la Arena.')
              else
                LayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1060
                      ? 3
                      : constraints.maxWidth >= 680
                          ? 2
                          : 1;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 12) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _visibleChallenges
                        .asMap()
                        .entries
                        .map((entry) => SizedBox(
                              width: width,
                              child: CorvusReveal(
                                delay: Duration(
                                    milliseconds:
                                        (entry.key * 65).clamp(0, 390)),
                                child: _ChallengeCard(
                                    challenge: entry.value,
                                    onTap: () =>
                                        _openChallenge(entry.value, profileId)),
                              ),
                            ))
                        .toList(),
                  );
                }),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArenaHeader extends StatelessWidget {
  final VoidCallback onCreate;
  const _ArenaHeader({required this.onCreate});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 620;
      final title = const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ARENA CORVUS',
              style: TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w900)),
          SizedBox(height: 7),
          Text('Desafios y duelos de arte',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  height: 1.1)),
          SizedBox(height: 6),
          Text(
              'Convocatorias abiertas, obra presentada y voto de la comunidad.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      );
      final button = FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded, size: 19),
          label: const Text('Crear desafio'));
      if (compact) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [title, const SizedBox(height: 14), button]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: title),
        const SizedBox(width: 16),
        button
      ]);
    });
  }
}

class _ArenaStatusBand extends StatelessWidget {
  final List<ArenaChallenge> challenges;
  const _ArenaStatusBand({required this.challenges});
  @override
  Widget build(BuildContext context) {
    final active =
        challenges.where((item) => item.effectiveStatus == 'open').length;
    final voting =
        challenges.where((item) => item.effectiveStatus == 'voting').length;
    final entries =
        challenges.fold<int>(0, (sum, item) => sum + item.entriesCount);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07))),
      child: Wrap(
        spacing: 24,
        runSpacing: 10,
        children: [
          _ArenaStat(
              icon: Icons.local_fire_department_outlined,
              value: '$active',
              label: 'abiertos',
              color: AppColors.primaryLight),
          _ArenaStat(
              icon: Icons.how_to_vote_outlined,
              value: '$voting',
              label: 'en votacion',
              color: AppColors.gold),
          _ArenaStat(
              icon: Icons.palette_outlined,
              value: '$entries',
              label: 'participaciones',
              color: AppColors.secondaryLight),
        ],
      ),
    );
  }
}

class _ArenaStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _ArenaStat(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 7),
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w900)),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12))
      ]);
}

class _ArenaFilterBar extends StatelessWidget {
  final _ArenaFilter selected;
  final ValueChanged<_ArenaFilter> onSelected;
  const _ArenaFilterBar({required this.selected, required this.onSelected});
  @override
  Widget build(BuildContext context) => SegmentedButton<_ArenaFilter>(
        segments: const [
          ButtonSegment(
              value: _ArenaFilter.active,
              icon: Icon(Icons.bolt_rounded),
              label: Text('Abiertos')),
          ButtonSegment(
              value: _ArenaFilter.duels,
              icon: Icon(Icons.compare_arrows_rounded),
              label: Text('Duelos')),
          ButtonSegment(
              value: _ArenaFilter.history,
              icon: Icon(Icons.history_rounded),
              label: Text('Historial')),
        ],
        selected: {selected},
        onSelectionChanged: (values) => onSelected(values.first),
      );
}

class _ChallengeCard extends StatefulWidget {
  final ArenaChallenge challenge;
  final VoidCallback onTap;
  const _ChallengeCard({required this.challenge, required this.onTap});
  @override
  State<_ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends State<_ChallengeCard> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: AnimatedScale(
        scale: hovered && !MediaQuery.disableAnimationsOf(context) ? 1.015 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 286,
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: AppColors.card.withValues(alpha: hovered ? 0.94 : 0.78),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: hovered
                        ? AppColors.primary.withValues(alpha: 0.38)
                        : Colors.white.withValues(alpha: 0.07)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _ArenaBadge(
                          label: challenge.isDuel ? 'DUELO' : 'DESAFIO',
                          color: challenge.isDuel
                              ? AppColors.gold
                              : AppColors.primaryLight),
                      const Spacer(),
                      Text(_remaining(challenge),
                          style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 15),
                    Text(challenge.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1.2)),
                    const SizedBox(height: 7),
                    Text(challenge.brief,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                            height: 1.45)),
                    const Spacer(),
                    if (challenge.theme.isNotEmpty)
                      Row(children: [
                        const Icon(Icons.auto_awesome_outlined,
                            size: 15, color: AppColors.secondaryLight),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(challenge.theme,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)))
                      ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.palette_outlined,
                          size: 15, color: AppColors.textMuted),
                      const SizedBox(width: 5),
                      Expanded(
                          child: Text(challenge.discipline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 11.5))),
                      const Icon(Icons.groups_2_outlined,
                          size: 15, color: AppColors.textMuted),
                      const SizedBox(width: 5),
                      Text('${challenge.entriesCount}/${challenge.maxEntries}',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11.5)),
                    ]),
                  ]),
            ),
          ),
        ),
      ),
    );
  }

  String _remaining(ArenaChallenge challenge) {
    if (challenge.effectiveStatus == 'closed') return 'Cerrado';
    if (challenge.effectiveStatus == 'voting') return 'En votacion';
    final duration = challenge.endsAt.difference(DateTime.now());
    if (duration.isNegative) return 'Finalizado';
    if (duration.inDays > 0) return '${duration.inDays} d restantes';
    return '${duration.inHours.clamp(1, 23)} h restantes';
  }
}

class _ArenaBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _ArenaBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.32))),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9.5, fontWeight: FontWeight.w900)));
}

class _ArenaDetailDialog extends StatefulWidget {
  final ArenaChallenge challenge;
  final String profileId;
  final ArenaService service;
  const _ArenaDetailDialog(
      {required this.challenge,
      required this.profileId,
      required this.service});
  @override
  State<_ArenaDetailDialog> createState() => _ArenaDetailDialogState();
}

class _ArenaDetailDialogState extends State<_ArenaDetailDialog> {
  List<ArenaEntry> entries = const [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await widget.service
          .getEntries(widget.challenge.id, viewerId: widget.profileId);
      if (mounted) {
        setState(() {
          entries = value;
          loading = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  Future<void> _toggleVote(ArenaEntry entry) async {
    try {
      if (entry.votedByMe) {
        await widget.service
            .removeVote(entryId: entry.id, voterProfileId: widget.profileId);
      } else {
        await widget.service
            .castVote(entryId: entry.id, voterProfileId: widget.profileId);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo registrar el voto: $e')));
      }
    }
  }

  Future<void> _join() async {
    final joined = await showDialog<bool>(
        context: context,
        builder: (_) => _SubmitEntryDialog(
            challenge: widget.challenge,
            profileId: widget.profileId,
            service: widget.service));
    if (joined == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final myEntry = entries.any((entry) => entry.profileId == widget.profileId);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _ArenaBadge(
                        label: widget.challenge.isDuel ? 'DUELO' : 'DESAFIO',
                        color: widget.challenge.isDuel
                            ? AppColors.gold
                            : AppColors.primaryLight),
                    const SizedBox(height: 9),
                    Text(widget.challenge.title,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                  ])),
              if (widget.challenge.acceptsEntries && !myEntry)
                FilledButton.icon(
                    onPressed: _join,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Participar')),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          Expanded(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FormattedManuscriptText(
                            text: widget.challenge.brief,
                            fontSize: 14,
                            lineHeight: 1.55),
                        if (widget.challenge.rules.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text('Reglas',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 7),
                          ...widget.challenge.rules.map((rule) => Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ',
                                        style:
                                            TextStyle(color: AppColors.gold)),
                                    Expanded(
                                        child: Text(rule,
                                            style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 12.5)))
                                  ]))),
                        ],
                        const SizedBox(height: 22),
                        Text('Participaciones (${entries.length})',
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        if (loading)
                          const CorvusCrowLoader(label: 'Cargando obras')
                        else if (error != null)
                          Text(error!,
                              style:
                                  const TextStyle(color: AppColors.errorLight))
                        else if (entries.isEmpty)
                          const Text('Aun no se han presentado obras.',
                              style: TextStyle(color: AppColors.textMuted))
                        else
                          LayoutBuilder(builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 680 ? 2 : 1;
                            final width =
                                (constraints.maxWidth - (columns - 1) * 10) /
                                    columns;
                            return Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: entries
                                    .map((entry) => SizedBox(
                                        width: width,
                                        child: _ArenaEntryTile(
                                            entry: entry,
                                            canVote: entry.profileId !=
                                                    widget.profileId &&
                                                widget.challenge.acceptsVotes,
                                            onVote: () => _toggleVote(entry))))
                                    .toList());
                          }),
                      ]))),
        ]),
      ),
    );
  }
}

class _ArenaEntryTile extends StatelessWidget {
  final ArenaEntry entry;
  final bool canVote;
  final VoidCallback onVote;
  const _ArenaEntryTile(
      {required this.entry, required this.canVote, required this.onVote});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                  width: 78,
                  height: 92,
                  child: entry.imageUrl.isEmpty
                      ? const ColoredBox(
                          color: AppColors.cardElevated,
                          child: Icon(Icons.palette_outlined,
                              color: AppColors.gold))
                      : CachedNetworkImage(
                          imageUrl: entry.imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const ColoredBox(
                              color: AppColors.cardElevated,
                              child: Icon(Icons.broken_image_outlined))))),
          const SizedBox(width: 11),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                    entry.profileDisplayName ??
                        entry.profileUsername ??
                        'Artista Corvus',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11.5)),
                const SizedBox(height: 8),
                Row(children: [
                  IconButton.filledTonal(
                      tooltip: entry.votedByMe ? 'Retirar voto' : 'Votar',
                      onPressed: canVote ? onVote : null,
                      icon: Icon(
                          entry.votedByMe
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 18)),
                  const SizedBox(width: 6),
                  Text('${entry.votesCount} votos',
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              ])),
        ]),
      );
}

class _SubmitEntryDialog extends StatefulWidget {
  final ArenaChallenge challenge;
  final String profileId;
  final ArenaService service;
  const _SubmitEntryDialog(
      {required this.challenge,
      required this.profileId,
      required this.service});
  @override
  State<_SubmitEntryDialog> createState() => _SubmitEntryDialogState();
}

class _SubmitEntryDialogState extends State<_SubmitEntryDialog> {
  final statement = TextEditingController();
  List<Work> works = const [];
  String? selectedId;
  bool loading = true;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await WorkService().getOwnWorks(widget.profileId);
    if (mounted) {
      setState(() {
        works = value;
        selectedId = value.firstOrNull?.id;
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    statement.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = selectedId;
    if (id == null || saving) return;
    final work = works.firstWhere((item) => item.id == id);
    setState(() => saving = true);
    try {
      await widget.service.submitEntry(
          challengeId: widget.challenge.id,
          profileId: widget.profileId,
          workId: work.id,
          title: work.title,
          statement: statement.text,
          mediaUrl: work.displayImage.isEmpty ? null : work.displayImage);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo presentar la obra: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Presentar obra'),
        content: SizedBox(
            width: 560,
            child: loading
                ? const CorvusCrowLoader(label: 'Abriendo tus obras')
                : works.isEmpty
                    ? const Text(
                        'Publica o guarda una obra antes de entrar a la Arena.')
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        DropdownButtonFormField<String>(
                            initialValue: selectedId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'Obra participante'),
                            items: works
                                .map((work) => DropdownMenuItem(
                                    value: work.id,
                                    child: Text(work.title,
                                        overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => selectedId = value)),
                        const SizedBox(height: 12),
                        CorvusMarkdownFieldPreview(
                            controller: statement,
                            child: TextField(
                                controller: statement,
                                minLines: 3,
                                maxLines: 6,
                                decoration: const InputDecoration(
                                    labelText: 'Declaracion de la pieza',
                                    alignLabelWithHint: true))),
                      ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton.icon(
              onPressed: works.isEmpty || saving ? null : _submit,
              icon: const Icon(Icons.outbox_outlined, size: 18),
              label: Text(saving ? 'Presentando' : 'Presentar'))
        ],
      );
}

class _CreateChallengeDialog extends StatefulWidget {
  const _CreateChallengeDialog();
  @override
  State<_CreateChallengeDialog> createState() => _CreateChallengeDialogState();
}

class _CreateChallengeDialogState extends State<_CreateChallengeDialog> {
  final title = TextEditingController();
  final brief = TextEditingController();
  final discipline = TextEditingController();
  final theme = TextEditingController();
  final rules = TextEditingController();
  final prize = TextEditingController();
  String format = 'challenge';
  int duration = 7;
  int maxEntries = 50;
  @override
  void dispose() {
    title.dispose();
    brief.dispose();
    discipline.dispose();
    theme.dispose();
    rules.dispose();
    prize.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Nueva convocatoria'),
        content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'challenge',
                        icon: Icon(Icons.emoji_events_outlined),
                        label: Text('Desafio')),
                    ButtonSegment(
                        value: 'duel',
                        icon: Icon(Icons.compare_arrows_rounded),
                        label: Text('Duelo'))
                  ],
                  selected: {
                    format
                  },
                  onSelectionChanged: (value) =>
                      setState(() => format = value.first)),
              const SizedBox(height: 14),
              TextField(
                  controller: title,
                  decoration: const InputDecoration(
                      labelText: 'Titulo de la convocatoria')),
              const SizedBox(height: 12),
              CorvusMarkdownFieldPreview(
                  controller: brief,
                  child: TextField(
                      controller: brief,
                      minLines: 4,
                      maxLines: 7,
                      decoration: const InputDecoration(
                          labelText: 'Consigna creativa',
                          alignLabelWithHint: true))),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: discipline,
                        decoration:
                            const InputDecoration(labelText: 'Disciplina'))),
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                        controller: theme,
                        decoration: const InputDecoration(labelText: 'Tema')))
              ]),
              const SizedBox(height: 12),
              TextField(
                  controller: rules,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                      labelText: 'Reglas, una por linea',
                      alignLabelWithHint: true)),
              const SizedBox(height: 12),
              TextField(
                  controller: prize,
                  decoration: const InputDecoration(
                      labelText: 'Reconocimiento o premio')),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, constraints) {
                final durationField = DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: duration,
                    decoration: const InputDecoration(labelText: 'Duracion'),
                    items: const [3, 7, 14, 30]
                        .map((days) => DropdownMenuItem(
                            value: days,
                            child: Text('$days dias',
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => duration = value ?? duration));
                final capacityField = DropdownButtonFormField<int>(
                    key: ValueKey(format),
                    isExpanded: true,
                    initialValue: format == 'duel' ? 2 : maxEntries,
                    decoration: const InputDecoration(labelText: 'Cupo'),
                    items:
                        (format == 'duel' ? const [2] : const [10, 25, 50, 100])
                            .map((count) => DropdownMenuItem(
                                value: count,
                                child: Text('$count artistas',
                                    overflow: TextOverflow.ellipsis)))
                            .toList(),
                    onChanged: (value) =>
                        setState(() => maxEntries = value ?? maxEntries));
                if (constraints.maxWidth < 430) {
                  return Column(children: [
                    durationField,
                    const SizedBox(height: 10),
                    capacityField,
                  ]);
                }
                return Row(children: [
                  Expanded(child: durationField),
                  const SizedBox(width: 10),
                  Expanded(child: capacityField),
                ]);
              }),
            ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () {
                if (title.text.trim().length < 3 || brief.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(
                    context,
                    _ChallengeDraft(
                        title: title.text,
                        brief: brief.text,
                        format: format,
                        discipline: discipline.text,
                        theme: theme.text,
                        rules: rules.text
                            .split('\n')
                            .map((value) => value.trim())
                            .where((value) => value.isNotEmpty)
                            .toList(),
                        prize: prize.text,
                        durationDays: duration,
                        maxEntries: format == 'duel' ? 2 : maxEntries));
              },
              child: const Text('Abrir convocatoria')),
        ],
      );
}

class _ChallengeDraft {
  final String title;
  final String brief;
  final String format;
  final String discipline;
  final String theme;
  final List<String> rules;
  final String prize;
  final int durationDays;
  final int maxEntries;
  const _ChallengeDraft(
      {required this.title,
      required this.brief,
      required this.format,
      required this.discipline,
      required this.theme,
      required this.rules,
      required this.prize,
      required this.durationDays,
      required this.maxEntries});
}

class _ArenaMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;
  const _ArenaMessage(
      {required this.icon,
      required this.title,
      required this.message,
      this.onRetry});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
      decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.64),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07))),
      child: Column(children: [
        Icon(icon, size: 36, color: AppColors.gold),
        const SizedBox(height: 12),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(message,
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        if (onRetry != null) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'))
        ]
      ]));
}
