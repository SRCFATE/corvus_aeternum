import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/atelier_models.dart';
import '../../models/creative_insights.dart';
import '../../models/work.dart';
import '../../providers/auth_provider.dart';
import '../../services/insights_service.dart';
import '../../shared/layout/corvus_page.dart';
import '../../shared/widgets/corvus_crow_animations.dart';
import '../../shared/widgets/corvus_empty_state.dart';
import '../../shared/widgets/corvus_surface.dart';

class InsightsPage extends StatefulWidget {
  final CreativeInsights? initialInsights;

  const InsightsPage({super.key, this.initialInsights});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  final _service = InsightsService();
  CreativeInsights? _insights;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialInsights;
    if (initial != null) {
      _insights = initial;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final profileId = context.read<AuthProvider>().profile?.id;
    if (profileId == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final insights = await _service.load(profileId);
      if (!mounted) return;
      setState(() {
        _insights = insights;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No pudimos calcular tu pulso creativo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = MediaQuery.sizeOf(context).width < 640 ? 16.0 : 40.0;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CorvusPage(
        padding: EdgeInsets.symmetric(horizontal: horizontal),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InsightsHeader(onRefresh: _load),
              const Divider(height: 1, color: AppColors.border),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CorvusCrowLoader(label: 'Leyendo tu trayectoria...'),
      );
    }
    if (_error != null) {
      return CorvusEmptyState(
        icon: Icons.query_stats_outlined,
        title: 'Estadisticas no disponibles',
        subtitle: _error!,
        actionText: 'Reintentar',
        onAction: _load,
      );
    }

    final insights = _insights;
    if (insights == null) return const SizedBox.shrink();
    if (insights.works.isEmpty &&
        insights.projects.isEmpty &&
        insights.collections.isEmpty) {
      return CorvusEmptyState(
        icon: Icons.insights_outlined,
        title: 'Tu pulso empieza con una obra',
        subtitle:
            'Las estadisticas creceran con tus proyectos, publicaciones y colecciones.',
        actionText: 'Abrir Atelier',
        onAction: () => context.go('/atelier'),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 22, 0, 56),
        children: [
          _MetricsGrid(insights: insights),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final primary = Column(
                children: [
                  _ProjectsPanel(
                    insights: insights,
                    onOpenAtelier: () => context.go('/atelier'),
                  ),
                  const SizedBox(height: 16),
                  _TopWorksPanel(
                    works: insights.topWorks,
                    onOpen: (work) => context.push('/work/${work.id}'),
                  ),
                ],
              );
              final secondary = Column(
                children: [
                  _DisciplinesPanel(counts: insights.disciplineCounts),
                  const SizedBox(height: 16),
                  _YearActivityPanel(worksByYear: insights.worksByYear),
                  const SizedBox(height: 16),
                  _ArchiveSummaryPanel(insights: insights),
                ],
              );

              if (!wide) {
                return Column(
                  children: [
                    primary,
                    const SizedBox(height: 16),
                    secondary,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: primary),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: secondary),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InsightsHeader extends StatelessWidget {
  final VoidCallback onRefresh;

  const _InsightsHeader({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 16),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ESTUDIO PRIVADO',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Pulso creativo',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            tooltip: 'Actualizar estadisticas',
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: () => context.go('/atelier'),
            icon: const Icon(Icons.auto_stories_outlined, size: 18),
            label: const Text('Atelier'),
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final CreativeInsights insights;

  const _MetricsGrid({required this.insights});

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricData(
        value: '${insights.completedWorks}',
        label: 'Obras terminadas',
        icon: Icons.task_alt_rounded,
        color: AppColors.successLight,
      ),
      _MetricData(
        value: _compact(insights.totalViews),
        label: 'Visualizaciones',
        icon: Icons.visibility_outlined,
        color: AppColors.secondaryLight,
      ),
      _MetricData(
        value: _compact(insights.totalInteractions),
        label: 'Interacciones',
        icon: Icons.favorite_border_rounded,
        color: AppColors.primaryLight,
      ),
      _MetricData(
        value: '${insights.activeProjects}',
        label: 'Proyectos activos',
        icon: Icons.hub_outlined,
        color: AppColors.gold,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 520
                ? 2
                : 1;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              SizedBox(width: width, child: _MetricTile(data: item)),
          ],
        );
      },
    );
  }
}

class _MetricData {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _MetricData({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _MetricTile extends StatelessWidget {
  final _MetricData data;

  const _MetricTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return CorvusSurface(
      borderRadius: BorderRadius.circular(8),
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(data.icon, color: data.color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
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

class _ProjectsPanel extends StatelessWidget {
  final CreativeInsights insights;
  final VoidCallback onOpenAtelier;

  const _ProjectsPanel({
    required this.insights,
    required this.onOpenAtelier,
  });

  @override
  Widget build(BuildContext context) {
    return _InsightPanel(
      title: 'Proyectos recientes',
      subtitle:
          '${insights.activeProjects} activos / ${insights.completedProjects} concluidos',
      action: IconButton(
        onPressed: onOpenAtelier,
        tooltip: 'Abrir Atelier',
        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
      ),
      child: insights.recentProjects.isEmpty
          ? const _PanelEmpty(label: 'Todavia no hay proyectos en Atelier.')
          : Column(
              children: [
                for (final project in insights.recentProjects)
                  _ProjectProgressRow(
                    project: project,
                    onTap: onOpenAtelier,
                  ),
              ],
            ),
    );
  }
}

class _ProjectProgressRow extends StatelessWidget {
  final AtelierProject project;
  final VoidCallback onTap;

  const _ProjectProgressRow({required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final progress = CreativeInsights.projectProgress(project);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(
                Icons.account_tree_outlined,
                size: 17,
                color: AppColors.secondaryLight,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          project.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$progress%',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 4,
                      backgroundColor: AppColors.overlay,
                      color: progress == 100
                          ? AppColors.successLight
                          : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${project.type} / ${_statusLabel(project.status)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
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

class _TopWorksPanel extends StatelessWidget {
  final List<Work> works;
  final ValueChanged<Work> onOpen;

  const _TopWorksPanel({required this.works, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return _InsightPanel(
      title: 'Obras con mayor alcance',
      subtitle: 'Vistas, guardados y reconocimiento acumulado',
      child: works.isEmpty
          ? const _PanelEmpty(label: 'Publica una obra para medir su alcance.')
          : Column(
              children: [
                for (var index = 0; index < works.length; index++)
                  _TopWorkRow(
                    rank: index + 1,
                    work: works[index],
                    onTap: () => onOpen(works[index]),
                  ),
              ],
            ),
    );
  }
}

class _TopWorkRow extends StatelessWidget {
  final int rank;
  final Work work;
  final VoidCallback onTap;

  const _TopWorkRow({
    required this.rank,
    required this.work,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppColors.overlay,
      child: const Icon(Icons.image_outlined, color: AppColors.textMuted),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 42,
                height: 42,
                child: work.hasImage
                    ? CachedNetworkImage(
                        imageUrl: work.displayImage,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => fallback,
                        errorWidget: (_, __, ___) => fallback,
                      )
                    : fallback,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    work.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_compact(work.viewsCount)} vistas / ${_compact(work.savesCount)} guardados / ${_compact(work.likesCount)} reconocimientos',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _DisciplinesPanel extends StatelessWidget {
  final Map<String, int> counts;

  const _DisciplinesPanel({required this.counts});

  @override
  Widget build(BuildContext context) {
    final maximum =
        counts.values.fold(0, (max, value) => value > max ? value : max);
    return _InsightPanel(
      title: 'Mapa disciplinario',
      subtitle: '${counts.length} lenguajes creativos registrados',
      child: counts.isEmpty
          ? const _PanelEmpty(label: 'Las disciplinas apareceran aqui.')
          : Column(
              children: [
                for (final entry in counts.entries.take(7))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${entry.value}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: maximum == 0 ? 0 : entry.value / maximum,
                            minHeight: 5,
                            backgroundColor: AppColors.overlay,
                            color: AppColors.secondaryLight,
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

class _YearActivityPanel extends StatelessWidget {
  final Map<int, int> worksByYear;

  const _YearActivityPanel({required this.worksByYear});

  @override
  Widget build(BuildContext context) {
    final entries = worksByYear.entries.toList();
    final visible =
        entries.length <= 8 ? entries : entries.sublist(entries.length - 8);
    final maximum =
        visible.fold(0, (max, entry) => entry.value > max ? entry.value : max);
    return _InsightPanel(
      title: 'Evolucion anual',
      subtitle:
          '${worksByYear.values.fold(0, (sum, value) => sum + value)} obras registradas',
      child: visible.isEmpty
          ? const _PanelEmpty(label: 'La cronologia crecera con tus obras.')
          : SizedBox(
              height: 128,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final entry in visible)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${entry.value}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              height: maximum == 0
                                  ? 2
                                  : 70 * (entry.value / maximum),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.72),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${entry.key}'.substring(2),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _ArchiveSummaryPanel extends StatelessWidget {
  final CreativeInsights insights;

  const _ArchiveSummaryPanel({required this.insights});

  @override
  Widget build(BuildContext context) {
    final rate = (insights.completionRate * 100).round();
    return _InsightPanel(
      title: 'Archivo creativo',
      subtitle: 'Estado general de tu produccion',
      child: Column(
        children: [
          _SummaryRow(label: 'Publicadas', value: '${insights.publishedWorks}'),
          _SummaryRow(label: 'Borradores', value: '${insights.draftWorks}'),
          _SummaryRow(
              label: 'Proyectos archivados',
              value: '${insights.archivedProjects}'),
          _SummaryRow(
              label: 'Colecciones', value: '${insights.collections.length}'),
          _SummaryRow(
              label: 'Piezas curadas', value: '${insights.collectionPieces}'),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Finalizacion de obras',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$rate%',
                style: const TextStyle(
                  color: AppColors.successLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: insights.completionRate,
              minHeight: 6,
              backgroundColor: AppColors.overlay,
              color: AppColors.successLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  const _InsightPanel({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return CorvusSurface(
      borderRadius: BorderRadius.circular(8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }
}

class _PanelEmpty extends StatelessWidget {
  final String label;

  const _PanelEmpty({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
    );
  }
}

String _compact(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}

String _statusLabel(String value) {
  return switch (value) {
    'idea' => 'Idea',
    'concepto' => 'Concepto',
    'planeacion' || 'planning' => 'Planeacion',
    'borrador' || 'draft' => 'Borrador',
    'prototipo' => 'Prototipo',
    'desarrollo' || 'in_progress' => 'Desarrollo',
    'produccion' => 'Produccion',
    'revision' => 'Revision',
    'edicion' => 'Edicion',
    'mezcla' => 'Mezcla',
    'pruebas' => 'Pruebas',
    'final' => 'Final',
    'lista' || 'lista_para_publicar' => 'Lista',
    'publicada' || 'published' => 'Publicada',
    'pausada' => 'Pausada',
    'archivada' || 'archived' => 'Archivada',
    'cancelada' || 'cancelled' => 'Cancelada',
    'edicion_definitiva' => 'Edicion definitiva',
    _ => value,
  };
}
