import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/aeternum_certificate.dart';
import '../../models/work.dart';
import '../../providers/auth_provider.dart';
import '../../services/certificate_service.dart';
import '../../shared/layout/corvus_page.dart';
import '../../shared/widgets/corvus_empty_state.dart';

class CertificatesPage extends StatefulWidget {
  const CertificatesPage({super.key});

  @override
  State<CertificatesPage> createState() => _CertificatesPageState();
}

class _CertificatesPageState extends State<CertificatesPage> {
  final _certificateService = CertificateService();
  List<AeternumCertificate> _certificates = [];
  List<Work> _works = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profileId = context.read<AuthProvider>().profile?.id;
    if (profileId == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        _certificateService.getMyCertificates(profileId),
        _certificateService.getEligibleWorks(profileId),
      ]);
      if (!mounted) return;
      setState(() {
        _certificates = results[0] as List<AeternumCertificate>;
        _works = results[1] as List<Work>;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No fue posible abrir el registro de certificados.';
      });
    }
  }

  Future<void> _openIssueDialog() async {
    if (_works.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Publica una obra antes de emitir un certificado.'),
        ),
      );
      return;
    }
    final number = await showDialog<String>(
      context: context,
      builder: (_) => _IssueCertificateDialog(
        works: _works,
        certificateService: _certificateService,
      ),
    );
    if (number == null || !mounted) return;
    await _load();
    if (mounted) context.push('/certificate/$number');
  }

  Future<void> _openVerificationDialog() async {
    final controller = TextEditingController();
    final number = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verificar certificado'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Número de certificado',
            hintText: 'CA-2026-000001',
            prefixIcon: Icon(Icons.verified_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim().toUpperCase();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Verificar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (number != null && mounted) context.push('/certificate/$number');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CorvusPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeArea(bottom: false, child: _buildHeader()),
            const Divider(height: 1, color: AppColors.border),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REGISTRO AETERNUM',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Certificados',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _openVerificationDialog,
            tooltip: 'Verificar certificado',
            icon: const Icon(Icons.search_rounded),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _openIssueDialog,
            tooltip: 'Emitir certificado',
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_errorMessage != null) {
      return CorvusEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Registro no disponible',
        subtitle: _errorMessage!,
        actionText: 'Reintentar',
        onAction: _load,
      );
    }
    if (_certificates.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 72),
          children: [
            CorvusEmptyState(
              icon: Icons.verified_outlined,
              title: 'Aún no hay certificados',
              subtitle: 'Emite el registro verificable de una obra publicada.',
              actionText: 'Emitir certificado',
              onAction: _openIssueDialog,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 96),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 440,
          mainAxisExtent: 230,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: _certificates.length,
        itemBuilder: (_, index) => _CertificateCard(
          certificate: _certificates[index],
          onTap: () => context.push(
            '/certificate/${_certificates[index].certificateNumber}',
          ),
        ),
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  final AeternumCertificate certificate;
  final VoidCallback onTap;

  const _CertificateCard({required this.certificate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: certificate.isValid
              ? AppColors.gold.withValues(alpha: 0.35)
              : AppColors.error.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 140,
              child: certificate.coverUrl?.isNotEmpty == true
                  ? CachedNetworkImage(
                      imageUrl: certificate.coverUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: AppColors.overlay,
                      child: const Icon(
                        Icons.verified_outlined,
                        color: AppColors.gold,
                        size: 38,
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      certificate.certificateNumber,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      certificate.titleSnapshot,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      certificate.artistSnapshot,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      certificate.editionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${certificate.statusLabel} · ${DateFormat('yyyy').format(certificate.issuedAt)}',
                      style: TextStyle(
                        color: certificate.isValid
                            ? AppColors.successLight
                            : AppColors.errorLight,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueCertificateDialog extends StatefulWidget {
  final List<Work> works;
  final CertificateService certificateService;

  const _IssueCertificateDialog({
    required this.works,
    required this.certificateService,
  });

  @override
  State<_IssueCertificateDialog> createState() =>
      _IssueCertificateDialogState();
}

class _IssueCertificateDialogState extends State<_IssueCertificateDialog> {
  final _editionController = TextEditingController(text: 'Original');
  late String _workId = widget.works.first.id;
  bool _ownerPublic = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _editionController.dispose();
    super.dispose();
  }

  Future<void> _issue() async {
    final edition = _editionController.text.trim();
    if (edition.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final number = await widget.certificateService.issueCertificate(
        workId: _workId,
        editionLabel: edition,
        ownerPublic: _ownerPublic,
      );
      if (mounted) Navigator.pop(context, number);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Emitir certificado'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _workId,
              decoration: const InputDecoration(
                labelText: 'Obra',
                prefixIcon: Icon(Icons.image_outlined),
              ),
              items: widget.works
                  .map(
                    (work) => DropdownMenuItem(
                      value: work.id,
                      child: Text(
                        work.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _workId = value);
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _editionController,
              decoration: const InputDecoration(
                labelText: 'Edición',
                hintText: 'Original, 03/25, prueba de artista...',
                prefixIcon: Icon(Icons.numbers_rounded),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _ownerPublic,
              onChanged: (value) => setState(() => _ownerPublic = value),
              contentPadding: EdgeInsets.zero,
              title: const Text('Mostrar titular públicamente'),
              subtitle: const Text(
                'La autenticidad siempre será pública; tu identidad puede permanecer privada.',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _issue,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.verified_rounded, size: 18),
          label: Text(_isSaving ? 'Emitiendo...' : 'Emitir'),
        ),
      ],
    );
  }
}
