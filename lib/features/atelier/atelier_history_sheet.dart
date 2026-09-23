import 'package:flutter/material.dart';
import '../../models/atelier_models.dart';
import '../../providers/atelier_provider.dart';
import '../../shared/widgets/formatted_manuscript_text.dart';
import '../../core/rpc_error.dart';
import 'atelier_text_diff.dart';

Future<bool?> showAtelierHistory(
        BuildContext context, AtelierProvider provider, AtelierNode node) =>
    showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _HistorySheet(provider: provider, node: node));

class _HistorySheet extends StatefulWidget {
  final AtelierProvider provider;
  final AtelierNode node;
  const _HistorySheet({required this.provider, required this.node});
  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  final _label = TextEditingController();
  bool _busy = false;
  String? _error;
  AtelierVersion? _selected;
  AtelierVersion? _compareTo;
  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.provider.createVersionSnapshot(
          profileId: widget.node.profileId,
          projectId: widget.node.projectId,
          label: _label.text.trim().isEmpty
              ? 'Versión de ${widget.node.title}'
              : _label.text.trim(),
          description: 'Versión conservada manualmente.');
      if (mounted) _label.clear();
    } catch (_) {
      if (mounted) {
        _error = 'No se pudo conservar esta versión. Inténtalo de nuevo.';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_selected == null) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Restaurar como nueva edición'),
              content: const Text(
                  'Se restaurará el contenido de los elementos del proyecto incluidos en esta versión. Conservaremos una copia de la edición actual. La publicación no cambiará.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Restaurar'))
              ],
            ));
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.provider.restoreNodeVersion(
          widget.provider.nodeById(widget.node.id) ?? widget.node, _selected!);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error is CorvusRpcException
              ? error.message
              : 'No se pudo restaurar. Tu copia de seguridad se conserva.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshots = _selected?.metadata['snapshot_nodes'];
    final previous = snapshots is List
        ? snapshots
            .whereType<Map>()
            .where((row) => row['id'] == widget.node.id)
            .firstOrNull
        : null;
    final body = previous?['body'] as String?;
    final comparisonNodes = _compareTo?.metadata['snapshot_nodes'];
    final comparison = comparisonNodes is List
        ? (comparisonNodes
            .whereType<Map>()
            .where((row) => row['id'] == widget.node.id)
            .firstOrNull?['body'] as String?)
        : null;
    final currentBody = _compareTo == null ? widget.node.body : comparison;
    return SafeArea(
        child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .85,
      child: ListenableBuilder(
          listenable: widget.provider,
          builder: (context, _) => Column(children: [
                const ListTile(
                    title: Text('Historial editorial'),
                    subtitle: Text(
                        'Restaurar conserva la edición actual y no publica cambios.')),
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.all(12), child: Text(_error!)),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      Expanded(
                          child: TextField(
                              controller: _label,
                              decoration: const InputDecoration(
                                  labelText: 'Nombre de la versión'))),
                      TextButton(
                          onPressed: _busy ? null : _capture,
                          child: const Text('Conservar')),
                    ])),
                Expanded(
                    child:
                        ListView(padding: const EdgeInsets.all(16), children: [
                  if (widget.provider.versions.isEmpty)
                    const ListTile(
                        title: Text(
                            'Todavía no hay versiones. Conserva una antes de experimentar.')),
                  for (final version in widget.provider.versions)
                    ListTile(
                        title: Text(version.label),
                        selected: _selected?.id == version.id,
                        subtitle: Text(
                            '${version.createdAt.toLocal().toString().substring(0, 16)} · ${version.authorName.isEmpty ? 'Autor no disponible' : version.authorName}\n${version.description}'),
                        onTap: _busy
                            ? null
                            : () => setState(() => _selected = version)),
                  if (_selected != null && body == null)
                    const Text(
                        'Esta versión antigua solo conserva estadísticas o no incluye este elemento.'),
                  if (body != null) ...[
                    DropdownButtonFormField<String>(
                        initialValue: _compareTo?.id,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Comparar con'),
                        items: [
                          const DropdownMenuItem<String>(
                              value: null, child: Text('Edición actual')),
                          for (final version in widget.provider.versions)
                            DropdownMenuItem(
                                value: version.id,
                                child: Text(version.label,
                                    overflow: TextOverflow.ellipsis))
                        ],
                        onChanged: (id) => setState(() => _compareTo = widget
                            .provider.versions
                            .where((version) => version.id == id)
                            .firstOrNull)),
                    const SizedBox(height: 16),
                    if (currentBody != null)
                      EditorialTextDiff(before: body, after: currentBody)
                    else
                      const Text('Esta versión no contiene el elemento.'),
                    Text('Versión anterior',
                        style: Theme.of(context).textTheme.titleMedium),
                    FormattedManuscriptText(text: body),
                    const Divider(height: 32),
                    Text(_compareTo?.label ?? 'Edición actual',
                        style: Theme.of(context).textTheme.titleMedium),
                    if (currentBody != null)
                      FormattedManuscriptText(text: currentBody),
                    FilledButton.icon(
                        onPressed: _busy ? null : _restore,
                        icon: const Icon(Icons.restore),
                        label: const Text('Restaurar como nueva edición')),
                  ],
                ])),
              ])),
    ));
  }
}
