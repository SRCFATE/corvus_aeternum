import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/corvus_design.dart';
import '../../../../models/atelier_models.dart';
import '../../../../providers/entitlement_provider.dart';
import '../data/editorial_repository.dart';
import '../domain/manuscript.dart';
import '../services/entitlement_service.dart';
import '../services/export_download.dart';
import '../services/export_service.dart';
import '../widgets/upgrade_prompt.dart';

/// La hoja de exportación de Atelier.
///
/// Markdown, TXT y JSON aparecen arriba, abiertos, y con una frase que dice por
/// qué: llevarse la obra no es una función de pago, es un derecho. Los formatos
/// de producción vienen después, con su candado cuando toca, y sin esconder que
/// existen.
Future<void> showAtelierExportSheet(
  BuildContext context, {
  required AtelierWorkspace workspace,
  String author = '',
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(CorvusRadius.xl)),
    ),
    builder: (context) => _ExportSheet(workspace: workspace, author: author),
  );
}

class _ExportSheet extends StatefulWidget {
  final AtelierWorkspace workspace;
  final String author;

  const _ExportSheet({required this.workspace, required this.author});

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  final _service = AtelierExportService();
  final _editorial = EditorialRepository();

  ManuscriptFrontMatter _frontMatter = const ManuscriptFrontMatter();
  AtelierExportFormat? _busy;

  @override
  void initState() {
    super.initState();
    _loadFrontMatter();
  }

  /// Las páginas de cortesía son opcionales: si el proyecto no las tiene —o el
  /// plan no incluye producción editorial— se exporta igual, sin ellas.
  Future<void> _loadFrontMatter() async {
    final projectId = widget.workspace.activeProject?.id;
    if (projectId == null) return;

    try {
      final front = await _editorial.fetchFrontMatter(projectId);
      if (mounted) setState(() => _frontMatter = front);
    } catch (_) {
      // Silencio deliberado: no tener portadilla no impide exportar.
    }
  }

  Future<void> _export(AtelierExportSpec spec) async {
    setState(() => _busy = spec.format);

    try {
      final result = await _service.build(
        format: spec.format,
        workspace: widget.workspace,
        author: widget.author,
        frontMatter: _frontMatter,
      );

      final downloaded = await downloadExport(
        filename: result.filename,
        bytes: result.bytes,
        mimeType: result.mimeType,
      );

      if (!mounted) return;

      if (downloaded) {
        _message('${result.filename} descargado.');
        return;
      }

      // Sin descarga, un formato de texto todavía se puede llevar; uno binario
      // no, y decirlo es mejor que fingir que sí.
      final texto = result.text;
      if (texto == null) {
        _message(
          '${spec.label} solo se puede descargar desde la web por ahora.',
        );
        return;
      }

      await Clipboard.setData(ClipboardData(text: texto));
      if (!mounted) return;
      _message('${spec.label} copiado al portapapeles.');
    } catch (error) {
      if (mounted) _message('No se pudo exportar. $error');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<EntitlementProvider>().service;

    final libres = atelierExportFormats
        .where((spec) => EntitlementService.isProtected(spec.featureKey))
        .toList();
    final produccion = atelierExportFormats
        .where((spec) => !EntitlementService.isProtected(spec.featureKey))
        .toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(CorvusSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('EXPORTAR', style: CorvusType.eyebrow(AppColors.gold)),
              const SizedBox(height: CorvusSpacing.md),
              Text(
                widget.workspace.activeProject?.title ?? 'Proyecto',
                style: CorvusType.title,
              ),
              const SizedBox(height: CorvusSpacing.xl),
              Row(
                children: [
                  const Icon(Icons.lock_open_rounded,
                      size: 14, color: AppColors.successLight),
                  const SizedBox(width: CorvusSpacing.sm),
                  Expanded(
                    child: Text(
                      'Llevarte tu obra nunca cuesta. Estos formatos están '
                      'abiertos en todos los planes, siempre.',
                      style: CorvusType.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CorvusSpacing.lg),
              for (final spec in libres) ...[
                _ExportRow(
                  spec: spec,
                  allowed: true,
                  busy: _busy == spec.format,
                  onTap: () => _export(spec),
                ),
                const SizedBox(height: CorvusSpacing.sm),
              ],
              const SizedBox(height: CorvusSpacing.lg),
              const CorvusSectionLabel(label: 'Formatos de producción'),
              const SizedBox(height: CorvusSpacing.md),
              if (!_frontMatter.isEmpty) ...[
                Text(
                  'Se incluirán las páginas de cortesía del proyecto: '
                  'copyright, dedicatoria y agradecimientos.',
                  style: CorvusType.muted,
                ),
                const SizedBox(height: CorvusSpacing.md),
              ],
              for (final spec in produccion) ...[
                _ExportRow(
                  spec: spec,
                  allowed: service.hasEntitlement(spec.featureKey),
                  busy: _busy == spec.format,
                  onTap: () {
                    if (!service.hasEntitlement(spec.featureKey)) {
                      showUpgradePrompt(
                        context,
                        featureKey: spec.featureKey,
                        title: 'Exportar en ${spec.label}',
                        description: spec.description,
                        check: service.canUse(spec.featureKey),
                        surface: 'atelier.export',
                      );
                      return;
                    }
                    _export(spec);
                  },
                ),
                const SizedBox(height: CorvusSpacing.sm),
              ],
              const SizedBox(height: CorvusSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportRow extends StatelessWidget {
  final AtelierExportSpec spec;
  final bool allowed;
  final bool busy;
  final VoidCallback onTap;

  const _ExportRow({
    required this.spec,
    required this.allowed,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CorvusPanel(
      onTap: busy ? null : onTap,
      padding: const EdgeInsets.all(CorvusSpacing.lg),
      accent: allowed ? null : AppColors.gold,
      child: Row(
        children: [
          Icon(
            allowed ? Icons.download_rounded : Icons.lock_outline_rounded,
            size: 17,
            color: allowed
                ? AppColors.textSecondary
                : AppColors.gold.withValues(alpha: 0.8),
          ),
          const SizedBox(width: CorvusSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spec.label, style: CorvusType.subtitle),
                const SizedBox(height: 2),
                Text(spec.description, style: CorvusType.muted),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              height: 15,
              width: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}
