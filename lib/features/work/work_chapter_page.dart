import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/page_load_trace.dart';
import '../../models/work.dart';
import '../../providers/auth_provider.dart';
import '../../services/work_service.dart';
import '../../shared/widgets/corvus_crow_animations.dart';
import '../../shared/widgets/corvus_empty_state.dart';
import '../../shared/widgets/formatted_manuscript_text.dart';

import 'work_reading_utils.dart';
import 'reader_preferences.dart';
import '../../core/theme/corvus_design.dart';

class WorkChapterPage extends StatefulWidget {
  final String workId;
  final int initialChapter;
  final WorkService? service;
  final bool resume;

  const WorkChapterPage({
    super.key,
    required this.workId,
    required this.initialChapter,
    this.service,
    this.resume = false,
  });

  @override
  State<WorkChapterPage> createState() => _WorkChapterPageState();
}

class _WorkChapterPageState extends State<WorkChapterPage> {
  late final _workService = widget.service ?? WorkService();
  Work? _work;
  List<WorkChapter> _chapters = [];
  bool _isLoading = true;
  late int _currentChapter;
  ReaderPreferences _preferences = const ReaderPreferences();
  double get _fontSize => _preferences.fontSize;
  SharedPreferences? _storage;
  late final String _readerKey;
  Timer? _positionTimer;
  final _progress = ValueNotifier<double>(0);
  bool _hideControls = false;
  bool _restoringPosition = false;
  final Map<int, double> _bookmarks = {};
  final _scrollController = ScrollController();
  final _loadTrace = PageLoadTrace('reader');

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.initialChapter;
    _readerKey =
        'corvus.reader.${context.read<AuthProvider>().profile?.id ?? 'visitor'}';
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _loadTrace.cancel();
    _positionTimer?.cancel();
    _savePosition();
    _progress.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _storage = await SharedPreferences.getInstance();
      if (widget.resume) {
        _currentChapter =
            _storage?.getInt('$_readerKey.${widget.workId}.last') ??
                widget.initialChapter;
      }
      final raw = _storage?.getString(_readerKey);
      if (raw != null) {
        _preferences = ReaderPreferences.fromMap(
            Map<String, dynamic>.from(jsonDecode(raw) as Map));
      }
      final marks =
          _storage?.getString('$_readerKey.${widget.workId}.bookmarks');
      if (marks != null) {
        for (final entry in (jsonDecode(marks) as Map).entries) {
          final index = int.tryParse(entry.key.toString());
          if (index != null && entry.value is num) {
            _bookmarks[index] = (entry.value as num).toDouble().clamp(0, 1);
          }
        }
      }
    } catch (_) {/* Las preferencias locales no impiden leer. */}
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
        _restorePosition();
        _loadTrace.rendered(isCurrent: () => mounted && !_isLoading);
      }
    } catch (_) {
      _loadTrace.cancel();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openReference(String url) async {
    if (!url.startsWith('corvus-node:')) {
      final uri = Uri.tryParse(url);
      if (uri != null && {'https', 'http', 'mailto'}.contains(uri.scheme)) {
        try {
          await launchUrl(uri);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No se pudo abrir el vínculo.')));
          }
        }
      }
      return;
    }
    final references = _work?.aeternumFicha.raw['public_references'];
    final reference = references is List
        ? references
            .whereType<Map>()
            .where((row) => row['id'] == url.substring(12))
            .firstOrNull
        : null;
    if (reference == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Esta ficha no está incluida en la publicación.')));
      return;
    }
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
            child: SizedBox(
                height: MediaQuery.sizeOf(ctx).height * .7,
                child: ListView(padding: const EdgeInsets.all(24), children: [
                  Text(reference['title'] as String? ?? 'Ficha',
                      style: Theme.of(ctx).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  FormattedManuscriptText(
                      text: reference['body'] as String? ?? ''),
                ]))));
  }

  void _goToChapter(int index) {
    if (index < 0 || index >= _chapters.length) return;
    _savePosition();
    setState(() => _currentChapter = index);
    _restorePosition();
  }

  void _onScroll() {
    if (_restoringPosition || !_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    _progress.value =
        max > 0 ? (_scrollController.offset / max).clamp(0, 1) : 1;
    _positionTimer?.cancel();
    _positionTimer = Timer(const Duration(milliseconds: 400), _savePosition);
  }

  void _savePosition() {
    _positionTimer?.cancel();
    if (!_scrollController.hasClients || _restoringPosition || _isLoading) {
      return;
    }
    unawaited(_storage
        ?.setDouble(
            '$_readerKey.${widget.workId}.$_currentChapter', _progress.value)
        .catchError((Object _) => false));
    unawaited(_storage
        ?.setInt('$_readerKey.${widget.workId}.last', _currentChapter)
        .catchError((Object _) => false));
  }

  void _restorePosition({double? fraction}) {
    _restoringPosition = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final saved = fraction ??
          _storage
              ?.getDouble('$_readerKey.${widget.workId}.$_currentChapter') ??
          0;
      _scrollController.jumpTo(
          saved.clamp(0, 1) * _scrollController.position.maxScrollExtent);
      _progress.value = saved.clamp(0, 1);
      _restoringPosition = false;
    });
  }

  void _setPreferences(ReaderPreferences value) {
    final progress = _progress.value;
    setState(() => _preferences = value);
    unawaited(_storage
        ?.setString(_readerKey, jsonEncode(value.toMap()))
        .catchError((Object _) => false));
    _restorePosition(fraction: progress);
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
    final compact = MediaQuery.sizeOf(context).width < 700;

    return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              _goToChapter(_currentChapter - 1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              _goToChapter(_currentChapter + 1),
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              setState(() => _hideControls = false),
        },
        child: Focus(
            autofocus: true,
            child: Scaffold(
              backgroundColor: _preferences.background,
              floatingActionButton: _hideControls
                  ? FloatingActionButton.small(
                      tooltip: 'Mostrar controles',
                      onPressed: () => setState(() => _hideControls = false),
                      child: const Icon(Icons.menu))
                  : null,
              body: Column(
                children: [
                  if (!_hideControls) _buildReaderTopBar(isSingleChapter),
                  ValueListenableBuilder<double>(
                      valueListenable: _progress,
                      builder: (_, progress, child) => Column(children: [
                            LinearProgressIndicator(
                                value: progress,
                                minHeight: 2,
                                semanticsLabel: 'Progreso del capítulo',
                                semanticsValue:
                                    '${(progress * 100).round()} %'),
                            if (!_hideControls)
                              Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 12),
                                  child: Text(
                                      'Capítulo ${(progress * 100).round()} % · Obra ${((_currentChapter + progress) / _chapters.length * 100).round()} %',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: _preferences.foreground))),
                          ])),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _preferences.background,
                            _preferences.background,
                          ],
                        ),
                      ),
                      child: CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          SliverToBoxAdapter(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                    maxWidth: _preferences.width),
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(compact ? 8 : 28,
                                      24, compact ? 8 : 28, 32),
                                  child: Container(
                                    padding: EdgeInsets.fromLTRB(
                                        compact ? 16 : 44,
                                        28,
                                        compact ? 16 : 44,
                                        40),
                                    decoration: BoxDecoration(
                                      color: _preferences.background,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.08),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.26),
                                          blurRadius: 34,
                                          offset: const Offset(0, 18),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Center(
                                          child: Wrap(
                                            alignment: WrapAlignment.center,
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _ReaderChip(
                                                icon:
                                                    Icons.auto_stories_rounded,
                                                label: isSingleChapter
                                                    ? 'CAPÍTULO ÚNICO'
                                                    : 'CAPÍTULO ${_currentChapter + 1}',
                                                color: _preferences.palette ==
                                                        ReaderPalette.sepia
                                                    ? const Color(0xFF9B2335)
                                                    : AppColors.primaryLight,
                                              ),
                                              _ReaderChip(
                                                icon: Icons.schedule_rounded,
                                                label:
                                                    '${_chapterReadingMinutes(chapter)} MIN',
                                                color: _preferences.palette ==
                                                        ReaderPalette.sepia
                                                    ? const Color(0xFF70501C)
                                                    : AppColors.gold,
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
                                              style: TextStyle(
                                                color: _preferences.foreground,
                                                fontFamily: CorvusType.serif,
                                                fontSize: 34,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: -0.6,
                                                height: 1.12,
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
                                                borderRadius:
                                                    BorderRadius.circular(99),
                                              ),
                                            ),
                                          ),
                                        ] else
                                          const SizedBox(height: 16),
                                        if (chapter.content.isNotEmpty)
                                          FormattedManuscriptText(
                                            onLink: _openReference,
                                            text: chapter.content,
                                            fontSize: _fontSize,
                                            lineHeight: _preferences.lineHeight,
                                            color: _preferences.foreground,
                                            fontFamily: _preferences.serif
                                                ? 'CorvusLiterary'
                                                : 'sans-serif',
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
            )));
  }

  Future<void> _showPreferences() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) {
        void update(ReaderPreferences value) {
          _setPreferences(value);
          refresh(() {});
        }

        return SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Preferencias de lectura'),
                  Wrap(spacing: 8, children: [
                    for (final palette in ReaderPalette.values)
                      ChoiceChip(
                          label: Text(switch (palette) {
                            ReaderPalette.dark => 'Oscuro',
                            ReaderPalette.sepia => 'Sepia',
                            ReaderPalette.contrast => 'Alto contraste'
                          }),
                          selected: _preferences.palette == palette,
                          onSelected: (_) =>
                              update(_preferences.copyWith(palette: palette))),
                  ]),
                  SwitchListTile(
                      title: const Text('Fuente literaria'),
                      value: _preferences.serif,
                      onChanged: (value) =>
                          update(_preferences.copyWith(serif: value))),
                  Text('Tamaño: ${_fontSize.round()}'),
                  Slider(
                      value: _fontSize,
                      min: 14,
                      max: 30,
                      divisions: 16,
                      label: '${_fontSize.round()}',
                      onChanged: (value) =>
                          update(_preferences.copyWith(fontSize: value))),
                  Text(
                      'Interlineado: ${_preferences.lineHeight.toStringAsFixed(1)}'),
                  Slider(
                      value: _preferences.lineHeight,
                      min: 1.3,
                      max: 2.5,
                      divisions: 12,
                      label: _preferences.lineHeight.toStringAsFixed(1),
                      onChanged: (value) =>
                          update(_preferences.copyWith(lineHeight: value))),
                  const Text('Ancho de página'),
                  Slider(
                      value: _preferences.width,
                      min: 650,
                      max: 1000,
                      divisions: 7,
                      label: '${_preferences.width.round()}',
                      onChanged: (value) =>
                          update(_preferences.copyWith(width: value))),
                ])));
      }),
    );
  }

  Future<void> _showContents() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, refresh) => SafeArea(
                  child: SizedBox(
                height: MediaQuery.sizeOf(ctx).height * .7,
                child: ListView(children: [
                  ListTile(
                      title: const Text('Guardar marcador aquí'),
                      leading: const Icon(Icons.bookmark_add_outlined),
                      onTap: () {
                        _bookmarks[_currentChapter] = _progress.value;
                        unawaited(_storage
                            ?.setString(
                                '$_readerKey.${widget.workId}.bookmarks',
                                jsonEncode(_bookmarks.map(
                                    (key, value) => MapEntry('$key', value))))
                            .catchError((Object _) => false));
                        Navigator.pop(ctx);
                      }),
                  for (final entry in _bookmarks.entries.where((entry) =>
                      entry.key >= 0 && entry.key < _chapters.length))
                    ListTile(
                        leading: const Icon(Icons.bookmark),
                        trailing: IconButton(
                            tooltip: 'Eliminar marcador',
                            icon: const Icon(Icons.bookmark_remove_outlined),
                            onPressed: () {
                              refresh(() => _bookmarks.remove(entry.key));
                              unawaited(_storage
                                  ?.setString(
                                      '$_readerKey.${widget.workId}.bookmarks',
                                      jsonEncode(_bookmarks.map((key, value) =>
                                          MapEntry('$key', value))))
                                  .catchError((Object _) => false));
                            }),
                        title: Text(
                            '${_chapterTitle(entry.key)} · ${(entry.value * 100).round()} %'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _goToChapter(entry.key);
                          _restorePosition(fraction: entry.value);
                        }),
                  const Divider(),
                  for (var i = 0; i < _chapters.length; i++)
                    ListTile(
                        selected: i == _currentChapter,
                        leading: Text('${i + 1}'),
                        title: Text(_chapterTitle(i)),
                        onTap: () {
                          Navigator.pop(ctx);
                          _goToChapter(i);
                        }),
                ]),
              ))),
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
                    fontWeight: FontWeight.w700,
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
          IconButton(
              tooltip: 'Índice y marcadores',
              icon: const Icon(Icons.toc),
              onPressed: _showContents),
          IconButton(
              tooltip: 'Preferencias de lectura',
              icon: const Icon(Icons.text_fields),
              onPressed: _showPreferences),
          IconButton(
              tooltip: 'Ocultar controles',
              icon: const Icon(Icons.fullscreen),
              onPressed: () => setState(() => _hideControls = true)),
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
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 16,
        runSpacing: 16,
        children: [
          if (hasPrev)
            _NavButton(
              label: _chapterTitle(_currentChapter - 1),
              icon: Icons.arrow_back_ios_rounded,
              leading: true,
              onTap: () => _goToChapter(_currentChapter - 1),
            ),
          if (hasNext)
            _NavButton(
              label: _chapterTitle(_currentChapter + 1),
              icon: Icons.arrow_forward_ios_rounded,
              leading: false,
              onTap: () => _goToChapter(_currentChapter + 1),
            ),
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
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
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
                  fontWeight: FontWeight.w700,
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
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
