import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/corvus_design.dart';
import '../../models/conspiracy_membership.dart';
import '../../models/work.dart';
import '../../services/conspiracy_service.dart';
import '../../services/work_service.dart';
import '../../shared/widgets/corvus_crow_animations.dart';
import '../../shared/widgets/user_avatar.dart';

/// Ritos de las casas que no se eligen: se entra por invitación o por
/// respaldo de quien ya pertenece.
///
/// - **Pacto de Sangre**: un miembro pronuncia un nombre una vez al año.
/// - **Primer Cuervo**: un reconocido respalda a un candidato con evidencia.

// ─── Panel de invitaciones pendientes ─────────────────────────────────────────

class ConspiracyRitualsPanel extends StatefulWidget {
  final VoidCallback? onChanged;

  const ConspiracyRitualsPanel({super.key, this.onChanged});

  @override
  State<ConspiracyRitualsPanel> createState() => _ConspiracyRitualsPanelState();
}

class _ConspiracyRitualsPanelState extends State<ConspiracyRitualsPanel> {
  final _service = ConspiracyService();
  List<ConspiracyInvitation> _invitations = const [];
  bool _loaded = false;
  String? _actingOn;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _service.pendingInvitations();
      if (mounted) setState(() { _invitations = list; _loaded = true; });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _respond(ConspiracyInvitation invitation, bool accept) async {
    setState(() => _actingOn = invitation.id);
    try {
      final result = await _service.respondToBloodPactInvitation(
        invitationId: invitation.id,
        accept: accept,
      );
      if (!mounted) return;
      if (!result.ok) {
        _message(ConspiracyService.messageFor(result.reasonCode));
      } else {
        if (accept) await showCrowFlight(context);
        if (!mounted) return;
        _message(accept
            ? 'El ${invitation.shortHouseName} te reconoce. El pacto queda sellado.'
            : 'Has dejado pasar la invitación.');
        widget.onChanged?.call();
      }
      await _load();
    } catch (error) {
      if (mounted) _message('El rito no pudo completarse: $error');
    } finally {
      if (mounted) setState(() => _actingOn = null);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: AppColors.card,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _invitations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CorvusSectionLabel(
          label: 'Ritos pendientes',
          count: _invitations.length,
          accent: _invitations.first.accentColor,
        ),
        const SizedBox(height: CorvusSpacing.md),
        ..._invitations.map((inv) => Padding(
              padding: const EdgeInsets.only(bottom: CorvusSpacing.md),
              child: _InvitationCard(
                invitation: inv,
                busy: _actingOn == inv.id,
                onAccept: () => _respond(inv, true),
                onDecline: () => _respond(inv, false),
              ),
            )),
        const SizedBox(height: CorvusSpacing.lg),
      ],
    );
  }
}

class _InvitationCard extends StatelessWidget {
  final ConspiracyInvitation invitation;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InvitationCard({
    required this.invitation,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final accent = invitation.accentColor;
    final days = invitation.daysLeft;

    return CorvusPanel(
      accent: accent,
      raised: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                imageUrl: invitation.inviterAvatarUrl,
                displayName: invitation.inviterName,
                radius: 18,
              ),
              const SizedBox(width: CorvusSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INVITACIÓN · ${invitation.shortHouseName.toUpperCase()}',
                      style: CorvusType.eyebrow(accent),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${invitation.inviterLabel} ha pronunciado tu nombre.',
                      style: CorvusType.subtitle,
                    ),
                  ],
                ),
              ),
              if (days != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: CorvusSurfaces.fill(CorvusSurfaces.fillBase),
                    borderRadius: BorderRadius.circular(CorvusRadius.pill),
                  ),
                  child: Text(
                    days == 0 ? 'expira hoy' : '$days d',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (invitation.note.trim().isNotEmpty) ...[
            const SizedBox(height: CorvusSpacing.md),
            Container(
              padding: const EdgeInsets.only(left: CorvusSpacing.md),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                      color: accent.withValues(alpha: 0.45), width: 2),
                ),
              ),
              child: Text(invitation.note.trim(),
                  style: CorvusType.body.copyWith(
                      fontStyle: FontStyle.italic)),
            ),
          ],
          const SizedBox(height: CorvusSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.55),
                    side: BorderSide(
                        color: CorvusSurfaces.fill(
                            CorvusSurfaces.borderStrong)),
                  ),
                  child: const Text('Dejar pasar'),
                ),
              ),
              const SizedBox(width: CorvusSpacing.md),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: busy ? null : onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Sellar el pacto'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Ritos que el usuario puede oficiar sobre otro artista ────────────────────

/// Abre la hoja de ritos disponibles hacia [targetProfileId]. Solo muestra los
/// que el usuario en sesión puede oficiar: pertenecer a la casa es el permiso.
Future<void> showConspiracyRitualsFor(
  BuildContext context, {
  required String targetProfileId,
  required String targetName,
}) async {
  final service = ConspiracyService();

  final results = await Future.wait([
    service.hasUnlocked('pacto_de_sangre'),
    service.hasUnlocked('primer_cuervo'),
  ]);
  final canInvite = results[0];
  final canEndorse = results[1];

  if (!context.mounted) return;

  if (!canInvite && !canEndorse) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
          'Los ritos se ofician desde dentro: aún no perteneces a una casa que los habilite.'),
      behavior: SnackBarBehavior.floating,
    ));
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(CorvusRadius.xl)),
    ),
    builder: (ctx) => _RitualSheet(
      targetProfileId: targetProfileId,
      targetName: targetName,
      canInvite: canInvite,
      canEndorse: canEndorse,
    ),
  );
}

class _RitualSheet extends StatefulWidget {
  final String targetProfileId;
  final String targetName;
  final bool canInvite;
  final bool canEndorse;

  const _RitualSheet({
    required this.targetProfileId,
    required this.targetName,
    required this.canInvite,
    required this.canEndorse,
  });

  @override
  State<_RitualSheet> createState() => _RitualSheetState();
}

class _RitualSheetState extends State<_RitualSheet> {
  final _service = ConspiracyService();
  final _workService = WorkService();
  final _noteController = TextEditingController();

  List<Work> _candidateWorks = const [];
  String? _evidenceWorkId;
  bool _loadingWorks = true;
  bool _busy = false;
  String? _ritual; // 'blood_pact' | 'first_crow'

  @override
  void initState() {
    super.initState();
    _ritual = widget.canInvite ? 'blood_pact' : 'first_crow';
    _loadWorks();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadWorks() async {
    try {
      // La evidencia debe ser obra publicada del candidato.
      final works =
          await _workService.getWorksByProfile(widget.targetProfileId, limit: 20);
      if (mounted) setState(() { _candidateWorks = works; _loadingWorks = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingWorks = false);
    }
  }

  bool get _canSubmit {
    if (_busy) return false;
    if (_ritual == 'first_crow') {
      // El respaldo exige obra concreta y una razón escrita.
      return _evidenceWorkId != null &&
          _noteController.text.trim().isNotEmpty;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    // Se capturan antes del await: la hoja se cierra al terminar el rito.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final result = _ritual == 'blood_pact'
          ? await _service.inviteToBloodPact(
              inviteeId: widget.targetProfileId,
              evidenceWorkId: _evidenceWorkId,
              note: _noteController.text.trim(),
            )
          : await _service.endorseFirstCrow(
              candidateId: widget.targetProfileId,
              evidenceWorkId: _evidenceWorkId!,
              note: _noteController.text.trim(),
            );

      if (!mounted) return;
      if (!result.ok) {
        setState(() => _busy = false);
        messenger.showSnackBar(SnackBar(
          content: Text(ConspiracyService.messageFor(result.reasonCode)),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }

      await showCrowFlight(context);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text(_ritual == 'blood_pact'
            ? 'Tu invitación anual fue pronunciada. Ahora le toca responder.'
            : 'Tu respaldo quedó inscrito en el registro.'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(
        content: Text('El rito no pudo completarse: $error'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBloodPact = _ritual == 'blood_pact';
    final accent = isBloodPact ? AppColors.primary : AppColors.gold;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      maxChildSize: 0.94,
      builder: (_, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(CorvusSpacing.xl, CorvusSpacing.md,
            CorvusSpacing.xl, CorvusSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: CorvusSpacing.xl),
            Text('OFICIAR UN RITO', style: CorvusType.eyebrow(accent)),
            const SizedBox(height: CorvusSpacing.sm),
            Text('Sobre ${widget.targetName}', style: CorvusType.title),
            const SizedBox(height: CorvusSpacing.xl),

            // Selector de rito, solo si el usuario puede oficiar ambos.
            if (widget.canInvite && widget.canEndorse) ...[
              Row(
                children: [
                  Expanded(
                    child: _RitualChoice(
                      label: 'Pacto de Sangre',
                      hint: 'Una invitación al año',
                      icon: Icons.bloodtype_rounded,
                      accent: AppColors.primary,
                      selected: isBloodPact,
                      onTap: () => setState(() => _ritual = 'blood_pact'),
                    ),
                  ),
                  const SizedBox(width: CorvusSpacing.md),
                  Expanded(
                    child: _RitualChoice(
                      label: 'Primer Cuervo',
                      hint: 'Respaldo con evidencia',
                      icon: Icons.visibility_rounded,
                      accent: AppColors.gold,
                      selected: !isBloodPact,
                      onTap: () => setState(() => _ritual = 'first_crow'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CorvusSpacing.xl),
            ],

            CorvusPanel(
              accent: accent,
              child: Text(
                isBloodPact
                    ? 'El Pacto de Sangre se hereda por reconocimiento. Solo puedes pronunciar un nombre por año, y la invitación pierde su pulso a los 30 días.'
                    : 'El Primer Cuervo no se pide: se respalda. El candidato debe llevar al menos dos años en el archivo y haber sostenido su obra en el tiempo.',
                style: CorvusType.body,
              ),
            ),
            const SizedBox(height: CorvusSpacing.xl),

            // Evidencia: obligatoria para el respaldo, opcional para el pacto.
            Text(
              isBloodPact ? 'Obra que lo justifica (opcional)' : 'Obra que respaldas',
              style: CorvusType.subtitle,
            ),
            const SizedBox(height: CorvusSpacing.md),
            if (_loadingWorks)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: CorvusSpacing.lg),
                child: Center(child: CorvusCrowLoader(size: 46)),
              )
            else if (_candidateWorks.isEmpty)
              Text('Este artista aún no tiene obra pública que citar.',
                  style: CorvusType.muted)
            else
              Wrap(
                spacing: CorvusSpacing.sm,
                runSpacing: CorvusSpacing.sm,
                children: _candidateWorks.map((w) {
                  final selected = _evidenceWorkId == w.id;
                  return GestureDetector(
                    onTap: () => setState(
                        () => _evidenceWorkId = selected ? null : w.id),
                    child: AnimatedContainer(
                      duration: CorvusMotion.fast,
                      constraints: const BoxConstraints(maxWidth: 240),
                      padding: const EdgeInsets.symmetric(
                          horizontal: CorvusSpacing.md, vertical: 9),
                      decoration: BoxDecoration(
                        color: selected
                            ? accent.withValues(alpha: 0.14)
                            : CorvusSurfaces.fill(CorvusSurfaces.fillBase),
                        borderRadius:
                            BorderRadius.circular(CorvusRadius.pill),
                        border: Border.all(
                          color: selected
                              ? accent.withValues(alpha: 0.55)
                              : CorvusSurfaces.fill(
                                  CorvusSurfaces.borderBase),
                        ),
                      ),
                      child: Text(
                        w.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? accent
                              : Colors.white.withValues(alpha: 0.62),
                          fontSize: 12.5,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: CorvusSpacing.xl),

            Text(
              isBloodPact ? 'Unas palabras (opcional)' : 'Razón del respaldo',
              style: CorvusType.subtitle,
            ),
            const SizedBox(height: CorvusSpacing.md),
            TextField(
              controller: _noteController,
              maxLines: 4,
              maxLength: isBloodPact ? 1000 : 1200,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14, height: 1.6),
              decoration: InputDecoration(
                hintText: isBloodPact
                    ? 'Por qué su obra merece cruzar este umbral…'
                    : 'Qué has visto sostenerse en su trabajo…',
              ),
            ),
            const SizedBox(height: CorvusSpacing.lg),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(isBloodPact
                        ? 'Pronunciar su nombre'
                        : 'Inscribir mi respaldo'),
              ),
            ),
            if (!_canSubmit && !_busy && !isBloodPact) ...[
              const SizedBox(height: CorvusSpacing.md),
              Text(
                'El respaldo exige una obra concreta y una razón escrita: queda en el registro con tu nombre.',
                style: CorvusType.muted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RitualChoice extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _RitualChoice({
    required this.label,
    required this.hint,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: CorvusMotion.fast,
        padding: const EdgeInsets.all(CorvusSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.12)
              : CorvusSurfaces.fill(CorvusSurfaces.fillSubtle),
          borderRadius: BorderRadius.circular(CorvusRadius.md),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.50)
                : CorvusSurfaces.fill(CorvusSurfaces.borderBase),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 18,
                color: selected
                    ? accent
                    : Colors.white.withValues(alpha: 0.40)),
            const SizedBox(height: CorvusSpacing.sm),
            Text(label,
                style: TextStyle(
                  color: selected
                      ? AppColors.textPrimary
                      : Colors.white.withValues(alpha: 0.62),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 2),
            Text(hint, style: CorvusType.muted.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
