// Primitivos de interfaz del Atelier.
//
// Paneles, tarjetas, filas, métricas y botones compartidos por todas las
// secciones del taller. Se extrajeron de atelier_page.dart para que las
// vistas nuevas puedan reutilizarlos sin depender de la página.

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/atelier_models.dart';
import '../../providers/atelier_provider.dart';
import 'atelier_catalog.dart';

class AtelierPanel extends StatelessWidget {
  final Color accent;
  final Widget child;
  final String? title;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  const AtelierPanel({
    super.key,
    required this.accent,
    required this.child,
    this.title,
    this.icon,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.075)),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: accent, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title!,
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
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class AtelierSectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Color accent;
  final Widget? trailing;

  const AtelierSectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AtelierEyebrow(eyebrow, color: accent),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              text,
              if (trailing != null) ...[
                const SizedBox(height: 12),
                trailing!,
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: text),
            if (trailing != null) ...[
              const SizedBox(width: 16),
              trailing!,
            ],
          ],
        );
      },
    );
  }
}

class AtelierMetricGrid extends StatelessWidget {
  final List<AtelierMetric> metrics;

  const AtelierMetricGrid({
    super.key,required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 960
            ? metrics.length.clamp(1, 6)
            : constraints.maxWidth >= 520
                ? 3
                : 2;
        final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: metrics
              .map((metric) =>
                  SizedBox(width: width, child: AtelierMetricCard(metric: metric)))
              .toList(),
        );
      },
    );
  }
}

class AtelierMetricCard extends StatelessWidget {
  final AtelierMetric metric;

  const AtelierMetricCard({
    super.key,required this.metric});

  @override
  Widget build(BuildContext context) {
    return AtelierPanel(
      accent: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class AtelierNodeGrid extends StatelessWidget {
  final List<AtelierNode> nodes;
  final Color accent;
  final ValueChanged<AtelierNode> onEditNode;
  final ValueChanged<AtelierNode> onDeleteNode;

  const AtelierNodeGrid({
    super.key,
    required this.nodes,
    required this.accent,
    required this.onEditNode,
    required this.onDeleteNode,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720
            ? 3
            : constraints.maxWidth >= 440
                ? 2
                : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: nodes
              .map(
                (node) => SizedBox(
                  width: width,
                  child: AtelierNodeCard(
                    node: node,
                    accent: accent,
                    onTap: () => onEditNode(node),
                    onDelete: () => onDeleteNode(node),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class AtelierNodeCard extends StatelessWidget {
  final AtelierNode node;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const AtelierNodeCard({
    super.key,
    required this.node,
    required this.accent,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AtelierKindBadge(kind: node.kind),
                const Spacer(),
                AtelierTinyIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Eliminar',
                  onTap: onDelete,
                  danger: true,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              node.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              node.body.trim().isEmpty ? 'Sin contenido' : node.body.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AtelierSelectableNodeRow extends StatelessWidget {
  final AtelierNode node;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AtelierSelectableNodeRow({
    super.key,
    required this.node,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.035),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.32)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          onTap: onTap,
          title: Text(
            node.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            '${nodeKinds[node.kind] ?? node.kind} / ${node.status}',
          ),
          trailing: Wrap(
            spacing: 2,
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded, size: 17),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AtelierNodeRow extends StatelessWidget {
  final AtelierNode node;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const AtelierNodeRow({
    super.key,
    required this.node,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          onTap: onTap,
          dense: true,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          leading: AtelierKindIcon(kind: node.kind),
          title: Text(
            node.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            '${nodeKinds[node.kind] ?? node.kind} / ${node.status}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: onDelete == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  onPressed: onDelete,
                ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class AtelierRelationRow extends StatelessWidget {
  final AtelierRelation relation;
  final AtelierProvider atelier;
  final VoidCallback onDelete;

  const AtelierRelationRow({
    super.key,
    required this.relation,
    required this.atelier,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final source = atelier.nodeById(relation.sourceNodeId);
    final target = atelier.nodeById(relation.targetNodeId);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${source?.title ?? 'Origen'} -> ${relation.relationType} -> ${target?.title ?? 'Destino'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 17),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class AtelierIssueRow extends StatelessWidget {
  final AtelierReviewIssue issue;

  const AtelierIssueRow({
    super.key,required this.issue});

  @override
  Widget build(BuildContext context) {
    final color = switch (issue.severity) {
      'alta' => AppColors.errorLight,
      'media' => AppColors.warning,
      _ => AppColors.textSecondary,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.report_problem_outlined, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${issue.category} / ${issue.detail}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.44),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          AtelierTag(issue.severity, color: color),
        ],
      ),
    );
  }
}

class AtelierChecklistRow extends StatelessWidget {
  final AtelierChecklistItem item;
  final Color accent;

  const AtelierChecklistRow({
    super.key,
    required this.item,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = item.done ? AppColors.successLight : AppColors.textMuted;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            item.done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: item.done ? color : accent.withValues(alpha: 0.45),
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.label,
              style: TextStyle(
                color:
                    item.done ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (!item.required) AtelierTag('opcional', color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class AtelierMessagePanel extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AtelierMessagePanel({
    super.key,
    required this.accent,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return AtelierPanel(
      accent: accent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                AtelierIconBox(icon: icon, color: accent, size: 58),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.44),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 20),
                  AtelierActionButton(
                    label: actionLabel!,
                    icon: Icons.arrow_forward_rounded,
                    accent: accent,
                    onTap: onAction,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AtelierEditorEmpty extends StatelessWidget {
  final VoidCallback onCreate;
  final String actionLabel;

  const AtelierEditorEmpty({
    super.key,
    required this.onCreate,
    required this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: AtelierEmptyInline(
        message:
            'Crea un primer elemento para empezar a desarrollar esta obra.',
        actionLabel: actionLabel,
        onAction: onCreate,
      ),
    );
  }
}

class AtelierEmptyInline extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AtelierEmptyInline({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              AtelierSoftButton(
                label: actionLabel!,
                icon: Icons.add_rounded,
                onTap: onAction!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AtelierSuccessInline extends StatelessWidget {
  final String message;

  const AtelierSuccessInline({
    super.key,required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle_outline_rounded,
            color: AppColors.successLight, size: 19),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class AtelierInfoLine extends StatelessWidget {
  final String label;
  final String value;
  final bool last;

  const AtelierInfoLine({
    super.key,
    required this.label,
    required this.value,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      margin: EdgeInsets.only(bottom: last ? 0 : 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: last
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AtelierActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  const AtelierActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor:
          onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.45 : 1,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.background, size: 17),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.background,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
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

class AtelierSoftButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const AtelierSoftButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor:
          onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.45 : 1,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.textSecondary, size: 17),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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

class AtelierIconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const AtelierIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AtelierTinyIconButton(icon: icon, tooltip: tooltip, onTap: onTap);
  }
}

class AtelierTinyIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool danger;

  const AtelierTinyIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.errorLight : AppColors.textSecondary;
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor:
            onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }
}

class AtelierIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const AtelierIconBox({
    super.key,
    required this.icon,
    required this.color,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }
}

class AtelierKindIcon extends StatelessWidget {
  final String kind;

  const AtelierKindIcon({
    super.key,required this.kind});

  @override
  Widget build(BuildContext context) {
    return AtelierIconBox(icon: atelierKindIcon(kind), color: atelierKindColor(kind), size: 34);
  }
}

class AtelierKindBadge extends StatelessWidget {
  final String kind;

  const AtelierKindBadge({
    super.key,required this.kind});

  @override
  Widget build(BuildContext context) {
    final color = atelierKindColor(kind);
    return AtelierTag(nodeKinds[kind] ?? kind, color: color);
  }
}

class AtelierTag extends StatelessWidget {
  final String label;
  final Color color;

  const AtelierTag(this.label, {super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class AtelierMiniMetric extends StatelessWidget {
  final String value;
  final String label;

  const AtelierMiniMetric({
    super.key,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class AtelierEyebrow extends StatelessWidget {
  final String label;
  final Color color;

  const AtelierEyebrow(this.label, {super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: color.withValues(alpha: 0.84),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    );
  }
}

class AtelierMetric {
  final String value;
  final String label;

  const AtelierMetric(this.value, this.label);
}

IconData atelierKindIcon(String kind) => switch (kind) {
      'chapter' => Icons.article_outlined,
      'scene' => Icons.movie_filter_outlined,
      'fragment' => Icons.auto_fix_high_outlined,
      'sketch' => Icons.brush_outlined,
      'moodboard' => Icons.dashboard_customize_outlined,
      'palette' => Icons.palette_outlined,
      'reference' => Icons.bookmark_border_rounded,
      'technical_sheet' => Icons.fact_check_outlined,
      'track' => Icons.audiotrack_rounded,
      'lyric' => Icons.lyrics_outlined,
      'demo' => Icons.mic_none_rounded,
      'mix' => Icons.graphic_eq_rounded,
      'credits' => Icons.badge_outlined,
      'script' => Icons.description_outlined,
      'storyboard' => Icons.view_carousel_outlined,
      'shot' => Icons.camera_alt_outlined,
      'location' => Icons.location_on_outlined,
      'prop' => Icons.category_outlined,
      'casting' => Icons.groups_outlined,
      'page' => Icons.insert_drive_file_outlined,
      'panel' => Icons.crop_16_9_outlined,
      'dialogue' => Icons.forum_outlined,
      'cover' => Icons.image_outlined,
      'garment' => Icons.checkroom_outlined,
      'collection' => Icons.grid_view_rounded,
      'material' => Icons.texture_outlined,
      'size_run' => Icons.straighten_outlined,
      'supplier' => Icons.local_shipping_outlined,
      'sample' => Icons.science_outlined,
      'lookbook' => Icons.photo_library_outlined,
      'gdd' => Icons.integration_instructions_outlined,
      'mechanic' => Icons.settings_suggest_outlined,
      'level' => Icons.map_outlined,
      'mission' => Icons.flag_outlined,
      'bug' => Icons.bug_report_outlined,
      'act' => Icons.theater_comedy_outlined,
      'rehearsal' => Icons.event_available_outlined,
      'costume' => Icons.checkroom_outlined,
      'light_cue' => Icons.lightbulb_outline_rounded,
      'zone' => Icons.grid_4x4_outlined,
      'plan' => Icons.architecture_rounded,
      'furniture' => Icons.chair_outlined,
      'budget' => Icons.payments_outlined,
      'note' => Icons.sticky_note_2_outlined,
      'universe' => Icons.public_rounded,
      'map' => Icons.map_outlined,
      'character' => Icons.person_outline_rounded,
      'place' => Icons.place_outlined,
      'faction' => Icons.flag_outlined,
      'event' => Icons.event_outlined,
      'object' => Icons.category_outlined,
      'system' => Icons.schema_outlined,
      'asset' => Icons.image_outlined,
      _ => Icons.bubble_chart_outlined,
    };

Color atelierKindColor(String kind) => switch (kind) {
      'chapter' => AppColors.primary,
      'scene' => AppColors.gold,
      'fragment' => AppColors.secondaryLight,
      'sketch' => AppColors.gold,
      'moodboard' => AppColors.secondaryLight,
      'palette' => AppColors.warning,
      'reference' => AppColors.silver,
      'technical_sheet' => AppColors.successLight,
      'track' => AppColors.warning,
      'lyric' => AppColors.secondaryLight,
      'demo' => AppColors.gold,
      'mix' => AppColors.successLight,
      'credits' => AppColors.silver,
      'script' => AppColors.primary,
      'storyboard' => AppColors.gold,
      'shot' => AppColors.silver,
      'location' => AppColors.successLight,
      'prop' => AppColors.warning,
      'casting' => AppColors.secondaryLight,
      'page' => AppColors.primary,
      'panel' => AppColors.gold,
      'dialogue' => AppColors.secondaryLight,
      'cover' => AppColors.warning,
      'garment' => AppColors.secondaryLight,
      'collection' => AppColors.gold,
      'material' => AppColors.silver,
      'size_run' => AppColors.successLight,
      'supplier' => AppColors.warning,
      'sample' => AppColors.primaryLight,
      'lookbook' => AppColors.gold,
      'gdd' => AppColors.successLight,
      'mechanic' => AppColors.primary,
      'level' => AppColors.gold,
      'mission' => AppColors.warning,
      'bug' => AppColors.errorLight,
      'act' => AppColors.primary,
      'rehearsal' => AppColors.successLight,
      'costume' => AppColors.secondaryLight,
      'light_cue' => AppColors.gold,
      'zone' => AppColors.silver,
      'plan' => AppColors.gold,
      'furniture' => AppColors.secondaryLight,
      'budget' => AppColors.successLight,
      'note' => AppColors.secondaryLight,
      'universe' => AppColors.primary,
      'map' => AppColors.gold,
      'character' => AppColors.successLight,
      'place' => AppColors.gold,
      'faction' => AppColors.warning,
      'event' => AppColors.primaryLight,
      'object' => AppColors.silver,
      'system' => AppColors.secondary,
      'asset' => AppColors.success,
      _ => AppColors.textSecondary,
    };

