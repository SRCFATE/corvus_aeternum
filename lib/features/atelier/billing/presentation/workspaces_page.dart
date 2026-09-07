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
import '../services/workspace_service.dart';
import '../widgets/upgrade_prompt.dart';

/// Los espacios de trabajo de Atelier Teams.
///
/// Un espacio es un estudio: gente distinta con permisos distintos sobre los
/// mismos proyectos. Esta pantalla es la puerta —crear, entrar, aceptar una
/// invitación— y la administración de cada uno vive en su detalle.
///
/// Las invitaciones van arriba del todo y no debajo de la lista: una
/// invitación caduca a los catorce días, así que enterrarla sería perder gente.
class WorkspacesPage extends StatefulWidget {
  const WorkspacesPage({super.key});

  @override
  State<WorkspacesPage> createState() => _WorkspacesPageState();
}

class _WorkspacesPageState extends State<WorkspacesPage> {
  final _service = WorkspaceService();

  List<WorkspaceInvitation> _invitations = const [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final invitations = await _service.pendingInvitations();
      if (!mounted) return;
      setState(() {
        _invitations = invitations;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('No se pudieron leer las invitaciones. $error');
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _create() async {
    final entitlements = context.read<EntitlementProvider>();
    final service = entitlements.service;

    // Se comprueba aquí para dar el mensaje bueno, pero la RPC lo vuelve a
    // comprobar: esta pantalla no es la que decide.
    final check = service.canUse(
      AtelierFeature.workspacesMax,
      currentCount: entitlements.workspaces.where((w) => w.isOwner).length,
    );

    if (!check.allowed) {
      await showUpgradePrompt(
        context,
        featureKey: AtelierFeature.workspace,
        title: 'Espacios de trabajo',
        description:
            'Un espacio de trabajo reúne a tu estudio alrededor de los mismos '
            'proyectos, con roles y permisos por persona.',
        check: check,
        surface: 'workspaces',
      );
      return;
    }

    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Nuevo espacio de trabajo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre del estudio o editorial',
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (name == null || name.trim().isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      await _service.createWorkspace(name.trim());
      if (!mounted) return;
      await context.read<EntitlementProvider>().refresh();
      if (!mounted) return;
      _message('Espacio creado.');
    } on CorvusRpcException catch (error) {
      if (mounted) _message(error.message);
    } catch (error) {
      if (mounted) _message('No se pudo crear el espacio. $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respond(WorkspaceInvitation invitation, bool accept) async {
    setState(() => _busy = true);
    try {
      await _service.respondInvitation(invitation.id, accept: accept);
      if (!mounted) return;
      await context.read<EntitlementProvider>().refresh();
      if (!mounted) return;
      _message(accept ? 'Ya formas parte del espacio.' : 'Invitación rechazada.');
      await _load();
    } on CorvusRpcException catch (error) {
      if (mounted) _message(error.message);
    } catch (error) {
      if (mounted) _message('No se pudo responder. $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entitlements = context.watch<EntitlementProvider>();
    final workspaces = entitlements.workspaces;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Espacios de trabajo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/atelier'),
        ),
      ),
      body: _loading
          ? const Center(child: CorvusCrowLoader())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: CorvusReadingPage(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_invitations.isNotEmpty) ...[
                      const CorvusSectionLabel(label: 'Te han invitado'),
                      const SizedBox(height: CorvusSpacing.md),
                      for (final invitation in _invitations) ...[
                        _InvitationCard(
                          invitation: invitation,
                          busy: _busy,
                          onRespond: (accept) => _respond(invitation, accept),
                        ),
                        const SizedBox(height: CorvusSpacing.md),
                      ],
                      const SizedBox(height: CorvusSpacing.xl),
                    ],
                    Row(
                      children: [
                        const Expanded(
                          child: CorvusSectionLabel(label: 'Tus espacios'),
                        ),
                        FilledButton.icon(
                          onPressed: _busy ? null : _create,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Nuevo espacio'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.secondaryLight,
                            foregroundColor: AppColors.background,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: CorvusSpacing.lg),
                    if (workspaces.isEmpty)
                      const _NoWorkspacesYet()
                    else
                      for (final workspace in workspaces) ...[
                        _WorkspaceCard(workspace: workspace),
                        const SizedBox(height: CorvusSpacing.md),
                      ],
                    const SizedBox(height: CorvusSpacing.section),
                  ],
                ),
              ),
            ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  final WorkspaceInvitation invitation;
  final bool busy;
  final ValueChanged<bool> onRespond;

  const _InvitationCard({
    required this.invitation,
    required this.busy,
    required this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    return CorvusPanel(
      accent: AppColors.gold,
      raised: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(invitation.workspaceName, style: CorvusType.subtitle),
          const SizedBox(height: CorvusSpacing.xs),
          Text(
            'Te invitan como ${_roleName(invitation.roleKey)}.',
            style: CorvusType.body,
          ),
          if (invitation.message.isNotEmpty) ...[
            const SizedBox(height: CorvusSpacing.sm),
            Text('«${invitation.message}»', style: CorvusType.muted),
          ],
          const SizedBox(height: CorvusSpacing.lg),
          Row(
            children: [
              FilledButton(
                onPressed: busy ? null : () => onRespond(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.background,
                ),
                child: const Text('Aceptar'),
              ),
              const SizedBox(width: CorvusSpacing.sm),
              TextButton(
                onPressed: busy ? null : () => onRespond(false),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                child: const Text('Ahora no'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  final WorkspaceSummary workspace;

  const _WorkspaceCard({required this.workspace});

  @override
  Widget build(BuildContext context) {
    return CorvusPanel(
      accent: workspace.planCode == PlanCode.teams
          ? AppColors.secondaryLight
          : null,
      onTap: () => context.push('/workspaces/${workspace.id}'),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: CorvusSurfaces.fill(CorvusSurfaces.fillRaised),
              borderRadius: BorderRadius.circular(CorvusRadius.md),
            ),
            child: Text(
              workspace.name.isEmpty ? '?' : workspace.name[0].toUpperCase(),
              style: CorvusType.subtitle,
            ),
          ),
          const SizedBox(width: CorvusSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(workspace.name, style: CorvusType.subtitle),
                const SizedBox(height: 2),
                Text(
                  '${_roleName(workspace.roleKey)} · @${workspace.slug}',
                  style: CorvusType.muted,
                ),
              ],
            ),
          ),
          if (workspace.planCode != PlanCode.teams)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(CorvusRadius.pill),
              ),
              child: Text(
                'SIN TEAMS',
                style: CorvusType.eyebrow(AppColors.warning),
              ),
            ),
          const SizedBox(width: CorvusSpacing.sm),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _NoWorkspacesYet extends StatelessWidget {
  const _NoWorkspacesYet();

  @override
  Widget build(BuildContext context) {
    return CorvusPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Todavía trabajas en solitario', style: CorvusType.subtitle),
          const SizedBox(height: CorvusSpacing.sm),
          Text(
            'Un espacio de trabajo reúne a un estudio, una editorial o un '
            'colectivo alrededor de los mismos proyectos, cada quien con su '
            'papel. Tu taller personal sigue siendo tuyo y no se mezcla.',
            style: CorvusType.body,
          ),
        ],
      ),
    );
  }
}

/// Los nombres de rol que ve la gente. Vienen del catálogo del servidor, pero
/// para una etiqueta suelta no vale la pena una consulta.
String _roleName(String key) => switch (key) {
      'owner' => 'Propietario',
      'admin' => 'Administrador',
      'editor' => 'Editor',
      'writer' => 'Autor',
      'reviewer' => 'Revisor',
      'viewer' => 'Lector',
      _ => key,
    };

String roleDisplayName(String key) => _roleName(key);
