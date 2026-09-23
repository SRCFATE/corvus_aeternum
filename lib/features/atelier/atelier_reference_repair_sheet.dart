import 'package:flutter/material.dart';
import '../../models/atelier_models.dart';
import 'atelier_reference_repair.dart';

typedef AtelierReferenceChoice = ({
  AtelierReferenceRepair repair,
  AtelierNode target
});

class AtelierReferenceRepairSheet extends StatefulWidget {
  final List<AtelierReferenceRepair> repairs;
  const AtelierReferenceRepairSheet({super.key, required this.repairs});
  @override
  State<AtelierReferenceRepairSheet> createState() =>
      _AtelierReferenceRepairSheetState();
}

class _AtelierReferenceRepairSheetState
    extends State<AtelierReferenceRepairSheet> {
  late final Map<int, AtelierNode> _selected = {
    for (final repair in widget.repairs)
      if (repair.candidates.length == 1)
        repair.offset: repair.candidates.single,
  };
  @override
  Widget build(BuildContext context) => SafeArea(
          child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: Column(children: [
          const ListTile(
              title: Text('Revisar referencias'),
              subtitle: Text(
                  'Solo cambiaremos las menciones que elijas. Los nombres ambiguos necesitan una ficha de destino.')),
          Expanded(
              child: ListView.builder(
                  itemCount: widget.repairs.length,
                  itemBuilder: (context, index) {
                    final repair = widget.repairs[index];
                    final selected = _selected[repair.offset];
                    if (repair.candidates.isEmpty) {
                      return ListTile(
                          leading: const Icon(Icons.link_off),
                          title: Text(repair.source),
                          subtitle: const Text(
                              'No hay ficha coincidente. Puedes crearla desde @ o revisar el nombre.'));
                    }
                    return Column(mainAxisSize: MainAxisSize.min, children: [
                      CheckboxListTile(
                          value: selected != null,
                          title: Text(repair.source),
                          subtitle: Text(selected == null
                              ? 'Sin cambios'
                              : '${repair.renamed ? 'Nombre actualizado' : 'Vincular a ficha'}: ${repair.replacement(selected)}'),
                          onChanged:
                              repair.candidates.length > 1 && selected == null
                                  ? null
                                  : (value) => setState(() {
                                        if (value == true) {
                                          _selected[repair.offset] =
                                              repair.candidates.first;
                                        } else {
                                          _selected.remove(repair.offset);
                                        }
                                      })),
                      if (repair.candidates.length > 1)
                        Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: DropdownButtonFormField<String>(
                                key: ValueKey(
                                    '${repair.offset}:${selected?.id}'),
                                initialValue: selected?.id,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                    labelText: 'Elegir ficha'),
                                items: repair.candidates
                                    .map((n) => DropdownMenuItem(
                                        value: n.id,
                                        child: Text(
                                            '${n.title}${n.body.trim().isEmpty ? '' : ' — ${n.body.split('\n').first}'}',
                                            overflow: TextOverflow.ellipsis)))
                                    .toList(),
                                onChanged: (value) => setState(() =>
                                    _selected[repair.offset] = repair.candidates
                                        .firstWhere((n) => n.id == value))))
                    ]);
                  })),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: _selected.isEmpty
                            ? null
                            : () => Navigator.pop(context, [
                                  for (final repair in widget.repairs)
                                    if (_selected.containsKey(repair.offset))
                                      (
                                        repair: repair,
                                        target: _selected[repair.offset]!
                                      ),
                                ]),
                        child: Text(_selected.length == 1
                            ? 'Aplicar 1 cambio'
                            : 'Aplicar ${_selected.length} cambios')),
                  ])),
        ]),
      ));
}
