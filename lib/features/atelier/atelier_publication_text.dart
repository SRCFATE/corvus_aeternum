import '../../models/atelier_models.dart';
import 'atelier_rich_text_editor.dart';

String composeAtelierPublicationText(List<AtelierNode> nodes) {
  return nodes.map((node) {
    final alignment = atelierTextAlign(node.metadata['text_alignment']);
    final directive =
        '<!-- corvus-align:${atelierAlignmentName(alignment)} -->';
    return '# ${node.title}\n\n$directive\n${node.body.trim()}';
  }).join('\n\n');
}
