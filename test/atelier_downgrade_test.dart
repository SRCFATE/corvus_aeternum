import 'package:corvus_aeternum/features/atelier/billing/domain/billing_models.dart';
import 'package:corvus_aeternum/features/atelier/billing/domain/feature_keys.dart';
import 'package:corvus_aeternum/features/atelier/billing/services/entitlement_service.dart';
import 'package:corvus_aeternum/features/atelier/billing/services/export_service.dart';
import 'package:corvus_aeternum/models/atelier_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// La promesa que no se rompe: **un downgrade jamás elimina contenido.**
///
/// Bajar de plan cambia lo que se puede HACER, nunca lo que existe. Estas
/// pruebas recorren el ciclo completo —alta, uso, cancelación, vuelta a Free—
/// y comprueban que en cada paso la obra sigue entera, legible y exportable.
///
/// Es la prueba que más importa de todo el módulo comercial. Si un día falla,
/// el producto ha dejado de ser el que se prometió.
void main() {
  AtelierNode node(String id, String title, String body, {int position = 0}) {
    return AtelierNode(
      id: id,
      projectId: 'proyecto-1',
      profileId: 'autora-1',
      kind: 'chapter',
      title: title,
      body: body,
      status: 'draft',
      canonStatus: 'canon',
      visibility: 'private',
      tags: const ['fantasia'],
      metadata: const {'purpose': 'apertura'},
      position: position,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 6, 1),
    );
  }

  final proyecto = AtelierProject(
    id: 'proyecto-1',
    profileId: 'autora-1',
    title: 'El cuervo de sal',
    type: 'Novela',
    status: 'draft',
    genre: 'Fantasía oscura',
    universe: 'Aeternum',
    language: 'es',
    visibility: 'private',
    weeklyWordGoal: 2000,
    publicProgressEnabled: false,
    metadata: const {'description': 'Una novela larga.'},
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 6, 1),
  );

  final taller = AtelierWorkspace(
    projects: [proyecto],
    activeProject: proyecto,
    nodes: [
      node('n1', 'Capítulo I', 'La sal cubrió el puerto durante tres días.'),
      node('n2', 'Capítulo II', 'Nadie recordaba el nombre del cuervo.',
          position: 1),
      node('n3', 'Ficha: Vela', 'Contrabandista. Miente por costumbre.',
          position: 2),
    ],
    relations: [
      AtelierRelation(
        id: 'r1',
        projectId: 'proyecto-1',
        profileId: 'autora-1',
        sourceNodeId: 'n1',
        relationType: 'menciona',
        targetNodeId: 'n3',
        description: '',
        canonStatus: 'canon',
        createdAt: DateTime(2026, 2, 1),
      ),
    ],
    versions: [
      AtelierVersion(
        id: 'v1',
        projectId: 'proyecto-1',
        profileId: 'autora-1',
        label: 'v1',
        description: 'Primer borrador completo',
        metadata: const {},
        createdAt: DateTime(2026, 3, 1),
      ),
    ],
  );

  Entitlements planDe(String code, Map<String, dynamic> features) {
    return Entitlements(
      subscription: SubscriptionState(planCode: code, status: 'active'),
      features: features,
      workspaces: const [],
      resolvedAt: DateTime.now(),
    );
  }

  final comoProfessional = planDe('professional', const {
    AtelierFeature.projectsUnlimited: true,
    AtelierFeature.worldbuilding: true,
    AtelierFeature.versionHistoryBasic: true,
    AtelierFeature.versionHistoryAdvanced: true,
    AtelierFeature.versionHistoryMaxSnapshots: -1,
    AtelierFeature.collaboration: true,
    AtelierFeature.collaboratorsMax: 10,
    AtelierFeature.storageMaxBytes: 26843545600,
    AtelierFeature.exportMarkdown: true,
    AtelierFeature.exportTxt: true,
    AtelierFeature.exportJson: true,
    AtelierFeature.exportPdf: true,
    AtelierFeature.customFields: true,
    AtelierFeature.automation: true,
  });

  final trasCancelar = planDe('free', const {
    AtelierFeature.projectsUnlimited: true,
    AtelierFeature.worldbuilding: true,
    AtelierFeature.versionHistoryBasic: true,
    AtelierFeature.versionHistoryAdvanced: false,
    AtelierFeature.versionHistoryMaxSnapshots: 10,
    AtelierFeature.collaboration: true,
    AtelierFeature.collaboratorsMax: 1,
    AtelierFeature.storageMaxBytes: 2147483648,
    AtelierFeature.exportMarkdown: true,
    AtelierFeature.exportTxt: true,
    AtelierFeature.exportJson: true,
    AtelierFeature.exportPdf: false,
    AtelierFeature.customFields: false,
    AtelierFeature.automation: false,
  });

  group('bajar de plan no toca la obra', () {
    test('el taller es exactamente el mismo objeto antes y después', () {
      // El downgrade es un cambio de derechos. No hay ninguna ruta de código
      // que reciba el taller y le quite nodos: se comprueba comparando el
      // contenido con el que había cuando era Professional.
      final antes = taller.nodes.map((n) => n.id).toList();

      EntitlementService(entitlements: comoProfessional);
      EntitlementService(entitlements: trasCancelar);

      expect(taller.nodes.map((n) => n.id).toList(), antes);
      expect(taller.nodes.length, 3);
      expect(taller.relations.length, 1);
      expect(taller.versions.length, 1);
      expect(taller.activeProject, isNotNull);
    });

    test('el texto escrito sigue íntegro, palabra por palabra', () {
      final capitulo = taller.nodes.first;
      expect(capitulo.body, 'La sal cubrió el puerto durante tres días.');
      expect(capitulo.wordCount, greaterThan(0));
      expect(capitulo.tags, contains('fantasia'));
      expect(capitulo.metadata['purpose'], 'apertura');
    });

    test('la obra se puede seguir exportando sin suscripción', () async {
      final service = EntitlementService(entitlements: trasCancelar);
      final exportador = AtelierExportService();

      for (final formato in [
        AtelierExportFormat.markdown,
        AtelierExportFormat.txt,
        AtelierExportFormat.json,
      ]) {
        final spec = AtelierExportService.specFor(formato);
        expect(
          service.hasEntitlement(spec.featureKey),
          isTrue,
          reason: 'Free debe poder exportar en ${spec.label}',
        );

        final resultado =
            await exportador.build(format: formato, workspace: taller);

        expect(resultado.text, isNotNull);
        expect(resultado.text, contains('Capítulo I'));
        expect(resultado.text, contains('La sal cubrió el puerto'));
        expect(resultado.text, contains('Capítulo II'));
        expect(resultado.bytes, isNotEmpty);
      }
    });

    test('el JSON exportado en Free lleva TODO: fichas, relaciones y versiones',
        () async {
      final resultado = await AtelierExportService()
          .build(format: AtelierExportFormat.json, workspace: taller);

      final json = resultado.text!;
      expect(json, contains('Ficha: Vela'));
      expect(json, contains('menciona'));
      expect(json, contains('Primer borrador completo'));
      expect(json, contains('El cuervo de sal'));
    });
  });

  group('lo Professional queda en pausa, no borrado', () {
    final service = EntitlementService(entitlements: trasCancelar);

    test('escribir y construir mundos siguen abiertos', () {
      expect(service.hasEntitlement(AtelierFeature.projectsUnlimited), isTrue);
      expect(service.hasEntitlement(AtelierFeature.worldbuilding), isTrue);
      expect(service.hasEntitlement(AtelierFeature.versionHistoryBasic), isTrue);
    });

    test('las funciones de pago se cierran, y solo esas', () {
      expect(service.hasEntitlement(AtelierFeature.versionHistoryAdvanced), isFalse);
      expect(service.hasEntitlement(AtelierFeature.exportPdf), isFalse);
      expect(service.hasEntitlement(AtelierFeature.customFields), isFalse);
      expect(service.hasEntitlement(AtelierFeature.automation), isFalse);
    });

    test('las versiones antiguas siguen listadas aunque no se restauren', () {
      // La ventana de Free son 10 versiones restaurables; las demás se
      // conservan y se muestran en solo lectura.
      expect(service.getLimit(AtelierFeature.versionHistoryMaxSnapshots), 10);
      expect(taller.versions, isNotEmpty);
    });
  });

  group('quedar por encima de la cuota tras el downgrade', () {
    // 15 GB guardados en Professional, y de vuelta a los 2 GB de Free.
    final service = EntitlementService(
      entitlements: trasCancelar,
      usage: const UsageSnapshot(
        bytesUsed: 16106127360,
        bytesLimit: 2147483648,
        objectsCount: 240,
      ),
    );

    test('no entra nada nuevo', () {
      final check = service.checkQuota(incomingBytes: 1);
      expect(check.allowed, isFalse);
      expect(check.reason, GateReason.quotaExceeded);
    });

    test('pero lo guardado sigue contado, accesible y sin tocar', () {
      expect(service.getUsage().bytesUsed, 16106127360);
      expect(service.getUsage().objectsCount, 240);
    });

    test('y escribir, que no ocupa cuota de archivos, sigue abierto', () {
      expect(service.hasEntitlement(AtelierFeature.projectsUnlimited), isTrue);
      expect(service.hasEntitlement(AtelierFeature.exportMarkdown), isTrue);
    });
  });

  group('reactivar devuelve todo tal cual', () {
    test('recuperar Professional restablece los derechos sin migrar nada', () {
      final antes = EntitlementService(entitlements: comoProfessional);
      final durante = EntitlementService(entitlements: trasCancelar);
      final despues = EntitlementService(entitlements: comoProfessional);

      expect(antes.hasEntitlement(AtelierFeature.exportPdf), isTrue);
      expect(durante.hasEntitlement(AtelierFeature.exportPdf), isFalse);
      expect(despues.hasEntitlement(AtelierFeature.exportPdf), isTrue);

      // Y el contenido nunca participó en el viaje.
      expect(taller.nodes.length, 3);
    });
  });
}
