import 'package:flutter/material.dart';
import 'atelier_project_import.dart';

class AtelierImportDialog extends StatefulWidget {
  final AtelierProjectImport project;
  final Future<void> Function() onImport;
  const AtelierImportDialog(
      {super.key, required this.project, required this.onImport});
  @override
  State<AtelierImportDialog> createState() => _AtelierImportDialogState();
}

class _AtelierImportDialogState extends State<AtelierImportDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onImport();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'No se pudo confirmar la recuperación. Comprueba la conexión y vuelve a intentarlo aquí; el reintento no duplica la copia.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy,
        child: AlertDialog(
          title: const Text('Recuperar proyecto'),
          content: SingleChildScrollView(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.project.title,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text(
                  '${widget.project.nodeCount} elementos · ${widget.project.relationCount} relaciones · ${widget.project.versionCount} versiones'),
              const SizedBox(height: 12),
              const Text(
                  'Se creará una copia privada en tu cuenta. El proyecto original y la obra publicada se conservarán. Las fichas también serán privadas; podrás revisar su visibilidad después.'),
              if (_busy)
                const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(
                        semanticsLabel: 'Recuperando proyecto')),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(_error!,
                        semanticsLabel: _error,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
            ],
          )),
          actions: [
            TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: _busy ? null : _restore,
                child: Text(_error == null
                    ? 'Restaurar como copia privada'
                    : 'Reintentar')),
          ],
        ),
      );
}
