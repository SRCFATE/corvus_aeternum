import 'package:flutter/material.dart';
import '../../providers/atelier_provider.dart';
import '../../shared/widgets/formatted_manuscript_text.dart';
import 'atelier_publication_review.dart';
import 'atelier_text_diff.dart';

Future<bool> confirmAtelierPublication(
    BuildContext context, AtelierProvider provider,
    {required String action}) async {
  final issues = provider.publicationIssues;
  final snapshot = provider.activeProject?.metadata['publication_snapshot'];
  final previous = {
    if (snapshot is List)
      for (final row in snapshot.whereType<Map>()) row['id'] as String: row
  };
  final anchors = {
    for (final node in provider.studioNodes) node.id: GlobalKey()
  };
  final blocked =
      issues.any((issue) => issue.severity == PublicationSeverity.blocking);
  final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
            title: const Text('Revisar antes de publicar'),
            content: SizedBox(
              width: 680,
              height: MediaQuery.sizeOf(ctx).height * .6,
              child: ListView(children: [
                Text(
                    '${provider.studioNodes.length} elementos · ${provider.wordCount} palabras'),
                const Text(
                    'Se enviará el manuscrito guardado del proyecto. Revisa también los demás capítulos.'),
                if (provider.activeProject?.metadata['publication_updated_at']
                    is String)
                  Text(
                      'Último envío: ${DateTime.tryParse(provider.activeProject!.metadata['publication_updated_at'] as String)?.toLocal().toString().substring(0, 16) ?? 'Fecha no disponible'}'),
                if (previous.isNotEmpty)
                  Text(provider.publicationIsCurrent
                      ? 'El manuscrito coincide con la última versión enviada.'
                      : 'Hay cambios pendientes. Abre cada elemento para compararlos.'),
                for (final old in previous.values
                    .where((row) => !anchors.containsKey(row['id'])))
                  ListTile(
                      leading: const Icon(Icons.remove_circle_outline),
                      title: Text('Se retirará: ${old['title']}')),
                if (issues.isEmpty)
                  const ListTile(
                      leading: Icon(Icons.check_circle_outline),
                      title: Text('Sin problemas estructurales detectados')),
                for (final issue in issues)
                  ListTile(
                    leading: Icon(issue.severity == PublicationSeverity.blocking
                        ? Icons.error_outline
                        : Icons.info_outline),
                    title: Text(issue.severity == PublicationSeverity.blocking
                        ? 'Bloqueante'
                        : 'Recomendación'),
                    subtitle: Text(issue.message),
                    onTap: issue.nodeId == null
                        ? null
                        : () {
                            final target =
                                anchors[issue.nodeId]?.currentContext;
                            if (target != null) {
                              Scrollable.ensureVisible(target,
                                  duration: MediaQuery.disableAnimationsOf(ctx)
                                      ? Duration.zero
                                      : const Duration(milliseconds: 150));
                            }
                          },
                  ),
                const Divider(),
                for (final node in provider.studioNodes)
                  ExpansionTile(
                      key: anchors[node.id],
                      title: Text(node.title),
                      subtitle: Text(
                          '${node.wordCount} palabras · ${previous[node.id] == null ? 'Nuevo' : previous[node.id]!['body'] == node.body && previous[node.id]!['title'] == node.title ? 'Sin cambios' : 'Modificado'}'),
                      children: [
                        if (previous[node.id] != null)
                          Padding(
                              padding: const EdgeInsets.all(16),
                              child: EditorialTextDiff(
                                  before:
                                      previous[node.id]!['body'] as String? ??
                                          '',
                                  after: node.body)),
                        Padding(
                            padding: const EdgeInsets.all(16),
                            child: FormattedManuscriptText(text: node.body))
                      ]),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Volver a revisar')),
              FilledButton(
                  onPressed: blocked ? null : () => Navigator.pop(ctx, true),
                  child: Text(action)),
            ],
          ));
  return result == true;
}
