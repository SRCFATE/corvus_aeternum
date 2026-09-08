import 'package:corvus_aeternum/features/discover/discover_page.dart';
import 'package:corvus_aeternum/models/aeternum_ficha.dart';
import 'package:corvus_aeternum/models/work.dart';
import 'package:corvus_aeternum/providers/auth_provider.dart';
import 'package:corvus_aeternum/services/work_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _DiscoverService extends WorkService {
  final List<Work> works;

  _DiscoverService(this.works);

  @override
  Future<List<Work>> getDiscoverWorks({
    String? discipline,
    String? query,
    int limit = 20,
    int offset = 0,
  }) async =>
      works;
}

void main() {
  Work work(int index) {
    final now = DateTime(2026);
    return Work(
      id: '$index',
      profileId: 'author',
      title: 'Obra $index',
      description: 'Descripción editorial',
      discipline: 'Literatura',
      subdiscipline: 'Narrativa',
      medium: 'Libro',
      mediaUrls: const [],
      tags: const [],
      likesCount: index,
      viewsCount: index * 10,
      savesCount: 0,
      commentsCount: 0,
      isPublic: true,
      isFeatured: false,
      isForSale: false,
      currency: 'MXN',
      status: 'published',
      workType: 'image',
      isMature: false,
      isComplete: true,
      aeternumFicha: const AeternumFicha(),
      createdAt: now,
      updatedAt: now,
      authorDisplayName: 'Autora de prueba',
    );
  }

  testWidgets('Descubrir muestra dos portadas por fila en móvil',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: DiscoverPage(
            service: _DiscoverService([for (var i = 1; i <= 6; i++) work(i)]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('discover-work-1')),
      240,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();

    final first = tester.getRect(
      find.byKey(const ValueKey('discover-work-1')),
    );
    final second = tester.getRect(
      find.byKey(const ValueKey('discover-work-2')),
    );

    expect(first.top, closeTo(second.top, 1));
    expect(first.left, lessThan(second.left));
    expect(first.width, lessThan(170));
    expect(tester.takeException(), isNull);
  });
}
