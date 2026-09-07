import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/rpc_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/corvus_design.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/entitlement_provider.dart';
import '../../../../shared/layout/corvus_page.dart';
import '../../../../shared/widgets/corvus_crow_animations.dart';
import '../domain/billing_models.dart';
import '../domain/feature_keys.dart';
import '../services/billing_service.dart';
import '../services/usage_service.dart';
import '../widgets/billing_format.dart';
import '../widgets/plan_badge.dart';

/// La pantalla de planes de Atelier.
///
/// Tres reglas gobiernan su diseño:
///   1. Free se presenta como un plan de verdad, no como el escalón de abajo.
///      Tiene su tarjeta, su lista y su promesa escrita.
///   2. Professional se destaca —está recomendado, y decirlo es honesto— pero
///      sin cuentas atrás, sin plazas limitadas y sin tachar precios que nunca
///      existieron.
///   3. El precio anual se muestra con su ahorro real, calculado, no inventado.
class PlansPage extends StatefulWidget {
  /// La función que trajo hasta aquí a alguien, si vino desde un candado.
  final String? highlightFeature;

  const PlansPage({super.key, this.highlightFeature});

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  final _billing = BillingService();

  List<AtelierPlan> _plans = const [];
  List<AddonOffer> _addons = const [];
  bool _loading = true;
  String? _error;
  String _interval = 'month';
  String? _busyPriceId;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<EntitlementProvider>().track(
        BillingEvent.planViewed,
        properties: {
          if (widget.highlightFeature != null)
            'feature_key': widget.highlightFeature!,
        },
      );
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final plans = await _billing.loadPlans();
      final addons = await _billing.loadAddons();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _addons = addons;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _choose(AtelierPlan plan, PlanPrice price) async {
    final auth = context.read<AuthProvider>();
    final entitlements = context.read<EntitlementProvider>();

    // Nadie tiene que pagar para entrar: si no hay sesión, se registra y
    // vuelve aquí con el destino guardado.
    if (!auth.isAuthenticated) {
      context.push('/register?redirect=${Uri.encodeComponent('/plans')}');
      return;
    }

    if (plan.isWorkspaceScoped) {
      _showMessage(
        'Crea primero tu espacio de trabajo desde Atelier y desde ahí '
        'contrata Teams para ese estudio.',
      );
      return;
    }

    await entitlements.track(
      BillingEvent.upgradeClicked,
      properties: {
        'plan_code': plan.code,
        'price_id': price.id,
        'interval': price.interval,
        if (widget.highlightFeature != null)
          'feature_key': widget.highlightFeature!,
      },
    );

    setState(() => _busyPriceId = price.id);

    try {
      await _billing.startCheckout(priceId: price.id);
    } on CorvusRpcException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (error) {
      if (mounted) _showMessage('No se pudo abrir el cobro. $error');
    } finally {
      if (mounted) setState(() => _busyPriceId = null);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Planes de Atelier'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/atelier'),
        ),
      ),
      body: _loading
          ? const Center(child: CorvusCrowLoader())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: CorvusPage(child: _content()),
                ),
    );
  }

  Widget _content() {
    final current = context.watch<EntitlementProvider>().subscription;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ATELIER', style: CorvusType.eyebrow(AppColors.gold)),
        const SizedBox(height: CorvusSpacing.md),
        const Text(
          'Crear es gratis. Producir es lo que se paga.',
          style: CorvusType.display,
        ),
        const SizedBox(height: CorvusSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            'Escribir, construir mundos, organizar tu obra y llevártela cuando '
            'quieras no cuesta nada y nunca costará. Lo que Atelier cobra es la '
            'infraestructura: colaboración, historial profundo, almacenamiento '
            'y producción editorial.',
            style: CorvusType.body,
          ),
        ),
        const SizedBox(height: CorvusSpacing.xl),
        _IntervalToggle(
          interval: _interval,
          savingPercent: _bestYearlySaving(),
          onChanged: (value) {
            setState(() => _interval = value);
            context.read<EntitlementProvider>().track(
              BillingEvent.planCompared,
              properties: {'interval': value},
            );
          },
        ),
        const SizedBox(height: CorvusSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final cards = _plans
                .map((plan) => _PlanCard(
                      plan: plan,
                      interval: _interval,
                      isCurrent: plan.code == current.planCode,
                      isHighlighted: plan.isRecommended,
                      busyPriceId: _busyPriceId,
                      onChoose: _choose,
                    ))
                .toList();

            if (!wide) {
              return Column(
                children: [
                  for (final card in cards) ...[
                    card,
                    const SizedBox(height: CorvusSpacing.lg),
                  ],
                ],
              );
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    Expanded(child: cards[i]),
                    if (i < cards.length - 1)
                      const SizedBox(width: CorvusSpacing.lg),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: CorvusSpacing.xl),
        const FreeForeverNote(),
        const SizedBox(height: CorvusSpacing.section),
        _ComparisonTable(
          plans: _plans,
          highlightFeature: widget.highlightFeature,
        ),
        if (_addons.isNotEmpty) ...[
          const SizedBox(height: CorvusSpacing.section),
          _AddonsSection(addons: _addons),
        ],
        const SizedBox(height: CorvusSpacing.section),
        const _PortabilityNote(),
        const SizedBox(height: CorvusSpacing.section),
      ],
    );
  }

  int? _bestYearlySaving() {
    for (final plan in _plans) {
      final saving = plan.yearlySavingPercent;
      if (saving != null) return saving;
    }
    return null;
  }
}

class _IntervalToggle extends StatelessWidget {
  final String interval;
  final int? savingPercent;
  final ValueChanged<String> onChanged;

  const _IntervalToggle({
    required this.interval,
    required this.savingPercent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: CorvusSpacing.md,
      runSpacing: CorvusSpacing.sm,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: CorvusSurfaces.fill(CorvusSurfaces.fillBase),
            borderRadius: BorderRadius.circular(CorvusRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IntervalChip(
                label: 'Mensual',
                selected: interval == 'month',
                onTap: () => onChanged('month'),
              ),
              _IntervalChip(
                label: 'Anual',
                selected: interval == 'year',
                onTap: () => onChanged('year'),
              ),
            ],
          ),
        ),
        if (savingPercent != null)
          Text(
            'Pagando al año ahorras un $savingPercent %.',
            style: CorvusType.muted.copyWith(color: AppColors.gold),
          ),
      ],
    );
  }
}

class _IntervalChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _IntervalChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: CorvusMotion.fast,
        curve: CorvusMotion.standard,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(CorvusRadius.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.background : AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final AtelierPlan plan;
  final String interval;
  final bool isCurrent;
  final bool isHighlighted;
  final String? busyPriceId;
  final Future<void> Function(AtelierPlan, PlanPrice) onChoose;

  const _PlanCard({
    required this.plan,
    required this.interval,
    required this.isCurrent,
    required this.isHighlighted,
    required this.busyPriceId,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    // Si el plan no tiene precio en el intervalo elegido, se enseña el que
    // tenga en vez de dejar la tarjeta muda.
    final price = plan.priceFor(interval) ??
        plan.priceFor('month') ??
        (plan.prices.isEmpty ? null : plan.prices.first);

    final accent = isHighlighted
        ? AppColors.gold
        : plan.code == PlanCode.teams
            ? AppColors.secondaryLight
            : null;

    return CorvusPanel(
      accent: accent,
      raised: isHighlighted,
      padding: const EdgeInsets.all(CorvusSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.badge.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: (accent ?? AppColors.textSecondary).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(CorvusRadius.pill),
              ),
              child: Text(
                plan.badge,
                style: CorvusType.eyebrow(accent ?? AppColors.textSecondary),
              ),
            ),
          const SizedBox(height: CorvusSpacing.md),
          Text(plan.name, style: CorvusType.title),
          const SizedBox(height: CorvusSpacing.xs),
          Text(plan.tagline, style: CorvusType.muted),
          const SizedBox(height: CorvusSpacing.lg),
          _PriceLine(plan: plan, price: price, interval: interval),
          const SizedBox(height: CorvusSpacing.lg),
          Text(plan.description, style: CorvusType.body),
          const SizedBox(height: CorvusSpacing.lg),
          for (final highlight in plan.highlights) ...[
            _HighlightRow(text: highlight, accent: accent),
            const SizedBox(height: CorvusSpacing.sm),
          ],
          const Spacer(),
          const SizedBox(height: CorvusSpacing.lg),
          _PlanAction(
            plan: plan,
            price: price,
            isCurrent: isCurrent,
            accent: accent,
            busy: price != null && busyPriceId == price.id,
            onChoose: onChoose,
          ),
        ],
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  final AtelierPlan plan;
  final PlanPrice? price;
  final String interval;

  const _PriceLine({
    required this.plan,
    required this.price,
    required this.interval,
  });

  @override
  Widget build(BuildContext context) {
    if (plan.isFree || price == null || price!.unitAmount == 0) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          const Text(r'$0', style: CorvusType.display),
          const SizedBox(width: CorvusSpacing.sm),
          Text('MXN para siempre', style: CorvusType.muted),
        ],
      );
    }

    final showsYear = price!.interval == 'year';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                formatMoney(price!.amount, price!.currency),
                style: CorvusType.display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: CorvusSpacing.xs),
            Text(intervalShort(price!.interval), style: CorvusType.muted),
          ],
        ),
        if (showsYear) ...[
          const SizedBox(height: CorvusSpacing.xs),
          Text(
            'Equivale a ${formatMoney(price!.monthlyEquivalent, price!.currency)} al mes.',
            style: CorvusType.muted,
          ),
        ],
        if (plan.isWorkspaceScoped) ...[
          const SizedBox(height: CorvusSpacing.xs),
          Text('Por espacio de trabajo, no por persona.', style: CorvusType.muted),
        ],
      ],
    );
  }
}

class _HighlightRow extends StatelessWidget {
  final String text;
  final Color? accent;

  const _HighlightRow({required this.text, this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Icon(
            Icons.check_rounded,
            size: 14,
            color: (accent ?? AppColors.textSecondary).withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(width: CorvusSpacing.sm),
        Expanded(child: Text(text, style: CorvusType.body)),
      ],
    );
  }
}

class _PlanAction extends StatelessWidget {
  final AtelierPlan plan;
  final PlanPrice? price;
  final bool isCurrent;
  final Color? accent;
  final bool busy;
  final Future<void> Function(AtelierPlan, PlanPrice) onChoose;

  const _PlanAction({
    required this.plan,
    required this.price,
    required this.isCurrent,
    required this.accent,
    required this.busy,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    if (isCurrent) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
          child: const Text('Tu plan actual'),
        ),
      );
    }

    if (plan.isFree) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => context.go('/atelier'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
          child: const Text('Empezar a escribir'),
        ),
      );
    }

    if (price == null) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
          child: const Text('Próximamente'),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: busy ? null : () => onChoose(plan, price!),
        style: FilledButton.styleFrom(
          backgroundColor: accent ?? AppColors.primary,
          foregroundColor: AppColors.background,
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
        child: busy
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text('Elegir ${plan.name.split(' ').last}'),
      ),
    );
  }
}

/// La comparación, ordenada por lo que de verdad separa a los planes. El bloque
/// de "creación" va primero y con todo en verde a propósito: es la parte que no
/// se cobra y conviene que se vea antes que ninguna otra.
class _ComparisonTable extends StatelessWidget {
  final List<AtelierPlan> plans;
  final String? highlightFeature;

  const _ComparisonTable({required this.plans, this.highlightFeature});

  static const _groups = <String, List<(String, String)>>{
    'Crear — incluido siempre': [
      ('Proyectos, obras y mundos', 'Ilimitados en los tres planes'),
      ('Personajes, lugares, lore y cronologías', 'Sin tope'),
      ('Capítulos, escenas y palabras', 'Sin tope'),
      ('Wiki interna, enlaces y backlinks', 'Incluido'),
      ('Exportar Markdown, TXT y JSON', 'Incluido'),
      ('Publicar en Corvus Aeternum', 'Incluido'),
    ],
    'Producir': [
      (AtelierFeature.versionHistoryAdvanced, 'Historial avanzado y comparación'),
      (AtelierFeature.versionHistoryMaxSnapshots, 'Versiones restaurables'),
      (AtelierFeature.backupsAdvanced, 'Backups avanzados'),
      (AtelierFeature.exportDocx, 'Exportar DOCX'),
      (AtelierFeature.exportPdf, 'Exportar PDF'),
      (AtelierFeature.exportEpub, 'Exportar EPUB'),
      (AtelierFeature.exportProjectBundle, 'Paquete completo del proyecto'),
      (AtelierFeature.editorialManuscript, 'Modo manuscrito y producción editorial'),
    ],
    'Colaborar': [
      (AtelierFeature.collaboratorsMax, 'Colaboradores por proyecto'),
      (AtelierFeature.comments, 'Comentarios y sugerencias'),
      (AtelierFeature.tasksAssign, 'Asignación de tareas'),
    ],
    'Trabajar como estudio': [
      (AtelierFeature.workspace, 'Espacios de trabajo'),
      (AtelierFeature.workspaceSeatsMax, 'Miembros por espacio'),
      (AtelierFeature.rolesCustom, 'Roles personalizados'),
      (AtelierFeature.auditLog, 'Registro de auditoría'),
    ],
    'Infraestructura': [
      (AtelierFeature.storageMaxBytes, 'Almacenamiento'),
      (AtelierFeature.automationsMax, 'Automatizaciones activas'),
      (AtelierFeature.customFields, 'Campos personalizados'),
      (AtelierFeature.templatesPro, 'Plantillas profesionales'),
      (AtelierFeature.analyticsAdvanced, 'Analíticas avanzadas'),
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CorvusSectionLabel(label: 'Comparación completa'),
        const SizedBox(height: CorvusSpacing.lg),
        _ComparisonHeader(plans: plans),
        for (final entry in _groups.entries) ...[
          const SizedBox(height: CorvusSpacing.lg),
          Padding(
            padding: const EdgeInsets.only(bottom: CorvusSpacing.sm),
            child: Text(
              entry.key.toUpperCase(),
              style: CorvusType.eyebrow(AppColors.gold, alpha: 0.55),
            ),
          ),
          for (final row in entry.value)
            _ComparisonRow(
              featureKey: row.$1,
              label: row.$2,
              plans: plans,
              alwaysIncluded: entry.key.startsWith('Crear'),
              highlighted: highlightFeature == row.$1,
            ),
        ],
      ],
    );
  }
}

class _ComparisonHeader extends StatelessWidget {
  final List<AtelierPlan> plans;

  const _ComparisonHeader({required this.plans});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CorvusSpacing.sm),
      child: Row(
        children: [
          const Expanded(flex: 3, child: SizedBox()),
          for (final plan in plans)
            Expanded(
              flex: 2,
              child: Text(
                plan.name.split(' ').last,
                textAlign: TextAlign.center,
                style: CorvusType.subtitle,
              ),
            ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String featureKey;
  final String label;
  final List<AtelierPlan> plans;
  final bool alwaysIncluded;
  final bool highlighted;

  const _ComparisonRow({
    required this.featureKey,
    required this.label,
    required this.plans,
    required this.alwaysIncluded,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: CorvusSpacing.sm),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.gold.withValues(alpha: 0.07)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(CorvusRadius.sm),
        border: Border(
          bottom: BorderSide(
            color: CorvusSurfaces.fill(CorvusSurfaces.borderSubtle),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              alwaysIncluded ? featureKey : label,
              style: CorvusType.body.copyWith(
                color: highlighted ? AppColors.textPrimary : null,
              ),
            ),
          ),
          for (final plan in plans)
            Expanded(
              flex: 2,
              child: Center(
                child: alwaysIncluded
                    ? const Icon(Icons.check_rounded,
                        size: 15, color: AppColors.successLight)
                    : _PlanValue(plan: plan, featureKey: featureKey),
              ),
            ),
        ],
      ),
    );
  }
}

/// El valor de un derecho en un plan concreto. Se lee del catálogo cacheado en
/// el propio plan cuando existe; si no, del mapa estático que la siembra fija.
class _PlanValue extends StatelessWidget {
  final AtelierPlan plan;
  final String featureKey;

  const _PlanValue({required this.plan, required this.featureKey});

  @override
  Widget build(BuildContext context) {
    final value = _planEntitlements[plan.code]?[featureKey];

    if (value == null) {
      return Icon(
        Icons.remove_rounded,
        size: 14,
        color: Colors.white.withValues(alpha: 0.16),
      );
    }

    if (value is bool) {
      return value
          ? const Icon(Icons.check_rounded,
              size: 15, color: AppColors.successLight)
          : Icon(
              Icons.remove_rounded,
              size: 14,
              color: Colors.white.withValues(alpha: 0.16),
            );
    }

    final number = value as int;
    final text = number == kUnlimited
        ? 'Sin límite'
        : featureKey == AtelierFeature.storageMaxBytes
            ? formatBytes(number)
            : number == 0
                ? '—'
                : '$number';

    return Text(
      text,
      textAlign: TextAlign.center,
      style: CorvusType.muted.copyWith(
        color: number == 0 ? null : AppColors.textPrimary,
        fontWeight: number == 0 ? null : FontWeight.w700,
      ),
    );
  }
}

/// Retrato de la tabla `plan_entitlements` para poder pintar la comparación
/// sin una consulta por celda. Si administración cambia un valor en la base,
/// la app lo respeta —la decisión real siempre viene del servidor— y esta
/// tabla solo afecta a lo que se anuncia aquí.
const _planEntitlements = <String, Map<String, Object>>{
  PlanCode.free: {
    AtelierFeature.versionHistoryAdvanced: false,
    AtelierFeature.versionHistoryMaxSnapshots: 10,
    AtelierFeature.backupsAdvanced: false,
    AtelierFeature.exportDocx: false,
    AtelierFeature.exportPdf: false,
    AtelierFeature.exportEpub: false,
    AtelierFeature.exportProjectBundle: false,
    AtelierFeature.editorialManuscript: false,
    AtelierFeature.collaboratorsMax: 1,
    AtelierFeature.comments: true,
    AtelierFeature.tasksAssign: false,
    AtelierFeature.workspace: false,
    AtelierFeature.workspaceSeatsMax: 0,
    AtelierFeature.rolesCustom: false,
    AtelierFeature.auditLog: false,
    AtelierFeature.storageMaxBytes: 2147483648,
    AtelierFeature.automationsMax: 0,
    AtelierFeature.customFields: false,
    AtelierFeature.templatesPro: false,
    AtelierFeature.analyticsAdvanced: false,
  },
  PlanCode.professional: {
    AtelierFeature.versionHistoryAdvanced: true,
    AtelierFeature.versionHistoryMaxSnapshots: kUnlimited,
    AtelierFeature.backupsAdvanced: true,
    AtelierFeature.exportDocx: true,
    AtelierFeature.exportPdf: true,
    AtelierFeature.exportEpub: true,
    AtelierFeature.exportProjectBundle: true,
    AtelierFeature.editorialManuscript: true,
    AtelierFeature.collaboratorsMax: 10,
    AtelierFeature.comments: true,
    AtelierFeature.tasksAssign: true,
    AtelierFeature.workspace: false,
    AtelierFeature.workspaceSeatsMax: 0,
    AtelierFeature.rolesCustom: false,
    AtelierFeature.auditLog: false,
    AtelierFeature.storageMaxBytes: 26843545600,
    AtelierFeature.automationsMax: 25,
    AtelierFeature.customFields: true,
    AtelierFeature.templatesPro: true,
    AtelierFeature.analyticsAdvanced: true,
  },
  PlanCode.teams: {
    AtelierFeature.versionHistoryAdvanced: true,
    AtelierFeature.versionHistoryMaxSnapshots: kUnlimited,
    AtelierFeature.backupsAdvanced: true,
    AtelierFeature.exportDocx: true,
    AtelierFeature.exportPdf: true,
    AtelierFeature.exportEpub: true,
    AtelierFeature.exportProjectBundle: true,
    AtelierFeature.editorialManuscript: true,
    AtelierFeature.collaboratorsMax: 50,
    AtelierFeature.comments: true,
    AtelierFeature.tasksAssign: true,
    AtelierFeature.workspace: true,
    AtelierFeature.workspaceSeatsMax: 25,
    AtelierFeature.rolesCustom: true,
    AtelierFeature.auditLog: true,
    AtelierFeature.storageMaxBytes: 107374182400,
    AtelierFeature.automationsMax: 100,
    AtelierFeature.customFields: true,
    AtelierFeature.templatesPro: true,
    AtelierFeature.analyticsAdvanced: true,
  },
};

class _AddonsSection extends StatelessWidget {
  final List<AddonOffer> addons;

  const _AddonsSection({required this.addons});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CorvusSectionLabel(label: 'Extras sin cambiar de plan'),
        const SizedBox(height: CorvusSpacing.sm),
        Text(
          'A veces solo falta una cosa. Estos extras se compran sueltos y se '
          'suman a lo que ya tienes.',
          style: CorvusType.body,
        ),
        const SizedBox(height: CorvusSpacing.lg),
        Wrap(
          spacing: CorvusSpacing.md,
          runSpacing: CorvusSpacing.md,
          children: [
            for (final addon in addons)
              SizedBox(
                width: 280,
                child: CorvusPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(addon.name, style: CorvusType.subtitle),
                      const SizedBox(height: CorvusSpacing.sm),
                      Text(addon.description, style: CorvusType.body),
                      const SizedBox(height: CorvusSpacing.md),
                      Text(
                        addon.prices.isEmpty
                            ? 'Precio por anunciar'
                            : formatMoney(
                                addon.prices.first.amount,
                                addon.prices.first.currency,
                              ),
                        style: CorvusType.subtitle.copyWith(
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PortabilityNote extends StatelessWidget {
  const _PortabilityNote();

  @override
  Widget build(BuildContext context) {
    return CorvusPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_open_rounded,
                  size: 16, color: AppColors.successLight),
              const SizedBox(width: CorvusSpacing.sm),
              Text(
                'Tu obra es tuya',
                style: CorvusType.subtitle,
              ),
            ],
          ),
          const SizedBox(height: CorvusSpacing.md),
          Text(
            'Puedes exportar todo tu contenido en cualquier momento, con o sin '
            'suscripción. Si cancelas, nada se borra: tus novelas, mundos, '
            'personajes, archivos y comentarios siguen ahí, y las funciones '
            'profesionales simplemente quedan en pausa hasta que vuelvas.',
            style: CorvusType.body,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CorvusSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 32, color: AppColors.textMuted),
            const SizedBox(height: CorvusSpacing.lg),
            Text(
              'No se pudo leer el catálogo de planes.',
              style: CorvusType.subtitle,
            ),
            const SizedBox(height: CorvusSpacing.sm),
            Text(message, style: CorvusType.muted, textAlign: TextAlign.center),
            const SizedBox(height: CorvusSpacing.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
