import 'package:flutter/material.dart';
import '../../services/work_ranking_service.dart';
import '../../shared/widgets/work_card.dart';

class WorkRankingSliver extends StatelessWidget {
  final List<WorkRankingEntry> entries;
  final WorkRankingMode mode;
  const WorkRankingSliver(
      {super.key, required this.entries, required this.mode});

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
        builder: (context, constraints) => SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:
                  (constraints.crossAxisExtent / 300).floor().clamp(1, 3),
              mainAxisExtent: 330 + MediaQuery.textScalerOf(context).scale(85),
              mainAxisSpacing: 20,
              crossAxisSpacing: 20),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: WorkCard(work: entry.work)),
                  const SizedBox(height: 8),
                  Text('${index + 1}. ${entry.context(mode)}',
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                  if (mode == WorkRankingMode.editorial)
                    Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                            onPressed: () => showDialog<void>(
                                context: context,
                                builder: (context) => AlertDialog(
                                        title: Text(entry.work.title),
                                        content: SingleChildScrollView(
                                            child: Text(entry.context(mode))),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Cerrar'))
                                        ])),
                            child: const Text('Leer motivo completo'))),
                ]);
          },
        ),
      );
}
