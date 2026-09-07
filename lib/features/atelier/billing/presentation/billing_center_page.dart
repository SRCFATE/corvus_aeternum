import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/rpc_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/corvus_design.dart';
import '../../../../providers/entitlement_provider.dart';
import '../../../../shared/layout/corvus_page.dart';
import '../../../../shared/widgets/corvus_crow_animations.dart';
import '../domain/billing_models.dart';
import '../domain/feature_keys.dart';
import '../services/billing_service.dart';
import '../widgets/billing_format.dart';
import '../widgets/billing_status_card.dart';
import '../widgets/usage_indicator.dart';

/// Settings › Facturación.
///
/// Aquí se ve lo que se paga, lo que se usa y lo que se ha pagado, y se puede
/// deshacer todo sin buscar. Cancelar está a la vista, en su sección, sin
/// esconderse detrás de tres pantallas ni de un formulario de motivos: si
/// alguien quiere irse, retenerlo con fricción sería la clase de truco que
/// este producto se prohíbe.
class BillingCenterPage extends StatefulWidget {
  /// Cuando se gestiona la facturación de un estudio en vez de la personal.
  final String? workspaceId;

  const BillingCenterPage({super.key, this.workspaceId});

  @override
  State<BillingCenterPage> createState() => _BillingCenterPageState();
}

class _BillingCenterPageState extends State<BillingCenterPage> {
  final _billing = BillingService();

  List<BillingTransaction> _transactions = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final entitlements = context.read<EntitlementProvider>();
      entitlements.track(BillingEvent.billingCenterViewed);
      entitlements.refreshUsage(workspaceId: widget.workspaceId);
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final transactions =
          await _billing.loadTransactions(workspaceId: widget.workspaceId);
      if (!mounted) return;
      setState(() {
        _transactions = transactions;
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

  Future<void> _run(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      await context
          .read<EntitlementProvider>()
          .refresh();
      if (!mounted) return;
      if (successMessage != null) _message(successMessage);
      await _load();
    } on CorvusRpcException catch (error) {
      if (mounted) _message(error.message);
    } catch (error) {
      if (mounted) _message('No se pudo completar la operación. $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cancelar la suscripción'),
        content: const Text(
          'Seguirás con acceso completo hasta el final del periodo que ya '
          'pagaste. Después vuelves a Atelier Free.\n\n'
          'Tus proyectos, mundos, personajes, archivos y comentarios se '
          'conservan íntegros. Las funciones profesionales quedan en pausa, no '
          'se borra nada, y todo vuelve tal cual si te suscribes otra vez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Seguir suscrito'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Cancelar suscripción'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _run(
      () => _billing.cancel(workspaceId: widget.workspaceId).then((_) {}),
      successMessage:
          'Suscripción cancelada. Conservas el acceso hasta el final del periodo.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Facturación'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/profile'),
        ),
        actions: [
          IconButton(
            tooltip: 'Volver a consultar al proveedor de pagos',
            icon: const Icon(Icons.sync_rounded),
            onPressed: _busy
                ? null
                : () => _run(
                      () => _billing
                          .sync(workspaceId: widget.workspaceId)
                          .then((_) {}),
                      successMessage: 'Estado actualizado.',
                    ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CorvusCrowLoader())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: CorvusReadingPage(child: _content()),
            ),
    );
  }

  Widget _content() {
    final provider = context.watch<EntitlementProvider>();
    final subscription = provider.subscription;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BillingStatusCard(
          onManage: _busy
              ? null
              : () => _run(
                    () => _billing.openBillingPortal(
                      workspaceId: widget.workspaceId,
                    ),
                  ),
          onReactivate: _busy
              ? null
              : () => _run(
                    () => _billing
                        .reactivate(workspaceId: widget.workspaceId)
                        .then((_) {}),
                    successMessage: 'Suscripción reactivada.',
                  ),
        ),
        const SizedBox(height: CorvusSpacing.xl),
        _UsageSection(provider: provider),
        const SizedBox(height: CorvusSpacing.xl),
        _PaymentSection(
          subscription: subscription,
          busy: _busy,
          onPortal: () => _run(
            () => _billing.openBillingPortal(workspaceId: widget.workspaceId),
          ),
        ),
        const SizedBox(height: CorvusSpacing.xl),
        _HistorySection(transactions: _transactions, error: _error),
        const SizedBox(height: CorvusSpacing.xl),
        _PlanActionsSection(
          subscription: subscription,
          busy: _busy,
          onCancel: _confirmCancel,
          onReactivate: () => _run(
            () => _billing
                .reactivate(workspaceId: widget.workspaceId)
                .then((_) {}),
            successMessage: 'Suscripción reactivada.',
          ),
        ),
        const SizedBox(height: CorvusSpacing.section),
      ],
    );
  }
}

class _UsageSection extends StatelessWidget {
  final EntitlementProvider provider;

  const _UsageSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    final entitlements = provider.entitlements;
    final usage = provider.usage;

    return CorvusPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CorvusSectionLabel(label: 'Uso'),
          const SizedBox(height: CorvusSpacing.lg),
          const StorageIndicator(),
          const SizedBox(height: CorvusSpacing.lg),
          // El tope de colaboradores es por proyecto, así que se compara con
          // el proyecto más poblado y no con la suma de todos.
          UsageIndicator(
            label: 'Colaboradores en tu proyecto más poblado',
            used: usage.count('collaborators'),
            limit: entitlements.limit(AtelierFeature.collaboratorsMax),
            icon: Icons.group_outlined,
            compact: true,
          ),
          const SizedBox(height: CorvusSpacing.md),
          UsageIndicator(
            label: 'Versiones guardadas',
            used: usage.count('versions'),
            limit: entitlements.limit(AtelierFeature.versionHistoryMaxSnapshots),
            icon: Icons.history_rounded,
            compact: true,
          ),
          const SizedBox(height: CorvusSpacing.md),
          UsageIndicator(
            label: 'Automatizaciones activas',
            used: usage.count('automations'),
            limit: entitlements.limit(AtelierFeature.automationsMax),
            icon: Icons.bolt_outlined,
            compact: true,
          ),
          const SizedBox(height: CorvusSpacing.md),
          UsageIndicator(
            label: 'Proyectos',
            used: usage.count('projects'),
            limit: kUnlimited,
            icon: Icons.auto_stories_outlined,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _PaymentSection extends StatelessWidget {
  final SubscriptionState subscription;
  final bool busy;
  final VoidCallback onPortal;

  const _PaymentSection({
    required this.subscription,
    required this.busy,
    required this.onPortal,
  });

  @override
  Widget build(BuildContext context) {
    return CorvusPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CorvusSectionLabel(label: 'Método de pago y datos fiscales'),
          const SizedBox(height: CorvusSpacing.md),
          Text(
            subscription.isFree
                ? 'Atelier Free no requiere método de pago. No hay tarjeta '
                    'registrada ni hace falta.'
                : 'La tarjeta y los datos de facturación se gestionan en el '
                    'portal del proveedor de pagos. Corvus nunca almacena ni ve '
                    'los datos de tu tarjeta.',
            style: CorvusType.body,
          ),
          if (!subscription.isFree) ...[
            const SizedBox(height: CorvusSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onPortal,
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: const Text('Abrir portal de pago'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  final List<BillingTransaction> transactions;
  final String? error;

  const _HistorySection({required this.transactions, this.error});

  @override
  Widget build(BuildContext context) {
    return CorvusPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CorvusSectionLabel(label: 'Historial de pagos'),
          const SizedBox(height: CorvusSpacing.lg),
          if (error != null)
            Text('No se pudo leer el historial. $error', style: CorvusType.muted)
          else if (transactions.isEmpty)
            Text(
              'Todavía no hay movimientos.',
              style: CorvusType.muted,
            )
          else
            for (final transaction in transactions)
              _TransactionRow(transaction: transaction),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final BillingTransaction transaction;

  const _TransactionRow({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final color = switch (transaction.status) {
      'paid' => AppColors.successLight,
      'failed' => AppColors.errorLight,
      'refunded' => AppColors.warning,
      _ => AppColors.textSecondary,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: CorvusSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description.isEmpty
                      ? 'Suscripción Atelier'
                      : transaction.description,
                  style: CorvusType.body.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  formatShortDate(transaction.occurredAt),
                  style: CorvusType.muted,
                ),
              ],
            ),
          ),
          const SizedBox(width: CorvusSpacing.md),
          Text(
            formatMoney(transaction.value, transaction.currency),
            style: CorvusType.body.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (transaction.invoiceUrl != null) ...[
            const SizedBox(width: CorvusSpacing.sm),
            IconButton(
              iconSize: 15,
              tooltip: 'Ver factura',
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () {},
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanActionsSection extends StatelessWidget {
  final SubscriptionState subscription;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onReactivate;

  const _PlanActionsSection({
    required this.subscription,
    required this.busy,
    required this.onCancel,
    required this.onReactivate,
  });

  @override
  Widget build(BuildContext context) {
    return CorvusPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CorvusSectionLabel(label: 'Tu suscripción'),
          const SizedBox(height: CorvusSpacing.lg),
          Wrap(
            spacing: CorvusSpacing.sm,
            runSpacing: CorvusSpacing.sm,
            children: [
              OutlinedButton(
                onPressed: () => context.push('/plans'),
                child: Text(
                  subscription.isFree ? 'Ver planes' : 'Cambiar de plan',
                ),
              ),
              if (!subscription.isFree)
                if (subscription.willEnd)
                  FilledButton(
                    onPressed: busy ? null : onReactivate,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.background,
                    ),
                    child: const Text('Reactivar'),
                  )
                else
                  TextButton(
                    onPressed: busy ? null : onCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Cancelar suscripción'),
                  ),
            ],
          ),
          const SizedBox(height: CorvusSpacing.lg),
          Container(
            padding: const EdgeInsets.all(CorvusSpacing.md),
            decoration: BoxDecoration(
              color: CorvusSurfaces.fill(CorvusSurfaces.fillSubtle),
              borderRadius: BorderRadius.circular(CorvusRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined,
                    size: 15, color: AppColors.textMuted),
                const SizedBox(width: CorvusSpacing.sm),
                Expanded(
                  child: Text(
                    'Cancelar nunca borra contenido. Tus proyectos, mundos, '
                    'archivos y comentarios se conservan completos; solo se '
                    'pausan las funciones profesionales y las cargas nuevas si '
                    'quedas por encima de la cuota de Free.',
                    style: CorvusType.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
