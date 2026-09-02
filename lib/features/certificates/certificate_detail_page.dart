import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/aeternum_certificate.dart';
import '../../providers/auth_provider.dart';
import '../../services/certificate_service.dart';
import '../../shared/layout/corvus_page.dart';
import '../../shared/widgets/corvus_empty_state.dart';
import '../../shared/widgets/corvus_markdown_preview.dart';

class CertificateDetailPage extends StatefulWidget {
  final String certificateNumber;

  const CertificateDetailPage({
    super.key,
    required this.certificateNumber,
  });

  @override
  State<CertificateDetailPage> createState() => _CertificateDetailPageState();
}

class _CertificateDetailPageState extends State<CertificateDetailPage> {
  final _certificateService = CertificateService();
  AeternumCertificate? _certificate;
  bool _isLoading = true;
  bool _isSaving = false;

  String? get _profileId => context.read<AuthProvider>().profile?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final certificate = await _certificateService.verifyCertificate(
        widget.certificateNumber,
      );
      if (!mounted) return;
      setState(() {
        _certificate = certificate;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleOwnerVisibility(bool value) async {
    final certificate = _certificate;
    if (certificate == null || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await _certificateService.setOwnerPublic(certificate.id, value);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _revoke() async {
    final certificate = _certificate;
    if (certificate == null || _isSaving) return;
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revocar certificado'),
        content: CorvusMarkdownFieldPreview(
          controller: controller,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Motivo',
              hintText: 'Describe por qué el registro deja de ser válido.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Revocar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    setState(() => _isSaving = true);
    try {
      await _certificateService.revokeCertificate(certificate.id, reason);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    final certificate = _certificate;
    if (certificate == null) return _buildUnavailable();
    final isOwner = certificate.ownerProfileId == _profileId;
    final isIssuer = certificate.issuerProfileId == _profileId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Certificado Aeternum'),
        actions: [
          IconButton(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: certificate.certificateNumber),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Número copiado')),
              );
            },
            tooltip: 'Copiar número',
            icon: const Icon(Icons.copy_rounded),
          ),
          if (isIssuer && certificate.isValid)
            IconButton(
              onPressed: _isSaving ? null : _revoke,
              tooltip: 'Revocar certificado',
              icon: const Icon(Icons.block_rounded),
            ),
        ],
      ),
      body: CorvusReadingPage(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 72),
        child: ListView(
          children: [
            _buildCertificate(certificate),
            if (isOwner && certificate.isValid) ...[
              const SizedBox(height: 14),
              _buildPrivacyControl(certificate),
            ],
            if (certificate.events.isNotEmpty) ...[
              const SizedBox(height: 28),
              _buildProvenance(certificate),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCertificate(AeternumCertificate certificate) {
    final facts = <(String, String)>[
      ('Artista', certificate.artistSnapshot),
      ('Edición', certificate.editionLabel),
      if (certificate.year != null) ('Año', '${certificate.year}'),
      if (certificate.discipline.isNotEmpty)
        ('Disciplina', certificate.discipline),
      if (certificate.technique.isNotEmpty) ('Técnica', certificate.technique),
      if (certificate.dimensions.isNotEmpty)
        ('Dimensiones', certificate.dimensions),
      ('Titular', certificate.ownerLabel),
      ('Emisión', DateFormat('dd MMM yyyy').format(certificate.issuedAt)),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: certificate.isValid
              ? AppColors.gold.withValues(alpha: 0.45)
              : AppColors.error.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (certificate.coverUrl?.isNotEmpty == true)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 8,
                child: CachedNetworkImage(
                  imageUrl: certificate.coverUrl!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      certificate.isValid
                          ? Icons.verified_rounded
                          : Icons.gpp_bad_rounded,
                      color: certificate.isValid
                          ? AppColors.gold
                          : AppColors.errorLight,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        certificate.certificateNumber,
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Text(
                      certificate.statusLabel.toUpperCase(),
                      style: TextStyle(
                        color: certificate.isValid
                            ? AppColors.successLight
                            : AppColors.errorLight,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  certificate.titleSnapshot,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 26),
                Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: facts
                      .map(
                        (fact) => SizedBox(
                          width: 210,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fact.$1.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                fact.$2,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.035),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.fingerprint_rounded,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          certificate.verificationCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyControl(AeternumCertificate certificate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: certificate.ownerPublic,
        onChanged: _isSaving ? null : _toggleOwnerVisibility,
        title: const Text('Titular público'),
        subtitle: const Text(
          'Permite mostrar tu nombre en la consulta pública.',
        ),
      ),
    );
  }

  Widget _buildProvenance(AeternumCertificate certificate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PROCEDENCIA',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        ...certificate.events.map(
          (event) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.history_rounded,
                  color: AppColors.gold,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.label,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (event.note.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          event.note,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(event.createdAt),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnavailable() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(),
      body: CorvusEmptyState(
        icon: Icons.gpp_bad_outlined,
        title: 'Certificado no encontrado',
        subtitle: 'El número no existe en el registro Aeternum.',
        actionText: 'Volver',
        onAction: () => context.canPop() ? context.pop() : context.go('/discover'),
      ),
    );
  }
}
