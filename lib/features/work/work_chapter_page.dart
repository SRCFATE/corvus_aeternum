import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/work.dart';
import '../../providers/auth_provider.dart';
import '../../services/work_service.dart';
import '../../shared/widgets/corvus_crow_animations.dart';
import '../../shared/widgets/corvus_empty_state.dart';
import '../../shared/widgets/formatted_manuscript_text.dart';
import '../../shared/widgets/user_avatar.dart';
import 'upload_wizard_sheet.dart';
import 'work_reading_utils.dart';

class WorkChapterPage extends StatefulWidget {
  final String workId;
  final int initialChapter;

  const WorkChapterPage({
    super.key,
    required this.workId,
    required this.initialChapter,
  });

  @override
  State<WorkChapterPage> createState() => _WorkChapterPageState();
}

class _WorkChapterPageState extends State<WorkChapterPage> {
  final _workService = WorkService();
  Work? _work;
  List<WorkChapter> _chapters = [];
  bool _isLoading = true;
  late int _currentChapter;
  double _fontSize = 16;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.initialChapter;
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final work = await _workService.getWorkById(widget.workId);
      if (mounted) {
        final chapters = parseWorkChapters(work.textBody ?? '');
        final lastChapterIndex = chapters.isEmpty ? 0 : chapters.length - 1;
        setState(() {
          _work = work;
          _chapters = chapters;
          _currentChapter = _currentChapter.clamp(0, lastChapterIndex).toInt();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToChapter(int index) {
    if (index < 0 || index >= _chapters.length) return;
    setState(() => _currentChapter = index);
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CorvusCrowLoader(label: 'Abriendo el manuscrito…')),
      );
    }
    if (_work == null || _chapters.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/discover'),
          ),
        ),
        body: CorvusEmptyState(
          icon: Icons.menu_book_outlined,
          title: 'Contenido no disponible',
          subtitle:
              'El manuscrito no tiene capitulos publicados o no se pudo abrir.',
          actionText: 'Volver a explorar',
          onAction: () => context.go('/discover'),
        ),
      );
    }

    final chapter = _chapters[_currentChapter];
    final hasPrev = _currentChapter > 0;
    final hasNext = _currentChapter < _chapters.length - 1;
    final isSingleChapter = _chapters.length == 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildGlobalTopBar(_work!),
          _buildReaderTopBar(isSingleChapter),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primaryMuted.withValues(alpha: 0.12),
                    AppColors.background,
                  ],
                ),
              ),
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 860),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(52, 44, 52, 50),
                            decoration: BoxDecoration(
                              color: const Color(0xFF100C14),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.26),
                                  blurRadius: 34,
                                  offset: const Offset(0, 18),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _ReaderChip(
                                        icon: Icons.auto_stories_rounded,
                                        label: isSingleChapter
                                            ? 'CAPÍTULO ÚNICO'
                                            : 'CAPÍTULO ${_currentChapter + 1}',
                                        color: AppColors.primary,
                                      ),
                                      _ReaderChip(
                                        icon: Icons.schedule_rounded,
                                        label:
                                            '${_chapterReadingMinutes(chapter)} MIN',
                                        color: AppColors.gold,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 22),
                                if (chapter.title.isNotEmpty) ...[
                                  Center(
                                    child: Text(
                                      chapter.title,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 34,
                                        fontWeight: FontWeight.w900,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: Container(
                                      width: 52,
                                      height: 3,
                                      margin: const EdgeInsets.only(
                                        top: 18,
                                        bottom: 42,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.55),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                    ),
                                  ),
                                ] else
                                  const SizedBox(height: 16),
                                if (chapter.content.isNotEmpty)
                                  FormattedManuscriptText(
                                    text: chapter.content,
                                    fontSize: _fontSize,
                                    lineHeight: 1.92,
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 40,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Este capítulo no tiene contenido publicado aún.',
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.34),
                                          fontSize: 14,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 64),
                                if (!isSingleChapter)
                                  _buildChapterNavigation(
                                    hasPrev: hasPrev,
                                    hasNext: hasNext,
                                  ),
                                const SizedBox(height: 80),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalTopBar(Work work) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 900;
    final profile = context.watch<AuthProvider>().profile;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.92),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(compact ? 10 : 18, 10, 18, 10),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    _TopBarBrand(compact: compact),
                    if (!compact) ...[
                      const SizedBox(width: 34),
                      const Expanded(child: _TopBarNav()),
                    ] else ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          work.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                    if (!compact) const SizedBox(width: 34),
                    _TopBarIconButton(
                      icon: Icons.search_rounded,
                      tooltip: 'Buscar',
                      onTap: () => context.go('/discover'),
                    ),
                    const SizedBox(width: 8),
                    _TopBarIconButton(
                      icon: Icons.menu_book_outlined,
                      tooltip: 'Glosario',
                      onTap: () => context.push('/glossary'),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 8),
                      _TopBarIconButton(
                        icon: Icons.notifications_none_rounded,
                        tooltip: 'Notificaciones',
                        onTap: () => context.push('/notifications'),
                      ),
                      const SizedBox(width: 8),
                      if (profile != null)
                        GestureDetector(
                          onTap: () => context.go('/profile'),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.24),
                              ),
                            ),
                            child: Center(
                              child: UserAvatar(
                                imageUrl: profile.avatarUrl,
                                displayName: profile.displayName,
                                radius: 15,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 10),
                      _TopBarPrimaryButton(
                        label: 'Crear obra',
                        onTap: () => showUploadWizard(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReaderTopBar(bool isSingleChapter) {
    final compact = MediaQuery.sizeOf(context).width < 860;
    return Container(
      height: 76,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 18),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.98),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver a la obra',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: AppColors.textSecondary,
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go('/work/${widget.workId}'),
          ),
          if (!compact) ...[
            const SizedBox(width: 10),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.24),
                ),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: AppColors.primary,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _work!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isSingleChapter
                      ? 'Lectura / capítulo único'
                      : 'Lectura / capítulo ${_currentChapter + 1} de ${_chapters.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.36),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (!compact && !isSingleChapter) ...[
            const SizedBox(width: 14),
            _ChapterSelector(
              currentLabel: _chapterTitle(_currentChapter),
              itemCount: _chapters.length,
              itemBuilder: _chapterTitle,
              onSelected: _goToChapter,
            ),
          ],
          if (!compact) ...[
            const SizedBox(width: 14),
            _ReaderStat(
              icon: Icons.article_outlined,
              label: '${_chapters[_currentChapter].wordCount} palabras',
            ),
          ],
          const SizedBox(width: 8),
          _FontButton(
            label: 'A-',
            enabled: _fontSize > 13,
            onTap: () => setState(() => _fontSize -= 1),
          ),
          const SizedBox(width: 6),
          _FontButton(
            label: 'A+',
            enabled: _fontSize < 24,
            onTap: () => setState(() => _fontSize += 1),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterNavigation({
    required bool hasPrev,
    required bool hasNext,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: Row(
        children: [
          if (hasPrev)
            _NavButton(
              label: _chapterTitle(_currentChapter - 1),
              icon: Icons.arrow_back_ios_rounded,
              leading: true,
              onTap: () => _goToChapter(_currentChapter - 1),
            )
          else
            const SizedBox(width: 180),
          const Spacer(),
          if (hasNext)
            _NavButton(
              label: _chapterTitle(_currentChapter + 1),
              icon: Icons.arrow_forward_ios_rounded,
              leading: false,
              onTap: () => _goToChapter(_currentChapter + 1),
            )
          else
            const SizedBox(width: 180),
        ],
      ),
    );
  }

  String _chapterTitle(int index) {
    final chapter = _chapters[index];
    if (chapter.title.isNotEmpty) return chapter.title;
    return _chapters.length == 1 ? 'Capítulo único' : 'Capítulo ${index + 1}';
  }

  int _chapterReadingMinutes(WorkChapter chapter) {
    if (chapter.wordCount == 0) return 0;
    return (chapter.wordCount / 220).ceil();
  }
}

class _TopBarBrand extends StatelessWidget {
  final bool compact;

  const _TopBarBrand({required this.compact});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/discover'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.26),
                ),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 11),
              const Text(
                'Corvus Aeternum',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopBarNav extends StatelessWidget {
  const _TopBarNav();

  static const _items = [
    ('Explorar', '/feed'),
    ('Descubrir', '/discover'),
    ('Atelier', '/atelier'),
    ('Subastas', '/auctions'),
    ('Artistas', '/artists'),
    ('Colecciones', '/collections'),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        spacing: 8,
        children: _items.map((item) {
          return _TopBarNavLink(
            label: item.$1,
            onTap: () => context.go(item.$2),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _TopBarNavLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _TopBarNavLink({
    required this.label,
    required this.onTap,
  });

  @override
  State<_TopBarNavLink> createState() => _TopBarNavLinkState();
}

class _TopBarNavLinkState extends State<_TopBarNavLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withValues(alpha: 0.045)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _hovered ? AppColors.textPrimary : AppColors.textMuted,
              fontSize: 13,
              fontWeight: _hovered ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBarIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TopBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_TopBarIconButton> createState() => _TopBarIconButtonState();
}

class _TopBarIconButtonState extends State<_TopBarIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _hovered ? 0.075 : 0.04),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: _hovered
                    ? AppColors.primary.withValues(alpha: 0.24)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Icon(widget.icon, size: 19, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _TopBarPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _TopBarPrimaryButton({required this.label, required this.onTap});

  @override
  State<_TopBarPrimaryButton> createState() => _TopBarPrimaryButtonState();
}

class _TopBarPrimaryButtonState extends State<_TopBarPrimaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.primaryLight : AppColors.primary,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color:
                    AppColors.primary.withValues(alpha: _hovered ? 0.28 : 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool leading;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.icon,
    required this.leading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: 13, color: AppColors.primary);
    final labelWidget = Text(
      label,
      style: const TextStyle(
          color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: 130,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: leading
                ? [
                    iconWidget,
                    const SizedBox(width: 6),
                    Flexible(child: labelWidget)
                  ]
                : [
                    Flexible(child: labelWidget),
                    const SizedBox(width: 6),
                    iconWidget
                  ],
          ),
        ),
      ),
    );
  }
}

class _ReaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ReaderChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color.withValues(alpha: 0.88), size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.88),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterSelector extends StatelessWidget {
  final String currentLabel;
  final int itemCount;
  final String Function(int index) itemBuilder;
  final ValueChanged<int> onSelected;

  const _ChapterSelector({
    required this.currentLabel,
    required this.itemCount,
    required this.itemBuilder,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Cambiar capítulo',
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: onSelected,
      itemBuilder: (_) => List.generate(
        itemCount,
        (index) => PopupMenuItem(
          value: index,
          child: Text(
            itemBuilder(index),
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                currentLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withValues(alpha: 0.42),
              size: 17,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderStat extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ReaderStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.36), size: 15),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.56),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FontButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _FontButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          width: 40,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: enabled ? 0.045 : 0.02),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color:
                    enabled ? AppColors.textSecondary : AppColors.textDisabled,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
