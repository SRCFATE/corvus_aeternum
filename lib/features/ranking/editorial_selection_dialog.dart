import 'package:flutter/material.dart';
import '../../services/work_ranking_service.dart';

class EditorialSelectionDialog extends StatefulWidget {
  final String workId;
  final String title;
  final WorkRankingService? service;
  const EditorialSelectionDialog(
      {super.key, required this.workId, required this.title, this.service});
  @override
  State<EditorialSelectionDialog> createState() =>
      _EditorialSelectionDialogState();
}

class _EditorialSelectionDialogState extends State<EditorialSelectionDialog> {
  late final _service = widget.service ?? WorkRankingService();
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  bool _selected = false;
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reason = await _service.editorialReason(widget.workId);
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _selected = reason != null;
        _reason.text = reason ?? '';
      });
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'No se pudo consultar la selección. Reintenta.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save({bool remove = false}) async {
    if (_saving || (!remove && !_form.currentState!.validate())) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.selectEditorial(
          widget.workId, remove ? null : _reason.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'No se guardó la selección. Comprueba la conexión y tus permisos.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Selección editorial'),
        content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
                child: Form(
              key: _form,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title),
                    const SizedBox(height: 12),
                    const Text(
                        'El motivo será público y acompañará la obra en Ranking.'),
                    if (_loading || _saving) const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: _reason,
                        enabled: !_loading && !_saving,
                        maxLines: 4,
                        maxLength: 600,
                        decoration: const InputDecoration(
                            labelText: 'Motivo de la elección'),
                        validator: (value) => (value?.trim().length ?? 0) < 10
                            ? 'Explica el motivo con al menos 10 caracteres.'
                            : null),
                    if (_error != null) Text(_error!, semanticsLabel: _error),
                    if (_error != null && !_saving && !_loaded)
                      TextButton(
                          onPressed: _load,
                          child: const Text('Volver a consultar')),
                  ]),
            ))),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancelar')),
          if (_selected)
            TextButton(
                onPressed:
                    _saving || _loading ? null : () => _save(remove: true),
                child: const Text('Retirar selección')),
          FilledButton(
              onPressed: _saving || _loading || !_loaded ? null : _save,
              child: const Text('Guardar selección')),
        ],
      ));
}
