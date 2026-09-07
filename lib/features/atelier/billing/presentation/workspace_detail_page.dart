import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/rpc_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/corvus_design.dart';
import '../../../../providers/entitlement_provider.dart';
import '../../../../shared/layout/corvus_page.dart';
import '../../../../shared/widgets/corvus_crow_animations.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../domain/billing_models.dart';
import '../domain/feature_keys.dart';
import '../services/workspace_service.dart';
import '../widgets/usage_indicator.dart';
import 'workspaces_page.dart';

/// La administración de un espacio de trabajo.
///
/// Cada control aparece según la capacidad de quien mira, no según su rol:
/// invitar exige `member.invite`, cambiar papeles exige `member.manage`, la
/// facturación exige `billing.manage`. Así un rol personalizado con permisos
/// a medida se comporta bien sin que esta pantalla sepa que existe.
class WorkspaceDetailPage extends StatefulWidget {
  final String workspaceId;

  const WorkspaceDetailPage({super.key, required this.workspaceId});

  @override
  State<WorkspaceDetailPage> createState() => _WorkspaceDetailPageState();
}

class _WorkspaceDetailPageState extends State<WorkspaceDetailPage> {
  final _service = WorkspaceService();

  List<WorkspaceMember> _members = const [];
  List<WorkspaceRole> _roles = const [];
  Entitlements? _entitlements;
  UsageSnapshot _usage = UsageSnapshot.empty;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final entitlements =
          await _service.workspaceEntitlements(widget.workspaceId);
      final members = await _service.members(widget.workspaceId);
      final roles = await _service.roles(widget.workspaceId);

      if (!mounted) return;
      setState(() {
        _entitlements = entitlements;
        _members = members;
        _roles = roles;
        _loading = false;
      });

      // El consumo del espacio es informativo: que falle no rompe la pantalla.
      try {
        final usage = await _loadUsage();
        if (mounted) setState(() => _usage = usage);
      } catch (_) {
        // Silencio deliberado.
      }
    } on CorvusRpcException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
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

  Future<UsageSnapshot> _loadUsage() async {
    final provider = context.read<EntitlementProvider>();
    await provider.refreshUsage(workspaceId: widget.workspaceId);
    return provider.usage;
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      _message(success);
      await _load();
    } on CorvusRpcException catch (error) {
      if (mounted) _message(error.message);
    } catch (error) {
      if (mounted) _message('No se pudo completar la operación. $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite() async {
    final emailController = TextEditingController();
    var roleKey = 'writer';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Invitar a alguien'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Correo'),
              ),
              const SizedBox(height: CorvusSpacing.lg),
              DropdownButtonFormField<String>(
                initialValue: roleKey,
                decoration: const InputDecoration(labelText: 'Papel'),
                items: [
                  for (final role in _roles)
                    DropdownMenuItem(
                      value: role.key,
                      child: Text(role.name),
                    ),
                ],
                onChanged: (value) =>
                    setDialogState(() => roleKey = value ?? roleKey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Invitar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final email = emailController.text.trim();
    if (email.isEmpty) {
      _message('Indica el correo de quien quieres invitar.');
      return;
    }

    await _run(
      () => _service
          .invite(
            workspaceId: widget.workspaceId,
            email: email,
            roleKey: roleKey,
          )
          .then((_) {}),
      'Invitación enviada a $email.',
    );
  }

  Future<void> _confirmRemove(WorkspaceMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Retirar a ${member.displayName}'),
        content: const Text(
          'Pierde el acceso al espacio, pero nada de lo que escribió se borra: '
          'sus capítulos, fichas y comentarios siguen siendo del proyecto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _run(
      () => _service.removeMember(
        workspaceId: widget.workspaceId,
        profileId: member.profileId,
      ),
      '${member.displayName} ya no forma parte del espacio.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = context
        .watch<EntitlementProvider>()
        .entitlements
        .workspaceById(widget.workspaceId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(summary?.name ?? 'Espacio de trabajo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/workspaces'),
        ),
      ),
      body: _loading
          ? const Center(child: CorvusCrowLoader())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(CorvusSpacing.xl),
                    child: Text(_error!, style: CorvusType.body),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: CorvusReadingPage(child: _content(summary)),
                ),
    );
  }

  Widget _content(WorkspaceSummary? summary) {
    final capabilities = summary?.capabilities ?? const <String>[];
    final canInvite = capabilities.contains(AtelierCapability.memberInvite);
    final canManage = capabilities.contains(AtelierCapability.memberManage);
    final canRemove = capabilities.contains(AtelierCapability.memberRemove);
    final canBill = capabilities.contains(AtelierCapability.billingManage);

    final seats = _entitlements?.limit(AtelierFeature.workspaceSeatsMax) ?? 0;
    final planCode = _entitlements?.subscription.planCode ?? 'free';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CorvusPanel(
          accent: AppColors.secondaryLight,
          raised: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ESPACIO DE TRABAJO',
                style: CorvusType.eyebrow(AppColors.secondaryLight),
              ),
              const SizedBox(height: CorvusSpacing.md),
              Text(summary?.name ?? '—', style: CorvusType.title),
              const SizedBox(height: CorvusSpacing.sm),
              Text(
                summary?.planCode == PlanCode.teams
                    ? 'Atelier Teams activo en este espacio.'
                    : 'Este espacio todavía no tiene Teams contratado: sus '
                        'miembros trabajan con sus derechos personales.',
                style: CorvusType.body,
              ),
              const SizedBox(height: CorvusSpacing.lg),
              UsageIndicator(
                label: 'Miembros activos',
                used: _members.length,
                limit: seats,
                icon: Icons.group_outlined,
              ),
              const SizedBox(height: CorvusSpacing.lg),
              StorageIndicator(snapshot: _usage),
              if (canBill) ...[
                const SizedBox(height: CorvusSpacing.lg),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(
                      '/settings/billing?workspace=${widget.workspaceId}',
                    ),
                    icon: const Icon(Icons.receipt_long_outlined, size: 15),
                    label: Text(
                      planCode == PlanCode.teams
                          ? 'Facturación del espacio'
                          : 'Contratar Teams para este espacio',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: CorvusSpacing.xl),
        Row(
          children: [
            Expanded(
              child: CorvusSectionLabel(
                label: 'Miembros',
                count: _members.length,
              ),
            ),
            if (canInvite)
              TextButton.icon(
                onPressed: _busy ? null : _invite,
                icon: const Icon(Icons.person_add_alt_rounded, size: 15),
                label: const Text('Invitar'),
              ),
          ],
        ),
        const SizedBox(height: CorvusSpacing.md),
        for (final member in _members) ...[
          _MemberRow(
            member: member,
            roles: _roles,
            isOwner: member.roleKey == 'owner',
            canManage: canManage,
            canRemove: canRemove,
            busy: _busy,
            onRoleChanged: (roleKey) => _run(
              () => _service.setMemberRole(
                workspaceId: widget.workspaceId,
                profileId: member.profileId,
                roleKey: roleKey,
              ),
              'Papel actualizado.',
            ),
            onRemove: () => _confirmRemove(member),
          ),
          const SizedBox(height: CorvusSpacing.sm),
        ],
        const SizedBox(height: CorvusSpacing.xl),
        _CapabilitiesNote(capabilities: capabilities),
        const SizedBox(height: CorvusSpacing.section),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  final WorkspaceMember member;
  final List<WorkspaceRole> roles;
  final bool isOwner;
  final bool canManage;
  final bool canRemove;
  final bool busy;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onRemove;

  const _MemberRow({
    required this.member,
    required this.roles,
    required this.isOwner,
    required this.canManage,
    required this.canRemove,
    required this.busy,
    required this.onRoleChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // El propietario no se degrada ni se retira desde aquí: el servidor lo
    // rechazaría, y ofrecerlo sería enseñar un botón que no funciona.
    final editable = canManage && !isOwner;

    return CorvusPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: CorvusSpacing.lg,
        vertical: CorvusSpacing.md,
      ),
      child: Row(
        children: [
          UserAvatar(
            imageUrl: member.avatarUrl,
            displayName:
                member.displayName.isEmpty ? member.username : member.displayName,
            radius: 17,
          ),
          const SizedBox(width: CorvusSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName.isEmpty
                      ? '@${member.username}'
                      : member.displayName,
                  style: CorvusType.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('@${member.username}', style: CorvusType.muted),
              ],
            ),
          ),
          if (editable)
            DropdownButton<String>(
              value: member.roleKey,
              underline: const SizedBox.shrink(),
              dropdownColor: AppColors.cardElevated,
              style: CorvusType.muted,
              items: [
                for (final role in roles)
                  if (role.key != 'owner')
                    DropdownMenuItem(
                      value: role.key,
                      child: Text(role.name),
                    ),
              ],
              onChanged: busy
                  ? null
                  : (value) {
                      if (value != null && value != member.roleKey) {
                        onRoleChanged(value);
                      }
                    },
            )
          else
            Text(roleDisplayName(member.roleKey), style: CorvusType.muted),
          if (canRemove && !isOwner) ...[
            const SizedBox(width: CorvusSpacing.sm),
            IconButton(
              iconSize: 16,
              tooltip: 'Retirar del espacio',
              icon: const Icon(Icons.person_remove_outlined),
              onPressed: busy ? null : onRemove,
            ),
          ],
        ],
      ),
    );
  }
}

/// Lo que puede hacer quien mira, dicho sin rodeos. Un permiso es información
/// que la gente merece ver, no un secreto de la administración.
class _CapabilitiesNote extends StatelessWidget {
  final List<String> capabilities;

  const _CapabilitiesNote({required this.capabilities});

  static const _labels = <String, String>{
    AtelierCapability.projectRead: 'Leer los proyectos',
    AtelierCapability.projectWrite: 'Escribir en los proyectos',
    AtelierCapability.projectCreate: 'Crear proyectos',
    AtelierCapability.projectDelete: 'Eliminar proyectos',
    AtelierCapability.memberInvite: 'Invitar personas',
    AtelierCapability.memberRemove: 'Retirar personas',
    AtelierCapability.memberManage: 'Cambiar papeles',
    AtelierCapability.roleManage: 'Definir papeles propios',
    AtelierCapability.billingManage: 'Gestionar la facturación',
    AtelierCapability.exportCreate: 'Exportar',
    AtelierCapability.commentCreate: 'Comentar',
    AtelierCapability.commentResolve: 'Resolver comentarios',
    AtelierCapability.taskAssign: 'Asignar tareas',
    AtelierCapability.automationManage: 'Gestionar automatizaciones',
    AtelierCapability.templateManage: 'Gestionar plantillas',
    AtelierCapability.settingsManage: 'Cambiar los ajustes',
    AtelierCapability.workspaceManage: 'Administrar el espacio',
    AtelierCapability.auditRead: 'Ver el registro de auditoría',
  };

  @override
  Widget build(BuildContext context) {
    if (capabilities.isEmpty) return const SizedBox.shrink();

    return CorvusPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CorvusSectionLabel(label: 'Lo que puedes hacer aquí'),
          const SizedBox(height: CorvusSpacing.md),
          Wrap(
            spacing: CorvusSpacing.sm,
            runSpacing: CorvusSpacing.sm,
            children: [
              for (final capability in capabilities)
                if (_labels.containsKey(capability))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: CorvusSurfaces.fill(CorvusSurfaces.fillBase),
                      borderRadius: BorderRadius.circular(CorvusRadius.pill),
                    ),
                    child: Text(_labels[capability]!, style: CorvusType.muted),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}
