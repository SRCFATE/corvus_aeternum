import '../../models/atelier_models.dart';
import '../work/work_reading_utils.dart';

enum PublicationSeverity { blocking, recommendation, information }

class PublicationIssue {
  final PublicationSeverity severity;
  final String message;
  final String? nodeId;
  const PublicationIssue(this.severity, this.message, [this.nodeId]);
}

List<PublicationIssue> reviewAtelierPublication(List<AtelierNode> nodes,
    {List<AtelierNode> references = const [],
    Map<String, String> previousBodies = const {}}) {
  final issues = <PublicationIssue>[];
  final titles = <String>{};
  if (nodes.isEmpty) {
    issues.add(const PublicationIssue(PublicationSeverity.blocking,
        'Añade al menos un elemento al manuscrito.'));
  }
  for (final node in nodes) {
    final title = node.title.trim();
    final previousBody = previousBodies[node.id];
    if (previousBody != null && previousBody != node.body) {
      final previousText = manuscriptPlainText(previousBody);
      final currentText = manuscriptPlainText(node.body);
      // Count added/removed word occurrences. Comparing whole lines makes a
      // one-letter correction in a long paragraph look like a full rewrite.
      final balance = <String, int>{};
      for (final word in RegExp(r'\S+').allMatches(previousText)) {
        balance.update(word[0]!, (n) => n + 1, ifAbsent: () => 1);
      }
      for (final word in RegExp(r'\S+').allMatches(currentText)) {
        balance.update(word[0]!, (n) => n - 1, ifAbsent: () => -1);
      }
      final changedCharacters = balance.entries.fold<int>(
          0, (sum, entry) => sum + entry.key.length * entry.value.abs());
      if (previousText.length >= 500 &&
          changedCharacters > previousText.length * .5) {
        issues.add(PublicationIssue(
            PublicationSeverity.recommendation,
            '«$title» tiene una revisión extensa. Revisa las adiciones y los fragmentos retirados antes de actualizar.',
            node.id));
      }
    }
    if (title.isEmpty ||
        title.toLowerCase() == 'sin título' ||
        title.toLowerCase() == 'sin titulo') {
      issues.add(PublicationIssue(PublicationSeverity.blocking,
          'Escribe un título para este elemento.', node.id));
    }
    if (!titles.add(title.toLowerCase())) {
      issues.add(PublicationIssue(
          PublicationSeverity.recommendation,
          'El título «$title» se repite. Comprueba que sea intencional.',
          node.id));
    }
    if (WorkChapter(title: title, content: node.body).wordCount == 0) {
      issues.add(PublicationIssue(
          PublicationSeverity.blocking,
          '«$title» no tiene contenido. Escribe el texto o retira el elemento del manuscrito.',
          node.id));
    }
    var previousLevel = 1;
    for (final heading
        in RegExp(r'^(#{1,6})\s+.+', multiLine: true).allMatches(node.body)) {
      final level = heading.group(1)!.length;
      if (level > previousLevel + 1) {
        issues.add(PublicationIssue(
            PublicationSeverity.recommendation,
            'Revisa el salto de nivel de los subtítulos de «$title».',
            node.id));
        break;
      }
      previousLevel = level;
    }
    for (final link in node.wikilinks) {
      final targets = references.where(
          (reference) => reference.title.toLowerCase() == link.toLowerCase());
      if (targets.isEmpty) {
        issues.add(PublicationIssue(
            PublicationSeverity.recommendation,
            'La referencia «$link» no tiene ficha. Crea la ficha o revisa el nombre.',
            node.id));
      }
    }
    for (final link
        in RegExp(r'\]\(corvus-node:([^)]+)\)').allMatches(node.body)) {
      final target = references
          .where((reference) => reference.id == link.group(1))
          .firstOrNull;
      if (target == null ||
          target.visibility != 'public' ||
          target.metadata['deleted_at'] != null) {
        issues.add(PublicationIssue(
            PublicationSeverity.blocking,
            '«$title» enlaza una ficha privada o no disponible. Retira el vínculo antes de publicar.',
            node.id));
      }
    }
    if (RegExp(r'\]\(\s*(?:javascript|data):', caseSensitive: false)
        .hasMatch(node.body)) {
      issues.add(PublicationIssue(PublicationSeverity.blocking,
          'Retira el vínculo incompatible de «$title».', node.id));
    }
    if (RegExp(
            r'<!--(?!\s*corvus-align:(?:left|center|right|justify)\s*-->)[\s\S]*?-->')
        .hasMatch(node.body)) {
      issues.add(PublicationIssue(
          PublicationSeverity.blocking,
          '«$title» contiene una anotación interna incompatible. Retírala del cuerpo antes de publicar.',
          node.id));
    }
    if (RegExp(r'^\s*⁂\s*\S+', multiLine: true).hasMatch(node.body)) {
      issues.add(PublicationIssue(
          PublicationSeverity.recommendation,
          'Coloca el separador de escena de «$title» en una línea independiente.',
          node.id));
    }
    if (node.status != 'done') {
      issues.add(PublicationIssue(PublicationSeverity.recommendation,
          '«$title» todavía no está marcado como terminado.', node.id));
    }
  }
  return issues;
}
