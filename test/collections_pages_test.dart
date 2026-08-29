import 'package:corvus_aeternum/features/collections/collection_detail_page.dart';
import 'package:corvus_aeternum/features/collections/collections_page.dart';
import 'package:corvus_aeternum/models/collection.dart';
import 'package:corvus_aeternum/models/work.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('collection library renders filters and cards on desktop', (
    tester,
  ) async {
    final collection = _collection();
    await _pumpAtSize(
      tester,
      const Size(1280, 900),
      CollectionsPage(
        initialMyCollections: [collection],
        initialPublicCollections: [collection],
        initialFeaturedCollections: [collection],
      ),
    );

    expect(find.text('Biblioteca y curaduría'), findsOneWidget);
    expect(find.text('Todas'), findsOneWidget);
    expect(find.text('SERIE TEMÁTICA'), findsOneWidget);
    expect(find.text('Nocturnos de la ciudad'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collection detail renders private notes on mobile', (
    tester,
  ) async {
    final collection = _collection();
    final item = CollectionItem(
      collectionId: collection.id,
      workId: 'work-1',
      position: 0,
      note: 'Una pieza central para la lectura pública.',
      addedBy: 'profile-1',
      addedAt: DateTime.utc(2026, 8, 16),
      work: _work(),
    );

    await _pumpAtSize(
      tester,
      const Size(390, 844),
      CollectionDetailPage(
        collectionId: collection.id,
        initialCollection: collection,
        initialItems: [item],
        initialPrivateNotes: const {
          'work-1': 'Retomar esta paleta para el capítulo ocho.',
        },
        initialProfileId: 'profile-1',
      ),
    );

    expect(find.text('Nocturnos de la ciudad'), findsOneWidget);
    expect(find.text('Añadir obras'), findsOneWidget);
    expect(find.text('Organizar'), findsOneWidget);
    expect(
      find.text('Retomar esta paleta para el capítulo ocho.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpAtSize(
  WidgetTester tester,
  Size size,
  Widget child,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

Collection _collection() {
  final now = DateTime.utc(2026, 8, 16);
  return Collection(
    id: 'collection-1',
    profileId: 'profile-1',
    curatorName: 'Elena',
    title: 'Nocturnos de la ciudad',
    description: 'Una lectura de la ciudad después de medianoche.',
    tags: const ['ciudad', 'noche'],
    collectionType: 'series',
    piecesCount: 1,
    likesCount: 8,
    viewsCount: 34,
    isPublic: true,
    isFeatured: true,
    isEditorial: false,
    createdAt: now,
    updatedAt: now,
  );
}

Work _work() {
  return Work.fromMap({
    'id': 'work-1',
    'profile_id': 'profile-1',
    'title': 'Avenida a las 03:17',
    'description': '',
    'discipline': 'Fotografía',
    'subdiscipline': 'Urbana',
    'medium': 'Digital',
    'status': 'published',
    'is_public': true,
    'is_complete': true,
    'tags': ['noche'],
    'views_count': 12,
    'likes_count': 3,
    'saves_count': 1,
    'created_at': '2026-08-16T00:00:00.000Z',
    'updated_at': '2026-08-16T00:00:00.000Z',
  });
}
