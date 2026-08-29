import 'package:corvus_aeternum/features/atelier/atelier_review_workspace.dart';
import 'package:corvus_aeternum/models/atelier_models.dart';
import 'package:corvus_aeternum/providers/atelier_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('review editor and thesaurus remain usable on mobile',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AtelierReviewWorkspace(
              accent: Colors.red,
              atelier: _ReviewProvider(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Correccion y precision del manuscrito'), findsOneWidget);
    expect(find.text('Diccionario de sinonimos'), findsOneWidget);
    expect(find.textContaining('Falta una tilde'), findsWidgets);
    expect(find.text('alegre'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ReviewProvider extends AtelierProvider {
  @override
  List<AtelierNode> get nodes => [
        AtelierNode(
          id: 'chapter-1',
          projectId: 'project-1',
          profileId: 'profile-1',
          kind: 'chapter',
          title: 'Prologo',
          body: 'Tambien  tambien avanzo hacia el arbol.',
          status: 'draft',
          canonStatus: 'canon',
          visibility: 'private',
          tags: const [],
          metadata: const {},
          position: 0,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

  @override
  List<AtelierRelation> get relations => const [];
}
