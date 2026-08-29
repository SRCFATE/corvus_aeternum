import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/atelier_models.dart';
import '../../providers/atelier_provider.dart';
import '../../shared/widgets/formatted_manuscript_text.dart';
import '../../shared/widgets/corvus_motion.dart';

enum _MundiariumMode { overview, universes, map, timeline, characters }

class MundiariumWorkspace extends StatefulWidget {
  final Color accent;
  final AtelierProvider atelier;
  final VoidCallback onCreateUniverse;
  final ValueChanged<String> onCreateNode;
  final ValueChanged<AtelierNode> onEditNode;
  final ValueChanged<AtelierNode> onDeleteNode;
  final VoidCallback onCreateRelation;
  final ValueChanged<AtelierRelation> onDeleteRelation;

  const MundiariumWorkspace({
    super.key,
    required this.accent,
    required this.atelier,
    required this.onCreateUniverse,
    required this.onCreateNode,
    required this.onEditNode,
    required this.onDeleteNode,
    required this.onCreateRelation,
    required this.onDeleteRelation,
  });

  @override
  State<MundiariumWorkspace> createState() => _MundiariumWorkspaceState();
}

class _MundiariumWorkspaceState extends State<MundiariumWorkspace> {
  _MundiariumMode _mode = _MundiariumMode.overview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModeBar(
          selected: _mode,
          onSelected: (mode) => setState(() => _mode = mode),
        ),
        const SizedBox(height: 14),
        switch (_mode) {
          _MundiariumMode.overview => _WorldIndex(
              accent: widget.accent,
              atelier: widget.atelier,
              onCreateUniverse: widget.onCreateUniverse,
              onEditNode: widget.onEditNode,
              onDeleteNode: widget.onDeleteNode,
              onCreateRelation: widget.onCreateRelation,
              onDeleteRelation: widget.onDeleteRelation,
            ),
          _MundiariumMode.universes => _UniverseGallery(
              universes: widget.atelier.nodes
                  .where((node) => node.kind == 'universe')
                  .toList(),
              onCreateUniverse: widget.onCreateUniverse,
              onEditUniverse: widget.onEditNode,
              onDeleteUniverse: widget.onDeleteNode,
            ),
          _MundiariumMode.map => _RelationshipMapPanel(
              nodes: widget.atelier.worldNodes,
              relations: widget.atelier.relations,
              onEditNode: widget.onEditNode,
              onCreateRelation: widget.onCreateRelation,
            ),
          _MundiariumMode.timeline => _MundiariumTimeline(
              characters: widget.atelier.characters,
              onCreateCharacter: () => widget.onCreateNode('character'),
              onEditCharacter: widget.onEditNode,
            ),
          _MundiariumMode.characters => _CharacterGallery(
              characters: widget.atelier.characters,
              onCreateCharacter: () => widget.onCreateNode('character'),
              onEditCharacter: widget.onEditNode,
              onDeleteCharacter: widget.onDeleteNode,
            ),
        },
      ],
    );
  }
}

class _ModeBar extends StatelessWidget {
  final _MundiariumMode selected;
  final ValueChanged<_MundiariumMode> onSelected;

  const _ModeBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(5),
        child: Row(
          children: [
            _ModeButton(
              icon: Icons.grid_view_rounded,
              label: 'Indice',
              selected: selected == _MundiariumMode.overview,
              onTap: () => onSelected(_MundiariumMode.overview),
            ),
            _ModeButton(
              icon: Icons.public_rounded,
              label: 'Universos',
              selected: selected == _MundiariumMode.universes,
              onTap: () => onSelected(_MundiariumMode.universes),
            ),
            _ModeButton(
              icon: Icons.hub_outlined,
              label: 'Mapa',
              selected: selected == _MundiariumMode.map,
              onTap: () => onSelected(_MundiariumMode.map),
            ),
            _ModeButton(
              icon: Icons.timeline_rounded,
              label: 'Cronologia',
              selected: selected == _MundiariumMode.timeline,
              onTap: () => onSelected(_MundiariumMode.timeline),
            ),
            _ModeButton(
              icon: Icons.people_alt_outlined,
              label: 'Personajes',
              selected: selected == _MundiariumMode.characters,
              onTap: () => onSelected(_MundiariumMode.characters),
            ),
          ],
        ),
      ),
    );
  }
}

class _UniverseGallery extends StatelessWidget {
  final List<AtelierNode> universes;
  final VoidCallback onCreateUniverse;
  final ValueChanged<AtelierNode> onEditUniverse;
  final ValueChanged<AtelierNode> onDeleteUniverse;

  const _UniverseGallery({
    required this.universes,
    required this.onCreateUniverse,
    required this.onEditUniverse,
    required this.onDeleteUniverse,
  });

  int _listCount(AtelierNode node, String key) {
    final value = node.metadata[key];
    return value is List ? value.length : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Universos creativos',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                  SizedBox(height: 5),
                  Text(
                      'Continuidades independientes con sus obras, colecciones y extensiones transmedia.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: onCreateUniverse,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nuevo universo'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (universes.isEmpty)
          _EmptyState(
            message: 'Todavia no has creado un universo.',
            actionLabel: 'Crear universo',
            onAction: onCreateUniverse,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 960
                  ? 3
                  : constraints.maxWidth >= 620
                      ? 2
                      : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: universes.map((universe) {
                  final works = _listCount(universe, 'linked_work_ids');
                  final collections =
                      _listCount(universe, 'linked_collection_ids');
                  final media = _listCount(universe, 'linked_media');
                  return SizedBox(
                    width: width,
                    child: CorvusReveal(
                      delay: Duration(
                          milliseconds:
                              (universes.indexOf(universe) * 70).clamp(0, 350)),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onEditUniverse(universe),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 210,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.07)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                          color: AppColors.gold
                                              .withValues(alpha: 0.12),
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.public_rounded,
                                          color: AppColors.gold, size: 21),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      tooltip: 'Eliminar universo',
                                      onPressed: () =>
                                          onDeleteUniverse(universe),
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(universe.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900)),
                                const SizedBox(height: 5),
                                Text(
                                    universe.body.isEmpty
                                        ? 'Sin descripcion base.'
                                        : universe.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12.5,
                                        height: 1.35)),
                                const Spacer(),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 6,
                                  children: [
                                    _UniverseCount(
                                        icon: Icons.auto_stories_outlined,
                                        value: works,
                                        label: 'obras'),
                                    _UniverseCount(
                                        icon:
                                            Icons.collections_bookmark_outlined,
                                        value: collections,
                                        label: 'colecciones'),
                                    _UniverseCount(
                                        icon: Icons.language_rounded,
                                        value: media,
                                        label: 'medios'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }
}

class _UniverseCount extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  const _UniverseCount(
      {required this.icon, required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.gold),
        const SizedBox(width: 4),
        Text('$value $label',
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? AppColors.gold : AppColors.textSecondary,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorldIndex extends StatelessWidget {
  final Color accent;
  final AtelierProvider atelier;
  final VoidCallback onCreateUniverse;
  final ValueChanged<AtelierNode> onEditNode;
  final ValueChanged<AtelierNode> onDeleteNode;
  final VoidCallback onCreateRelation;
  final ValueChanged<AtelierRelation> onDeleteRelation;

  const _WorldIndex({
    required this.accent,
    required this.atelier,
    required this.onCreateUniverse,
    required this.onEditNode,
    required this.onDeleteNode,
    required this.onCreateRelation,
    required this.onDeleteRelation,
  });

  @override
  Widget build(BuildContext context) {
    final entities = _MundiariumPanel(
      accent: AppColors.gold,
      title: 'Indice vivo',
      icon: Icons.grid_view_rounded,
      child: atelier.worldNodes.isEmpty
          ? _EmptyState(
              message: 'No hay elementos de mundo.',
              actionLabel: 'Crear universo',
              onAction: onCreateUniverse,
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 640 ? 2 : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 10) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: atelier.worldNodes
                      .map((node) => SizedBox(
                            width: width,
                            child: _WorldNodeTile(
                              node: node,
                              onEdit: () => onEditNode(node),
                              onDelete: () => onDeleteNode(node),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
    );
    final relations = _MundiariumPanel(
      accent: accent,
      title: 'Relaciones',
      icon: Icons.hub_outlined,
      child: atelier.relations.isEmpty
          ? _EmptyState(
              message: 'No hay relaciones registradas.',
              actionLabel: 'Crear relacion',
              onAction: onCreateRelation,
            )
          : Column(
              children: atelier.relations.map((relation) {
                final source = atelier.nodeById(relation.sourceNodeId);
                final target = atelier.nodeById(relation.targetNodeId);
                return _RelationTile(
                  source: source?.title ?? 'Origen',
                  target: target?.title ?? 'Destino',
                  type: relation.relationType,
                  onDelete: () => onDeleteRelation(relation),
                );
              }).toList(),
            ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 880) {
          return Column(
            children: [entities, const SizedBox(height: 14), relations],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 58, child: entities),
            const SizedBox(width: 14),
            Expanded(flex: 42, child: relations),
          ],
        );
      },
    );
  }
}

class _WorldNodeTile extends StatelessWidget {
  final AtelierNode node;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _WorldNodeTile({
    required this.node,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _worldNodeColor(node.kind);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Icon(_worldNodeIcon(node.kind), color: color, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _kindLabel(node.kind),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Acciones',
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelationTile extends StatelessWidget {
  final String source;
  final String target;
  final String type;
  final VoidCallback onDelete;

  const _RelationTile({
    required this.source,
    required this.target,
    required this.type,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.arrow_forward_rounded,
              color: AppColors.gold, size: 16),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$source · $target',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(type,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Eliminar relacion',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 17),
          ),
        ],
      ),
    );
  }
}

class _RelationshipMapPanel extends StatefulWidget {
  final List<AtelierNode> nodes;
  final List<AtelierRelation> relations;
  final ValueChanged<AtelierNode> onEditNode;
  final VoidCallback onCreateRelation;

  const _RelationshipMapPanel({
    required this.nodes,
    required this.relations,
    required this.onEditNode,
    required this.onCreateRelation,
  });

  @override
  State<_RelationshipMapPanel> createState() => _RelationshipMapPanelState();
}

class _RelationshipMapPanelState extends State<_RelationshipMapPanel> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final nodeLimit = MediaQuery.sizeOf(context).width < 700 ? 12 : 24;
    final visibleNodes = _visibleMapNodes(nodeLimit);
    AtelierNode? selected;
    for (final node in visibleNodes) {
      if (node.id == _selectedId) selected = node;
    }
    return _MundiariumPanel(
      accent: AppColors.gold,
      title: 'Mapa de relaciones',
      icon: Icons.hub_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  selected == null
                      ? '${visibleNodes.length} entidades · ${widget.relations.length} vinculos'
                      : selected.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (selected != null)
                IconButton(
                  tooltip: 'Abrir ficha',
                  onPressed: () => widget.onEditNode(selected!),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                ),
              IconButton.filledTonal(
                tooltip: 'Crear relacion',
                onPressed: widget.onCreateRelation,
                icon: const Icon(Icons.add_link_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (visibleNodes.isEmpty)
            _EmptyState(
              message: 'Crea entidades para construir el mapa.',
              actionLabel: 'Crear relacion',
              onAction: widget.onCreateRelation,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final height = compact ? 520.0 : 560.0;
                final nodeSize = Size(compact ? 92 : 116, compact ? 50 : 56);
                final positions = _mapPositions(
                  nodes: visibleNodes,
                  size: Size(constraints.maxWidth, height),
                  nodeSize: nodeSize,
                );
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _RelationshipPainter(
                              nodes: visibleNodes,
                              relations: widget.relations,
                              positions: positions,
                              nodeSize: nodeSize,
                              selectedId: _selectedId,
                            ),
                          ),
                        ),
                        ...visibleNodes.map((node) {
                          final position = positions[node.id]!;
                          return Positioned(
                            left: position.dx,
                            top: position.dy,
                            width: nodeSize.width,
                            height: nodeSize.height,
                            child: _RelationshipNode(
                              node: node,
                              compact: compact,
                              selected: node.id == _selectedId,
                              dimmed: _selectedId != null &&
                                  !_isConnected(
                                    node.id,
                                    _selectedId!,
                                    widget.relations,
                                  ),
                              onTap: () => setState(() {
                                _selectedId =
                                    _selectedId == node.id ? null : node.id;
                              }),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
          if (widget.nodes.length > visibleNodes.length) ...[
            const SizedBox(height: 10),
            Text(
              'Se muestran las 24 entidades con mas conexiones.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.38),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<AtelierNode> _visibleMapNodes(int limit) {
    final degree = <String, int>{};
    for (final relation in widget.relations) {
      degree.update(
        relation.sourceNodeId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      degree.update(
        relation.targetNodeId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final nodes = List<AtelierNode>.of(widget.nodes)
      ..sort((a, b) {
        if (a.kind == 'universe' && b.kind != 'universe') return -1;
        if (b.kind == 'universe' && a.kind != 'universe') return 1;
        final compared = (degree[b.id] ?? 0).compareTo(degree[a.id] ?? 0);
        return compared != 0 ? compared : a.title.compareTo(b.title);
      });
    return nodes.take(limit).toList();
  }
}

Map<String, Offset> _mapPositions({
  required List<AtelierNode> nodes,
  required Size size,
  required Size nodeSize,
}) {
  final result = <String, Offset>{};
  if (nodes.isEmpty) return result;
  final center = Offset(
    (size.width - nodeSize.width) / 2,
    (size.height - nodeSize.height) / 2,
  );
  result[nodes.first.id] = center;
  if (nodes.length == 1) return result;

  if (size.width < 620) {
    final columns = math.max(
      1,
      ((size.width - 16) / (nodeSize.width + 10)).floor(),
    );
    final rows = (nodes.length / columns).ceil();
    final horizontalGap =
        (size.width - columns * nodeSize.width) / (columns + 1);
    final verticalGap = (size.height - rows * nodeSize.height) / (rows + 1);
    for (var index = 0; index < nodes.length; index++) {
      final column = index % columns;
      final row = index ~/ columns;
      result[nodes[index].id] = Offset(
        horizontalGap + column * (nodeSize.width + horizontalGap),
        verticalGap + row * (nodeSize.height + verticalGap),
      );
    }
    return result;
  }

  final innerCount = math.min(8, nodes.length - 1);
  final outerCount = nodes.length - 1 - innerCount;
  final innerRadiusX = math.max(90.0, (size.width - nodeSize.width) * 0.27);
  final innerRadiusY = math.max(90.0, (size.height - nodeSize.height) * 0.27);
  final outerRadiusX = math.max(120.0, (size.width - nodeSize.width) * 0.47);
  final outerRadiusY = math.max(150.0, (size.height - nodeSize.height) * 0.45);

  void positionRing(int start, int count, double radiusX, double radiusY) {
    for (var index = 0; index < count; index++) {
      final angle = -math.pi / 2 + (2 * math.pi * index / count);
      final raw = Offset(
        center.dx + math.cos(angle) * radiusX,
        center.dy + math.sin(angle) * radiusY,
      );
      result[nodes[start + index].id] = Offset(
        raw.dx
            .clamp(8.0, math.max(8.0, size.width - nodeSize.width - 8))
            .toDouble(),
        raw.dy
            .clamp(8.0, math.max(8.0, size.height - nodeSize.height - 8))
            .toDouble(),
      );
    }
  }

  positionRing(1, innerCount, innerRadiusX, innerRadiusY);
  if (outerCount > 0) {
    positionRing(1 + innerCount, outerCount, outerRadiusX, outerRadiusY);
  }
  return result;
}

bool _isConnected(
  String first,
  String second,
  List<AtelierRelation> relations,
) {
  if (first == second) return true;
  return relations.any((relation) =>
      (relation.sourceNodeId == first && relation.targetNodeId == second) ||
      (relation.sourceNodeId == second && relation.targetNodeId == first));
}

class _RelationshipNode extends StatelessWidget {
  final AtelierNode node;
  final bool compact;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  const _RelationshipNode({
    required this.node,
    required this.compact,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _worldNodeColor(node.kind);
    return Tooltip(
      message: '${_kindLabel(node.kind)}: ${node.title}',
      child: AnimatedOpacity(
        opacity: dimmed ? 0.32 : 1,
        duration: const Duration(milliseconds: 150),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(7),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 7 : 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  color.withValues(alpha: selected ? 0.22 : 0.11),
                  AppColors.card,
                ),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: selected ? color : color.withValues(alpha: 0.34),
                  width: selected ? 1.5 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.18),
                          blurRadius: 16,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(_worldNodeIcon(node.kind), color: color, size: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      node.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: compact ? 10 : 11,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
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

class _RelationshipPainter extends CustomPainter {
  final List<AtelierNode> nodes;
  final List<AtelierRelation> relations;
  final Map<String, Offset> positions;
  final Size nodeSize;
  final String? selectedId;

  _RelationshipPainter({
    required this.nodes,
    required this.relations,
    required this.positions,
    required this.nodeSize,
    required this.selectedId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final nodeIds = nodes.map((node) => node.id).toSet();
    for (final relation in relations) {
      if (!nodeIds.contains(relation.sourceNodeId) ||
          !nodeIds.contains(relation.targetNodeId)) {
        continue;
      }
      final source = positions[relation.sourceNodeId]! +
          Offset(nodeSize.width / 2, nodeSize.height / 2);
      final target = positions[relation.targetNodeId]! +
          Offset(nodeSize.width / 2, nodeSize.height / 2);
      final highlighted = selectedId == null ||
          relation.sourceNodeId == selectedId ||
          relation.targetNodeId == selectedId;
      final color = relation.canonStatus == 'canon'
          ? AppColors.gold
          : AppColors.secondaryLight;
      final paint = Paint()
        ..color = color.withValues(alpha: highlighted ? 0.52 : 0.09)
        ..strokeWidth = highlighted ? 1.4 : 1
        ..style = PaintingStyle.stroke;
      canvas.drawLine(source, target, paint);
      _drawArrow(canvas, source, target, paint);

      if (selectedId != null && highlighted) {
        final midpoint = Offset(
          (source.dx + target.dx) / 2,
          (source.dy + target.dy) / 2,
        );
        final labelPainter = TextPainter(
          text: TextSpan(
            text: relation.relationType,
            style: TextStyle(
              color: color.withValues(alpha: 0.92),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              backgroundColor: AppColors.background.withValues(alpha: 0.84),
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: 110);
        labelPainter.paint(
          canvas,
          midpoint - Offset(labelPainter.width / 2, labelPainter.height / 2),
        );
      }
    }
  }

  void _drawArrow(Canvas canvas, Offset source, Offset target, Paint paint) {
    final direction = target - source;
    if (direction.distance < 1) return;
    final unit = direction / direction.distance;
    final tip = target - unit * (nodeSize.width * 0.46);
    final normal = Offset(-unit.dy, unit.dx);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - unit.dx * 7 + normal.dx * 3.5,
        tip.dy - unit.dy * 7 + normal.dy * 3.5,
      )
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - unit.dx * 7 - normal.dx * 3.5,
        tip.dy - unit.dy * 7 - normal.dy * 3.5,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RelationshipPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.relations != relations ||
        oldDelegate.positions != positions ||
        oldDelegate.selectedId != selectedId;
  }
}

class _MundiariumTimeline extends StatefulWidget {
  final List<AtelierNode> characters;
  final VoidCallback onCreateCharacter;
  final ValueChanged<AtelierNode> onEditCharacter;

  const _MundiariumTimeline({
    required this.characters,
    required this.onCreateCharacter,
    required this.onEditCharacter,
  });

  @override
  State<_MundiariumTimeline> createState() => _MundiariumTimelineState();
}

class _MundiariumTimelineState extends State<_MundiariumTimeline> {
  String? _selectedCharacterId;

  @override
  Widget build(BuildContext context) {
    final visible = _selectedCharacterId == null
        ? widget.characters
        : widget.characters
            .where((character) => character.id == _selectedCharacterId)
            .toList();
    return _MundiariumPanel(
      accent: AppColors.gold,
      title: 'Cronologias de personajes',
      icon: Icons.timeline_rounded,
      child: widget.characters.isEmpty
          ? _EmptyState(
              message: 'Crea un personaje para iniciar su cronologia.',
              actionLabel: 'Crear personaje',
              onAction: widget.onCreateCharacter,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Todos'),
                        selected: _selectedCharacterId == null,
                        onSelected: (_) =>
                            setState(() => _selectedCharacterId = null),
                      ),
                      const SizedBox(width: 8),
                      ...widget.characters.map((character) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(character.title),
                              selected: _selectedCharacterId == character.id,
                              onSelected: (_) => setState(
                                  () => _selectedCharacterId = character.id),
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ...visible.map((character) => _CharacterTimelineBand(
                      character: character,
                      onEdit: () => widget.onEditCharacter(character),
                    )),
              ],
            ),
    );
  }
}

class _CharacterTimelineBand extends StatelessWidget {
  final AtelierNode character;
  final VoidCallback onEdit;

  const _CharacterTimelineBand({
    required this.character,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final moments = characterTimeline(character);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                color: AppColors.primaryLight,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  character.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Editar ficha y cronologia',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
            ],
          ),
          if (moments.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 8),
              child: Text(
                'Sin momentos. Abre la ficha para agregar el primero.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.38),
                  fontSize: 12,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 7, top: 8),
              child: Column(
                children: moments.asMap().entries.map((entry) {
                  return _TimelineRow(
                    moment: entry.value,
                    isLast: entry.key == moments.length - 1,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final Map<String, String> moment;
  final bool isLast;

  const _TimelineRow({required this.moment, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final date = moment['date'] ?? '';
    final description = moment['description'] ?? '';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      color: AppColors.gold.withValues(alpha: 0.28),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (date.isNotEmpty)
                    Text(
                      date.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  Text(
                    moment['title'] ?? 'Momento',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    FormattedManuscriptText(
                      text: description,
                      fontSize: 12,
                      lineHeight: 1.5,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CharacterGallery extends StatelessWidget {
  final List<AtelierNode> characters;
  final VoidCallback onCreateCharacter;
  final ValueChanged<AtelierNode> onEditCharacter;
  final ValueChanged<AtelierNode> onDeleteCharacter;

  const _CharacterGallery({
    required this.characters,
    required this.onCreateCharacter,
    required this.onEditCharacter,
    required this.onDeleteCharacter,
  });

  @override
  Widget build(BuildContext context) {
    return _MundiariumPanel(
      accent: AppColors.primaryLight,
      title: 'Fichas de personaje',
      icon: Icons.badge_outlined,
      child: characters.isEmpty
          ? _EmptyState(
              message: 'No hay personajes en este universo.',
              actionLabel: 'Crear personaje',
              onAction: onCreateCharacter,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: onCreateCharacter,
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 17),
                    label: const Text('Nuevo personaje'),
                  ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1050
                        ? 3
                        : constraints.maxWidth >= 650
                            ? 2
                            : 1;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 12) / columns;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: characters
                          .map((character) => SizedBox(
                                width: width,
                                height: 170,
                                child: _CharacterSummaryCard(
                                  character: character,
                                  onEdit: () => onEditCharacter(character),
                                  onDelete: () => onDeleteCharacter(character),
                                ),
                              ))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _CharacterSummaryCard extends StatelessWidget {
  final AtelierNode character;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CharacterSummaryCard({
    required this.character,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final sheet = characterSheet(character);
    final role = sheet['role'] ?? 'Funcion sin definir';
    final template = switch (character.metadata['character_template']) {
      'essential' => 'Esencial',
      'complete' => 'Completa',
      _ => 'Narrativa',
    };
    final timelineCount = characterTimeline(character).length;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.primaryLight,
                    size: 19,
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: 'Acciones del personaje',
                    iconSize: 18,
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar ficha')),
                      PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                character.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                role,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  _Metric(icon: Icons.view_quilt_outlined, text: template),
                  const SizedBox(width: 12),
                  _Metric(
                    icon: Icons.timeline_rounded,
                    text: '$timelineCount momentos',
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

class _Metric extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Metric({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 13),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.48),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MundiariumPanel extends StatelessWidget {
  final Color accent;
  final String title;
  final IconData icon;
  final Widget child;

  const _MundiariumPanel({
    required this.accent,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.075)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyState({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.blur_on_rounded,
              color: AppColors.textMuted, size: 28),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

Color _worldNodeColor(String kind) => switch (kind) {
      'universe' || 'world' => AppColors.gold,
      'character' => AppColors.primaryLight,
      'place' || 'map' => AppColors.successLight,
      'faction' || 'family' || 'organization' => AppColors.secondaryLight,
      'event' => AppColors.warning,
      _ => AppColors.silver,
    };

IconData _worldNodeIcon(String kind) => switch (kind) {
      'universe' || 'world' => Icons.public_rounded,
      'character' => Icons.person_outline_rounded,
      'place' => Icons.place_outlined,
      'map' => Icons.map_outlined,
      'event' => Icons.bolt_outlined,
      'faction' || 'family' || 'organization' => Icons.groups_outlined,
      'object' => Icons.diamond_outlined,
      _ => Icons.circle_outlined,
    };

String _kindLabel(String kind) => switch (kind) {
      'universe' => 'Universo',
      'world' => 'Mundo',
      'character' => 'Personaje',
      'place' => 'Lugar',
      'faction' => 'Faccion',
      'family' => 'Familia',
      'organization' => 'Organizacion',
      'religion' => 'Religion',
      'culture' => 'Cultura',
      'language' => 'Idioma',
      'system' => 'Sistema',
      'technology' => 'Tecnologia',
      'magic' => 'Magia',
      'creature' => 'Criatura',
      'object' => 'Objeto',
      'event' => 'Evento',
      'map' => 'Mapa',
      _ => kind,
    };

Map<String, String> characterSheet(AtelierNode character) {
  final source = character.metadata['character_sheet'];
  if (source is! Map) return const {};
  return source.map((key, value) => MapEntry('$key', '$value'));
}

List<Map<String, String>> characterTimeline(AtelierNode character) {
  final source = character.metadata['character_timeline'];
  if (source is! List) return const [];
  return source.whereType<Map>().map((entry) {
    return {
      'id': '${entry['id'] ?? ''}',
      'date': '${entry['date'] ?? ''}',
      'title': '${entry['title'] ?? 'Momento'}',
      'description': '${entry['description'] ?? ''}',
    };
  }).toList();
}
