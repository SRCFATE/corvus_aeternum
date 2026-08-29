import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/conspiration_provider.dart';

class _Discipline {
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> subs;

  const _Discipline({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.subs,
  });
}

const _kDisciplines = [
  _Discipline(
    name: 'Pintura',
    description: 'Lienzo, color y materia.',
    icon: Icons.brush_rounded,
    color: Color(0xFFC9A84C),
    subs: [
      'Óleo',
      'Acrílico',
      'Acuarela',
      'Gouache',
      'Pastel',
      'Técnica mixta'
    ],
  ),
  _Discipline(
    name: 'Fotografía',
    description: 'Instantes, mirada y luz.',
    icon: Icons.photo_camera_rounded,
    color: Color(0xFF5B8FDE),
    subs: [
      'Documental',
      'Retrato',
      'Paisaje',
      'Callejera',
      'Moda',
      'Conceptual'
    ],
  ),
  _Discipline(
    name: 'Escultura',
    description: 'Forma, volumen y espacio.',
    icon: Icons.architecture_rounded,
    color: Color(0xFF9B8B7A),
    subs: ['Bronce', 'Mármol', 'Cerámica', 'Madera', 'Metal', 'Instalación'],
  ),
  _Discipline(
    name: 'Música',
    description: 'Sonido, ritmo y atmósfera.',
    icon: Icons.music_note_rounded,
    color: Color(0xFFE67E22),
    subs: [
      'Electrónica',
      'Clásica',
      'Jazz',
      'Rock / Metal',
      'Ambient',
      'Experimental'
    ],
  ),
  _Discipline(
    name: 'Literatura',
    description: 'Palabra, relato y memoria.',
    icon: Icons.menu_book_rounded,
    color: Color(0xFF6BAE6B),
    subs: [
      'Cuento',
      'Novela',
      'Ensayo',
      'Microficción',
      'Crónica',
      'Dramaturgia'
    ],
  ),
  _Discipline(
    name: 'Cine',
    description: 'Imagen, montaje y escena.',
    icon: Icons.movie_rounded,
    color: Color(0xFFE63946),
    subs: [
      'Cortometraje',
      'Documental',
      'Experimental',
      'Animación',
      'Ficción',
      'Video Arte'
    ],
  ),
  _Discipline(
    name: 'Performance',
    description: 'Cuerpo, presencia y acción.',
    icon: Icons.theater_comedy_rounded,
    color: Color(0xFFE91E8C),
    subs: [
      'Danza contemporánea',
      'Teatro físico',
      'Acción poética',
      'Intervención'
    ],
  ),
];

void showUploadWizard(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.82),
    builder: (_) => const _UploadWizardDialog(),
  );
}

class _UploadWizardDialog extends StatelessWidget {
  const _UploadWizardDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: const _UploadWizardSheet(),
      ),
    );
  }
}

class _UploadWizardSheet extends StatefulWidget {
  const _UploadWizardSheet();

  @override
  State<_UploadWizardSheet> createState() => _UploadWizardSheetState();
}

class _UploadWizardSheetState extends State<_UploadWizardSheet> {
  int _step = 0;
  _Discipline? _selected;
  String _selectedSub = '';

  void _selectDiscipline(_Discipline discipline) {
    setState(() {
      _selected = discipline;
      _selectedSub = '';
      _step = 1;
    });
  }

  void _goBack() {
    setState(() {
      _step = 0;
      _selectedSub = '';
    });
  }

  void _continue() {
    if (_selected == null) return;

    Navigator.of(context).pop();

    context.push(
      '/atelier',
      extra: {
        'openProjectDialog': true,
        'branch': _atelierBranchFor(_selected!.name, _selectedSub),
        'type': _atelierTypeFor(_selected!.name, _selectedSub),
        'genre': _selectedSub,
        'sourceDiscipline': _selected!.name,
        'language': 'es',
      },
    );
  }

  String _atelierTypeFor(String discipline, String subdiscipline) {
    final sub = subdiscipline.trim();
    if (discipline == 'Literatura') {
      return switch (sub) {
        'Cuento' => 'Cuento',
        'Novela' => 'Novela',
        'Dramaturgia' => 'Guion',
        _ => sub.isNotEmpty ? sub : 'Novela',
      };
    }
    if (discipline == 'Cine') return 'Guion';
    if (discipline == 'Pintura' || discipline == 'FotografÃ­a') {
      return discipline;
    }
    return sub.isNotEmpty ? sub : discipline;
  }

  String _atelierBranchFor(String discipline, String subdiscipline) {
    final sub = subdiscipline.toLowerCase();
    if (discipline == 'Literatura') return 'writing';
    if (discipline == 'MÃºsica') return 'music';
    if (discipline == 'Cine') return 'video';
    if (discipline == 'Performance') return 'stage';
    if (discipline == 'Escultura') return 'visual';
    if (discipline == 'Pintura' || discipline.startsWith('Fotograf')) {
      return 'visual';
    }
    if (sub.contains('manga') || sub.contains('comic')) return 'comic';
    return 'visual';
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<ConspirationProvider>().accent;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.16),
                blurRadius: 60,
                offset: const Offset(0, 24),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 36,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.2, -1),
                      radius: 1.2,
                      colors: [
                        accent.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Header(
                    step: _step,
                    selected: _selected,
                    onBack: _goBack,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _step == 0
                          ? _DisciplineStep(
                              key: const ValueKey('disciplines'),
                              onSelect: _selectDiscipline,
                            )
                          : _SubdisciplineStep(
                              key: const ValueKey('subs'),
                              discipline: _selected!,
                              selectedSub: _selectedSub,
                              onSelect: (value) {
                                setState(() => _selectedSub = value);
                              },
                            ),
                    ),
                  ),
                  if (_step == 1)
                    _Footer(
                      discipline: _selected!,
                      selectedSub: _selectedSub,
                      onContinue: _continue,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int step;
  final _Discipline? selected;
  final VoidCallback onBack;
  final VoidCallback onClose;

  const _Header({
    required this.step,
    required this.selected,
    required this.onBack,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final title = step == 0 ? 'Elige el origen de tu obra' : selected!.name;
    final subtitle = step == 0
        ? 'Toda pieza entra al Archivo Vivo mediante una disciplina principal.'
        : 'Ahora selecciona la técnica o subdisciplina más cercana.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 18, 22),
      child: Row(
        children: [
          if (step == 1) ...[
            _IconShell(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: onBack,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step == 0 ? 'NUEVA OBRA' : 'DISCIPLINA SELECCIONADA',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.34),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.46),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          _IconShell(
            icon: Icons.close_rounded,
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

class _DisciplineStep extends StatelessWidget {
  final ValueChanged<_Discipline> onSelect;

  const _DisciplineStep({
    super.key,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = width >= 660
              ? 3
              : width >= 430
                  ? 2
                  : 1;
          const gap = 14.0;
          final cardWidth = (width - (gap * (columns - 1))) / columns;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: _kDisciplines.map((discipline) {
              return SizedBox(
                width: cardWidth,
                child: _DisciplineCard(
                  discipline: discipline,
                  onTap: () => onSelect(discipline),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _DisciplineCard extends StatefulWidget {
  final _Discipline discipline;
  final VoidCallback onTap;

  const _DisciplineCard({
    required this.discipline,
    required this.onTap,
  });

  @override
  State<_DisciplineCard> createState() => _DisciplineCardState();
}

class _DisciplineCardState extends State<_DisciplineCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.discipline;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          scale: _hovered ? 1.025 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 132,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _hovered
                  ? d.color.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _hovered
                    ? d.color.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: d.color.withValues(alpha: 0.14),
                        blurRadius: 26,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: d.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: d.color.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(
                    d.icon,
                    color: d.color,
                    size: 21,
                  ),
                ),
                const Spacer(),
                Text(
                  d.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  d.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 11,
                    height: 1.25,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubdisciplineStep extends StatelessWidget {
  final _Discipline discipline;
  final String selectedSub;
  final ValueChanged<String> onSelect;

  const _SubdisciplineStep({
    super.key,
    required this.discipline,
    required this.selectedSub,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final allSubs = ['', ...discipline.subs];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SelectedDisciplineBadge(discipline: discipline),
          const SizedBox(height: 24),
          Text(
            'Técnica / subdisciplina',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.36),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: allSubs.map((sub) {
              final label = sub.isEmpty ? 'Sin especificar' : sub;
              final selected = selectedSub == sub;

              return _SubChip(
                label: label,
                selected: selected,
                color: sub.isEmpty ? AppColors.textMuted : discipline.color,
                onTap: () => onSelect(sub),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _TipBox(color: discipline.color),
        ],
      ),
    );
  }
}

class _SelectedDisciplineBadge extends StatelessWidget {
  final _Discipline discipline;

  const _SelectedDisciplineBadge({
    required this.discipline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: discipline.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: discipline.color.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: discipline.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              discipline.icon,
              color: discipline.color,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  discipline.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  discipline.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.44),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubChip extends StatefulWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SubChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  State<_SubChip> createState() => _SubChipState();
}

class _SubChipState extends State<_SubChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _hovered;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? widget.color.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: _hovered ? 0.075 : 0.04),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: active
                  ? widget.color.withValues(alpha: 0.65)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.selected) ...[
                Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: widget.color,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.selected
                      ? widget.color
                      : Colors.white.withValues(alpha: 0.68),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipBox extends StatelessWidget {
  final Color color;

  const _TipBox({
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: color.withValues(alpha: 0.85),
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Podrás cambiar la disciplina y técnica después de publicar.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final _Discipline discipline;
  final String selectedSub;
  final VoidCallback onContinue;

  const _Footer({
    required this.discipline,
    required this.selectedSub,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final label = selectedSub.isNotEmpty
        ? 'Crear en Atelier: $selectedSub'
        : 'Crear en Atelier: ${discipline.name}';

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: discipline.color,
            foregroundColor: AppColors.background,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.edit_note_rounded, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconShell extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconShell({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Icon(
            icon,
            color: AppColors.textSecondary,
            size: 18,
          ),
        ),
      ),
    );
  }
}
