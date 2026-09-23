import 'package:corvus_aeternum/features/work/work_chapter_page.dart';
import 'package:corvus_aeternum/models/work.dart';
import 'package:corvus_aeternum/providers/auth_provider.dart';
import 'package:corvus_aeternum/services/work_service.dart';
import 'package:corvus_aeternum/shared/widgets/formatted_manuscript_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Works extends WorkService {
  @override
  Future<Work> getWorkById(String id) async => Work.fromMap({
        'id': id,
        'profile_id': 'author',
        'title': 'La biblioteca',
        'created_at': '2026-09-01T00:00:00Z',
        'updated_at': '2026-09-01T00:00:00Z',
        'text_body':
            '<!-- corvus-chapter -->\n# La puerta\nPrimer capítulo.\n\n<!-- corvus-chapter -->\n# El archivo\n[El cuervo](corvus-node:bird)\n\n${List.filled(35, 'Un párrafo largo para comprobar que la posición de lectura se conserva.').join('\n\n')}',
        'aeternum_ficha': {
          'public_references': [
            {
              'id': 'bird',
              'title': 'El cuervo',
              'body': 'Guardián de la biblioteca.'
            }
          ]
        },
      });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        'corvus.reader.visitor.book.last': 1,
        'corvus.reader.visitor.book.1': .5,
      }));
  Future<void> open(WidgetTester tester, {bool resume = true}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.4)),
              child: child!),
          home: WorkChapterPage(
              workId: 'book',
              initialChapter: 0,
              resume: resume,
              service: _Works()),
        )));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'resume restores chapter and position on small screens with enlarged text',
      (tester) async {
    await open(tester);
    expect(find.text('Lectura / capítulo 2 de 2'), findsOneWidget);
    final scroll = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    expect(scroll.offset / scroll.position.maxScrollExtent, closeTo(.5, .01));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Preferencias de lectura'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('explicit chapter links ignore last chapter', (tester) async {
    await open(tester, resume: false);
    expect(find.text('Lectura / capítulo 1 de 2'), findsOneWidget);
  });
  testWidgets('bookmark removal persists and whole-work progress is visible',
      (tester) async {
    await open(tester);
    expect(find.text('Capítulo 50 % · Obra 75 %'), findsOneWidget);
    await tester.tap(find.byTooltip('Índice y marcadores'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar marcador aquí'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Índice y marcadores'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Eliminar marcador'), findsOneWidget);
    await tester.tap(find.byTooltip('Eliminar marcador'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Eliminar marcador'), findsNothing);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('corvus.reader.visitor.book.bookmarks'), '{}');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'formatted references invoke their stable target without exposing it',
      (tester) async {
    String? target;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FormattedManuscriptText(
                text: '[**El cuervo**](corvus-node:bird)',
                onLink: (value) => target = value))));
    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(text.textSpan!.toPlainText(), 'El cuervo');
    final link = text.textSpan!.children!.whereType<TextSpan>().first;
    (link.recognizer! as TapGestureRecognizer).onTap!();
    expect(target, 'corvus-node:bird');
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
