import '../../models/atelier_models.dart';
import 'atelier_rich_text_editor.dart';

const atelierChapterBoundaryMarker = '<!-- corvus-chapter -->';

final _atelierAlignmentDirective = RegExp(
  r'^<!--\s*corvus-align:(?:left|right|center|justify)\s*-->$',
  multiLine: true,
);

String composeAtelierPublicationText(List<AtelierNode> nodes) {
  return nodes.map((node) {
    final title = node.title.replaceAll(RegExp(r'\s+'), ' ').trim();
    final body = node.body.trim();
    final alignment =
        atelierAlignmentName(atelierTextAlign(node.metadata['text_alignment']));
    final needsLegacyAlignment = alignment != 'left' &&
        body.isNotEmpty &&
        !_atelierAlignmentDirective.hasMatch(body);
    final content =
        needsLegacyAlignment ? '<!-- corvus-align:$alignment -->\n$body' : body;
    return '$atelierChapterBoundaryMarker\n# $title'
        '${content.isEmpty ? '' : '\n\n$content'}';
  }).join('\n\n');
}
